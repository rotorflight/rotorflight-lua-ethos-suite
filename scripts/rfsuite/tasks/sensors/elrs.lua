--[[

 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 *
]] --
--
-- Rotorflight Custom Telemetry Decoder for ELRS (refactored)
-- Focus: less repetition, clearer structure, tiny perf wins
-- + Enhancement: refresh stale sensors every 0.5s to avoid invalidation
--

local arg = {...}
local config = arg[1]

local elrs = {}

-- used by sensors.lua to know if module has changed
elrs.name = "elrs"

---------------------------------------------------------------------
-- Crossfire access shims (keep exact runtime behaviour)
---------------------------------------------------------------------
if crsf.getSensor ~= nil then
    local sensor = crsf.getSensor()
    elrs.popFrame = function() return sensor:popFrame() end
    elrs.pushFrame = function(x, y) return sensor:pushFrame(x, y) end
else
    elrs.popFrame = function() return crsf.popFrame() end
    elrs.pushFrame = function(x, y) return crsf.pushFrame(x, y) end
end

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local sensors = { uid = {}, lastvalue = {}, lasttime = {} }
local rssiSensor = nil

local constants = {
    CRSF_FRAME_CUSTOM_TELEM = 0x88,
    FRAME_COUNT_ID = 0xEE01,
    FRAME_SKIP_ID  = 0xEE02,
}

elrs.telemetryFrameId    = 0
elrs.telemetryFrameSkip  = 0
elrs.telemetryFrameCount = 0

-- refresh stale sensors older than this many milliseconds
local REFRESH_INTERVAL_MS = 5000 -- 5s

---------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------
local function telemetryActive()
    return rfsuite and rfsuite.session and rfsuite.session.telemetryState == true
end

local function nowMs()
    -- os.clock() returns seconds as a floating-point number; multiply by 1000 for ms
    return math.floor(os.clock() * 1000)
end

local function resetSensors()
    sensors.uid, sensors.lastvalue, sensors.lasttime = {}, {}, {}
end

---------------------------------------------------------------------
-- Sensor creation / update helpers
---------------------------------------------------------------------
local function createTelemetrySensor(uid, name, unit, dec, value, min, max)
    if not telemetryActive() then return nil end

    sensors.uid[uid] = model.createSensor({ type = SENSOR_TYPE_DIY })
    local s = sensors.uid[uid]
    s:name(name)
    s:appId(uid)
    s:module(1)
    s:minimum(min or -1000000000)
    s:maximum(max or 2147483647)
    if dec then
        s:decimals(dec)
        s:protocolDecimals(dec)
    end
    if unit then
        s:unit(unit)
        s:protocolUnit(unit)
    end
    if value then s:value(value) end
    return s
end

local function getOrCreateSensor(uid, name, unit, dec, value, min, max)
    if not sensors.uid[uid] then
        sensors.uid[uid] = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = uid })
        if not sensors.uid[uid] then
            rfsuite.utils.log("Create sensor: " .. uid, "debug")
            createTelemetrySensor(uid, name, unit, dec, value, min, max)
        end
    end
    return sensors.uid[uid]
end

local function setTelemetryValue(uid, subid, instance, value, unit, dec, name, min, max)
    if not telemetryActive() then return end

    local s = getOrCreateSensor(uid, name, unit, dec, value, min, max)
    if s then
        local last = sensors.lastvalue[uid]
        -- Only write and bump lasttime when the value actually changes
        if last == nil or last ~= value then
            s:value(value)
            sensors.lastvalue[uid] = value
            sensors.lasttime[uid] = nowMs()
        end
        -- If the value didn't change, don't bump lasttime.
        -- This allows refreshStaleSensors() to re-apply the value periodically.
    end
end

-- re-apply last value for any sensor that hasn't updated recently
local function refreshStaleSensors()
    local now = nowMs()
    for uid, s in pairs(sensors.uid) do
        local last = sensors.lastvalue[uid]
        local lastt = sensors.lasttime[uid]
        if last and lastt and (now - lastt) > REFRESH_INTERVAL_MS then
            s:value(last)
            sensors.lasttime[uid] = now
        end
    end
end

---------------------------------------------------------------------
-- Decoders (generalized and thin wrappers)
---------------------------------------------------------------------
-- decInt: decode big-endian integer of arbitrary byte width; optional signed
local function decInt(data, pos, bytes, signed)
    local val = 0
    for i = 0, bytes - 1 do
        val = (val << 8) | data[pos + i]
    end
    if signed then
        local bits = bytes * 8
        local signBit = 1 << (bits - 1)
        if (val & signBit) ~= 0 then
            val = val - (1 << bits)
        end
    end
    return val, pos + bytes
end

local function decNil(_, pos) return nil, pos end

local function decU8(data, pos)  return decInt(data, pos, 1, false) end
local function decS8(data, pos)  return decInt(data, pos, 1, true)  end
local function decU16(data, pos) return decInt(data, pos, 2, false) end
local function decS16(data, pos) return decInt(data, pos, 2, true)  end
local function decU24(data, pos) return decInt(data, pos, 3, false) end
local function decS24(data, pos) return decInt(data, pos, 3, true)  end
local function decU32(data, pos) return decInt(data, pos, 4, false) end
local function decS32(data, pos) return decInt(data, pos, 4, true)  end

-- 12-bit packed helpers remain bespoke
local function decU12U12(data, pos)
    local a = ((data[pos] & 0x0F) << 8) | data[pos + 1]
    local b = ((data[pos] & 0xF0) << 4) | data[pos + 2]
    return a, b, pos + 3
end

local function decS12S12(data, pos)
    local a, b, ptr = decU12U12(data, pos)
    if a >= 0x800 then a = a - 0x1000 end
    if b >= 0x800 then b = b - 0x1000 end
    return a, b, ptr
end

-- cell voltage helpers
local function decCellV(data, pos)
    local val, ptr = decU8(data, pos)
    return (val > 0 and val + 200 or 0), ptr
end

local function decCells(data, pos)
    local cnt, val, vol
    cnt, pos = decU8(data, pos)
    setTelemetryValue(0x1020, 0, 0, cnt, UNIT_RAW, 0, "Cell Count", 0, 15)
    for i = 1, cnt do
        val, pos = decU8(data, pos)
        val = (val > 0 and val + 200 or 0)
        vol = (cnt << 24) | ((i - 1) << 16) | val
        setTelemetryValue(0x102F, 0, 0, vol, UNIT_CELLS, 2, "Cell Voltages", 0, 455)
    end
    return nil, pos
end

-- composite decoders write multiple values and return nil
local function decControl(data, pos)
    local r, p, y, c
    p, r, pos = decS12S12(data, pos)
    y, c, pos = decS12S12(data, pos)
    setTelemetryValue(0x1031, 0, 0, p,     UNIT_DEGREE, 2, "Pitch Control", -4500, 4500)
    setTelemetryValue(0x1032, 0, 0, r,     UNIT_DEGREE, 2, "Roll Control",  -4500, 4500)
    setTelemetryValue(0x1033, 0, 0, 3 * y, UNIT_DEGREE, 2, "Yaw Control",   -9000, 9000)
    setTelemetryValue(0x1034, 0, 0, c,     UNIT_DEGREE, 2, "Coll Control",  -4500, 4500)
    return nil, pos
end

local function decAttitude(data, pos)
    local p, r, y
    p, pos = decS16(data, pos)
    r, pos = decS16(data, pos)
    y, pos = decS16(data, pos)
    setTelemetryValue(0x1101, 0, 0, p, UNIT_DEGREE, 1, "Pitch Attitude", -1800, 3600)
    setTelemetryValue(0x1102, 0, 0, r, UNIT_DEGREE, 1, "Roll Attitude",  -1800, 3600)
    setTelemetryValue(0x1103, 0, 0, y, UNIT_DEGREE, 1, "Yaw Attitude",   -1800, 3600)
    return nil, pos
end

local function decAccel(data, pos)
    local x, y, z
    x, pos = decS16(data, pos)
    y, pos = decS16(data, pos)
    z, pos = decS16(data, pos)
    setTelemetryValue(0x1111, 0, 0, x, UNIT_G, 2, "Accel X", -4000, 4000)
    setTelemetryValue(0x1112, 0, 0, y, UNIT_G, 2, "Accel Y", -4000, 4000)
    setTelemetryValue(0x1113, 0, 0, z, UNIT_G, 2, "Accel Z", -4000, 4000)
    return nil, pos
end

local function decLatLong(data, pos)
    local lat, lon
    lat, pos = decS32(data, pos)
    lon, pos = decS32(data, pos)
    lat = math.floor(lat * 0.001)
    lon = math.floor(lon * 0.001)
    setTelemetryValue(0x1125, 0, 0, lat, UNIT_DEGREE, 4, "GPS Latitude",  -10000000000, 10000000000)
    setTelemetryValue(0x112B, 0, 0, lon, UNIT_DEGREE, 4, "GPS Longitude", -10000000000, 10000000000)
    return nil, pos
end

local function decAdjFunc(data, pos)
    local fun, val
    fun, pos = decU16(data, pos)
    val, pos = decS32(data, pos)
    setTelemetryValue(0x1221, 0, 0, fun, UNIT_RAW, 0, "Adj. Source", 0, 255)
    setTelemetryValue(0x1222, 0, 0, val, UNIT_RAW, 0, "Adj. Value")
    return nil, pos
end

---------------------------------------------------------------------
-- Sensor map (kept identical), then programmatically add Debug 0..7
---------------------------------------------------------------------
elrs.RFSensors = {
    [0x1000] = {name = "NULL",          unit = UNIT_RAW,     prec = 0, min = nil, max = nil,     dec = decNil},
    [0x1001] = {name = "Heartbeat",     unit = UNIT_RAW,     prec = 0, min = 0,   max = 60000,   dec = decU16},

    [0x1011] = {name = "Voltage",       unit = UNIT_VOLT,    prec = 2, min = 0,   max = 6500,    dec = decU16},
    [0x1012] = {name = "Current",       unit = UNIT_AMPERE,  prec = 2, min = 0,   max = 65000,   dec = decU16},
    [0x1013] = {name = "Consumption",   unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    [0x1014] = {name = "Charge Level",  unit = UNIT_PERCENT, prec = 0, min = 0,   max = 100,     dec = decU8},

    [0x1020] = {name = "Cell Count",    unit = UNIT_RAW,     prec = 0, min = 0,   max = 16,      dec = decU8},
    [0x1021] = {name = "Cell Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,   max = 455,     dec = decCellV},
    [0x102F] = {name = "Cell Voltages", unit = UNIT_VOLT,    prec = 2, min = nil, max = nil,     dec = decCells},

    [0x1030] = {name = "Ctrl",          unit = UNIT_RAW,     prec = 0, min = nil, max = nil,     dec = decControl},
    [0x1031] = {name = "Pitch Control", unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,    dec = decS16},
    [0x1032] = {name = "Roll Control",  unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,    dec = decS16},
    [0x1033] = {name = "Yaw Control",   unit = UNIT_DEGREE,  prec = 1, min = -900, max = 900,    dec = decS16},
    [0x1034] = {name = "Coll Control",  unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,    dec = decS16},
    [0x1035] = {name = "Throttle %",    unit = UNIT_PERCENT, prec = 0, min = -100, max = 100,    dec = decS8},

    [0x1041] = {name = "ESC1 Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,   dec = decU16},
    [0x1042] = {name = "ESC1 Current",  unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,  dec = decU16},
    [0x1043] = {name = "ESC1 Consump",  unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    [0x1044] = {name = "ESC1 eRPM",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,  dec = decU24},
    [0x1045] = {name = "ESC1 PWM",      unit = UNIT_PERCENT, prec = 1, min = 0,    max = 1000,   dec = decU16},
    [0x1046] = {name = "ESC1 Throttle", unit = UNIT_PERCENT, prec = 1, min = 0,    max = 1000,   dec = decU16},
    [0x1047] = {name = "ESC1 Temp",     unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x1048] = {name = "ESC1 Temp 2",   unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x1049] = {name = "ESC1 BEC Volt", unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1500,   dec = decU16},
    [0x104A] = {name = "ESC1 BEC Curr", unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 10000,  dec = decU16},
    [0x104E] = {name = "ESC1 Status",   unit = UNIT_RAW,     prec = 0, min = 0,    max = 2147483647, dec = decU32},
    [0x104F] = {name = "ESC1 Model ID", unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,    dec = decU8},

    [0x1051] = {name = "ESC2 Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,   dec = decU16},
    [0x1052] = {name = "ESC2 Current",  unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,  dec = decU16},
    [0x1053] = {name = "ESC2 Consump",  unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    [0x1054] = {name = "ESC2 eRPM",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,  dec = decU24},
    [0x1057] = {name = "ESC2 Temp",     unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x105F] = {name = "ESC2 Model ID", unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,    dec = decU8},

    [0x1080] = {name = "ESC Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,   dec = decU16},
    [0x1081] = {name = "BEC Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1600,   dec = decU16},
    [0x1082] = {name = "BUS Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1200,   dec = decU16},
    [0x1083] = {name = "MCU Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 500,    dec = decU16},

    [0x1090] = {name = "ESC Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,  dec = decU16},
    [0x1091] = {name = "BEC Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 10000,  dec = decU16},
    [0x1092] = {name = "BUS Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 1000,   dec = decU16},
    [0x1093] = {name = "MCU Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 1000,   dec = decU16},

    [0x10A0] = {name = "ESC Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x10A1] = {name = "BEC Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x10A3] = {name = "MCU Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,    dec = decU8},

    [0x10B1] = {name = "Heading",       unit = UNIT_DEGREE,  prec = 1, min = -1800, max = 3600,  dec = decS16},
    [0x10B2] = {name = "Altitude",      unit = UNIT_METER,   prec = 2, min = -100000, max = 100000, dec = decS24},
    [0x10B3] = {name = "VSpeed",        unit = UNIT_METER_PER_SECOND, prec = 2, min = -10000, max = 10000, dec = decS16},

    [0x10C0] = {name = "Headspeed",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,  dec = decU16},
    [0x10C1] = {name = "Tailspeed",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,  dec = decU16},

    [0x1100] = {name = "Attd",          unit = UNIT_DEGREE,  prec = 1, min = nil,  max = nil,    dec = decAttitude},
    [0x1101] = {name = "Pitch Attitude",unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,    dec = decS16},
    [0x1102] = {name = "Roll Attitude", unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,    dec = decS16},
    [0x1103] = {name = "Yaw Attitude",  unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,    dec = decS16},

    [0x1110] = {name = "Accl",          unit = UNIT_G,       prec = 2, min = nil,  max = nil,    dec = decAccel},
    [0x1111] = {name = "Accel X",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,  dec = decS16},
    [0x1112] = {name = "Accel Y",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,  dec = decS16},
    [0x1113] = {name = "Accel Z",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,  dec = decS16},

    [0x1121] = {name = "GPS Sats",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x1122] = {name = "GPS PDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x1123] = {name = "GPS HDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x1124] = {name = "GPS VDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x1125] = {name = "GPS Coord",     unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,    dec = decLatLong},
    [0x1126] = {name = "GPS Altitude",  unit = UNIT_METER,   prec = 2, min = -100000000, max = 100000000, dec = decS16},
    [0x1127] = {name = "GPS Heading",   unit = UNIT_DEGREE,  prec = 1, min = -1800, max = 3600,  dec = decS16},
    [0x1128] = {name = "GPS Speed",     unit = UNIT_METER_PER_SECOND, prec = 2, min = 0, max = 10000, dec = decU16},
    [0x1129] = {name = "GPS Home Dist", unit = UNIT_METER,   prec = 1, min = 0,    max = 65535,  dec = decU16},
    [0x112A] = {name = "GPS Home Dir",  unit = UNIT_METER,   prec = 1, min = 0,    max = 3600,   dec = decU16},

    [0x1141] = {name = "CPU Load",      unit = UNIT_PERCENT, prec = 0, min = 0,    max = 100,    dec = decU8},
    [0x1142] = {name = "SYS Load",      unit = UNIT_PERCENT, prec = 0, min = 0,    max = 10,     dec = decU8},
    [0x1143] = {name = "RT Load",       unit = UNIT_PERCENT, prec = 0, min = 0,    max = 200,    dec = decU8},

    [0x1200] = {name = "Model ID",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x1201] = {name = "Flight Mode",   unit = UNIT_RAW,     prec = 0, min = 0,    max = 65535,  dec = decU16},
    [0x1202] = {name = "Arming Flags",  unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x1203] = {name = "Arming Disable",unit = UNIT_RAW,     prec = 0, min = 0,    max = 2147483647, dec = decU32},
    [0x1204] = {name = "Rescue",        unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,    dec = decU8},
    [0x1205] = {name = "Governor",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,    dec = decU8},

    [0x1211] = {name = "PID Profile",   unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,      dec = decU8},
    [0x1212] = {name = "Rate Profile",  unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,      dec = decU8},
    [0x1213] = {name = "LED Profile",   unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,      dec = decU8},

    [0x1220] = {name = "ADJ",           unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,    dec = decAdjFunc},
}

-- Programmatically add Debug 0..7 (0xDB00..0xDB07)
for i = 0, 7 do
    elrs.RFSensors[0xDB00 + i] = { name = "Debug " .. i, unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32 }
end

---------------------------------------------------------------------
-- Telemetry pump
---------------------------------------------------------------------
function elrs.crossfirePop()
    if (CRSF_PAUSE_TELEMETRY == true or rfsuite.app.triggers.mspBusy == true or not telemetryActive()) then
        local module = rfsuite.session.telemetryModule
        if module ~= nil and module.muteSensorLost ~= nil then module:muteSensorLost(5.0) end
        if not telemetryActive() then resetSensors() end
        return false
    end

    local command, data = elrs.popFrame()
    if not (command and data) then return false end

    if command == constants.CRSF_FRAME_CUSTOM_TELEM then
        local ptr = 3
        local fid
        fid, ptr = decU8(data, ptr)
        local delta = (fid - elrs.telemetryFrameId) & 0xFF
        if delta > 1 then elrs.telemetryFrameSkip = elrs.telemetryFrameSkip + 1 end
        elrs.telemetryFrameId = fid
        elrs.telemetryFrameCount = elrs.telemetryFrameCount + 1

        local MAX_TLVS_PER_FRAME = 40  -- sensible cap per frame

        local len = #data
        local tlvCount = 0

        while ptr < len do
            -- Need at least 2 bytes to read sid (U16)
            if (len - ptr) < 2 then break end

            local sid
            sid, ptr = decU16(data, ptr)

            local sensor = elrs.RFSensors[sid]
            if not sensor then break end

            local prev = ptr

            -- Decode safely; bail if decoder errors
            local ok, val, newptr = pcall(sensor.dec, data, ptr)
            if not ok then
                -- optional: rfsuite.utils.log("Decoder error for SID 0x" .. string.format("%04X", sid), "debug")
                break
            end

            -- Ensure the decoder actually advanced the pointer
            ptr = newptr or prev
            if ptr <= prev then break end

            if val ~= nil then
                setTelemetryValue(sid, 0, 0, val, sensor.unit, sensor.prec, sensor.name, sensor.min, sensor.max)
            end

            tlvCount = tlvCount + 1
            if tlvCount >= MAX_TLVS_PER_FRAME then break end
        end

        setTelemetryValue(constants.FRAME_COUNT_ID, 0, 0, elrs.telemetryFrameCount, UNIT_RAW, 0, "Frame Count", 0, 2147483647)
        setTelemetryValue(constants.FRAME_SKIP_ID,  0, 0, elrs.telemetryFrameSkip,  UNIT_RAW, 0, "Frame Skip",  0, 2147483647)
    end

    return true
end

function elrs.wakeup()
    if telemetryActive() and rfsuite.session.telemetrySensor then
        local frameCount = 0
        while elrs.crossfirePop() do
            frameCount = frameCount + 1
            if frameCount >= 100 then break end
            if CRSF_PAUSE_TELEMETRY == true or rfsuite.app.triggers.mspBusy == true then break end
        end
        refreshStaleSensors()
    else
        resetSensors()
    end
end

function elrs.reset()
    resetSensors()
end

return elrs

--[[

 * Copyright (C) Rotorflight Project
 *
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

 * Note.  Some icons have been sourced from https://www.flaticon.com/
 *

]] --

local arg = {...}
local config = arg[1]

local elrs = {}

-- used by sensors.lua to know if module has changed
elrs.name = "elrs"

-- Compatibility shim for CRSF sensor access
if crsf.getSensor ~= nil then
    local sensor = crsf.getSensor()
    elrs.popFrame = function() return sensor:popFrame() end
    elrs.pushFrame = function(x, y) return sensor:pushFrame(x, y) end
else
    elrs.popFrame = function() return crsf.popFrame() end
    elrs.pushFrame = function(x, y) return crsf.pushFrame(x, y) end
end

local sensors = {}
sensors['uid'] = {}
sensors['lastvalue'] = {}

-- Track when a sensor was last re-sent to UI (frame index)
sensors['lastsent'] = {}
-- Track an ordered list of active sensor IDs to avoid pairs() scanning
sensors['active_uids'] = {}

-- configurable resend throttle (in frames). Example: 40 ~= ~0.5s at 80Hz
local RESEND_INTERVAL_FRAMES = 40

local rssiSensor = nil

local CRSF_FRAME_CUSTOM_TELEM = 0x88

local function createTelemetrySensor(uid, name, unit, dec, value, min, max)
    if rfsuite.session.telemetryState == false then return end

    sensors['uid'][uid] = model.createSensor({type=SENSOR_TYPE_DIY})
    sensors['uid'][uid]:name(name)
    sensors['uid'][uid]:appId(uid)
    sensors['uid'][uid]:module(1)
    sensors['uid'][uid]:minimum(min or -1000000000)
    sensors['uid'][uid]:maximum(max or 2147483647)
    if dec then
        sensors['uid'][uid]:decimals(dec)
        sensors['uid'][uid]:protocolDecimals(dec)
    end
    if unit then
        sensors['uid'][uid]:unit(unit)
        sensors['uid'][uid]:protocolUnit(unit)
    end
    if value then sensors['uid'][uid]:value(value) end

    -- add to active list once
    sensors['active_uids'][#sensors['active_uids'] + 1] = uid
end

local function setTelemetryValue(uid, subid, instance, value, unit, dec, name, min, max)
    if rfsuite.session.telemetryState == false then return end

    if sensors['uid'][uid] == nil then
        sensors['uid'][uid] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = uid})
        if sensors['uid'][uid] == nil then
            rfsuite.utils.log("Create sensor: " .. uid, "debug")
            createTelemetrySensor(uid, name, unit, dec, value, min, max)
        else
            -- add to active list if picked up from system.getSource
            local found = false
            for i = 1, #sensors['active_uids'] do if sensors['active_uids'][i] == uid then found = true; break end end
            if not found then sensors['active_uids'][#sensors['active_uids'] + 1] = uid end
        end
        sensors['lastvalue'][uid] = value
        sensors['lastsent'][uid] = sensors['lastsent'][uid] or 0
        return
    end

    if sensors['uid'][uid] then
        if sensors['lastvalue'][uid] == nil or sensors['lastvalue'][uid] ~= value then
            sensors['uid'][uid]:value(value)
            sensors['lastvalue'][uid] = value
            sensors['lastsent'][uid] = elrs.telemetryFrameId or 0
        end

        -- detect if sensor has been deleted or is missing after initial creation
        if sensors['uid'][uid].state and sensors['uid'][uid]:state() == false then
            sensors['uid'][uid] = nil
            sensors['lastvalue'][uid] = nil
            sensors['lastsent'][uid] = nil
            -- leave active_uids as-is (cheap); missing entries are OK
        end
    end
end

-- --- Decoders

local function decNil(data, pos)
    return nil, pos
end

local function decU8(data, pos)
    return data[pos], pos + 1
end

local function decS8(data, pos)
    local val, ptr = decU8(data, pos)
    if val < 0x80 then
        return val, ptr
    else
        return val - 0x100, ptr
    end
end

local function decU16(data, pos)
    return (data[pos] << 8) | data[pos + 1], pos + 2
end

local function decS16(data, pos)
    local val, ptr = decU16(data, pos)
    if val < 0x8000 then
        return val, ptr
    else
        return val - 0x10000, ptr
    end
end

local function decU12U12(data, pos)
    local a = ((data[pos] & 0x0F) << 8) | data[pos + 1]
    local b = ((data[pos] & 0xF0) << 4) | data[pos + 2]
    return a, b, pos + 3
end

local function decS12S12(data, pos)
    local a, b, ptr = decU12U12(data, pos)
    if a < 0x0800 then
        a = a
    else
        a = a - 0x1000
    end
    if b < 0x0800 then
        b = b
    else
        b = b - 0x1000
    end
    return a, b, ptr
end

local function decU24(data, pos)
    return (data[pos] << 16) | (data[pos + 1] << 8) | data[pos + 2], pos + 3
end

local function decS24(data, pos)
    local val, ptr = decU24(data, pos)
    if val < 0x800000 then
        return val, ptr
    else
        return val - 0x1000000, ptr
    end
end

local function decU32(data, pos)
    return (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3], pos + 4
end

local function decS32(data, pos)
    local val, ptr = decU32(data, pos)
    if val < 0x80000000 then
        return val, ptr
    else
        return val - 0x100000000, ptr
    end
end

local function decCellV(data, pos)
    local val, ptr = decU8(data, pos)
    if val > 0 then
        return val + 200, ptr
    else
        return 0, ptr
    end
end

local function decCells(data, pos)
    local cnt, val, vol
    cnt, pos = decU8(data, pos)
    setTelemetryValue(0x1020, 0, 0, cnt, UNIT_RAW, 0, "Cell Count", 0, 15) -- Cel#
    for i = 1, cnt do
        val, pos = decU8(data, pos)
        val = val > 0 and val + 200 or 0
        vol = (cnt << 24) | ((i - 1) << 16) | val
        setTelemetryValue(0x102F, 0, 0, vol, UNIT_CELLS, 2, "Cell Voltages", 0, 455) -- Cels
    end
    return nil, pos
end

local function decControl(data, pos)
    local r, p, y, c
    p, r, pos = decS12S12(data, pos)
    y, c, pos = decS12S12(data, pos)
    setTelemetryValue(0x1031, 0, 0, p, UNIT_DEGREE, 2, "Pitch Control", -4500, 4500)
    setTelemetryValue(0x1032, 0, 0, r, UNIT_DEGREE, 2, "Roll Control", -4500, 4500)
    setTelemetryValue(0x1033, 0, 0, 3 * y, UNIT_DEGREE, 2, "Yaw Control", -9000, 9000)
    setTelemetryValue(0x1034, 0, 0, c, UNIT_DEGREE, 2, "Coll Control", -4500, 4500)
    return nil, pos
end

local function decAttitude(data, pos)
    local p, r, y
    p, pos = decS16(data, pos)
    r, pos = decS16(data, pos)
    y, pos = decS16(data, pos)
    setTelemetryValue(0x1101, 0, 0, p, UNIT_DEGREE, 1, "Pitch Attitude", -1800, 3600)
    setTelemetryValue(0x1102, 0, 0, r, UNIT_DEGREE, 1, "Roll Attitude", -1800, 3600)
    setTelemetryValue(0x1103, 0, 0, y, UNIT_DEGREE, 1, "Yaw Attitude", -1800, 3600)
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
    setTelemetryValue(0x1125, 0, 0, lat, UNIT_DEGREE, 4, "GPS Latitude", -10000000000, 10000000000)
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

-- --- Sensor map (identical) ---
elrs.RFSensors = {
    [0x1000] = {name = "NULL", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decNil},
    [0x1001] = {name = "Heartbeat", unit = UNIT_RAW, prec = 0, min = 0, max = 60000, dec = decU16},

    [0x1011] = {name = "Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    [0x1012] = {name = "Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    [0x1013] = {name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    [0x1014] = {name = "Charge Level", unit = UNIT_PERCENT, prec = 0, min = 0, max = 100, dec = decU8},

    [0x1020] = {name = "Cell Count", unit = UNIT_RAW, prec = 0, min = 0, max = 16, dec = decU8},
    [0x1021] = {name = "Cell Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 455, dec = decCellV},
    [0x102F] = {name = "Cell Voltages", unit = UNIT_VOLT, prec = 2, min = nil, max = nil, dec = decCells},

    [0x1030] = {name = "Ctrl", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decControl},
    [0x1031] = {name = "Pitch Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    [0x1032] = {name = "Roll Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    [0x1033] = {name = "Yaw Control", unit = UNIT_DEGREE, prec = 1, min = -900, max = 900, dec = decS16},
    [0x1034] = {name = "Coll Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    [0x1035] = {name = "Throttle %", unit = UNIT_PERCENT, prec = 0, min = -100, max = 100, dec = decS8},

    [0x1041] = {name = "ESC1 Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    [0x1042] = {name = "ESC1 Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    [0x1043] = {name = "ESC1 Consump", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    [0x1044] = {name = "ESC1 eRPM", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU24},
    [0x1045] = {name = "ESC1 PWM", unit = UNIT_PERCENT, prec = 1, min = 0, max = 1000, dec = decU16},
    [0x1046] = {name = "ESC1 Throttle", unit = UNIT_PERCENT, prec = 1, min = 0, max = 1000, dec = decU16},
    [0x1047] = {name = "ESC1 Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1048] = {name = "ESC1 Temp 2", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1049] = {name = "ESC1 BEC Volt", unit = UNIT_VOLT, prec = 2, min = 0, max = 1500, dec = decU16},
    [0x104A] = {name = "ESC1 BEC Curr", unit = UNIT_AMPERE, prec = 2, min = 0, max = 10000, dec = decU16},
    [0x104E] = {name = "ESC1 Status", unit = UNIT_RAW, prec = 0, min = 0, max = 2147483647, dec = decU32},
    [0x104F] = {name = "ESC1 Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},

    [0x1051] = {name = "ESC2 Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    [0x1052] = {name = "ESC2 Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    [0x1053] = {name = "ESC2 Consump", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    [0x1054] = {name = "ESC2 eRPM", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU24},
    [0x1057] = {name = "ESC2 Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x105F] = {name = "ESC2 Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},

    [0x1080] = {name = "ESC Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    [0x1081] = {name = "BEC Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 1600, dec = decU16},
    [0x1082] = {name = "BUS Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 1200, dec = decU16},
    [0x1083] = {name = "MCU Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 500, dec = decU16},

    [0x1090] = {name = "ESC Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    [0x1091] = {name = "BEC Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 10000, dec = decU16},
    [0x1092] = {name = "BUS Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 1000, dec = decU16},
    [0x1093] = {name = "MCU Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 1000, dec = decU16},

    [0x10A0] = {name = "ESC Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x10A1] = {name = "BEC Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x10A3] = {name = "MCU Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},

    [0x10B1] = {name = "Heading", unit = UNIT_DEGREE, prec = 1, min = -1800, max = 3600, dec = decS16},
    [0x10B2] = {name = "Altitude", unit = UNIT_METER, prec = 2, min = -100000, max = 100000, dec = decS24},
    [0x10B3] = {name = "VSpeed", unit = UNIT_METER_PER_SECOND, prec = 2, min = -10000, max = 10000, dec = decS16},

    [0x10C0] = {name = "Headspeed", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU16},
    [0x10C1] = {name = "Tailspeed", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU16},

    [0x1100] = {name = "Attd", unit = UNIT_DEGREE, prec = 1, min = nil, max = nil, dec = decAttitude},
    [0x1101] = {name = "Pitch Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},
    [0x1102] = {name = "Roll Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},
    [0x1103] = {name = "Yaw Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},

    [0x1110] = {name = "Accl", unit = UNIT_G, prec = 2, min = nil, max = nil, dec = decAccel},
    [0x1111] = {name = "Accel X", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},
    [0x1112] = {name = "Accel Y", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},
    [0x1113] = {name = "Accel Z", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},

    [0x1121] = {name = "GPS Sats", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1122] = {name = "GPS PDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1123] = {name = "GPS HDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1124] = {name = "GPS VDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1125] = {name = "GPS Coord", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decLatLong},
    [0x1126] = {name = "GPS Altitude", unit = UNIT_METER, prec = 2, min = -100000000, max = 100000000, dec = decS16},
    [0x1127] = {name = "GPS Heading", unit = UNIT_DEGREE, prec = 1, min = -1800, max = 3600, dec = decS16},
    [0x1128] = {name = "GPS Speed", unit = UNIT_METER_PER_SECOND, prec = 2, min = 0, max = 10000, dec = decU16},
    [0x1129] = {name = "GPS Home Dist", unit = UNIT_METER, prec = 1, min = 0, max = 65535, dec = decU16},
    [0x112A] = {name = "GPS Home Dir", unit = UNIT_METER, prec = 1, min = 0, max = 3600, dec = decU16},

    [0x1141] = {name = "CPU Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 100, dec = decU8},
    [0x1142] = {name = "SYS Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 10, dec = decU8},
    [0x1143] = {name = "RT Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 200, dec = decU8},

    [0x1200] = {name = "Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1201] = {name = "Flight Mode", unit = UNIT_RAW, prec = 0, min = 0, max = 65535, dec = decU16},
    [0x1202] = {name = "Arming Flags", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1203] = {name = "Arming Disable", unit = UNIT_RAW, prec = 0, min = 0, max = 2147483647, dec = decU32},
    [0x1204] = {name = "Rescue", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1205] = {name = "Governor", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},

    [0x1211] = {name = "PID Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},
    [0x1212] = {name = "Rate Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},
    [0x1213] = {name = "LED Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},

    [0x1220] = {name = "ADJ", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decAdjFunc},

    [0xDB00] = {name = "Debug 0", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB01] = {name = "Debug 1", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB02] = {name = "Debug 2", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB03] = {name = "Debug 3", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB04] = {name = "Debug 4", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB05] = {name = "Debug 5", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB06] = {name = "Debug 6", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB07] = {name = "Debug 7", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32}
}

elrs.telemetryFrameId = 0
elrs.telemetryFrameSkip = 0
elrs.telemetryFrameCount = 0
elrs._lastSkip = 0

-- incremental frame parsing state (non-blocking)
elrs._cur = nil  -- { data=table, ptr=number, len=number, fid=number, counted=bool }
elrs._seen = {}  -- reusable set/table of UIDs seen in a frame

-- Utility: clear a table in-place (for reusing _seen)
local function clear_table(t)
    for k in pairs(t) do t[k] = nil end
end

-- Throttled resend helper
local function maybe_resend_missing(uid)
    -- If we don't know this sensor or last value, skip
    if sensors['uid'][uid] == nil then return end
    local last = sensors['lastvalue'][uid]
    if last == nil then return end

    -- throttle by frame interval
    local lastSent = sensors['lastsent'][uid] or 0
    local now = elrs.telemetryFrameId or 0
    local delta = (now - lastSent) & 0xFF -- same wrap behavior as fid
    if delta < RESEND_INTERVAL_FRAMES then return end

    -- Use the normal setter (respects "only-on-change")
    sensors['uid'][uid]:value(last)
    sensors['lastsent'][uid] = now
end

-- Process at most one sensor item per call. Never blocks the UI.
function elrs.crossfirePop()
    -- paused / busy / telemetry off?
    if (CRSF_PAUSE_TELEMETRY == true or rfsuite.app.triggers.mspBusy == true or rfsuite.session.telemetryState == false) then
        local modIdx = rfsuite.session.telemetrySensor and rfsuite.session.telemetrySensor:module() or 1
        local module = model.getModule(modIdx)
        if module ~= nil and module.muteSensorLost ~= nil then module:muteSensorLost(5.0) end
        if rfsuite.session.telemetryState == false then
            sensors['uid'] = {}
            sensors['lastvalue'] = {}
            sensors['lastsent'] = {}
            sensors['active_uids'] = {}
        end
        elrs._cur = nil
        return false
    end

    -- If no current frame, try to pop one
    if not elrs._cur then
        local command, data = elrs.popFrame()
        if not (command and data) then return false end
        if command ~= CRSF_FRAME_CUSTOM_TELEM then
            -- popped a frame, but not ours
            return true
        end

        -- Begin a new custom telemetry frame
        local ptr = 3
        local fid
        fid, ptr = decU8(data, ptr)
        local delta = (fid - elrs.telemetryFrameId) & 0xFF
        if delta > 1 then elrs.telemetryFrameSkip = elrs.telemetryFrameSkip + 1 end
        elrs.telemetryFrameId = fid

        elrs._cur = { data = data, ptr = ptr, len = #data, fid = fid, counted = false }
        clear_table(elrs._seen)
    end

    local st = elrs._cur

    if not st.counted then
        elrs.telemetryFrameCount = elrs.telemetryFrameCount + 1
        st.counted = true
    end

    if st.ptr >= st.len then
        -- Frame finished: opportunistically resend a FEW missing sensors (throttled)
        -- Limit work here to avoid long tails
        local resend_budget = 6
        local active = sensors['active_uids']
        if active then
            for i = 1, #active do
                local uid = active[i]
                if uid and not elrs._seen[uid] then
                    maybe_resend_missing(uid)
                    resend_budget = resend_budget - 1
                    if resend_budget <= 0 then break end
                end
            end
        end

        setTelemetryValue(0xEE01, 0, 0, elrs.telemetryFrameCount, UNIT_RAW, 0, "Frame Count", 0, 2147483647)
        setTelemetryValue(0xEE02, 0, 0, elrs.telemetryFrameSkip, UNIT_RAW, 0, "Frame Skip", 0, 2147483647)
        elrs._cur = nil
        return true
    end

    -- Decode one sensor ID + value
    local sid
    sid, st.ptr = decU16(st.data, st.ptr)
    elrs._seen[sid] = true

    local sensor = elrs.RFSensors[sid]
    if not sensor then
        -- Unknown sensor id: abandon this frame safely
        elrs._cur = nil
        return true
    end

    local val
    val, st.ptr = sensor.dec(st.data, st.ptr)
    if val then
        setTelemetryValue(sid, 0, 0, val, sensor.unit, sensor.prec, sensor.name, sensor.min, sensor.max)
    end

    -- Finish?
    if st.ptr >= st.len then
        -- Throttled resend, as above
        local resend_budget = 6
        local active = sensors['active_uids']
        if active then
            for i = 1, #active do
                local uid = active[i]
                if uid and not elrs._seen[uid] then
                    maybe_resend_missing(uid)
                    resend_budget = resend_budget - 1
                    if resend_budget <= 0 then break end
                end
            end
        end

        setTelemetryValue(0xEE01, 0, 0, elrs.telemetryFrameCount, UNIT_RAW, 0, "Frame Count", 0, 2147483647)
        setTelemetryValue(0xEE02, 0, 0, elrs.telemetryFrameSkip, UNIT_RAW, 0, "Frame Skip", 0, 2147483647)
        elrs._cur = nil
    end

    return true
end

function elrs.wakeup()
    if rfsuite.session.telemetryState and rfsuite.session.telemetrySensor then
        if CRSF_PAUSE_TELEMETRY ~= true and rfsuite.app.triggers.mspBusy ~= true then
            -- Adaptive, bounded, conservative
            local budget = 1                       -- base work per tick (lower default)
            if elrs._cur then budget = budget + 2 end
            if elrs.telemetryFrameSkip > (elrs._lastSkip or 0) then budget = budget + 2 end
            if budget > 6 then budget = 6 end      -- lower hard ceiling to avoid UI stalls

            for _ = 1, budget do
                if not elrs.crossfirePop() then break end
            end

            elrs._lastSkip = elrs.telemetryFrameSkip
        else
            sensors['uid'] = {}
            sensors['lastvalue'] = {}
            sensors['lastsent'] = {}
            sensors['active_uids'] = {}
            elrs._cur = nil
        end
    else
        sensors['uid'] = {}
        sensors['lastvalue'] = {}
        sensors['lastsent'] = {}
        sensors['active_uids'] = {}
        elrs._cur = nil
    end
end

function elrs.reset()
    sensors.uid = {}
    sensors.lastvalue = {}
    sensors.lastsent = {}
    sensors.active_uids = {}
end

return elrs

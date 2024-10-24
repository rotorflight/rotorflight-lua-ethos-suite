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

]]--
--
-- Rotorflight Custom Telemetry Decoder for ELRS
--
--
local arg = {...}
local config = arg[1]
local compile = arg[2]

local elrs = {}

if crsf.getSensor ~= nil then
    local sensor = crsf.getSensor()
    elrs.popFrame = function() return sensor:popFrame() end
    elrs.pushFrame = function(x,y) return sensor:pushFrame(x,y) end
else
    elrs.popFrame = function() return crsf.popFrame() end
    elrs.pushFrame = function(x,y) return crsf.pushFrame(x,y) end
end

local sensors = {}
sensors['uid'] = {}
sensors['lastvalue'] = {}

local rssiSensor = nil

local CRSF_FRAME_CUSTOM_TELEM = 0x88

local function createTelemetrySensor(uid, name, unit, dec, value, min, max)
    sensors['uid'][uid] = model.createSensor()
    sensors['uid'][uid]:name(name)
    sensors['uid'][uid]:appId(uid)
    sensors['uid'][uid]:module(1)
    sensors['uid'][uid]:minimum(min or -2147483647)
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
end

local function setTelemetryValue(uid, subid, instance, value, unit, dec, name, min, max)

    if sensors['uid'][uid] == nil then
        sensors['uid'][uid] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = uid})
        if sensors['uid'][uid] == nil then
            print("Create sensor: " .. uid)
            createTelemetrySensor(uid, name, unit, dec, value, min, max)
        end
    else
        if sensors['uid'][uid] then
            if sensors['lastvalue'][uid] == nil or sensors['lastvalue'][uid] ~= value then sensors['uid'][uid]:value(value) end

            -- detect if sensor has been deleted or is missing after initial creation
            if sensors['uid'][uid]:state() == false then
                sensors['uid'][uid] = nil
                sensors['lastvalue'][uid] = nil
            end

        end
    end
end

local function decNil(data, pos)
    return nil, pos
end

local function decU8(data, pos)
    return data[pos], pos + 1
end

local function decS8(data, pos)
    local val, ptr = decU8(data, pos)
    return val < 0x80 and val or val - 0x100, ptr
end

local function decU16(data, pos)
    return (data[pos] << 8) | data[pos + 1], pos + 2
end

local function decS16(data, pos)
    local val, ptr = decU16(data, pos)
    return val < 0x8000 and val or val - 0x10000, ptr
end

local function decU12U12(data, pos)
    local a = ((data[pos] & 0x0F) << 8) | data[pos + 1]
    local b = ((data[pos] & 0xF0) << 4) | data[pos + 2]
    return a, b, pos + 3
end

local function decS12S12(data, pos)
    local a, b, ptr = decU12U12(data, pos)
    return a < 0x0800 and a or a - 0x1000, b < 0x0800 and b or b - 0x1000, ptr
end

local function decU24(data, pos)
    return (data[pos] << 16) | (data[pos + 1] << 8) | data[pos + 2], pos + 3
end

local function decS24(data, pos)
    local val, ptr = decU24(data, pos)
    return val < 0x800000 and val or val - 0x1000000, ptr
end

local function decU32(data, pos)
    return (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3], pos + 4
end

local function decS32(data, pos)
    local val, ptr = decU32(data, pos)
    return val < 0x80000000 and val or val - 0x100000000, ptr
end

local function decCellV(data, pos)
    local val, ptr = decU8(data, pos)
    return val > 0 and val + 200 or 0, ptr
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
    setTelemetryValue(0x1031, 0, 0, p, UNIT_DEGREE, 2, "Pitch Control", -4500, 4500) -- CPtc
    setTelemetryValue(0x1032, 0, 0, r, UNIT_DEGREE, 2, "Roll Control", -4500, 4500) -- CRol
    setTelemetryValue(0x1033, 0, 0, 3*y, UNIT_DEGREE, 2, "Yaw Control", -9000, 9000) -- CYaw
    setTelemetryValue(0x1034, 0, 0, c, UNIT_DEGREE, 2, "Coll Control", -4500, 4500) -- CCol
    return nil, pos
end

local function decAttitude(data, pos)
    local p, r, y
    p, pos = decS16(data, pos)
    r, pos = decS16(data, pos)
    y, pos = decS16(data, pos)
    setTelemetryValue(0x1101, 0, 0, p, UNIT_DEGREE, 1, "Pitch Attitude", -1800, 3600) -- Ptch
    setTelemetryValue(0x1102, 0, 0, r, UNIT_DEGREE, 1, "Roll Attitude", -1800, 3600) -- Roll
    setTelemetryValue(0x1103, 0, 0, y, UNIT_DEGREE, 1, "Yaw Attitude", -1800, 3600) -- Yaw
    return nil, pos
end

local function decAccel(data, pos)
    local x, y, z
    x, pos = decS16(data, pos)
    y, pos = decS16(data, pos)
    z, pos = decS16(data, pos)
    setTelemetryValue(0x1111, 0, 0, x, UNIT_G, 2, "Accel X", -4000, 4000) -- AccX
    setTelemetryValue(0x1112, 0, 0, y, UNIT_G, 2, "Accel Y", -4000, 4000) -- AccY
    setTelemetryValue(0x1113, 0, 0, z, UNIT_G, 2, "Accel Z", -4000, 4000) -- AccZ
    return nil, pos
end

local function decLatLong(data, pos)
    local lat, lon
    lat, pos = decS32(data, pos)
    lon, pos = decS32(data, pos)
    setTelemetryValue(0x1125, 0, 0, 0, UNIT_GPS, 0, "GPS")
    setTelemetryValue(0x1125, 0, 0, lat, UNIT_GPS_LATITUDE)
    setTelemetryValue(0x1125, 0, 0, lon, UNIT_GPS_LONGITUDE)
    return nil, pos
end

local function decAdjFunc(data, pos)
    local fun, val
    fun, pos = decU16(data, pos)
    val, pos = decS32(data, pos)
    setTelemetryValue(0x1221, 0, 0, fun, UNIT_RAW, 0, "Adj. Source", 0, 255) -- AdjF
    setTelemetryValue(0x1222, 0, 0, val, UNIT_RAW, 0, "Adj. Value") -- AdjV
    return nil, pos
end

elrs.RFSensors = {
    -- No data
    [0x1000] = {name = "NULL", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decNil},
    -- Heartbeat (millisecond uptime % 60000)
    [0x1001] = {original = "BEAT", name = "Heartbeat", unit = UNIT_RAW, prec = 0, min = 0, max = 60000, dec = decU16},

    -- Main battery voltage
    [0x1011] = {original = "Vbat", name = "Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    -- Main battery current
    [0x1012] = {original = "Curr", name = "Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    -- Main battery used capacity
    [0x1013] = {original = "Capa", name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    -- Main battery charge / fuel level
    [0x1014] = {original = "Bat%", name = "Charge Level", unit = UNIT_PERCENT, prec = 0, min = 0, max = 100, dec = decU8},

    -- Main battery cell count
    [0x1020] = {original = "Cel#", name = "Cell Count", unit = UNIT_RAW, prec = 0, min = 0, max = 16, dec = decU8},
    -- Main battery cell voltage (minimum/average)
    [0x1021] = {original = "Vcel", name = "Cell Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 455, dec = decCellV},
    -- Main battery cell voltages
    [0x102F] = {original = "Cels", name = "Cell Voltages", unit = UNIT_VOLT, prec = 2, min = nil, max = nil, dec = decCells},

    -- Control Combined (hires)
    [0x1030] = {name = "Ctrl", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decControl},
    -- Pitch Control angle
    [0x1031] = {original = "CPtc", name = "Pitch Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    -- Roll Control angle
    [0x1032] = {original = "CRol", name = "Roll Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    -- Yaw Control angle
    [0x1033] = {original = "CYaw", name = "Yaw Control", unit = UNIT_DEGREE, prec = 1, min = -900, max = 900, dec = decS16},
    -- Collective Control angle
    [0x1034] = {original = "CCol", name = "Coll Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    -- Throttle output %
    [0x1035] = {original = "Thr",  name = "Throttle %", unit = UNIT_PERCENT, prec = 0, min = -100, max = 100, dec = decS8},

    -- ESC#1 voltage
    [0x1041] = {original = "EscV", name = "ESC1 Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    -- ESC#1 current
    [0x1042] = {original = "EscI", name = "ESC1 Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    -- ESC#1 capacity/consumption
    [0x1043] = {original = "EscC", name = "ESC1 Consump", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    -- ESC#1 eRPM
    [0x1044] = {original = "EscR", name = "ESC1 eRPM", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU24},
    -- ESC#1 PWM/Power
    [0x1045] = {original = "EscP", name = "ESC1 PWM", unit = UNIT_PERCENT, prec = 1, min = 0, max = 1000, dec = decU16},
    -- ESC#1 throttle
    [0x1046] = {original = "Esc%", name = "ESC1 Throttle", unit = UNIT_PERCENT, prec = 1, min = 0, max = 1000, dec = decU16},
    -- ESC#1 temperature
    [0x1047] = {original = "EscT", name = "ESC1 Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    -- ESC#1 / BEC temperature
    [0x1048] = {original = "BecT", name = "ESC1 BEC Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    -- ESC#1 / BEC voltage
    [0x1049] = {original = "BecV", name = "ESC1 BEC Volt", unit = UNIT_VOLT, prec = 2, min = 0, max = 1500, dec = decU16},
    -- ESC#1 / BEC current
    [0x104A] = {original = "BecI", name = "ESC1 BEC Curr", unit = UNIT_AMPERE, prec = 2, min = 0, max = 10000, dec = decU16},
    -- ESC#1 Status Flags
    [0x104E] = {original = "EscF", name = "ESC1 Status", unit = UNIT_RAW, prec = 0, min = 0, max = 2147483647, dec = decU32},
    -- ESC#1 Model Id
    [0x104F] = {original = "Esc#", name = "ESC1 Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},

    -- ESC#2 voltage
    [0x1051] = {original = "Es2V", name = "ESC2 Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    -- ESC#2 current
    [0x1052] = {original = "Es2I", name = "ESC2 Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    -- ESC#2 capacity/consumption
    [0x1053] = {original = "Es2C", name = "ESC2 Consump", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    -- ESC#2 eRPM
    [0x1054] = {original = "Es2R", name = "ESC2 eRPM", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU24},
    -- ESC#2 temperature
    [0x1057] = {original = "Es2T", name = "ESC2 Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    -- ESC#2 Model Id
    [0x105F] = {original = "Es2#", name = "ESC2 Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},

    -- Combined ESC voltage
    [0x1080] = {original = "Vesc", name = "ESC Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    -- BEC voltage
    [0x1081] = {original = "Vbec", name = "BEC Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 1600, dec = decU16},
    -- BUS voltage
    [0x1082] = {original = "Vbus", name = "BUS Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 1200, dec = decU16},
    -- MCU voltage
    [0x1083] = {original = "Vmcu", name = "MCU Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 500, dec = decU16},

    -- Combined ESC current
    [0x1090] = {original = "Iesc", name = "ESC Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    -- BEC current
    [0x1091] = {original = "Ibec", name = "BEC Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 10000, dec = decU16},
    -- BUS current
    [0x1092] = {original = "Ibus", name = "BUS Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 1000, dec = decU16},
    -- MCU current
    [0x1093] = {original = "Imcu", name = "MCU Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 1000, dec = decU16},

    -- Combined ESC temeperature
    [0x10A0] = {original = "Tesc", name = "ESC Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    -- BEC temperature
    [0x10A1] = {original = "Tbec", name = "BEC Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    -- MCU temperature
    [0x10A3] = {original = "Tmcu", name = "MCU Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},

    -- Heading (combined gyro+mag+GPS)
    [0x10B1] = {original = "Hdg",  name = "Heading", unit = UNIT_DEGREE, prec = 1, min = -1800, max = 3600, dec = decS16},
    -- Altitude (combined baro+GPS)
    [0x10B2] = {original = "Alt",  name = "Altitude", unit = UNIT_METER, prec = 2, min = -100000, max = 100000, dec = decS24},
    -- Variometer (combined baro+GPS)
    [0x10B3] = {original = "Var",  name = "VSpeed", unit = UNIT_METER_PER_SECOND, prec = 2, min = -10000, max = 10000, dec = decS16},

    -- Headspeed
    [0x10C0] = {original = "Hspd", name = "Headspeed", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU16},
    -- Tailspeed
    [0x10C1] = {original = "Tspd", name = "Tailspeed", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU16},

    -- Attitude (hires combined)
    [0x1100] = {name = "Attd", unit = UNIT_DEGREE, prec = 1, min = nil, max = nil, dec = decAttitude},
    -- Attitude pitch
    [0x1101] = {original = "Ptch", name = "Pitch Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},
    -- Attitude roll
    [0x1102] = {original = "Roll", name = "Roll Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},
    -- Attitude yaw
    [0x1103] = {original = "Yaw",  name = "Yaw Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},

    -- Acceleration (hires combined)
    [0x1110] = {name = "Accl", unit = UNIT_G, prec = 2, min = nil, max = nil, dec = decAccel},
    -- Acceleration X
    [0x1111] = {original = "AccX", name = "Accel X", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},
    -- Acceleration Y
    [0x1112] = {original = "AccY", name = "Accel Y", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},
    -- Acceleration Z
    [0x1113] = {original = "AccZ", name = "Accel Z", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},

    -- GPS Satellite count
    [0x1121] = {original = "Sats", name = "GPS Sats", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- GPS PDOP
    [0x1122] = {original = "PDOP", name = "GPS PDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- GPS HDOP
    [0x1123] = {original = "HDOP", name = "GPS HDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- GPS VDOP
    [0x1124] = {original = "VDOP", name = "GPS VDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- GPS Coordinates
    [0x1125] = {original = "GPS",  name = "GPS Coord", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decLatLong},
    -- GPS altitude
    [0x1126] = {original = "GAlt", name = "GPS Altitude", unit = UNIT_METER, prec = 1, min = -10000, max = 10000, dec = decS16},
    -- GPS heading
    [0x1127] = {original = "GHdg", name = "GPS Heading", unit = UNIT_DEGREE, prec = 1, min = -1800, max = 3600, dec = decS16},
    -- GPS ground speed
    [0x1128] = {original = "GSpd", name = "GPS Speed", unit = UNIT_METER_PER_SECOND, prec = 2, min = 0, max = 10000, dec = decU16},
    -- GPS home distance
    [0x1129] = {original = "GDis", name = "GPS Home Dist", unit = UNIT_METER, prec = 1, min = 0, max = 65535, dec = decU16},
    -- GPS home direction
    [0x112A] = {original = "GDir", name = "GPS Home Dir", unit = UNIT_METER, prec = 1, min = 0, max = 3600, dec = decU16},

    -- CPU load
    [0x1141] = {original = "CPU%", name = "CPU Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 100, dec = decU8},
    -- System load
    [0x1142] = {original = "SYS%", name = "SYS Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 10, dec = decU8},
    -- Realtime CPU load
    [0x1143] = {original = "RT%",  name = "RT Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 200, dec = decU8},

    -- Model ID
    [0x1200] = {original = "MDL#", name = "Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- Flight mode flags
    [0x1201] = {original = "Mode", name = "Flight Mode", unit = UNIT_RAW, prec = 0, min = 0, max = 65535, dec = decU16},
    -- Arming flags
    [0x1202] = {original = "ARM",  name = "Arming Flags", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- Arming disable flags
    [0x1203] = {original = "ARMD", name = "Arming Disable", unit = UNIT_RAW, prec = 0, min = 0, max = 2147483647, dec = decU32},
    -- Rescue state
    [0x1204] = {original = "Resc", name = "Rescue", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- Governor state
    [0x1205] = {original = "Gov",  name = "Governor", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},

    -- Current PID profile
    [0x1211] = {original = "PID#", name = "PID Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},
    -- Current Rate profile
    [0x1212] = {original = "RTE#", name = "Rate Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},
    -- Current LED profile
    [0x1213] = {original = "LED#", name = "LED Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},

    -- Adjustment function
    [0x1220] = {name = "ADJ", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decAdjFunc},

    -- Debug
    [0xDB00] = {original = "DBG0", name = "Debug 0", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB01] = {original = "DBG1", name = "Debug 1", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB02] = {original = "DBG2", name = "Debug 2", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB03] = {original = "DBG3", name = "Debug 3", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB04] = {original = "DBG4", name = "Debug 4", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB05] = {original = "DBG5", name = "Debug 5", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB06] = {original = "DBG6", name = "Debug 6", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB07] = {original = "DBG7", name = "Debug 7", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32}
}

elrs.telemetryFrameId = 0
elrs.telemetryFrameSkip = 0
elrs.telemetryFrameCount = 0

function elrs.crossfirePop()

    if (CRSF_PAUSE_TELEMETRY == true or rfsuite.app.triggers.mspBusy == true) then
        return false
    else

        local command, data = elrs.popFrame()
        if command and data then

            if command == CRSF_FRAME_CUSTOM_TELEM then
                local fid, sid, val
                local ptr = 3
                fid, ptr = decU8(data, ptr)
                local delta = (fid - elrs.telemetryFrameId) & 0xFF
                if delta > 1 then elrs.telemetryFrameSkip = elrs.telemetryFrameSkip + 1 end
                elrs.telemetryFrameId = fid
                elrs.telemetryFrameCount = elrs.telemetryFrameCount + 1
                while ptr < #data do

                    sid, ptr = decU16(data, ptr)
                    local sensor = elrs.RFSensors[sid]
                    if sensor then
                        val, ptr = sensor.dec(data, ptr)
                        if val then setTelemetryValue(sid, 0, 0, val, sensor.unit, sensor.prec, sensor.name, sensor.min, sensor.max) end
                    else
                        break
                    end
                end
                setTelemetryValue(0xEE01, 0, 0, elrs.telemetryFrameCount, UNIT_RAW, 0, "Frame Count", 0, 2147483647) -- *Cnt
                setTelemetryValue(0xEE02, 0, 0, elrs.telemetryFrameSkip,  UNIT_RAW, 0, "Frame Skip",  0, 2147483647) -- *Skp
                -- setTelemetryValue(0xEE03, 0, 0, elrs.telemetryFrameId, UNIT_RAW, 0, "*Frm", 0, 255)
            end

            return true
        end

        return false
    end
end

function elrs.wakeup()

    if rfsuite.bg.telemetry.active() and rfsuite.rssiSensor then while elrs.crossfirePop() do if (CRSF_PAUSE_TELEMETRY == true or rfsuite.app.triggers.mspBusy == true) then break end end end
end

return elrs

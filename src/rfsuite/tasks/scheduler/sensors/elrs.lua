--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local elrs = {}

elrs.name = "elrs"

local useRawValue = rfsuite.utils.ethosVersionAtLeast({1, 7, 0})

if crsf.getSensor ~= nil then
    local sensor = crsf.getSensor(...)
    elrs.popFrame = function(...)
        return sensor:popFrame(...)
    end
    elrs.pushFrame = function(x, y) return sensor:pushFrame(x, y) end
else
    elrs.popFrame = function(...)
        return crsf.popFrame(...)
    end
    elrs.pushFrame = function(x, y) return crsf.pushFrame(x, y) end
end

local sensors = {}
sensors['uid'] = {}
sensors['lastvalue'] = {}
sensors['lasttime'] = {}

local rssiSensor = nil

local CRSF_FRAME_CUSTOM_TELEM = 0x88

elrs.publishBudgetPerFrame = 50  -- If everything works this should never be reached.  we use it as a safeguard.

local META_UID = {
    [0xEE01] = true, 
    [0xEE02] = true,
    [0xEE03] = true
}

elrs.strictUntilConfig = false

local sidLookup = {
    [1] = {'0x1001'},
    [3] = {'0x1011'},
    [4] = {'0x1012'},
    [5] = {'0x1013'},
    [6] = {'0x1014'},
    [7] = {'0x1020'},
    [8] = {'0x1021'},
    [9] = {'0x102F'},
    [10] = {'0x1030'},
    [11] = {'0x1031'},
    [12] = {'0x1032'},
    [13] = {'0x1033'},
    [14] = {'0x1034'},
    [15] = {'0x1035'},
    [17] = {'0x1041'},
    [18] = {'0x1042'},
    [19] = {'0x1043'},
    [20] = {'0x1044'},
    [21] = {'0x1045'},
    [22] = {'0x1046'},
    [23] = {'0x1047'},
    [24] = {'0x1048'},
    [25] = {'0x1049'},
    [26] = {'0x104A'},
    [27] = {'0x104E'},
    [28] = {'0x104F'},
    [30] = {'0x1051'},
    [31] = {'0x1052'},
    [32] = {'0x1053'},
    [33] = {'0x1054'},
    [36] = {'0x1057'},
    [41] = {'0x105F'},
    [42] = {'0x1080'},
    [43] = {'0x1081'},
    [44] = {'0x1082'},
    [45] = {'0x1083'},
    [46] = {'0x1090'},
    [47] = {'0x1091'},
    [48] = {'0x1092'},
    [49] = {'0x1093'},
    [50] = {'0x10A0'},
    [51] = {'0x10A1'},
    [52] = {'0x10A3'},
    [57] = {'0x10B1'},
    [58] = {'0x10B2'},
    [59] = {'0x10B3'},
    [60] = {'0x10C0'},
    [61] = {'0x10C1'},
    [64] = {'0x1100', '0x1101', '0x1102', '0x1103'},
    [65] = {'0x1101'},
    [66] = {'0x1102'},
    [67] = {'0x1103'},
    [68] = {'0x1110', '0x1111', '0x1112', '0x1113'},
    [69] = {'0x1111'},
    [70] = {'0x1112'},
    [71] = {'0x1113'},
    [73] = {'0x1121'},
    [74] = {'0x1122'},
    [75] = {'0x1123'},
    [76] = {'0x1124'},
    [77] = {'0x1125', '0x112B'},
    [78] = {'0x1126'},
    [79] = {'0x1127'},
    [80] = {'0x1128'},
    [81] = {'0x1129'},
    [82] = {'0x112A'},
    [85] = {'0x1141'},
    [86] = {'0x1142'},
    [87] = {'0x1143'},
    [88] = {'0x1200'},
    [89] = {'0x1201'},
    [90] = {'0x1202'},
    [91] = {'0x1203'},
    [92] = {'0x1204'},
    [93] = {'0x1205'},
    [95] = {'0x1211'},
    [96] = {'0x1212'},
    [98] = {'0x1213'},
    [99] = {'0x1220', '0x1221', '0x1222'},
    [100] = {'0xDB00'},
    [101] = {'0xDB01'},
    [102] = {'0xDB02'},
    [103] = {'0xDB03'},
    [104] = {'0xDB04'},
    [105] = {'0xDB05'},
    [106] = {'0xDB06'},
    [107] = {'0xDB07'}
}

elrs._relevantSig = nil
elrs._relevantSidSet = nil

local function telemetrySlotsSignature(slots)
    local parts = {}
    for i, v in ipairs(slots) do parts[#parts + 1] = tostring(v or 0) end
    return table.concat(parts, ",")
end

local function resetSensors()
    sensors['uid'] = {}
    sensors['lastvalue'] = {}
    sensors['lasttime'] = {}
end

local function rebuildRelevantSidSet()

    if elrs._relevantSidSet ~= nil then return end
    local cfg = rfsuite and rfsuite.session and rfsuite.session.telemetryConfig
    if not cfg then

        elrs._relevantSidSet = nil
        return
    end
    elrs._relevantSidSet = {}

    elrs._relevantSig = telemetrySlotsSignature(cfg)

    for _, slotId in ipairs(cfg) do
        local apps = sidLookup[slotId]
        if apps then
            for _, hex in ipairs(apps) do
                local sid = tonumber(hex)
                if sid then elrs._relevantSidSet[sid] = true end
            end
        end
    end
end

local function sidIsRelevant(sid)
    if META_UID[sid] then return true end
    if elrs._relevantSidSet == nil then return not elrs.strictUntilConfig end
    return elrs._relevantSidSet[sid] == true
end

local function nowMs() return math.floor(os.clock() * 1000) end
local REFRESH_INTERVAL_MS = 2500

local function createTelemetrySensor(uid, name, unit, dec, value, min, max)

    if rfsuite.session.telemetryState == false then return end

    sensors['uid'][uid] = model.createSensor({type = SENSOR_TYPE_DIY})
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
    if value then
        if useRawValue then
            sensors['uid'][uid]:rawValue(value)
        else
            sensors['uid'][uid]:value(value)
        end
        sensors['lastvalue'][uid] = value
        sensors['lasttime'][uid] = nowMs()
    end
end

local function refreshStaleSensors()
    local t = nowMs()
    for uid, s in pairs(sensors['uid']) do
        local last = sensors['lastvalue'][uid]
        local lt = sensors['lasttime'][uid]
        if s and last and lt and (t - lt) > REFRESH_INTERVAL_MS then
            if useRawValue then
                s:rawValue(last)
            else
                s:value(last)
            end    
            sensors['lasttime'][uid] = t
        end
    end
end

local function setTelemetryValue(uid, subid, instance, value, unit, dec, name, min, max)

    if rfsuite.session.telemetryState == false then return end

    if not sidIsRelevant(uid) then return end

    if sensors['uid'][uid] == nil then
        sensors['uid'][uid] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = uid})
        if sensors['uid'][uid] == nil then
            if rfsuite.utils and rfsuite.utils.log then rfsuite.utils.log("Create sensor: " .. tostring(uid), "debug") end
            createTelemetrySensor(uid, name, unit, dec, value, min, max)
        end
    else
        if sensors['uid'][uid] then
            if sensors['lastvalue'][uid] == nil or sensors['lastvalue'][uid] ~= value then
                if useRawValue then
                    sensors['uid'][uid]:rawValue(value)
                else
                    sensors['uid'][uid]:value(value)
                end
                sensors['lastvalue'][uid] = value
                sensors['lasttime'][uid] = nowMs()
            end

            if sensors['uid'][uid]:state() == false then
                sensors['uid'][uid] = nil
                sensors['lastvalue'][uid] = nil
                sensors['lasttime'][uid] = nil
            end

        end
    end
end

local function decNil(data, pos) return nil, pos end

local function decU8(data, pos) return data[pos], pos + 1 end

local function decS8(data, pos)
    local val, ptr = decU8(data, pos)
    return val < 0x80 and val or val - 0x100, ptr
end

local function decU16(data, pos) return (data[pos] << 8) | data[pos + 1], pos + 2 end

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

local function decU24(data, pos) return (data[pos] << 16) | (data[pos + 1] << 8) | data[pos + 2], pos + 3 end

local function decS24(data, pos)
    local val, ptr = decU24(data, pos)
    return val < 0x800000 and val or val - 0x1000000, ptr
end

local function decU32(data, pos) return (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3], pos + 4 end

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
    setTelemetryValue(0x1020, 0, 0, cnt, UNIT_RAW, 0, "Cell Count", 0, 15)
    for i = 1, cnt do
        val, pos = decU8(data, pos)
        val = val > 0 and val + 200 or 0
        vol = (cnt << 24) | ((i - 1) << 16) | val
        setTelemetryValue(0x102F, 0, 0, vol, UNIT_CELLS, 2, "Cell Voltages", 0, 455)
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

local sensorsList = {

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
elrs._lastFrameMs = nil
elrs._haveFrameId = false

function elrs.crossfirePop()

    if (rfsuite.session.telemetryState == false) then
        local module = model.getModule(rfsuite.session.telemetrySensor:module())
        if module ~= nil and module.muteSensorLost ~= nil then module:muteSensorLost(5.0) end

        if rfsuite.session.telemetryState == false then resetSensors() end

        return false
    else

        local command, data = elrs.popFrame(CRSF_FRAME_CUSTOM_TELEM)
        if command and data then

            local fid, sid, val
            local ptr = 3

            rebuildRelevantSidSet()

            fid, ptr = decU8(data, ptr)
            if elrs._haveFrameId then
                local delta = (fid - elrs.telemetryFrameId) & 0xFF
                if delta > 1 then
                    elrs.telemetryFrameSkip = elrs.telemetryFrameSkip + (delta - 1)
                end
            else
                -- First frame after (re)connect: establish baseline, don’t count skips.
                elrs._haveFrameId = true
            end
            elrs.telemetryFrameId = fid
            elrs.telemetryFrameCount = elrs.telemetryFrameCount + 1

            -- Frame timing (ms between received custom telemetry frames)
            local tnow = nowMs()
            if elrs._lastFrameMs ~= nil then
                local dt = tnow - elrs._lastFrameMs
                setTelemetryValue(0xEE03, 0, 0, dt, UNIT_MILLISECOND, 0, "Frame Δms", 0, 60000)
            end
            elrs._lastFrameMs = tnow

            local published = 0
            while ptr < #data do

                sid, ptr = decU16(data, ptr)
                local sensor = sensorsList[sid]
                if sensor then

                    local prev = ptr
                    local ok, v, np = pcall(sensor.dec, data, ptr)
                    if not ok then break end
                    ptr = np or prev
                    if ptr <= prev then break end

                    if v then
                        if published < (elrs.publishBudgetPerFrame or 40) then
                            setTelemetryValue(sid, 0, 0, v, sensor.unit, sensor.prec, sensor.name, sensor.min, sensor.max)
                            published = published + 1
                        end
                    end
                else
                    break
                end
            end

            setTelemetryValue(0xEE01, 0, 0, elrs.telemetryFrameCount, UNIT_RAW, 0, "Frame Count", 0, 2147483647)
            setTelemetryValue(0xEE02, 0, 0, elrs.telemetryFrameSkip, UNIT_RAW, 0, "Frame Skip", 0, 2147483647)
            return true
        end

        return false
    end
end

function elrs.wakeup()

    if not rfsuite.session.isConnected then return end
    if rfsuite.tasks and rfsuite.tasks.onconnect and rfsuite.tasks.onconnect.active and rfsuite.tasks.onconnect.active() then return end

    rebuildRelevantSidSet()

    if rfsuite.session.telemetryState and rfsuite.session.telemetrySensor then
        local budget = (elrs.popBudgetSeconds or (config and config.elrsPopBudgetSeconds) or 0.1)
        local deadline = (budget and budget > 0) and (os.clock() + budget) or nil
        while elrs.crossfirePop() do
            if deadline and os.clock() >= deadline then break end
        end
        refreshStaleSensors()
    else
        resetSensors()
    end
end

function elrs.reset()

    for i, v in pairs(sensors['uid']) do
        if v then
            v:reset()
        end
    end

    resetSensors()
    elrs._relevantSidSet = nil
    elrs._relevantSig = nil
    _lastSlotsSig = nil
    elrs.telemetryFrameId = 0
    elrs.telemetryFrameSkip = 0
    elrs.telemetryFrameCount = 0
    elrs._lastFrameMs = nil
    elrs._haveFrameId = false    
end

return elrs

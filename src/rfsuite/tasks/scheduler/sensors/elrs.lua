--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
ELRS sensor memory strategy:
- Keep the large full SID definition table in `elrs_sensors.lua`.
- Keep telemetry slot->SID mapping in `elrs_sid_lookup.lua`.
- Rebuild a runtime table on demand:
  - relevant SIDs keep full metadata + decoder
  - non-relevant SIDs keep decoder only (for parser alignment)
- Drop the full table after rebuild and rebuild again after reset/session restart.

Flow summary:
1. Build relevant SID set from telemetry config slots.
2. Load full SID map, reduce to runtime map, then release full table.
3. Decode all incoming SIDs to preserve parser alignment.
4. Publish values only for runtime entries that still include metadata (`name`).
]]

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]
local os_clock = os.clock
local math_floor = math.floor
local system_getSource = system.getSource
local model_createSensor = model.createSensor
local string_format = string.format
local load_file = loadfile

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

local CRSF_FRAME_CUSTOM_TELEM = 0x88

elrs.publishBudgetPerFrame = 50  -- If everything works this should never be reached.  we use it as a safeguard.

local META_UID = {
    [0xEE01] = true, 
    [0xEE02] = true,
    [0xEE03] = true,
    [0xEE04] = true,
    [0xEE05] = true,
    [0xEE06] = true
}

elrs.strictUntilConfig = false

local function loadSidLookup()
    local lookupLoader, lookupErr = load_file("tasks/scheduler/sensors/elrs_sid_lookup.lua")
    if not lookupLoader then
        if rfsuite.utils and rfsuite.utils.log then rfsuite.utils.log("[elrs] Failed to load SID lookup table: " .. tostring(lookupErr), "error") end
        return {}
    end

    local lookupTable = lookupLoader()
    if type(lookupTable) ~= "table" then
        if rfsuite.utils and rfsuite.utils.log then rfsuite.utils.log("[elrs] SID lookup file did not return a table", "error") end
        return {}
    end

    return lookupTable
end

local sidLookup = loadSidLookup()

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

    local cfg = rfsuite and rfsuite.session and rfsuite.session.telemetryConfig
    if not cfg then

        elrs._relevantSidSet = nil
        elrs._relevantSig = nil
        return
    end

    local sig = telemetrySlotsSignature(cfg)
    if elrs._relevantSidSet ~= nil and elrs._relevantSig == sig then return end

    elrs._relevantSidSet = {}
    elrs._relevantSig = sig

    for _, slotId in ipairs(cfg) do
        local apps = sidLookup[slotId]
        if apps then
            for _, sid in ipairs(apps) do
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

local function nowMs() return math_floor(os_clock() * 1000) end
local REFRESH_INTERVAL_MS = 2500

local function createTelemetrySensor(uid, name, unit, dec, value, min, max)

    if rfsuite.session.telemetryState == false then return end

    sensors['uid'][uid] = model_createSensor({type = SENSOR_TYPE_DIY})
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
        sensors['uid'][uid] = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = uid})
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

    lat = math_floor(lat * 0.001)
    lon = math_floor(lon * 0.001)

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

local sensorsList = {}
local activeSensorsListSig = nil

local function rebuildActiveSensorsList(force)
    local sig = elrs._relevantSig or "__all__"
    if not force and activeSensorsListSig == sig and next(sensorsList) ~= nil then return end

    local listLoader, listErr = load_file("tasks/scheduler/sensors/elrs_sensors.lua")
    if not listLoader then
        if rfsuite.utils and rfsuite.utils.log then rfsuite.utils.log("[elrs] Failed to load sensor list: " .. tostring(listErr), "error") end
        sensorsList = {}
        activeSensorsListSig = sig
        return
    end

    local listFactory = listLoader()
    if type(listFactory) ~= "function" then
        if rfsuite.utils and rfsuite.utils.log then rfsuite.utils.log("[elrs] Sensor list file did not return a factory function", "error") end
        sensorsList = {}
        activeSensorsListSig = sig
        return
    end

    local fullList = listFactory({
        decNil = decNil,
        decU8 = decU8,
        decS8 = decS8,
        decU16 = decU16,
        decS16 = decS16,
        decU24 = decU24,
        decS24 = decS24,
        decU32 = decU32,
        decS32 = decS32,
        decCellV = decCellV,
        decCells = decCells,
        decControl = decControl,
        decAttitude = decAttitude,
        decAccel = decAccel,
        decLatLong = decLatLong,
        decAdjFunc = decAdjFunc
    })

    if type(fullList) ~= "table" then
        if rfsuite.utils and rfsuite.utils.log then rfsuite.utils.log("[elrs] Sensor list factory did not return a table", "error") end
        sensorsList = {}
        activeSensorsListSig = sig
        return
    end

    local nextList = {}
    for sid, sensor in pairs(fullList) do
        if sidIsRelevant(sid) then
            nextList[sid] = sensor
        else
            nextList[sid] = {dec = sensor.dec}
        end
    end

    sensorsList = nextList
    activeSensorsListSig = sig

    fullList = nil
    collectgarbage("collect")
end

elrs.telemetryFrameId = 0
elrs.telemetryFrameSkip = 0
elrs.telemetryFrameCount = 0
elrs._lastFrameMs = nil
elrs._haveFrameId = false
elrs.publishOverflowCount = 0
elrs.wakeupBudgetBreakCount = 0
elrs.parseBreakCount = 0
elrs.diagLogCooldownSeconds = 2.0
elrs.wakeupBudgetLogEvery = 25

local lastDiagLogAt = {
    publish_overflow = 0,
    wakeup_budget = 0,
    parse_break = 0
}

local function logDiag(kind, msg, level)
    local utils = rfsuite.utils
    if not utils or type(utils.log) ~= "function" then return end
    local now = os_clock()
    local last = lastDiagLogAt[kind] or 0
    if now - last < (elrs.diagLogCooldownSeconds or 2.0) then return end
    lastDiagLogAt[kind] = now
    utils.log(msg, level or "debug")
end

function elrs.crossfirePop()

    if (rfsuite.session.telemetryState == false) then
        local ts = rfsuite.session.telemetrySensor
        if ts then
            local module = model.getModule(ts:module())
            if module ~= nil and module.muteSensorLost ~= nil then module:muteSensorLost(5.0) end
        end

        resetSensors()

        return false
    else

        local command, data = elrs.popFrame(CRSF_FRAME_CUSTOM_TELEM)
        if command and data then

            local fid, sid, val
            local ptr = 3

            rebuildRelevantSidSet()
            rebuildActiveSensorsList()

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
            local publishOverflowed = false
            while ptr < #data do

                sid, ptr = decU16(data, ptr)
                local sensor = sensorsList[sid]
                if sensor then

                    local prev = ptr
                    local ok, v, np = pcall(sensor.dec, data, ptr)
                    if not ok then
                        elrs.parseBreakCount = elrs.parseBreakCount + 1
                        logDiag("parse_break", string_format("[elrs] telemetry parse break: sid=0x%04X decode error", sid), "info")
                        break
                    end
                    ptr = np or prev
                    if ptr <= prev then
                        elrs.parseBreakCount = elrs.parseBreakCount + 1
                        logDiag("parse_break", string_format("[elrs] telemetry parse break: sid=0x%04X decoder made no progress", sid), "info")
                        break
                    end

                    if v and sensor.name ~= nil then
                        if published < (elrs.publishBudgetPerFrame or 40) then
                            setTelemetryValue(sid, 0, 0, v, sensor.unit, sensor.prec, sensor.name, sensor.min, sensor.max)
                            published = published + 1
                        elseif not publishOverflowed then
                            publishOverflowed = true
                            elrs.publishOverflowCount = elrs.publishOverflowCount + 1
                            logDiag("publish_overflow", string_format("[elrs] telemetry publish overflow: frameId=%d sid=0x%04X budget=%d", elrs.telemetryFrameId, sid, elrs.publishBudgetPerFrame or 40), "info")
                        end
                    end
                else
                    elrs.parseBreakCount = elrs.parseBreakCount + 1
                    logDiag("parse_break", string_format("[elrs] telemetry parse break: unknown sid=0x%04X", sid), "info")
                    break
                end
            end

            setTelemetryValue(0xEE01, 0, 0, elrs.telemetryFrameCount, UNIT_RAW, 0, "Frame Count", 0, 2147483647)
            setTelemetryValue(0xEE02, 0, 0, elrs.telemetryFrameSkip, UNIT_RAW, 0, "Frame Skip", 0, 2147483647)

            --[[
            These are for debug only, not intended to be added as official telemetry sensors
             setTelemetryValue(0xEE04, 0, 0, elrs.publishOverflowCount, UNIT_RAW, 0, "Publish Overflow", 0, 2147483647)
             setTelemetryValue(0xEE05, 0, 0, elrs.wakeupBudgetBreakCount, UNIT_RAW, 0, "Wakeup Break", 0, 2147483647)
             setTelemetryValue(0xEE06, 0, 0, elrs.parseBreakCount, UNIT_RAW, 0, "Parse Break", 0, 2147483647)
            ]]--

            return true
        end

        return false
    end
end

function elrs.wakeup()

    if not rfsuite.session.isConnected then return end

    rebuildRelevantSidSet()

    if rfsuite.session.telemetryState and rfsuite.session.telemetrySensor then
        local budget = (elrs.popBudgetSeconds or (config and config.elrsPopBudgetSeconds) or 0.2)
        local deadline = (budget and budget > 0) and (os_clock() + budget) or nil
        local pops = 0
        while elrs.crossfirePop() do
            pops = pops + 1
            if deadline and os_clock() >= deadline then
                elrs.wakeupBudgetBreakCount = elrs.wakeupBudgetBreakCount + 1
                local logEvery = tonumber(elrs.wakeupBudgetLogEvery) or 25
                if elrs.wakeupBudgetBreakCount == 1 or (logEvery > 0 and (elrs.wakeupBudgetBreakCount % logEvery) == 0) then
                    logDiag(
                        "wakeup_budget",
                        string_format(
                            "[elrs] wakeup budget break: budget=%.3fs frames=%d count=%d",
                            budget,
                            pops,
                            elrs.wakeupBudgetBreakCount
                        ),
                        "info"
                    )
                end
                break
            end
        end
        setTelemetryValue(0xEE05, 0, 0, elrs.wakeupBudgetBreakCount, UNIT_RAW, 0, "Wakeup Break", 0, 2147483647)
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
    sensorsList = {}
    activeSensorsListSig = nil
    elrs.telemetryFrameId = 0
    elrs.telemetryFrameSkip = 0
    elrs.telemetryFrameCount = 0
    elrs._lastFrameMs = nil
    elrs._haveFrameId = false
    elrs.publishOverflowCount = 0
    elrs.wakeupBudgetBreakCount = 0
    elrs.parseBreakCount = 0
end

return elrs

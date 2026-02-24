--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
Telemetry table layout:
- `sources/sensor_table.lua` stores shared sensor metadata (name, units, stats, transforms, onchange).
- `sources/sim.lua`, `sources/sport.lua`, `sources/crsf.lua`, and `sources/crsf_legacy.lua`
  store transport-specific source candidates only.
- Only the active transport table is loaded to keep RAM usage down.

Update process:
1. Add or change the sensor key in `sources/sensor_table.lua`.
2. Mirror the same key in every transport source file.
3. Keep keys stable because widgets, stats, and events index by sensor key.
]]

local rfsuite = require("rfsuite")

local arg = {...}

local simSensors = rfsuite.utils.simSensors

local telemetry = {}

local telemetryTypeChanged = false

local os_clock = os.clock
local sys_getSource = system.getSource
local sys_getVersion = system.getVersion
local t_insert = table.insert
local t_remove = table.remove
local t_pairs = pairs
local t_ipairs = ipairs
local t_type = type
local load_file = loadfile
local isSim = sys_getVersion().simulation == true

local protocol, crsfSOURCE

local sensors = setmetatable({}, {__mode = "v"})

local cache_hits, cache_misses = 0, 0

local HOT_SIZE = 20
local hot_list, hot_index = {}, {}

local function rebuild_hot_index()
    hot_index = {}
    for i, k in t_ipairs(hot_list) do hot_index[k] = i end
end

local function mark_hot(key)
    local idx = hot_index[key]

    if idx and idx >= 1 and idx <= #hot_list then
        t_remove(hot_list, idx)
        rebuild_hot_index()

    elseif #hot_list >= HOT_SIZE then
        local old = t_remove(hot_list, 1)
        if old ~= nil then
            hot_index[old] = nil
            sensors[old] = nil
        end
        rebuild_hot_index()
    end

    t_insert(hot_list, key)
    hot_index[key] = #hot_list
end

function telemetry._debugStats() return {hits = cache_hits, misses = cache_misses, hot_size = #hot_list, hot_list = hot_list} end

local sensorRateLimit = os_clock()
local ONCHANGE_RATE = 5

local lastValidationResult = nil
local lastValidationTime = 0
local VALIDATION_RATE_LIMIT = 10

local telemetryState = false

local lastSensorValues = {}

telemetry.sensorStats = {}

local memo_listSensors, memo_listSwitchSensors, memo_listAudioUnits = nil, nil, nil

local filteredOnchangeSensors = nil
local onchangeInitialized = false

local function loadSensorMetadata()
    local metadataLoader, metadataErr = load_file("tasks/scheduler/telemetry/sources/sensor_table.lua")
    if not metadataLoader then
        if rfsuite and rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("[telemetry] Failed to load sensor metadata table: " .. tostring(metadataErr), "error")
        end
        return {}
    end

    local metadataTable = metadataLoader()
    if t_type(metadataTable) ~= "table" then
        if rfsuite and rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("[telemetry] Sensor metadata file did not return a table", "error")
        end
        return {}
    end

    return metadataTable
end

local sensorTable = loadSensorMetadata()

local sourceModules = {
    sim = "tasks/scheduler/telemetry/sources/sim.lua",
    sport = "tasks/scheduler/telemetry/sources/sport.lua",
    crsf = "tasks/scheduler/telemetry/sources/crsf.lua",
    crsfLegacy = "tasks/scheduler/telemetry/sources/crsf_legacy.lua"
}

local sourceTables = {}
local activeSourceMode, activeSourceTable = nil, nil

local function clearRuntimeCaches()
    sensors = setmetatable({}, {__mode = "v"})
    hot_list, hot_index = {}, {}
    filteredOnchangeSensors = nil
    lastSensorValues = {}
    onchangeInitialized = false
    lastValidationResult = nil
    lastValidationTime = 0
    cache_hits, cache_misses = 0, 0
    memo_listSensors, memo_listSwitchSensors, memo_listAudioUnits = nil, nil, nil
end

local function detectSourceMode(session)
    if isSim then
        protocol = "sport"
        return "sim"
    end

    if session and session.telemetryType == "crsf" then
        if not crsfSOURCE then crsfSOURCE = sys_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = 0xEE01}) end
        if crsfSOURCE then
            protocol = "crsf"
            return "crsf"
        end
        protocol = "crsfLegacy"
        return "crsfLegacy"
    end

    if session and session.telemetryType == "sport" then
        protocol = "sport"
        return "sport"
    end

    protocol = "unknown"
    return nil
end

local function loadSourceTable(mode, keepOtherModes)
    if not mode then return nil end

    local sourceTable = sourceTables[mode]
    if not sourceTable then
        local modulePath = sourceModules[mode]
        if not modulePath then return nil end
        local sourceLoader, sourceErr = load_file(modulePath)
        if not sourceLoader then
            if rfsuite and rfsuite.utils and rfsuite.utils.log then rfsuite.utils.log("[telemetry] Failed to load source table: " .. tostring(sourceErr), "error") end
            return nil
        end
        sourceTable = sourceLoader() or {}
        sourceTables[mode] = sourceTable
    end

    if not keepOtherModes then
        for otherMode in t_pairs(sourceModules) do
            if otherMode ~= mode then sourceTables[otherMode] = nil end
        end
    end

    return sourceTable
end

local function setActiveSourceMode(mode)
    if not mode then
        clearRuntimeCaches()
        activeSourceMode, activeSourceTable = nil, nil
        return nil
    end

    if activeSourceMode == mode and activeSourceTable then return activeSourceTable end

    activeSourceTable = loadSourceTable(mode, false)
    activeSourceMode = mode
    clearRuntimeCaches()
    collectgarbage("collect")
    return activeSourceTable
end

function telemetry.getSensorProtocol() return protocol end

local function build_memo_lists()
    memo_listSensors, memo_listSwitchSensors, memo_listAudioUnits = {}, {}, {}
    for key, sensor in t_pairs(sensorTable) do
        t_insert(memo_listSensors, {
            key = key,
            name = sensor.name,
            mandatory = sensor.mandatory,
            set_telemetry_sensors = sensor.set_telemetry_sensors
        })
        if sensor.switch_alerts then
            t_insert(memo_listSwitchSensors, {
                key = key,
                name = sensor.name,
                mandatory = sensor.mandatory,
                set_telemetry_sensors = sensor.set_telemetry_sensors
            })
        end
        if sensor.unit then
            memo_listAudioUnits[key] = sensor.unit
        end
    end
end

function telemetry.listSensors()
    if not memo_listSensors then build_memo_lists() end
    return memo_listSensors
end

function telemetry.listSensorAudioUnits()
    if not memo_listAudioUnits then build_memo_lists() end
    return memo_listAudioUnits
end

function telemetry.listSwitchSensors()
    if not memo_listSwitchSensors then build_memo_lists() end
    return memo_listSwitchSensors
end

local function checkCondition(sensorEntry)
    if t_type(sensorEntry) ~= "table" then return true end
    local sess = rfsuite.session
    if not (sess and sess.apiVersion) then return true end
    local gt, lt = sensorEntry.mspgt, sensorEntry.msplt
    if gt and not rfsuite.utils.apiVersionCompare(">=", gt) then return false end
    if lt and not rfsuite.utils.apiVersionCompare("<=", lt) then return false end
    return true
end

function telemetry.getSensorSource(name)

    local session = rfsuite.session
    local entry = sensorTable[name]
    if not entry then return nil end

    local mode = detectSourceMode(session)
    local sourceTable = setActiveSourceMode(mode)
    if not sourceTable then return nil end

    local src = sensors[name]
    if src then
        cache_hits = cache_hits + 1
        mark_hot(name)
        return src
    end

    local sourceCandidates = sourceTable[name] or {}

    if mode == "sim" then
        for _, sensor in t_ipairs(sourceCandidates) do
            if sensor.uid then
                local sensorQ = {appId = sensor.uid, category = CATEGORY_TELEMETRY_SENSOR}
                local source = sys_getSource(sensorQ)
                if source then
                    cache_misses = cache_misses + 1
                    sensors[name] = source
                    mark_hot(name)
                    return source
                end
            else
                if checkCondition(sensor) and t_type(sensor) == "table" then
                    local source = sys_getSource(sensor)
                    if source then
                        cache_misses = cache_misses + 1
                        sensors[name] = source
                        mark_hot(name)
                        return source
                    end
                end
            end
        end

    elseif mode == "crsfLegacy" then
        for _, sensor in t_ipairs(sourceCandidates) do
            local source = sys_getSource(sensor)
            if source then
                cache_misses = cache_misses + 1
                sensors[name] = source
                mark_hot(name)
                return source
            end
        end

    elseif mode == "sport" or mode == "crsf" then
        for _, sensor in t_ipairs(sourceCandidates) do
            if checkCondition(sensor) and t_type(sensor) == "table" then
                local source = sys_getSource(sensor)
                if source then
                    cache_misses = cache_misses + 1
                    sensors[name] = source
                    mark_hot(name)
                    return source
                end
            end
        end
    end

    return nil
end

function telemetry.getSensor(sensorKey, paramMin, paramMax, paramThresholds)
    local entry = sensorTable[sensorKey]

    if entry and t_type(entry.source) == "function" then
        local src = entry.source()
        if src and t_type(src.value) == "function" then
            local value, major, minor = src.value()
            major = major or entry.unit
            if entry.localizations and t_type(entry.localizations) == "function" then value, major, minor = entry.localizations(value) end
            return value, major, minor
        end
    end

    local source = telemetry.getSensorSource(sensorKey)
    if not source then return nil end

    local value = source:value()
    local major = entry and entry.unit or nil
    local minor = nil

    if entry and entry.transform and t_type(entry.transform) == "function" then value = entry.transform(value) end

    if entry and entry.localizations and t_type(entry.localizations) == "function" then return entry.localizations(value, paramMin, paramMax, paramThresholds) end

    return value, major, minor, paramMin, paramMax, paramThresholds
end

function telemetry.validateSensors(returnValid)
    local now = os_clock()
    if (now - lastValidationTime) < VALIDATION_RATE_LIMIT then return lastValidationResult or true end
    lastValidationTime = now

    local session = rfsuite.session
    if not (session and session.telemetryState) then
        if not memo_listSensors then build_memo_lists() end
        lastValidationResult = memo_listSensors
        return memo_listSensors
    end

    local resultSensors = {}
    for key, sensor in t_pairs(sensorTable) do
        local sensorSource = telemetry.getSensorSource(key)
        local isValid = (sensorSource ~= nil and sensorSource:state() ~= false)
        if returnValid then
            if isValid then t_insert(resultSensors, {key = key, name = sensor.name}) end
        else
            if not isValid and sensor.mandatory ~= false then t_insert(resultSensors, {key = key, name = sensor.name}) end
        end
    end

    lastValidationResult = resultSensors
    return resultSensors
end

function telemetry.simSensors(returnValid)
    local sourceTable = loadSourceTable("sim", true) or {}
    local result = {}
    for key, sensor in t_pairs(sensorTable) do
        local candidates = sourceTable[key]
        local firstSim = candidates and candidates[1]
        if firstSim then t_insert(result, {name = sensor.name, sensor = firstSim}) end
    end
    return result
end

function telemetry.active() return (rfsuite.session and rfsuite.session.telemetryState) or false end

function telemetry.reset()
    protocol, crsfSOURCE = nil, nil
    clearRuntimeCaches()
    sensorRateLimit = os_clock()
end

function telemetry.wakeup()
    local now = os_clock()
    local session = rfsuite.session

    if session and session.mspBusy then return end

    local tasks = rfsuite.tasks
    if tasks and tasks.onconnect and tasks.onconnect.active and tasks.onconnect.active() then return end

    if (now - sensorRateLimit) >= ONCHANGE_RATE then
        sensorRateLimit = now

        if not filteredOnchangeSensors then
            filteredOnchangeSensors = {}
            for sensorKey, sensorDef in t_pairs(sensorTable) do if t_type(sensorDef.onchange) == "function" then filteredOnchangeSensors[sensorKey] = sensorDef end end
            onchangeInitialized = true
        end

        if onchangeInitialized then
            onchangeInitialized = false
        else
            for sensorKey, sensorDef in t_pairs(filteredOnchangeSensors) do
                local source = telemetry.getSensorSource(sensorKey)
                if source and source:state() then
                    local val = source:value()
                    if lastSensorValues[sensorKey] ~= val then
                        sensorDef.onchange(val)
                        lastSensorValues[sensorKey] = val
                    end
                end
            end
        end
    end

    if not (session and session.telemetryState) then telemetry.reset() end
end

function telemetry.getSensorStats(sensorKey) return telemetry.sensorStats[sensorKey] or {min = nil, max = nil} end

function telemetry.setTelemetryTypeChanged()
    telemetryTypeChanged = true
    telemetry.reset()
end

telemetry.sensorTable = sensorTable

return telemetry

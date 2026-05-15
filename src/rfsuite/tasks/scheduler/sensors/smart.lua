--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local smart = {}

local smartfuel = assert(loadfile("tasks/scheduler/sensors/lib/smartfuel.lua"))()
local smartfuelvoltage = assert(loadfile("tasks/scheduler/sensors/lib/smartfuelvoltage.lua"))()
local smartfuelprefs = assert(loadfile("tasks/scheduler/sensors/lib/smartfuelprefs.lua"))()

local log
local tasks

local os_clock = os.clock
local math_abs = math.abs
local interval = 1
local lastWake = os_clock()
local system_getSource = system.getSource
local model_createSensor = model.createSensor
local telemetry
local firstWakeup = true

local sensorCache = {}
local negativeCache = {}
local lastValue = {}
local lastPush = {}
local lastModule = nil
local VALUE_EPSILON = 0.0
local FORCE_REFRESH_INTERVAL = 2.0
local modeSignature = nil
local lastSmartFuelMode = nil

local useRawValue = rfsuite.utils.ethosVersionAtLeast({26, 1, 0})

local mirror_sources = {
    sport = {
        smartfuel = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600},
        smartconsumption = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250}
    },
    crsf = {
        smartfuel = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014},
        smartconsumption = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013}
    }
}

local function getProtocol()
    return rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.protocol and rfsuite.tasks.msp.protocol.mspProtocol
end

local function getFirmwareSmartFuelSource()
    if system.getVersion().simulation == true then
        return nil
    end

    if not rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
        return nil
    end

    local batteryConfig = rfsuite.session and rfsuite.session.batteryConfig
    return batteryConfig and tonumber(batteryConfig.smartfuelRemoteSource)
end

local function useFirmwareSmartFuel()
    local source = getFirmwareSmartFuelSource()
    return source ~= nil and source > 0
end

local function useLocalVoltageSmartFuel()
    return smartfuelprefs.getSource() == 1
end

local function getSmartFuelMode()
    if useFirmwareSmartFuel() then
        return "firmware"
    elseif useLocalVoltageSmartFuel() then
        return "voltage"
    end
    return "current"
end

local function getSmartFuelModeDetail(mode)
    local firmwareSource = getFirmwareSmartFuelSource()
    local localSource = smartfuelprefs.getSource()
    local remoteLabel = firmwareSource == 1 and "VOLTAGE" or firmwareSource == 2 and "CURRENT" or firmwareSource == 3 and "COMBINED" or firmwareSource == 0 and "OFF" or "n/a"
    local localLabel = localSource == 1 and "VOLTAGE" or "CURRENT"
    if mode == "firmware" then
        return "firmware " .. remoteLabel
    end
    return "local " .. localLabel .. " (firmware " .. remoteLabel .. ")"
end

local function getMirrorSensorValue(name)
    local protocol = getProtocol()
    local sources = protocol and mirror_sources[protocol]
    local query = sources and sources[name]
    if not query then return nil end

    local source = system_getSource(query)
    if not source or (source.state and source:state() == false) then
        return nil
    end

    return source:value()
end

local function calculateFuel()
    if useFirmwareSmartFuel() then
        local rawFuel = getMirrorSensorValue("smartfuel")
        if rawFuel == nil then return nil end
        return math.floor(math.min(100, math.max(0, rawFuel)) + 0.5)
    end

    return smartfuelvoltage.calculate()
end

local function calculateConsumption()
    if useFirmwareSmartFuel() then
        return getMirrorSensorValue("smartconsumption")
    end

    if smartfuelvoltage.getConsumption then
        local consumption = smartfuelvoltage.getConsumption()
        if consumption ~= nil then return consumption end
    end
    return 0
end

local function resetFuel()
    smartfuel.reset()
    smartfuelvoltage.reset()
end

local function clamp(v, minv, maxv)
    if v == nil then return nil end
    if v < minv then
        return minv
    elseif v > maxv then
        return maxv
    else
        return v
    end
end

local function resetConsumption() end

local smart_sensors = {smartfuel = {name = "Smart Fuel", appId = 0x5FE1, unit = UNIT_PERCENT, minimum = -1, maximum = 100, value = calculateFuel}, smartconsumption = {name = "Smart Consumption", appId = 0x5FE0, unit = UNIT_MILLIAMPERE_HOUR, minimum = 0, maximum = 1000000000, value = calculateConsumption}}

smart.sensors = smart_sensors

local function syncSmartSensorMode()
    local session = rfsuite.session
    if not (session and session.apiVersion and session.telemetrySensor) then return end

    local protocol = getProtocol()
    local moduleId = session.telemetrySensor and session.telemetrySensor.module and session.telemetrySensor:module() or "?"
    local smartFuelMode = getSmartFuelMode()
    local signature = table.concat({tostring(session.apiVersion), tostring(protocol or "?"), tostring(moduleId), smartFuelMode}, ":")
    if modeSignature == signature then return end
    modeSignature = signature

    if lastSmartFuelMode ~= smartFuelMode then
        resetFuel()
        resetConsumption()
        lastValue = {}
        lastPush = {}
        if log then
            local msg = "Smart Fuel mode: " .. getSmartFuelModeDetail(smartFuelMode)
            log(msg, "info")
            log(msg, "connect")
        end
    end
    lastSmartFuelMode = smartFuelMode
end

local function createOrUpdateSensor(appId, fieldMeta, value)

    local currentModule = rfsuite.session.telemetrySensor and rfsuite.session.telemetrySensor:module()
    if lastModule ~= currentModule then
        sensorCache = {}
        negativeCache = {}
        lastModule = currentModule
    end

    if sensorCache[appId] == nil and negativeCache[appId] then
        return
    end

    if not sensorCache[appId] and not negativeCache[appId] then
        local existingSensor = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
        if existingSensor then
            sensorCache[appId] = existingSensor
        else
            if not rfsuite.session.telemetrySensor then
                negativeCache[appId] = true
                return
            end
            local sensor = model_createSensor({type = SENSOR_TYPE_DIY})
            sensor:name(fieldMeta.name)
            sensor:appId(appId)
            sensor:physId(0)
            sensor:module(rfsuite.session.telemetrySensor:module())

            if fieldMeta.unit then
                sensor:unit(fieldMeta.unit)
                sensor:protocolUnit(fieldMeta.unit)
            end
            sensor:minimum(fieldMeta.minimum or -1000000000)
            sensor:maximum(fieldMeta.maximum or 1000000000)

            sensorCache[appId] = sensor
        end
        if not sensorCache[appId] then negativeCache[appId] = true end
    end

    if value ~= nil then
        local minv = fieldMeta.minimum or -1000000000
        local maxv = fieldMeta.maximum or 1000000000
        local v = clamp(value, minv, maxv)
        local last = lastValue[appId]
        local now = os_clock()
        local stale = (now - (lastPush[appId] or 0)) >= FORCE_REFRESH_INTERVAL
        if last == nil or math_abs(v - last) >= VALUE_EPSILON or stale then
            if useRawValue then
                sensorCache[appId]:rawValue(v)
            else
                sensorCache[appId]:value(v)
            end
            lastValue[appId] = v
            lastPush[appId] = now
        end
    else
        sensorCache[appId]:reset()
        lastValue[appId] = nil
        lastPush[appId] = os_clock()
    end
end
function smart.wakeup()

    if not rfsuite.session.isConnected then return end
    if rfsuite.tasks and rfsuite.tasks.onconnect and rfsuite.tasks.onconnect.active and rfsuite.tasks.onconnect.active() then return end

    if firstWakeup then
        log = rfsuite.utils.log
        tasks = rfsuite.tasks
        firstWakeup = false
    end

    if not (rfsuite.session.telemetryState and rfsuite.session.telemetrySensor) then
        sensorCache = {}
        negativeCache = {}
        lastValue = {}
        return
    end

    if (os_clock() - lastWake) < interval then return end
    lastWake = os_clock()

    syncSmartSensorMode()

    for name, meta in pairs(smart_sensors) do
        local value
        if type(meta.value) == "function" then
            value = meta.value()
        else
            value = meta.value
        end
        createOrUpdateSensor(meta.appId, meta, value)
    end
end

function smart.reset()

    -- Reset the sensors before clearing caches
    for i,v in pairs(sensorCache) do
        if v then
            v:reset()
        end
    end

    -- clear caches
    sensorCache = {}
    negativeCache = {}
    lastValue = {}
    lastPush = {}
    lastModule = nil
    modeSignature = nil
    lastSmartFuelMode = nil

    resetFuel()
    resetConsumption()

end

return smart

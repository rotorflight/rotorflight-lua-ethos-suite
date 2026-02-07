--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]
local os_clock = os.clock
local cacheExpireTime = 10
local lastCacheFlushTime = os_clock()
local sensorTlm
local POP_BUDGET_SECONDS = (config and config.frskyLegacyPopBudgetSeconds) or 0.004

local system_getSource = system.getSource
local model_createSensor = model.createSensor

local frsky_legacy = {}

frsky_legacy.name = "frsky_legacy"

local createSensorList = {}
createSensorList[0x5450] = {name = "Governor Flags", unit = UNIT_RAW}
createSensorList[0x5110] = {name = "Adj. Source", unit = UNIT_RAW}
createSensorList[0x5111] = {name = "Adj. Value", unit = UNIT_RAW}
createSensorList[0x5460] = {name = "Model ID", unit = UNIT_RAW}
createSensorList[0x5471] = {name = "PID Profile", unit = UNIT_RAW}
createSensorList[0x5472] = {name = "Rate Profile", unit = UNIT_RAW}
createSensorList[0x5440] = {name = "Throttle %", unit = UNIT_PERCENT}
createSensorList[0x5250] = {name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR}
createSensorList[0x5462] = {name = "Arming Flags", unit = UNIT_RAW}

local dropSensorList = {}
dropSensorList[0x0400] = {name = "Temp1"}
dropSensorList[0x0410] = {name = "Temp1"}

local renameSensorList = {}
renameSensorList[0x0500] = {name = "Headspeed", onlyifname = "RPM"}
renameSensorList[0x0501] = {name = "Tailspeed", onlyifname = "RPM"}

renameSensorList[0x0210] = {name = "Voltage", onlyifname = "VFAS"}
renameSensorList[0x0200] = {name = "Current", onlyifname = "Current"}
renameSensorList[0x0600] = {name = "Charge Level", onlyifname = "Fuel"}
renameSensorList[0x0910] = {name = "Cell Voltage", onlyifname = "ADC4"}
renameSensorList[0x0900] = {name = "BEC Voltage", onlyifname = "ADC3"}

renameSensorList[0x0211] = {name = "ESC Voltage", onlyifname = "VFAS"}
renameSensorList[0x0201] = {name = "ESC Current", onlyifname = "Current"}
renameSensorList[0x0502] = {name = "ESC RPM", onlyifname = "RPM"}
renameSensorList[0x0B70] = {name = "ESC Temp", onlyifname = "ESC temp"}

renameSensorList[0x0212] = {name = "ESC2 Voltage", onlyifname = "VFAS"}
renameSensorList[0x0202] = {name = "ESC2 Current", onlyifname = "Current"}
renameSensorList[0x0503] = {name = "ESC2 RPM", onlyifname = "RPM"}
renameSensorList[0x0B71] = {name = "ESC2 Temp", onlyifname = "ESC temp"}

renameSensorList[0x0401] = {name = "MCU Temp", onlyifname = "Temp1"}
renameSensorList[0x0840] = {name = "Heading", onlyifname = "GPS course"}

frsky_legacy.createSensorCache = {}
frsky_legacy.dropSensorCache = {}
frsky_legacy.renameSensorCache = {}

local function createSensor(physId, primId, appId, frameValue)

    if createSensorList[appId] ~= nil then

        local v = createSensorList[appId]

        if frsky_legacy.createSensorCache[appId] == nil then

            frsky_legacy.createSensorCache[appId] = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky_legacy.createSensorCache[appId] == nil then

                frsky_legacy.createSensorCache[appId] = model_createSensor()
                frsky_legacy.createSensorCache[appId]:name(v.name)
                frsky_legacy.createSensorCache[appId]:appId(appId)
                frsky_legacy.createSensorCache[appId]:physId(physId)
                frsky_legacy.createSensorCache[appId]:module(rfsuite.session.telemetrySensor:module())

                frsky_legacy.createSensorCache[appId]:minimum(min or -1000000000)
                frsky_legacy.createSensorCache[appId]:maximum(max or 2147483647)
                if v.unit ~= nil then
                    frsky_legacy.createSensorCache[appId]:unit(v.unit)
                    frsky_legacy.createSensorCache[appId]:protocolUnit(v.unit)
                end
                if v.minimum ~= nil then frsky_legacy.createSensorCache[appId]:minimum(v.minimum) end
                if v.maximum ~= nil then frsky_legacy.createSensorCache[appId]:maximum(v.maximum) end

            end

        end
    end

end

local function dropSensor(physId, primId, appId, frameValue)

    if dropSensorList[appId] ~= nil then
        local v = dropSensorList[appId]

        if frsky_legacy.dropSensorCache[appId] == nil then
            frsky_legacy.dropSensorCache[appId] = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky_legacy.dropSensorCache[appId] ~= nil then frsky_legacy.dropSensorCache[appId]:drop() end

        end

    end

end

local function renameSensor(physId, primId, appId, frameValue)

    if renameSensorList[appId] ~= nil then
        local v = renameSensorList[appId]

        if frsky_legacy.renameSensorCache[appId] == nil then
            frsky_legacy.renameSensorCache[appId] = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky_legacy.renameSensorCache[appId] ~= nil then if frsky_legacy.renameSensorCache[appId]:name() == v.onlyifname then frsky_legacy.renameSensorCache[appId]:name(v.name) end end

        end

    end

end

local function telemetryPop()

    if not sensorTlm then
        sensorTlm = sport.getSensor()
        sensorTlm:module(rfsuite.session.telemetrySensor:module())

        if not sensorTlm then return false end
    end    

    local frame = sensorTlm:popFrame()

    if frame == nil then return false end

    local physId = frame:physId()
    local primId = frame:primId()

    if not physId or not primId then return end

    local appId = frame:appId()
    local value = frame:value()

    createSensor(physId, primId, appId, value)
    dropSensor(physId, primId, appId, value)
    renameSensor(physId, primId, appId, value)
    return true
end

function frsky_legacy.wakeup()

    local function clearCaches()
        frsky_legacy.createSensorCache = {}
        frsky_legacy.renameSensorCache = {}
        frsky_legacy.dropSensorCache = {}
    end

    if os_clock() - lastCacheFlushTime >= cacheExpireTime then
        clearCaches()
        lastCacheFlushTime = os_clock()
    end

    if not rfsuite.session.telemetryState or not rfsuite.session.telemetrySensor then clearCaches() end

    -- if this function exists, we can use it to determine if we should quick exit and avoid all sensor popping
    if system.isSensorDiscoverActive then 
        if system.isSensorDiscoverActive() then
            return
        end
    end

    if rfsuite.tasks and rfsuite.tasks.telemetry and rfsuite.session.telemetryState and rfsuite.session.telemetrySensor then
        local deadline = (POP_BUDGET_SECONDS and POP_BUDGET_SECONDS > 0) and (os_clock() + POP_BUDGET_SECONDS) or nil
        while telemetryPop() do
            if deadline and os_clock() >= deadline then break end
        end
    end

end

function frsky_legacy.reset()
    frsky_legacy.createSensorCache = {}
    frsky_legacy.renameSensorCache = {}
    frsky_legacy.dropSensorCache = {}
end

return frsky_legacy

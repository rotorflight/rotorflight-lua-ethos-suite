--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local frsky_legacy = {}

frsky_legacy.name = "frsky_legacy"

local MAX_FRAMES_PER_WAKEUP = 32
local MAX_TIME_BUDGET = 0.004

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

frsky_legacy.renamed = {}
frsky_legacy.dropped = {}

local function createSensor(physId, primId, appId, frameValue)
    if rfsuite.session.apiVersion == nil then return "skip" end
    local v = createSensorList[appId]
    if not v then return "skip" end

    if frsky.createSensorCache[appId] == nil then
        frsky.createSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
        if frsky.createSensorCache[appId] == nil then
            local s = model.createSensor()
            s:name(v.name)
            s:appId(appId)
            s:physId(physId)
            s:module(rfsuite.session.telemetrySensor:module())
            s:minimum(min or -1000000000)
            s:maximum(max or 2147483647)
            if v.unit then
                s:unit(v.unit);
                s:protocolUnit(v.unit)
            end
            if v.decimals then
                s:decimals(v.decimals);
                s:protocolDecimals(v.decimals)
            end
            if v.minimum then s:minimum(v.minimum) end
            if v.maximum then s:maximum(v.maximum) end
            frsky.createSensorCache[appId] = s
            return "created"
        end
    end

    return "noop"
end

local function dropSensor(physId, primId, appId, frameValue)
    if rfsuite.session.apiVersion == nil then return "skip" end
    if not dropSensorList or not dropSensorList[appId] then return "skip" end

    if frsky.dropSensorCache[appId] == nil then
        local src = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
        frsky.dropSensorCache[appId] = src or false
    end
    local src = frsky.dropSensorCache[appId]
    if src and src ~= false then
        if not frsky.dropped[appId] then
            src:drop()
            frsky.dropped[appId] = true
            return "dropped"
        end
        return "noop"
    end
    return "skip"
end

local function renameSensor(physId, primId, appId, frameValue)
    if rfsuite.session.apiVersion == nil then return "skip" end
    local v = renameSensorList[appId]
    if not v then return "skip" end
    if frsky.renamed[appId] then return "noop" end

    if frsky.renameSensorCache[appId] == nil then
        local src = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
        frsky.renameSensorCache[appId] = src or false
    end
    local src = frsky.renameSensorCache[appId]
    if src and src ~= false then
        if src:name() == v.onlyifname then
            src:name(v.name)
            frsky.renamed[appId] = true
            return "renamed"
        end
        return "noop"
    end
    return "skip"
end

local function telemetryPop()

    if not rfsuite.tasks.msp.sensorTlm then return false end

    local frame = rfsuite.tasks.msp.sensorTlm:popFrame()
    if frame == nil then return false end
    if not frame.physId or not frame.primId then return false end

    local physId, primId, appId, value = frame:physId(), frame:primId(), frame:appId(), frame:value()

    local cs = createSensor(physId, primId, appId, value)
    if cs ~= "skip" then return true end

    local ds = dropSensor(physId, primId, appId, value)
    if ds ~= "skip" then return true end

    renameSensor(physId, primId, appId, value)
    return true
end

function frsky_legacy.wakeup()
    local function clearCaches()
        frsky_legacy.createSensorCache = {}
        frsky_legacy.renameSensorCache = {}
        frsky_legacy.dropSensorCache = {}
    end

    if not rfsuite.session.telemetryState or not rfsuite.session.telemetrySensor then
        clearCaches()
        return
    end

    if not (rfsuite.tasks and rfsuite.tasks.telemetry and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue) then return end

    if rfsuite.app and rfsuite.app.guiIsRunning == false and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local discoverActive = (system and system.isSensorDiscoverActive and system.isSensorDiscoverActive() == true)
        rfsuite.utils.log("FRSKY: Discovery active, draining all frames", "info")
        if discoverActive then
            while telemetryPop() do end
        else
            local start = os.clock()
            local count = 0
            while count < MAX_FRAMES_PER_WAKEUP and (os.clock() - start) <= MAX_TIME_BUDGET do
                if not telemetryPop() then break end
                count = count + 1
            end
        end
    end
end

function frsky_legacy.reset()
    frsky_legacy.createSensorCache = {}
    frsky_legacy.renameSensorCache = {}
    frsky_legacy.dropSensorCache = {}
    frsky_legacy.renamed = {}
    frsky_legacy.dropped = {}
end

return frsky_legacy

--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]
local os_clock = os.clock

local sensors = {}
local loadedSensorModule = nil

local delayDuration = 2
local delayStartTime = nil
local delayPending = false
local schedulerTick = 0

local msp
local smart
local telemetryconfig
local battery


local log = rfsuite.utils.log
local tasks = rfsuite.tasks

local function ensureHelperModule(path, current)
    if current ~= nil then return current end
    return assert(loadfile(path))(config)
end

local function getMspModule()
    msp = ensureHelperModule("tasks/scheduler/sensors/msp.lua", msp)
    return msp
end

local function getSmartModule()
    smart = ensureHelperModule("tasks/scheduler/sensors/smart.lua", smart)
    return smart
end

local function getTelemetryConfigModule()
    telemetryconfig = ensureHelperModule("tasks/scheduler/sensors/lib/telemetryconfig.lua", telemetryconfig)
    return telemetryconfig
end

local function getBatteryModule()
    battery = ensureHelperModule("tasks/scheduler/sensors/lib/battery.lua", battery)
    return battery
end

local function loadSensorModule()
    if not tasks.active() then return nil end
    if not rfsuite.session.apiVersion then return nil end
    

    local protocol = tasks.msp.protocol.mspProtocol

    if system:getVersion().simulation == true then
        if not loadedSensorModule or loadedSensorModule.name ~= "sim" then loadedSensorModule = {name = "sim", module = assert(loadfile("tasks/scheduler/sensors/sim.lua"))(config)} end
    elseif protocol == "crsf" then
        if not loadedSensorModule or loadedSensorModule.name ~= "elrs" then loadedSensorModule = {name = "elrs", module = assert(loadfile("tasks/scheduler/sensors/elrs.lua"))(config)} end
    elseif protocol == "sport" then
        if rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then
            if not loadedSensorModule or loadedSensorModule.name ~= "frsky" then loadedSensorModule = {name = "frsky", module = assert(loadfile("tasks/scheduler/sensors/frsky.lua"))(config)} end
        else
            if not loadedSensorModule or loadedSensorModule.name ~= "frsky_legacy" then loadedSensorModule = {name = "frsky_legacy", module = assert(loadfile("tasks/scheduler/sensors/frsky_legacy.lua"))(config)} end
        end
    else
        loadedSensorModule = nil
    end
end

function sensors.wakeup()

    if rfsuite.tasks and rfsuite.tasks.onconnect and rfsuite.tasks.onconnect.active and rfsuite.tasks.onconnect.active() then return end

    -- Ensure telemetry config is complete before proceeding
    -- This is a one time msp call on startup to get telemetry config data
    if rfsuite.session.telemetryConfig == nil then
        local telemetryconfigModule = getTelemetryConfigModule()
        if not telemetryconfigModule.isComplete() then
            telemetryconfigModule.wakeup()
            return
        end
        telemetryconfig = nil
    else
        telemetryconfig = nil
    end

    -- Ensure battery config is complete before proceeding
    -- This is a one time msp call on startup to get battery config data
    if rfsuite.session.batteryConfig == nil then
        local batteryModule = getBatteryModule()
        if not batteryModule.isComplete() then
            batteryModule.wakeup()
            return
        end
        battery = nil
    else
        battery = nil
    end

    schedulerTick = schedulerTick + 1

    if rfsuite.session.resetSensors and not delayPending then
        delayStartTime = os_clock()
        delayPending = true
        rfsuite.session.resetSensors = false

        log("Delaying sensor wakeup for " .. delayDuration .. " seconds", "info")
        return
    end

    if delayPending then
        if os_clock() - delayStartTime >= delayDuration then
            log("Delay complete; resuming sensor wakeup", "info")
            delayPending = false
        else
            return
        end
    end

    loadSensorModule()
    if loadedSensorModule and loadedSensorModule.module.wakeup then


        
        loadedSensorModule.module.wakeup()

        local cycleFlip = schedulerTick % 2
        if cycleFlip == 0 then
            if rfsuite.session and rfsuite.session.isConnected then

                local mspModule = getMspModule()
                if mspModule and mspModule.wakeup then mspModule.wakeup() end

                local smartModule = getSmartModule()
                if smartModule and smartModule.wakeup then smartModule.wakeup() end

            end
        end

    end

end

function sensors.reset()

    if loadedSensorModule and loadedSensorModule.module and loadedSensorModule.module.reset then loadedSensorModule.module.reset() end
    sensors.resetSmart()
    if msp and msp.reset then msp.reset() end
    if telemetryconfig and telemetryconfig.reset then telemetryconfig.reset() end
    if battery and battery.reset then battery.reset() end
    loadedSensorModule = nil
    msp = nil
    telemetryconfig = nil
    battery = nil

end

function sensors.resetSmart()
    if smart and smart.reset then smart.reset() end
    smart = nil
end

return sensors

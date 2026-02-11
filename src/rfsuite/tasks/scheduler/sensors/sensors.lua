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

local msp = assert(loadfile("tasks/scheduler/sensors/msp.lua"))(config)
local smart = assert(loadfile("tasks/scheduler/sensors/smart.lua"))(config)
local telemetryconfig = assert(loadfile("tasks/scheduler/sensors/lib/telemetryconfig.lua"))(config)
local battery = assert(loadfile("tasks/scheduler/sensors/lib/battery.lua"))(config)


local log = rfsuite.utils.log
local tasks = rfsuite.tasks

local function loadSensorModule()
    if not tasks.active() then return nil end
    if not rfsuite.session.apiVersion then return nil end
    

    local protocol = tasks.msp.protocol.mspProtocol

    if system:getVersion().simulation == true then
        if not loadedSensorModule or loadedSensorModule.name ~= "sim" then loadedSensorModule = {name = "sim", module = assert(loadfile("tasks/scheduler/sensors/sim.lua"))(config)} end
    elseif protocol == "crsf" then
        if not loadedSensorModule or loadedSensorModule.name ~= "elrs" then loadedSensorModule = {name = "elrs", module = assert(loadfile("tasks/scheduler/sensors/elrs.lua"))(config)} end
    elseif protocol == "sport" then
        if rfsuite.utils.apiVersionCompare(">=", "12.08") then
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
    if not telemetryconfig.isComplete() then
        telemetryconfig.wakeup()
        return
    end

    -- Ensure battery config is complete before proceeding
    -- This is a one time msp call on startup to get battery config data
    if not battery.isComplete() then
        battery.wakeup()
        return
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

                if msp and msp.wakeup then msp.wakeup() end

                if smart and smart.wakeup then smart.wakeup() end

            end
        end

    end

end

function sensors.reset()

    if loadedSensorModule and loadedSensorModule.module and loadedSensorModule.module.reset then loadedSensorModule.module.reset() end
    if smart and smart.reset then smart.reset() end
    if msp and msp.reset then msp.reset() end
    if telemetryconfig and telemetryconfig.reset then telemetryconfig.reset() end
    if battery and battery.reset then battery.reset() end
    loadedSensorModule = nil

end

return sensors

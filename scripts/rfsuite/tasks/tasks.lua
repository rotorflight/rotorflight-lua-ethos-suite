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

-- this stops it loading if we are not on the correct ethos version
-- and is needed by main.lua to prevent errors
if not rfsuite.utils.ethosVersionAtLeast() then
    return
end

--
-- background processing of system tasks
--
local arg = {...}
local config = arg[1]
local currentTelemetrySensor

-- declare vars
local tasks = {}
tasks.heartbeat = nil
tasks.init = false
tasks.wasOn = false

local tasksList = {}

rfsuite.session.telemetryTypeChanged = true


local ethosVersionGood = nil  
local telemetryCheckScheduler = os.clock()
local lastTelemetrySensorName = nil

local sportSensor 
local elrsSensor

-- Cache telemetry source
local tlm = system.getSource({category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE})

-- findModules on task init to ensure we are precached  
if rfsuite.app.moduleList == nil then rfsuite.app.moduleList = rfsuite.utils.findModules() end

--[[
    tasks._callbacks: Table to store callback functions with their scheduled times and repeat intervals.

    get_time: Function to get the current time using os.clock().

    tasks.callbackNow(callback):
        - Registers a callback function to be executed immediately.
        - Parameters:
            - callback (function): The function to be executed.

    tasks.callbackInSeconds(seconds, callback):
        - Registers a callback function to be executed after a specified number of seconds.
        - Parameters:
            - seconds (number): The delay in seconds before the callback is executed.
            - callback (function): The function to be executed.

    tasks.callbackEvery(seconds, callback):
        - Registers a callback function to be executed repeatedly at specified intervals.
        - Parameters:
            - seconds (number): The interval in seconds between each execution of the callback.
            - callback (function): The function to be executed.
]]
tasks._callbacks = {}

local function get_time()
    return os.clock()
end

function tasks.callbackNow(callback)
    table.insert(tasks._callbacks, {time = nil, func = callback, repeat_interval = nil})
end

function tasks.callbackInSeconds(seconds, callback)
    table.insert(tasks._callbacks, {time = get_time() + seconds, func = callback, repeat_interval = nil})
end

function tasks.callbackEvery(seconds, callback)
    table.insert(tasks._callbacks, {time = get_time() + seconds, func = callback, repeat_interval = seconds})
end

function tasks.callback()
    local now = get_time()
    local i = 1
    while i <= #tasks._callbacks do
        local entry = tasks._callbacks[i]
        if not entry.time or entry.time <= now then
            entry.func()

            if entry.repeat_interval then
                entry.time = now + entry.repeat_interval
                i = i + 1
            else
                table.remove(tasks._callbacks, i)
            end
        else
            i = i + 1
        end
    end
end

function tasks.clearCallback(callback)
    for i = #tasks._callbacks, 1, -1 do
        if tasks._callbacks[i].func == callback then
            table.remove(tasks._callbacks, i)
        end
    end
end

function tasks.clearAllCallbacks()
    tasks._callbacks = {}
end

-- findTasks
--[[
    Function: tasks.findTasks
    Description: This function scans the "tasks" directory for task configurations and scripts. 
                 It loads and validates each task's configuration, then adds valid tasks to the tasksList.
                 It also loads and initializes the corresponding task scripts.
    Usage: Call tasks.findTasks() to initialize and load all tasks from the "tasks" directory.
]]
function tasks.findTasks()

    local taskdir = "tasks"
    local tasks_path = "tasks/"

    for _, v in pairs(system.listFiles(tasks_path)) do
       
        if v ~= ".." and v ~= "tasks.lua" then  -- exlude ourself
            local init_path = tasks_path .. v .. '/init.lua'

                local func, err = loadfile(init_path)

                if err then
                    rfsuite.utils.log("Error loading " .. init_path .. ": " .. err,"info")
                end

                if func then
                    local tconfig = func()
                    if type(tconfig) ~= "table" or not tconfig.interval or not tconfig.script then
                        rfsuite.utils.log("Invalid configuration in " .. init_path,"debug")
                    else
                        local task = {
                            name = v,
                            interval = tconfig.interval,
                            script = tconfig.script,
                            msp = tconfig.msp,
                            always_run = tconfig.always_run or false, -- Default is false
                            last_run = os.clock()
                        }
                        table.insert(tasksList, task)

                        local script = tasks_path .. v .. '/' .. tconfig.script
                        local fs = io.open(script, "r")
                        if fs then
                            io.close(fs)
                            tasks[v] = assert(loadfile(script))(config)
                        end
                    end
                end
        end    
    end
end


--[[
    Checks if the tasks script is active based on the heartbeat and MSP status.

    Returns:
        boolean: True if the tasks script is active, otherwise false.
]]
function tasks.active()

    if tasks.heartbeat == nil then return false end

    if (os.clock() - tasks.heartbeat) >= 2 then
        tasks.wasOn = true
    else
        tasks.wasOn = false
    end

    -- if msp is busy.. we are 100% ok
    if rfsuite.app.triggers.mspBusy == true then return true end

    -- if we have not run within 2 seconds.. notify that tasks script is down
    if (os.clock() - tasks.heartbeat) <= 2 then return true end

    return false
end

--[[
    Function: tasks.wakeup

    Short:
    Handles the periodic wakeup tasks for the rotorflight suite.

    Use:
    This function is responsible for processing logs, checking the Ethos version, initializing tasks, updating the heartbeat, 
    managing Telemetry sensor checks, and dynamically loading tasks based on settings.

    Details:
    - Processes the log using `rfsuite.log.process()`.
    - Checks if the Ethos version is at least the required version using `rfsuite.utils.ethosVersionAtLeast()`.
    - Initializes tasks if not already initialized by calling `tasks.findTasks()`.
    - Updates the heartbeat timestamp using `os.clock()`.
    - Manages Telemetry sensor checks and updates the current Telemetry sensor and its type.
    - Runs tasks dynamically based on their defined intervals and conditions.
--]]
function tasks.wakeup()
    -- Check version only once after startup
    if ethosVersionGood == nil then
        ethosVersionGood = rfsuite.utils.ethosVersionAtLeast()
    end

    -- Stop execution if Ethos version is incorrect
    if not ethosVersionGood then
        return
    end

    -- Process the log
    rfsuite.log.process()    

    -- Run the callbacks
    tasks.callback()

    -- Initialize tasks if not already done
    if tasks.init == false then
        tasks.findTasks()
        tasks.init = true
        return
    end

    tasks.heartbeat = os.clock()

    -- Run telemetry check every second
    local now = os.clock()
    if now - (telemetryCheckScheduler or 0) >= 1 then
        telemetryState = tlm and tlm:state() or false

        if not telemetryState then
            -- **Reset telemetry environment variables**
            rfsuite.session.telemetryState = false
            rfsuite.session.telemetryType = nil
            rfsuite.session.telemetryTypeChanged = false
            rfsuite.session.telemetrySensor = nil
            lastTelemetrySensorName = nil
            sportSensor = nil
            elrsSensor = nil 
            telemetryCheckScheduler = now    
        else
            -- Determine telemetry sensor
            if not sportSensor then sportSensor = system.getSource({appId = 0xF101}) end
            if not elrsSensor then elrsSensor = system.getSource({crsfId=0x14, subIdStart=0, subIdEnd=1}) end

            currentTelemetrySensor = sportSensor or elrsSensor or nil
            rfsuite.session.telemetrySensor = currentTelemetrySensor

            if currentTelemetrySensor == nil then
                -- **Reset telemetry environment variables again**
                rfsuite.session.telemetryState = false
                rfsuite.session.telemetryType = nil
                rfsuite.session.telemetryTypeChanged = false
                rfsuite.session.telemetrySensor = nil
                lastTelemetrySensorName = nil
                sportSensor = nil
                elrsSensor = nil 
                telemetryCheckScheduler = now
            else
                -- **Telemetry is valid, store session variables**
                rfsuite.session.telemetryState = true
                rfsuite.session.telemetryType = sportSensor and "sport" or elrsSensor and "crsf" or nil
                rfsuite.session.telemetryTypeChanged = currentTelemetrySensor and (lastTelemetrySensorName ~= currentTelemetrySensor:name()) or false
                lastTelemetrySensorName = currentTelemetrySensor and currentTelemetrySensor:name() or nil    
                telemetryCheckScheduler = now
            end
        end
    end

    -- **Modified Task Execution Loop**
    local now = os.clock()
    for _, task in ipairs(tasksList) do
        if now - task.last_run >= task.interval then
            if tasks[task.name].wakeup then
                -- **Allow always_run tasks to execute even if telemetryState is false**
                if task.always_run or telemetryState then
                    if task.msp == true then
                        tasks[task.name].wakeup()
                    else
                        if not rfsuite.app.triggers.mspBusy then
                            tasks[task.name].wakeup() 
                        end
                    end
                end
                task.last_run = now
            end
        end
    end
end

--[[
    Handles events for the tasks module by delegating to specific event handlers.

    @param widget The widget that triggered the event.
    @param category The category of the event.
    @param value The value associated with the event.
]]
function tasks.event(widget, category, value)
    -- currently does nothing.
end

return tasks
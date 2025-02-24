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
--
-- background processing of system tasks
--
local arg = {...}
local config = arg[1]
local currentRssiSensor

-- declare vars
local tasks = {}
tasks.heartbeat = nil
tasks.init = false
tasks.wasOn = false

local tasksList = {}

rfsuite.session.rssiSensorChanged = true

local rssiCheckScheduler = os.clock()
local lastRssiSensorName = nil

-- findModules on task init to ensure we are precached  
if rfsuite.app.moduleList == nil then rfsuite.app.moduleList = rfsuite.utils.findModules() end

-- findTasks
-- Configurable delay for module discovery
tasks.discoveryInterval = 0.5  -- seconds per task (not used directly but implies spread over multiple wakeups)
tasks.taskScanIndex = 1         -- Tracks current task being processed
tasks.taskListTemp = nil        -- Holds list of tasks to process incrementally
tasks.tasksInitialized = false  -- Ensures findTasks runs only once

function tasks.findTasks()
    -- Initialize the task list on first call
    if tasks.taskListTemp == nil then
        local tasks_path = "tasks/"
        tasks.taskListTemp = system.listFiles(tasks_path)
        tasks.taskScanIndex = 1  -- Start fresh
    end

    -- Process one task per wakeup
    if tasks.taskScanIndex <= #tasks.taskListTemp then
        local v = tasks.taskListTemp[tasks.taskScanIndex]

        if v ~= ".." then
            local tasks_path = "tasks/"
            local init_path = tasks_path .. v .. '/init.lua'

            local f = io.open(init_path, "r")
            if f then
                io.close(f)

                local func, err = loadfile(init_path)

                if func then
                    local tconfig = func()
                    if type(tconfig) ~= "table" or not tconfig.interval or not tconfig.script then
                        rfsuite.utils.log("Invalid configuration in " .. init_path, "debug")
                    else
                        local task = {
                            name = v,
                            interval = tconfig.interval,
                            script = tconfig.script,
                            msp = tconfig.msp,
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
        -- Move to the next task on the next wakeup
        tasks.taskScanIndex = tasks.taskScanIndex + 1
 
    else
        -- Cleanup once all tasks are processed
        tasks.taskListTemp = nil
        tasks.tasksInitialized = true
    end
end



function tasks.active()

    if tasks.heartbeat == nil then return false end

    if (os.clock() - tasks.heartbeat) >= 2 then
        tasks.wasOn = true
    else
        tasks.wasOn = false
    end

    -- if msp is busy.. we are 100% ok
    if rfsuite.app.triggers.mspBusy == true then return true end

    -- if we have not run within 2 seconds.. notify that task script is down
    if (os.clock() - tasks.heartbeat) <= 2 then return true end

    return false
end

-- wakeup
function tasks.wakeup()

    -- process the log
    rfsuite.log.process()

    -- kill if version is bad
    if not rfsuite.utils.ethosVersionAtLeast() then
        return
    end

    -- Incremental task initialization
    if not tasks.tasksInitialized then
        tasks.findTasks()
        return
    end

    tasks.heartbeat = os.clock()

    -- Heavy checks, run every few seconds
    local now = os.clock()
    if now - (rssiCheckScheduler or 0) >= 4 then
        currentRssiSensor = system.getSource({appId = 0xF101}) or system.getSource({crsfId=0x14, subIdStart=0, subIdEnd=1}) or nil
        rfsuite.session.rssiSensorChanged = currentRssiSensor and (lastRssiSensorName ~= currentRssiSensor:name()) or false
        lastRssiSensorName = currentRssiSensor and currentRssiSensor:name() or nil    
        rssiCheckScheduler = now
    end

    if system:getVersion().simulation == true then 
        rfsuite.session.rssiSensorChanged = false 
    end

    if currentRssiSensor ~= nil then 
        rfsuite.session.rssiSensor = currentRssiSensor 
    end

    -- Process scheduled tasks
    for _, task in ipairs(tasksList) do
        if now - task.last_run >= task.interval then
            if tasks[task.name].wakeup then
                if task.msp == true then
                    tasks[task.name].wakeup()
                else
                    if not rfsuite.app.triggers.mspBusy then 
                        tasks[task.name].wakeup() 
                    end
                end
                task.last_run = now
            end
        end
    end
end

function tasks.event(widget, category, value)
    if tasks.msp.event then tasks.msp.event(widget, category, value) end
    if tasks.adjfunctions.event then tasks.adjfunctions.event(widget, category, value) end
end

return tasks

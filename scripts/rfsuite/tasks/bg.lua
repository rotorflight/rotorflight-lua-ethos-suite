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
local bg = {}
bg.heartbeat = nil
bg.init = false
bg.wasOn = false

local tasksList = {}

rfsuite.rssiSensorChanged = true

local rssiCheckScheduler = os.clock()
local lastRssiSensorName = nil

-- findModules on task init to ensure we are precached  
if rfsuite.app.moduleList == nil then rfsuite.app.moduleList = rfsuite.utils.findModules() end

-- findTasks
-- Configurable delay for module discovery
bg.discoveryInterval = 0.5  -- seconds per task (not used directly but implies spread over multiple wakeups)
bg.taskScanIndex = 1         -- Tracks current task being processed
bg.taskListTemp = nil        -- Holds list of tasks to process incrementally
bg.tasksInitialized = false  -- Ensures findTasks runs only once

function bg.findTasks()
    -- Initialize the task list on first call
    if bg.taskListTemp == nil then
        local tasks_path = "tasks/"
        bg.taskListTemp = system.listFiles(tasks_path)
        bg.taskScanIndex = 1  -- Start fresh
    end

    -- Process one task per wakeup
    if bg.taskScanIndex <= #bg.taskListTemp then
        local v = bg.taskListTemp[bg.taskScanIndex]
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
                        bg[v] = assert(loadfile(script))(config)
                    end
                end
            end
        end

        -- Move to the next task on the next wakeup
        bg.taskScanIndex = bg.taskScanIndex + 1
    else
        -- Cleanup once all tasks are processed
        bg.taskListTemp = nil
        bg.tasksInitialized = true
    end
end



function bg.active()

    if bg.heartbeat == nil then return false end

    if (os.clock() - bg.heartbeat) >= 2 then
        bg.wasOn = true
    else
        bg.wasOn = false
    end

    -- if msp is busy.. we are 100% ok
    if rfsuite.app.triggers.mspBusy == true then return true end

    -- if we have not run within 2 seconds.. notify that bg script is down
    if (os.clock() - bg.heartbeat) <= 2 then return true end

    return false
end

-- wakeup
function bg.wakeup()

    -- process the log
    rfsuite.log.process()

    -- kill if version is bad
    if not rfsuite.utils.ethosVersionAtLeast() then
        return
    end

    -- Incremental task initialization
    if not bg.tasksInitialized then
        bg.findTasks()
        return
    end

    bg.heartbeat = os.clock()

    -- Heavy checks, run every few seconds
    local now = os.clock()
    if now - (rssiCheckScheduler or 0) >= 4 then
        currentRssiSensor = system.getSource({appId = 0xF101}) or system.getSource({crsfId=0x14, subIdStart=0, subIdEnd=1}) or nil
        rfsuite.rssiSensorChanged = currentRssiSensor and (lastRssiSensorName ~= currentRssiSensor:name()) or false
        lastRssiSensorName = currentRssiSensor and currentRssiSensor:name() or nil    
        rssiCheckScheduler = now
    end

    if system:getVersion().simulation == true then 
        rfsuite.rssiSensorChanged = false 
    end

    if currentRssiSensor ~= nil then 
        rfsuite.rssiSensor = currentRssiSensor 
    end

    -- Process scheduled tasks
    for _, task in ipairs(tasksList) do
        if now - task.last_run >= task.interval then
            if bg[task.name].wakeup then
                if task.msp == true then
                    bg[task.name].wakeup()
                else
                    if not rfsuite.app.triggers.mspBusy then 
                        bg[task.name].wakeup() 
                    end
                end
                task.last_run = now
            end
        end
    end
end

function bg.event(widget, category, value)
    if bg.msp.event then bg.msp.event(widget, category, value) end
    if bg.adjfunctions.event then bg.adjfunctions.event(widget, category, value) end
end

return bg

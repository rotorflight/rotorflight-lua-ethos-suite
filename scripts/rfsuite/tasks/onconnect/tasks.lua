--[[
 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
--]]

local tasks = {}
local tasksList = {}
local tasksLoaded = false

local TASK_TIMEOUT_SECONDS = 10

-- Base path and priority levels
local BASE_PATH = "tasks/onconnect/tasks/"
local PRIORITY_LEVELS = {"high", "medium", "low"}

-- Initialize or reset session flags
local function resetSessionFlags()
    rfsuite.session.onConnect = rfsuite.session.onConnect or {}
    for _, level in ipairs(PRIORITY_LEVELS) do
        rfsuite.session.onConnect[level] = false
    end
    -- Ensure isConnected resets until high priority completes
    rfsuite.session.isConnected = false
end

-- Discover task files in fixed priority order
function tasks.findTasks()
    if tasksLoaded then return end

    resetSessionFlags()

    for _, level in ipairs(PRIORITY_LEVELS) do
        local dirPath = BASE_PATH .. level .. "/"
        local files = system.listFiles(dirPath) or {}
        for _, file in ipairs(files) do
            if file:match("%.lua$") then
                local fullPath = dirPath .. file
                local name = level .. "/" .. file:gsub("%.lua$", "")
                local chunk, err = rfsuite.compiler.loadfile(fullPath)
                if not chunk then
                    rfsuite.utils.log("Error loading task " .. fullPath .. ": " .. err, "error")
                else
                    local module = assert(chunk())
                    if type(module) == "table" and type(module.wakeup) == "function" then
                        tasksList[name] = {
                            module = module,
                            priority = level,
                            initialized = false,
                            complete = false,
                            startTime = nil
                        }
                    else
                        rfsuite.utils.log("Invalid task file: " .. fullPath, "info")
                    end
                end
            end
        end
    end

    tasksLoaded = true
end

function tasks.resetAllTasks()
    for _, task in pairs(tasksList) do
        if type(task.module.reset) == "function" then task.module.reset() end
        task.initialized = false
        task.complete = false
        task.startTime = nil
    end

    resetSessionFlags()
    rfsuite.tasks.reset()
    rfsuite.session.resetMSPSensors = true
end

function tasks.wakeup()
    local telemetryActive = rfsuite.tasks.msp.onConnectChecksInit and rfsuite.session.telemetryState

    if rfsuite.session.telemetryTypeChanged then
        rfsuite.utils.logRotorFlightBanner()
        --rfsuite.utils.log("Telemetry type changed, resetting tasks.", "info")
        rfsuite.session.telemetryTypeChanged = false
        tasks.resetAllTasks()
        tasksLoaded = false
        return
    end

    if not telemetryActive then
        tasks.resetAllTasks()
        tasksLoaded = false
        return
    end

    if not tasksLoaded then
        tasks.findTasks()
        return
    end

    local now = os.clock()

    -- Run each task
    for name, task in pairs(tasksList) do
        if not task.initialized then
            task.initialized = true
            task.startTime = now
        end
        if not task.complete then
            rfsuite.utils.log("Waking up " .. name, "debug")
            task.module.wakeup()
            if task.module.isComplete and task.module.isComplete() then
                task.complete = true
                task.startTime = nil
                rfsuite.utils.log("Completed " .. name, "debug")
            elseif task.startTime and (now - task.startTime) > TASK_TIMEOUT_SECONDS then
                rfsuite.utils.log("Task '" .. name .. "' timed out.", "info")
                task.startTime = nil
            end
        end
    end

    -- Update session flags as soon as each priority level completes
    for _, level in ipairs(PRIORITY_LEVELS) do
        if not rfsuite.session.onConnect[level] then
            local levelDone = true
            for _, task in pairs(tasksList) do
                if task.priority == level and not task.complete then
                    levelDone = false
                    break
                end
            end
            if levelDone then
                rfsuite.session.onConnect[level] = true
                rfsuite.utils.log("All '" .. level .. "' tasks complete.", "info")

                -- Signal the session connected immediately when high priority finishes
                if level == "high" then
                    rfsuite.utils.playFileCommon("beep.wav")
                    rfsuite.flightmode.current = "preflight"
                    rfsuite.tasks.events.flightmode.reset()
                    rfsuite.session.isConnectedHigh = true
                    return
                elseif level == "medium" then
                    rfsuite.session.isConnectedMedium = true
                    return
                elseif level == "low" then 
                    rfsuite.session.isConnectedLow = true    
                    rfsuite.session.isConnected = true  
                    collectgarbage()
                    return
                end
            end
        end
    end
end

return tasks

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
local completionNotified = false

local TASK_TIMEOUT_SECONDS = 10

function tasks.findTasks()
    if tasksLoaded then
        return
    end

    local basePath = "tasks/onconnect/tasks/"
    local taskMetadata = {}

    for _, file in pairs(system.listFiles(basePath)) do
        if file ~= ".." and file:match("%.lua$") then
            local fullPath = basePath .. file
            local taskName = file:gsub("%.lua$", "")

            local chunk, err = loadfile(fullPath)
            if not chunk then
                rfsuite.utils.log("Error loading task file " .. file .. ": " .. err, "error")
            else
                local taskModule = assert(chunk())

                if type(taskModule) == "table" and type(taskModule.wakeup) == "function" then
                    tasksList[taskName] = {
                        module = taskModule,
                        initialized = false,
                        complete = false,
                        resetPending = false,
                        startTime = nil
                    }
                    taskMetadata[taskName] = file
                else
                    rfsuite.utils.log("Invalid task file: " .. file .. " (must return table with wakeup()).", "info")
                end
            end
        end
    end

    tasksLoaded = true
    return taskMetadata
end

function tasks.resetAllTasks()
    for name, task in pairs(tasksList) do
        if type(task.module.reset) == "function" then
            task.module.reset()
        end
        task.initialized = false
        task.complete = false
        task.resetPending = false
        task.startTime = nil
    end

    -- reset all main tasks
    rfsuite.tasks.reset()

    completionNotified = false
end

function tasks.wakeup()
    local telemetryActive = rfsuite.tasks.msp.onConnectChecksInit and rfsuite.session.telemetryState

    if rfsuite.session.telemetryTypeChanged then
        rfsuite.utils.logRotorFlightBanner()
        rfsuite.utils.log("Telemetry type changed, resetting all tasks and reconnecting.", "info")
        rfsuite.session.telemetryTypeChanged = false
        tasks.resetAllTasks()
        tasksLoaded = false

        -- mute sensor lost
        local module = model.getModule(rfsuite.session.telemetrySensor:module())
        if module and module.muteSensorLost then module:muteSensorLost(2.0) end
        
        return
    end

    if not telemetryActive then
        tasks.resetAllTasks()
        tasksLoaded = false
        return
    end

    if not tasksLoaded then
        local cacheFile = "onconnect.cache"
        local cachePath = "cache/" .. cacheFile
        local taskMetadata

        if io.open(cachePath, "r") then
            local ok, cached = pcall(dofile, cachePath)
            if ok and type(cached) == "table" then
                taskMetadata = cached
                rfsuite.utils.log("[cache] Loaded onconnect task metadata from cache","info")
            else
                rfsuite.utils.log("[cache] Failed to load onconnect cache","info")
            end
        end

        if not taskMetadata then
            taskMetadata = tasks.findTasks()
            rfsuite.utils.createCacheFile(taskMetadata, cacheFile)
            rfsuite.utils.log("[cache] Created onconnect cache file","info")
        else
            local basePath = "tasks/onconnect/tasks/"
            for taskName, file in pairs(taskMetadata) do
                local fullPath = basePath .. file
                local chunk = assert(loadfile(fullPath))
                local taskModule = assert(chunk())
                tasksList[taskName] = {
                    module = taskModule,
                    initialized = false,
                    complete = false,
                    resetPending = false,
                    startTime = nil
                }
            end
            tasksLoaded = true
        end

        completionNotified = false
    end

    local now = os.clock()

    for name, task in pairs(tasksList) do
        if task.resetPending then
            if type(task.module.reset) == "function" then
                task.module.reset()
            end
            task.resetPending = false
            task.initialized = false
            task.complete = false
            task.startTime = nil
        end

        if not task.initialized then
            task.initialized = true
            task.startTime = now
        end

        if not task.complete then
            rfsuite.utils.log("Waking up task: " .. name, "debug")
            task.module.wakeup()

            if task.module.isComplete and task.module.isComplete() then
                rfsuite.utils.log("Task '" .. name .. "' is complete.", "debug")
                task.complete = true
                task.startTime = nil
            else
                if not task.module.isComplete then
                    rfsuite.utils.log("Task '" .. name .. "' does not implement isComplete(). This may block task completion detection.", "info")
                elseif task.startTime and (now - task.startTime) > TASK_TIMEOUT_SECONDS then
                    rfsuite.utils.log("Task '" .. name .. "' has not completed within " .. TASK_TIMEOUT_SECONDS .. " seconds.", "info")
                    task.startTime = nil
                end
            end
        end
    end

    local allComplete = true
    for name, task in pairs(tasksList) do
        if not task.complete then
            allComplete = false
        end
    end

    if allComplete and not completionNotified then
        rfsuite.utils.log("All tasks complete.", "info")
        completionNotified = true
        rfsuite.utils.playFileCommon("beep.wav")
        collectgarbage()
    end
end

return tasks

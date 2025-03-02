--[[
 * Copyright (C) Rotorflight Project
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
 *
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 *
]] --
local tasks = {}
local tasksList = {}
local tasksLoaded = false
local totalTaskCount = 0  -- Tracks total number of loaded tasks

local STATE = {
    WAITING_FOR_CONNECT = "waiting",
    CONNECTED = "connected"
}

local taskState = STATE.WAITING_FOR_CONNECT
local completionNotified = false
local remainingTasks = 0 -- Tracks how many tasks are still incomplete

function tasks.findTasks()
    if tasksLoaded then
        return
    end

    local basePath = "tasks/onconnect/tasks/"

    for _, file in pairs(system.listFiles(basePath)) do
        if file ~= ".." and file:match("%.lua$") then
            local fullPath = basePath .. file
            local taskName = file:gsub("%.lua$", "")

            local chunk, err = loadfile(fullPath)
            if not chunk then
                --rfsuite.utils.log("Error loading " .. file .. ": " .. err, "error")
            else
                local taskModule = assert(chunk())

                if type(taskModule) == "table" and type(taskModule.wakeup) == "function" then
                    tasksList[taskName] = {
                        module = taskModule,
                        initialized = false,
                        complete = false,
                        resetPending = false
                    }
                    totalTaskCount = totalTaskCount + 1  -- Track total
                else
                    --rfsuite.utils.log("Invalid task file: " .. file .. " (must return table with wakeup())", "debug")
                end
            end
        end
    end

    tasksLoaded = true
end

function tasks.resetAllTasks()
    for name, task in pairs(tasksList) do
        if type(task.module.reset) == "function" then
            task.module.reset()
        end
        task.initialized = false
        task.complete = false
        task.resetPending = false
    end

    completionNotified = false
    remainingTasks = totalTaskCount  -- Direct reset to known count
end

function tasks.wakeup()
    local active = rfsuite.tasks.msp.onConnectChecksInit and rfsuite.tasks.telemetry.active()

    if taskState == STATE.WAITING_FOR_CONNECT then
        if active then
            tasks.findTasks()
            taskState = STATE.CONNECTED
            completionNotified = false
            remainingTasks = totalTaskCount  -- Reset at the start of each session
        end

    elseif taskState == STATE.CONNECTED then
        if not active then
            tasks.resetAllTasks()
            taskState = STATE.WAITING_FOR_CONNECT
            return
        end

        for name, task in pairs(tasksList) do
            if task.resetPending then
                if type(task.module.reset) == "function" then
                    task.module.reset()
                end
                task.resetPending = false
                task.initialized = false
                task.complete = false
            end

            if not task.initialized then
                task.initialized = true
            end

            if not task.complete then
                task.module.wakeup()

                if task.module.isComplete and task.module.isComplete() then
                    task.complete = true
                    remainingTasks = remainingTasks - 1  -- Track completion here

                    if remainingTasks == 0 and not completionNotified then
                        completionNotified = true
                        rfsuite.utils.playFileCommon("beep.wav")
                    end
                end
            end
        end
    end
end

return tasks
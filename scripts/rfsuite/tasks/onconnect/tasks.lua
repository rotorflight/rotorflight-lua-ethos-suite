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
local activeLevel = nil

local telemetryTypeChanged = false

local TASK_TIMEOUT_SECONDS = 10
local MAX_RETRIES = 3            -- how many times to retry a timed-out task
local RETRY_BACKOFF_SECONDS = 1  -- base backoff; actual backoff = base * 2^(attempt-1)


-- Debounce for telemetryTypeChanged -> avoid repeated resets on ELRS/S.Port flaps
local TYPE_CHANGE_DEBOUNCE = 1.0  -- seconds
local lastTypeChangeAt = 0
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
                            failed = false,
                            attempts = 0,
                            nextEligibleAt = 0,
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
        task.failed = false
        task.attempts = 0
        task.nextEligibleAt = 0        
    end

    resetSessionFlags()
    rfsuite.tasks.reset()
    rfsuite.session.resetMSPSensors = true
end

function tasks.wakeup()
    local telemetryActive = rfsuite.tasks.msp.onConnectChecksInit and rfsuite.session.telemetryState

    if telemetryTypeChanged then
        telemetryTypeChanged = false
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
    end

    -- Find the first priority level that isn't complete yet.
    activeLevel = nil
    for _, level in ipairs(PRIORITY_LEVELS) do
        if not rfsuite.session.onConnect[level] then
            activeLevel = level
            break
        end
    end

    -- If no active level, everything is finished – nothing to do this cycle.
    if not activeLevel then
        return
    end

    local now = os.clock()

    -- Only run tasks from the active level.
    for name, task in pairs(tasksList) do
        if task.priority == activeLevel then
            -- Skip failed tasks entirely
            if task.failed then goto continue end

            -- Respect backoff window
            if task.nextEligibleAt and task.nextEligibleAt > now then
                goto continue
            end

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
                    task.nextEligibleAt = 0
                    rfsuite.utils.log("Completed " .. name, "debug")
                elseif task.startTime and (now - task.startTime) > TASK_TIMEOUT_SECONDS then
                    -- Timeout: re-queue with backoff or mark failed
                    task.attempts = (task.attempts or 0) + 1
                    if task.attempts <= MAX_RETRIES then
                        local backoff = RETRY_BACKOFF_SECONDS * (2 ^ (task.attempts - 1))
                        task.nextEligibleAt = now + backoff
                        task.initialized = false
                        task.startTime = nil
                        rfsuite.utils.log(
                            string.format("Task '%s' timed out. Re-queueing (attempt %d/%d) in %.1fs.",
                                        name, task.attempts, MAX_RETRIES, backoff), "info")
                    else
                        task.failed = true
                        task.startTime = nil
                        rfsuite.utils.log(
                            string.format("Task '%s' failed after %d attempts. Skipping.", name, MAX_RETRIES), "info")
                    end
                end
            end
            ::continue::
        end
    end


    -- Check if the active level just finished; if so, set flags and return early.
    local levelDone = true
    for _, task in pairs(tasksList) do
        if task.priority == activeLevel and not task.complete then
            levelDone = false
            break
        end
    end

    if levelDone then
        rfsuite.session.onConnect[activeLevel] = true
        rfsuite.utils.log("All [" .. activeLevel .. "] tasks complete.", "info")

        if activeLevel == "high" then
            rfsuite.utils.playFileCommon("beep.wav")
            rfsuite.flightmode.current = "preflight"
            rfsuite.tasks.events.flightmode.reset()
            rfsuite.session.isConnectedHigh = true
            return
        elseif activeLevel == "medium" then
            rfsuite.session.isConnectedMedium = true
            return
        elseif activeLevel == "low" then
            rfsuite.session.isConnectedLow = true
            rfsuite.session.isConnected = true
            rfsuite.utils.log("Connection [established].", "info")
            return
        end
    end
end

function tasks.setTelemetryTypeChanged()
    telemetryTypeChanged = true
    lastTypeChangeAt = os.clock()
end

function tasks.active()
    if not activeLevel then
        return false
    end
    return true
end


return tasks

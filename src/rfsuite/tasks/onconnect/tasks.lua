--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local tasks = {}
local tasksList = {}
local tasksLoaded = false
local activeLevel = nil

local telemetryTypeChanged = false

local TASK_TIMEOUT_SECONDS = 10
local MAX_RETRIES = 3
local RETRY_BACKOFF_SECONDS = 1

local TYPE_CHANGE_DEBOUNCE = 1.0
local lastTypeChangeAt = 0

local BASE_PATH = "tasks/onconnect/tasks/"
local PRIORITY_LEVELS = {"high", "medium", "low"}

local function resetSessionFlags()
    rfsuite.session.onConnect = rfsuite.session.onConnect or {}
    for _, level in ipairs(PRIORITY_LEVELS) do rfsuite.session.onConnect[level] = false end

    rfsuite.session.isConnected = false
end

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
                local chunk, err = loadfile(fullPath)
                if not chunk then
                    rfsuite.utils.log("Error loading task " .. fullPath .. ": " .. err, "info")
                else
                    local module = assert(chunk())
                    if type(module) == "table" and type(module.wakeup) == "function" then
                        tasksList[name] = {module = module, priority = level, initialized = false, complete = false, failed = false, attempts = 0, nextEligibleAt = 0, startTime = nil}
                    else
                        rfsuite.utils.log("Invalid task file: " .. fullPath, "info")
                        rfsuite.utils.log("Invalid task file: " .. fullPath, "connect")
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

    if not tasksLoaded then tasks.findTasks() end

    activeLevel = nil
    for _, level in ipairs(PRIORITY_LEVELS) do
        if not rfsuite.session.onConnect[level] then
            activeLevel = level
            break
        end
    end

    if not activeLevel then return end

    local now = os.clock()

    for name, task in pairs(tasksList) do
        if task.priority == activeLevel then

            if task.failed then goto continue end

            if task.nextEligibleAt and task.nextEligibleAt > now then goto continue end

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

                    task.attempts = (task.attempts or 0) + 1
                    if task.attempts <= MAX_RETRIES then
                        local backoff = RETRY_BACKOFF_SECONDS * (2 ^ (task.attempts - 1))
                        task.nextEligibleAt = now + backoff
                        task.initialized = false
                        task.startTime = nil
                        rfsuite.utils.log(string.format("Task '%s' timed out. Re-queueing (attempt %d/%d) in %.1fs.", name, task.attempts, MAX_RETRIES, backoff), "info")
                        rfsuite.utils.log(string.format("Task '%s' timed out. Re-queueing (attempt %d/%d) in %.1fs.", name, task.attempts, MAX_RETRIES, backoff), "connect")
                    else
                        task.failed = true
                        task.startTime = nil
                        rfsuite.utils.log(string.format("Task '%s' failed after %d attempts. Skipping.", name, MAX_RETRIES), "info")
                        rfsuite.utils.log(string.format("Task '%s' failed after %d attempts. Skipping.", name, MAX_RETRIES), "connect")
                    end
                end
            end
            ::continue::
        end
    end

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
            rfsuite.utils.log("Connection [established].", "connect")
            return
        end
    end
end

function tasks.setTelemetryTypeChanged()
    telemetryTypeChanged = true
    lastTypeChangeAt = os.clock()
end

function tasks.active()
    if not activeLevel then return false end
    return true
end

return tasks

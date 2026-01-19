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

-- All onconnect task modules live in a single folder.
-- A hard-coded manifest avoids runtime directory scans (system.listFiles).
local BASE_PATH = "tasks/onconnect/tasks/"
local MANIFEST_PATH = "tasks/onconnect/manifest.lua"
local PRIORITY_LEVELS = {"high", "medium", "low"}

-- Track link transitions so we reset exactly once per connect/disconnect.
local lastTelemetryActive = false

local function loadTaskModuleFromPath(fullPath)

    local chunk, err = loadfile(fullPath)
    if not chunk then
        return nil, err
    end

    local ok, module = pcall(chunk)
    if not ok then
        return nil, module
    end

    if type(module) ~= "table" or type(module.wakeup) ~= "function" then
        return nil, "Invalid task module"
    end

    return module, nil
end

local function hardReloadTask(task)
    if not task or not task.path then return end

    local module, err = loadTaskModuleFromPath(task.path)
    if not module then
        rfsuite.utils.log("Error reloading task " .. task.path .. ": " .. (err or "?"), "info")
        return
    end

    task.module = module
end


local function resetSessionFlags()
    rfsuite.session.onConnect = rfsuite.session.onConnect or {}
    for _, level in ipairs(PRIORITY_LEVELS) do rfsuite.session.onConnect[level] = false end

    rfsuite.session.isConnected = false
end

local function resetTasksOnly()
    -- Ensure task-local state truly resets by hard-reloading each task module from disk.
    for _, task in pairs(tasksList) do
        hardReloadTask(task)

        if type(task.module.reset) == "function" then task.module.reset() end
        task.initialized = false
        task.complete = false
        task.startTime = nil
        task.failed = false
        task.attempts = 0
        task.nextEligibleAt = 0
    end

    resetSessionFlags()
end


local function loadManifest()
    local chunk, err = loadfile(MANIFEST_PATH)

    if not chunk then
        rfsuite.utils.log("Error loading tasks manifest " .. MANIFEST_PATH .. ": " .. (err or "?"), "info")
        return nil
    end

    local ok, manifest = pcall(chunk)
    if not ok or type(manifest) ~= "table" then
        rfsuite.utils.log("Invalid tasks manifest: " .. MANIFEST_PATH, "info")
        return nil
    end

    return manifest
end


function tasks.findTasks()
    if tasksLoaded then return end

    resetSessionFlags()

    local manifest = loadManifest()
    if not manifest then
        tasksLoaded = true
        return
    end

    for _, entry in ipairs(manifest) do
        local level = entry.level
        local file = entry.name

        if level and file then

            local fullPath = BASE_PATH .. file .. ".lua"
            local name = level .. "/" .. file

            local module, err = loadTaskModuleFromPath(fullPath)
            if not module then
                rfsuite.utils.log("Error loading task " .. fullPath .. ": " .. (err or "?"), "info")
            else
                tasksList[name] = {
                    module = module,
                    path = fullPath,
                    priority = level,
                    initialized = false,
                    complete = false,
                    failed = false,
                    attempts = 0,
                    nextEligibleAt = 0,
                    startTime = nil,
                }
            end
        end
    end

    tasksLoaded = true
end

function tasks.resetAllTasks()
    -- Kept for compatibility: do a "task-only" reset.
    -- IMPORTANT: do NOT reset MSP/task system here; doing so can bounce telemetryActive and prevent tasks running.
    resetTasksOnly()
end

function tasks.wakeup()
    local telemetryActive = rfsuite.tasks.msp.onConnectChecksInit and rfsuite.session.telemetryState

    local now = os.clock()

    if telemetryTypeChanged then
        -- optional debounce (prevents thrash if link rapidly flips types)
        if (now - (lastTypeChangeAt or 0)) >= TYPE_CHANGE_DEBOUNCE then
            telemetryTypeChanged = false
            tasks.resetAllTasks()
        end
    end

    if not telemetryActive then
        -- Only reset once on transition from active -> inactive.
        if lastTelemetryActive then
            -- On disconnect, do a HARD reset (ok to nuke MSP/sensors here).
            resetTasksOnly()
            rfsuite.tasks.reset()
            rfsuite.session.resetMSPSensors = true
        else
            resetSessionFlags()
        end
        lastTelemetryActive = false
        return
    end

    -- First connect after being inactive: start clean once.
    if not lastTelemetryActive then
        if not tasksLoaded then tasks.findTasks() end
        -- On connect, only reset task state (do NOT reset MSP/sensors).
        resetTasksOnly()
    end

    lastTelemetryActive = true

    if not tasksLoaded then tasks.findTasks() end

    activeLevel = nil
    for _, level in ipairs(PRIORITY_LEVELS) do
        if not rfsuite.session.onConnect[level] then
            activeLevel = level
            break
        end
    end

    if not activeLevel then return end

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

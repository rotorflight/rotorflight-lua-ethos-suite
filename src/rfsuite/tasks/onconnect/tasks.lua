--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local tasks = {}

-- Single ordered queue (manifest order)
local tasksQueue = {}
local tasksLoaded = false
local active = false

local telemetryTypeChanged = false

-- Safer defaults for intermittent RF links
local DEFAULT_TASK_TIMEOUT_SECONDS = 25
local MAX_RETRIES = 3
local RETRY_BACKOFF_SECONDS = 1

local TYPE_CHANGE_DEBOUNCE = 1.0
local lastTypeChangeAt = 0

-- Link stability / anti-flap settings
local CONNECT_STABLE_SECONDS = 0.6
local DISCONNECT_STABLE_SECONDS = 0.8

local BASE_PATH = "tasks/onconnect/tasks/"
local MANIFEST_PATH = "tasks/onconnect/manifest.lua"

-- Track link transitions so we reset exactly once per connect/disconnect.
local lastTelemetryActive = false

-- Hysteresis state
local linkUpSince = nil
local linkDownSince = nil
local linkStableUp = false

-- Completion guard (per link session)
local linkSessionToken = 0
local establishedToken = nil

-- Sequential index
local queueIndex = 1

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
    rfsuite.session = rfsuite.session or {}
    rfsuite.session.isConnected = false
end

local function resetQueuesAndState()
    for i = 1, #tasksQueue do
        local task = tasksQueue[i]

        hardReloadTask(task)

        if task.module and type(task.module.reset) == "function" then
            pcall(task.module.reset)
        end

        task.initialized = false
        task.complete = false
        task.failed = false
        task.attempts = 0
        task.nextEligibleAt = 0
        task.startTime = nil
    end

    queueIndex = 1
    establishedToken = nil
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

local function isTelemetryActive()
    local session = rfsuite.session
    local t = rfsuite.tasks
    local msp = t and t.msp

    local init = msp and msp.onConnectChecksInit
    if type(init) == "function" then
        local ok, v = pcall(init)
        if not ok or not v then return false end
    else
        if not init then return false end
    end

    local ts = session and session.telemetryState
    if type(ts) == "boolean" then
        return ts
    elseif type(ts) == "table" then
        if type(ts.active) == "boolean" then return ts.active end
        if type(ts.telemetryActive) == "boolean" then return ts.telemetryActive end
        if type(ts.connected) == "boolean" then return ts.connected end
        if type(ts.isActive) == "boolean" then return ts.isActive end
        return false
    end

    return false
end

function tasks.findTasks()
    if tasksLoaded then return end

    resetSessionFlags()

    -- reset queue (in case of reload)
    tasksQueue = {}
    queueIndex = 1

    local manifest = loadManifest()
    if not manifest then
        tasksLoaded = true
        return
    end

    -- Load tasks in manifest order into a single queue
    for _, entry in ipairs(manifest) do
        local file = entry and entry.name
        if file then
            local fullPath = BASE_PATH .. file .. ".lua"
            local module, err = loadTaskModuleFromPath(fullPath)
            if not module then
                rfsuite.utils.log("Error loading task " .. fullPath .. ": " .. (err or "?"), "info")
            else
                tasksQueue[#tasksQueue + 1] = {
                    name = file,
                    module = module,
                    path = fullPath,

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
    -- Task-only reset (doesn't nuke MSP/sensors)
    resetQueuesAndState()
end

local function currentTask()
    return tasksQueue[queueIndex], queueIndex
end

local function advancePastCompletedOrFailed()
    local idx = queueIndex or 1
    while idx <= #tasksQueue do
        local t = tasksQueue[idx]
        if t and not t.complete and not t.failed then
            break
        end
        idx = idx + 1
    end
    queueIndex = idx
end

local function isQueueDone()
    advancePastCompletedOrFailed()
    return (queueIndex or 1) > #tasksQueue
end

function tasks.wakeup()
    local telemetryActive = isTelemetryActive()
    local now = os.clock()

    if telemetryTypeChanged then
        if (now - (lastTypeChangeAt or 0)) >= TYPE_CHANGE_DEBOUNCE then
            telemetryTypeChanged = false
            tasks.resetAllTasks()
        end
    end

    -- Link hysteresis: require stable up/down to avoid flaps restarting tasks (and beeps)
    if telemetryActive then
        linkDownSince = nil
        if not linkUpSince then linkUpSince = now end

        if not linkStableUp and (now - linkUpSince) >= CONNECT_STABLE_SECONDS then
            linkStableUp = true
            linkSessionToken = linkSessionToken + 1
            establishedToken = nil
        end
    else
        linkUpSince = nil
        if not linkDownSince then linkDownSince = now end

        if linkStableUp and (now - linkDownSince) >= DISCONNECT_STABLE_SECONDS then
            linkStableUp = false
        end
    end

    if not linkStableUp then
        active = false
        if lastTelemetryActive then
            -- Hard reset on disconnect (ok to nuke MSP/sensors)
            resetQueuesAndState()

            if rfsuite.tasks and type(rfsuite.tasks.reset) == "function" then
                pcall(rfsuite.tasks.reset)
            end

            rfsuite.session = rfsuite.session or {}
            rfsuite.session.resetMSPSensors = true
        else
            resetSessionFlags()
        end

        lastTelemetryActive = false
        return
    end

    -- First stable connect: reset task state once (do NOT reset MSP/sensors here)
    if not lastTelemetryActive then
        if not tasksLoaded then tasks.findTasks() end
        resetQueuesAndState()
    end
    lastTelemetryActive = true
    active = true

    if not tasksLoaded then tasks.findTasks() end

    -- If everything is complete, mark connected once per link session
    if isQueueDone() then
        local token = tostring(linkSessionToken)
        if establishedToken ~= token then
            establishedToken = token

            -- Keep behavior: move to preflight once we have core link + api sanity.
            rfsuite.flightmode.current = "preflight"
            if rfsuite.tasks and rfsuite.tasks.events and rfsuite.tasks.events.flightmode
                and type(rfsuite.tasks.events.flightmode.reset) == "function"
            then
                rfsuite.tasks.events.flightmode.reset()
            end

            rfsuite.session.isConnected = true
            rfsuite.utils.log("Connection [established].", "info")
            rfsuite.utils.log("Connection [established].", "connect")
        end
        return
    end

    -- Sequential execution: run ONLY the current task in the queue
    local task = currentTask()
    if not task then
        return
    end

    -- Skip if it’s waiting for retry backoff
    if task.nextEligibleAt and task.nextEligibleAt > now then
        return
    end

    if not task.initialized then
        task.initialized = true
        task.startTime = now
    end

    -- Call wakeup for this single task
    rfsuite.utils.log("Waking up onconnect/" .. task.name, "debug")

    local ok, err = pcall(task.module.wakeup)
    if not ok then
        task.attempts = (task.attempts or 0) + 1
        local backoff = RETRY_BACKOFF_SECONDS
        task.nextEligibleAt = now + backoff
        task.initialized = false
        task.startTime = nil
        rfsuite.utils.log("Task 'onconnect/" .. task.name .. "' errored: " .. tostring(err), "info")
        rfsuite.utils.log("Task 'onconnect/" .. task.name .. "' errored: " .. tostring(err), "connect")
        return
    end

    -- Completion check
    if task.module.isComplete and task.module.isComplete() then
        task.complete = true
        task.startTime = nil
        task.nextEligibleAt = 0
        rfsuite.utils.log("Completed onconnect/" .. task.name, "debug")

        -- Special-case: as soon as API version is known, it's safe to switch preflight logic.
        if task.name == "apiversion" then
            rfsuite.flightmode.current = "preflight"
            if rfsuite.tasks and rfsuite.tasks.events and rfsuite.tasks.events.flightmode
                and type(rfsuite.tasks.events.flightmode.reset) == "function"
            then
                rfsuite.tasks.events.flightmode.reset()
            end
        end

        -- Advance to next task (sequential)
        queueIndex = (queueIndex or 1) + 1
        advancePastCompletedOrFailed()
        return
    end

    -- Timeout / retry logic for the currently active task ONLY
    local timeout = DEFAULT_TASK_TIMEOUT_SECONDS
    if type(task.module.timeoutSeconds) == "number" and task.module.timeoutSeconds > 0 then
        timeout = task.module.timeoutSeconds
    end

    if task.startTime and (now - task.startTime) > timeout then
        task.attempts = (task.attempts or 0) + 1

        if task.attempts <= MAX_RETRIES then
            local backoff = RETRY_BACKOFF_SECONDS * (2 ^ (task.attempts - 1))
            task.nextEligibleAt = now + backoff
            task.initialized = false
            task.startTime = nil
            rfsuite.utils.log(
                string.format("Task 'onconnect/%s' timed out. Re-queueing (attempt %d/%d) in %.1fs.",
                    task.name, task.attempts, MAX_RETRIES, backoff),
                "info"
            )
            rfsuite.utils.log(
                string.format("Task 'onconnect/%s' timed out. Re-queueing (attempt %d/%d) in %.1fs.",
                    task.name, task.attempts, MAX_RETRIES, backoff),
                "connect"
            )
        else
            task.failed = true
            task.startTime = nil
            rfsuite.utils.log(
                string.format("Task 'onconnect/%s' failed after %d attempts. Skipping.",
                    task.name, MAX_RETRIES),
                "info"
            )
            rfsuite.utils.log(
                string.format("Task 'onconnect/%s' failed after %d attempts. Skipping.",
                    task.name, MAX_RETRIES),
                "connect"
            )

            -- Skip to next task when a task fully fails
            queueIndex = (queueIndex or 1) + 1
            advancePastCompletedOrFailed()
        end
    end
end

function tasks.setTelemetryTypeChanged()
    telemetryTypeChanged = true
    lastTypeChangeAt = os.clock()
end

function tasks.active()
    return active
end

return tasks

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

-- Safer defaults for intermittent RF links
local DEFAULT_TASK_TIMEOUT_SECONDS = 25
local MAX_RETRIES = 3
local RETRY_BACKOFF_SECONDS = 1

local BASE_PATH = "tasks/events/postconnect/tasks/"
local MANIFEST_PATH = "tasks/events/postconnect/manifest.lua"

-- Edge tracking: we only begin a postconnect run when isConnected rises.
local lastConnected = false

-- Sequential index
local queueIndex = 1

local function loadTaskModuleFromPath(fullPath)
    local chunk, err = loadfile(fullPath)
    if not chunk then
        return nil, err
    end

    local module = chunk()

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

local function resetQueuesAndState()
    for i = 1, #tasksQueue do
        local task = tasksQueue[i]

        hardReloadTask(task)

        if task.module and type(task.module.reset) == "function" then
            task.module.reset()
        end

        task.initialized = false
        task.complete = false
        task.failed = false
        task.attempts = 0
        task.nextEligibleAt = 0
        task.startTime = nil
    end

    queueIndex = 1
end

local function loadManifest()
    local chunk, err = loadfile(MANIFEST_PATH)
    if not chunk then
        rfsuite.utils.log("Error loading tasks manifest " .. MANIFEST_PATH .. ": " .. (err or "?"), "info")
        return nil
    end

    local manifest = chunk()
    if type(manifest) ~= "table" then
        rfsuite.utils.log("Invalid tasks manifest: " .. MANIFEST_PATH, "info")
        return nil
    end

    return manifest
end

local function buildQueueFromManifest(manifest)
    local q = {}
    for i = 1, #manifest do
        local entry = manifest[i]
        local name = entry and entry.name
        if name then
            local path = BASE_PATH .. name .. ".lua"
            table.insert(q, {
                name = name,
                path = path,
                module = nil,
                initialized = false,
                complete = false,
                failed = false,
                attempts = 0,
                nextEligibleAt = 0,
                startTime = nil,
            })
        end
    end
    return q
end

function tasks.findTasks()
    local manifest = loadManifest()
    if not manifest then
        tasksLoaded = false
        tasksQueue = {}
        return
    end

    tasksQueue = buildQueueFromManifest(manifest)

    -- Load modules once
    for i = 1, #tasksQueue do
        local task = tasksQueue[i]
        local module, err = loadTaskModuleFromPath(task.path)
        if not module then
            rfsuite.utils.log("Error loading postconnect task " .. task.path .. ": " .. (err or "?"), "info")
        else
            task.module = module
        end
    end

    tasksLoaded = true
end

local function isQueueDone()
    for i = 1, #tasksQueue do
        if not tasksQueue[i].complete then return false end
    end
    return true
end

local function currentTask()
    return tasksQueue[queueIndex]
end

local function advanceQueue()
    queueIndex = queueIndex + 1
    if queueIndex > #tasksQueue then
        queueIndex = #tasksQueue + 1
    end
end

local function failTask(task, reason)
    task.failed = true
    task.complete = true
    rfsuite.utils.log("postconnect/" .. tostring(task.name) .. " failed: " .. tostring(reason), "info")
end

function tasks.active()
    return active
end

function tasks.reset()
    resetQueuesAndState()
    active = false
    lastConnected = false
    if rfsuite.session then
        rfsuite.session.postConnectComplete = false
    end
end

function tasks.wakeup()
    local now = os.clock()

    -- If we are not connected, reset the edge latch and state
    if not (rfsuite.session and rfsuite.session.isConnected) then
        if lastConnected then
            tasks.reset()
        end
        lastConnected = false
        return
    end

    -- Rising edge: start a postconnect run once per connection
    if not lastConnected then
        lastConnected = true
        active = true
        if not tasksLoaded then tasks.findTasks() end
        resetQueuesAndState()
        rfsuite.utils.log("Postconnect: [started]", "info")
    end

    if not active then
        return
    end

    if not tasksLoaded or #tasksQueue == 0 then
        active = false
        return
    end

    if isQueueDone() then
        active = false
        rfsuite.utils.log("Postconnect: [complete]", "info")
        rfsuite.session.postConnectComplete = true
        return
    end

    local task = currentTask()
    if not task then
        active = false
        return
    end

    -- Skip missing/invalid modules
    if not task.module or type(task.module.wakeup) ~= "function" then
        failTask(task, "missing module")
        advanceQueue()
        return
    end

    -- Retry backoff
    if task.nextEligibleAt and task.nextEligibleAt > now then
        return
    end

    if not task.initialized then
        task.initialized = true
        task.startTime = now
    end

    -- Timeout
    if task.startTime and (now - task.startTime) > DEFAULT_TASK_TIMEOUT_SECONDS then
        task.attempts = (task.attempts or 0) + 1
        if task.attempts <= MAX_RETRIES then
            task.startTime = now
            task.nextEligibleAt = now + RETRY_BACKOFF_SECONDS
            rfsuite.utils.log("postconnect/" .. task.name .. " timeout, retry " .. task.attempts .. "/" .. MAX_RETRIES, "info")
            return
        end
        failTask(task, "timeout")
        advanceQueue()
        return
    end

    -- Call wakeup
    task.module.wakeup()

    -- Completion check
    if task.module.isComplete and task.module.isComplete() then
        task.complete = true
        task.startTime = nil
        task.nextEligibleAt = 0
        rfsuite.utils.log("Completed postconnect/" .. task.name, "debug")
        advanceQueue()
    end
end

return tasks

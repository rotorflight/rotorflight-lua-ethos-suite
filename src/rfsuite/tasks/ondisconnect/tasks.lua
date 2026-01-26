--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local tasks = {}


local tasksQueue = {}
local tasksLoaded = false
local active = false

local BASE_PATH = "tasks/ondisconnect/tasks/"
local MANIFEST_PATH = "tasks/ondisconnect/manifest.lua"

-- Link hysteresis (match onconnect defaults)
local DISCONNECT_STABLE_SECONDS = 0.8

-- Edge state
local lastTelemetryActive = false
local linkDownSince = nil
local linkStableDown = false

-- Completion guard (per disconnect session)
local disconnectSessionToken = 0
local firedToken = nil
local pendingFire = false

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

    tasksQueue = {}
    queueIndex = 1

    local manifest = loadManifest()
    if not manifest then
        tasksLoaded = true
        return
    end

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
                }
            end
        end
    end

    tasksLoaded = true
end

local function resetQueueState()
    for i = 1, #tasksQueue do
        local task = tasksQueue[i]

        hardReloadTask(task)

        if task.module and type(task.module.reset) == "function" then
            pcall(task.module.reset)
        end

        task.initialized = false
        task.complete = false
        task.failed = false
    end

    queueIndex = 1
end

function tasks.resetAllTasks()
    resetQueueState()
    active = false
    pendingFire = false
    firedToken = nil
end

local function isQueueDone()
    return (queueIndex or 1) > #tasksQueue
end

-- Called from the core scheduler so this module can edge-detect disconnects.
-- telemetryActive: boolean
-- now: os.clock() timestamp (optional)
function tasks.updateLinkState(telemetryActive, now)
    now = now or os.clock()

    if telemetryActive then
        linkDownSince = nil
        linkStableDown = false
        pendingFire = false
    else
        if not linkDownSince then linkDownSince = now end
        if not linkStableDown and (now - linkDownSince) >= DISCONNECT_STABLE_SECONDS then
            linkStableDown = true
            disconnectSessionToken = disconnectSessionToken + 1
            pendingFire = true
        end
    end

    lastTelemetryActive = telemetryActive
end

-- Run once when a stable disconnect edge is detected.
function tasks.wakeup()
    if not pendingFire then
        active = false
        return
    end

    local token = tostring(disconnectSessionToken)
    if firedToken == token then
        active = false
        pendingFire = false
        return
    end

    firedToken = token
    pendingFire = false
    active = true

    if not tasksLoaded then tasks.findTasks() end
    resetQueueState()

    rfsuite.utils.log("Connection [lost]. (ondisconnect hook)", "info")

    -- If tasks exist later, run them sequentially (one per wakeup) similar to onconnect.
    if #tasksQueue == 0 then
        active = false
        return
    end

    while not isQueueDone() do
        local task = tasksQueue[queueIndex]
        if not task or task.complete or task.failed then
            queueIndex = (queueIndex or 1) + 1
        else
            if not task.initialized then task.initialized = true end
            local ok, err = pcall(task.module.wakeup)
            if not ok then
                task.failed = true
                rfsuite.utils.log("Task 'ondisconnect/" .. task.name .. "' errored: " .. tostring(err), "info")
            elseif task.module.isComplete and task.module.isComplete() then
                task.complete = true
            else
                -- Task needs more time; yield until next wakeup
                return
            end
            queueIndex = (queueIndex or 1) + 1
        end
    end

    active = false
end

function tasks.active()
    return active
end

return tasks

--[[
    Copyright (C) 2025 Rotorflight Project
    GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local tasks = {}

local tasksQueue = {}
local tasksLoaded = false
local active = false

local BASE_PATH = "tasks/events/ondisconnect/tasks/"
local MANIFEST_PATH = "tasks/events/ondisconnect/manifest.lua"

-- Completion guard (per disconnect session)
local disconnectSessionToken = 0
local firedToken = nil
local pendingFire = false

-- Data preservation across session reset
local preservedModelName = nil

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

local function clearTaskEntries()
    for i = #tasksQueue, 1, -1 do
        tasksQueue[i] = nil
    end
end

local function ensureTaskModule(task)
    local module, err

    if not task or not task.path then
        return nil, "Invalid task descriptor"
    end
    if task.module then
        return task.module, nil
    end

    module, err = loadTaskModuleFromPath(task.path)
    if not module then
        return nil, err
    end

    task.module = module
    return module, nil
end

local function releaseTaskModule(task, runReset)
    local module = task and task.module

    if not module then return end
    if runReset and type(module.reset) == "function" then
        module.reset()
    end
    task.module = nil
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

function tasks.findTasks()
    if tasksLoaded then return end

    clearTaskEntries()
    queueIndex = 1

    local manifest = loadManifest()
    if not manifest then
        tasksLoaded = true
        return
    end

    for _, entry in ipairs(manifest) do
        local file = entry and entry.name
        if file then
            tasksQueue[#tasksQueue + 1] = {
                name = file,
                module = nil,
                path = BASE_PATH .. file .. ".lua",
                initialized = false,
                complete = false,
                failed = false,
            }
        end
    end

    tasksLoaded = true
end

local function resetQueueState()
    for i = 1, #tasksQueue do
        local task = tasksQueue[i]

        releaseTaskModule(task, true)
        task.initialized = false
        task.complete = false
        task.failed = false
    end

    queueIndex = 1
end

function tasks.reset()
    resetQueueState()
    active = false
    pendingFire = false
    firedToken = nil
    preservedModelName = nil
end

local function isQueueDone()
    return (queueIndex or 1) > #tasksQueue
end

function tasks.fire(args)
    disconnectSessionToken = disconnectSessionToken + 1
    pendingFire = true
    active = true
    rfsuite.utils.log("ondisconnect fired", "debug")
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

    if #tasksQueue == 0 then
        active = false
        return
    end

    while not isQueueDone() do
        local task = tasksQueue[queueIndex]
        local module, err
        if not task or task.complete or task.failed then
            queueIndex = (queueIndex or 1) + 1
        else
            if not task.initialized then task.initialized = true end

            module, err = ensureTaskModule(task)
            if not module or type(module.wakeup) ~= "function" then
                task.failed = true
                rfsuite.utils.log("Failed to load ondisconnect/" .. tostring(task and task.name) .. ": " .. tostring(err or "missing module"), "info")
                queueIndex = (queueIndex or 1) + 1
                goto continue
            end

            module.wakeup()

            if module.isComplete and module.isComplete() then
                task.complete = true
                releaseTaskModule(task, false)
            else
                return
            end
            queueIndex = (queueIndex or 1) + 1
        end
        ::continue::
    end

    active = false
end

function tasks.active()
    return active
end

return tasks

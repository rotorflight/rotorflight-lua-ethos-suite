--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local utils = rfsuite.utils

local hook = {}

local BASE_PATH = "tasks/events/onarm/tasks/"
local MANIFEST_PATH = "tasks/events/onarm/manifest.lua"

-- Ordered queue (manifest order). Empty by default.
local taskQueue = nil
local active = false

-- Optional: last payload/context provided by the edge that triggered this hook
hook.lastContext = nil

local function loadManifest()
    local fn, err = loadfile(MANIFEST_PATH)
    if not fn then
        -- Missing manifest is non-fatal; treat as no tasks
        return {}
    end
    local ok, manifestOrErr = pcall(fn)
    if not ok then
        utils.log(string.format("[hook:onarm] manifest error: %s", tostring(manifestOrErr)), "error")
        return {}
    end
    if type(manifestOrErr) ~= "table" then
        return {}
    end
    return manifestOrErr
end

local function buildQueue()
    taskQueue = {}
    local manifest = loadManifest()
    for i = 1, #manifest do
        local item = manifest[i]
        local name = item and item.name
        if name then
            taskQueue[#taskQueue + 1] = name
        end
    end
end

-- Called by the core when this hook edge triggers.
-- Context is optional and can be used by future hook tasks.
function hook.fire(context)
    hook.lastContext = context
    if not taskQueue then buildQueue() end
    active = true
end

-- Reset hook state so it can trigger again.
function hook.reset()
    active = false
    hook.lastContext = nil
end

-- Compatibility with other task modules
function hook.resetAllTasks()
    taskQueue = nil
    hook.reset()
end

-- Runs hook tasks (if/when they exist). Safe no-op when the manifest is empty.
function hook.wakeup()
    if not active then return end
    if not taskQueue or #taskQueue == 0 then
        active = false
        return
    end

    -- NOTE: Framework only. When you add tasks, you can implement execution here
    -- similarly to onconnect/postconnect (timeouts, retries, etc).
    -- For now we just clear the latch so the hook only fires once per edge.
    active = false
end

return hook

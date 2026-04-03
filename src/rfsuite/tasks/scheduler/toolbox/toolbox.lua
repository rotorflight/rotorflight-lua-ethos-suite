--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]
local toolbox = {}
local telemetryStartTime = nil
local wakeupStep = 0
local os_clock = os.clock
local type = type
local wasActive = false

local taskExecutionPercent = 50
local taskEntries = {
    {name = "armflags", path = "tasks/scheduler/toolbox/tasks/armflags.lua"},
    {name = "governor", path = "tasks/scheduler/toolbox/tasks/governor.lua"},
    {name = "craftname", path = "tasks/scheduler/toolbox/tasks/craftname.lua"},
    {name = "bbl", path = "tasks/scheduler/toolbox/tasks/bbl.lua"},
    {name = "craftimage", path = "tasks/scheduler/toolbox/tasks/craftimage.lua"},
    {name = "timer", path = "tasks/scheduler/toolbox/tasks/timer.lua"}
}

local function loadTaskModule(entry)
    local chunk, err = loadfile(entry.path)
    if not chunk then
        rfsuite.utils.log("Error loading toolbox task " .. tostring(entry.path) .. ": " .. tostring(err or "?"), "info")
        return nil
    end

    local module = chunk(config)
    if type(module) ~= "table" or type(module.wakeup) ~= "function" then
        rfsuite.utils.log("Invalid toolbox task module: " .. tostring(entry.path), "info")
        return nil
    end

    entry.module = module
    return module
end

local function ensureTaskModule(entry)
    return entry.module or loadTaskModule(entry)
end

local function resetTaskModule(entry)
    local module = entry and entry.module
    if not module then return end
    if type(module.reset) == "function" then module.reset() end
    entry.module = nil
end

local function maybeWakeTask(entry)
    local module = ensureTaskModule(entry)
    if not module or type(module.wakeup) ~= "function" then return false end

    module.wakeup()
    return true
end

for i = 1, #taskEntries do
    local entry = taskEntries[i]
    toolbox[entry.name] = {
        wakeup = function()
            maybeWakeTask(entry)
        end,
        reset = function()
            resetTaskModule(entry)
        end,
        isLoaded = function()
            return entry.module ~= nil
        end
    }
end

local tasksPerWakeup = math.max(1, math.floor((taskExecutionPercent / 100) * #taskEntries))
local numEntries = #taskEntries

function toolbox.wakeup()
    local session = rfsuite.session
    local currentTime = os_clock()

    if not session or session.toolbox == nil then
        if wasActive then
            toolbox.reset()
        end
        wasActive = false
        return
    end

    wasActive = true

    if session.isConnected and session.telemetryState then
        local ran = 0
        local attempts = 0

        if telemetryStartTime == nil then telemetryStartTime = currentTime end
        if (currentTime - telemetryStartTime) < 2.5 then return end

        while ran < tasksPerWakeup and attempts < numEntries do
            wakeupStep = (wakeupStep % numEntries) + 1
            if maybeWakeTask(taskEntries[wakeupStep]) then
                ran = ran + 1
            end
            attempts = attempts + 1
        end
    else
        telemetryStartTime = nil
        wakeupStep = 0
    end
end

function toolbox.reset()
    telemetryStartTime = nil
    wakeupStep = 0
    for i = 1, #taskEntries do
        resetTaskModule(taskEntries[i])
    end
end

return toolbox

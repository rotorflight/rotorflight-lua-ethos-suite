--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]
local events = {}
local telemetryStartTime = nil
local wakeupStep = 0
local wakeupHandlers = {}
local os_clock = os.clock

local taskNames = {"rxmap", "flightmode", "telemetry", "switches", "stats", "flighttimer"}
local taskExecutionPercent = 50

for _, name in ipairs(taskNames) do
    events[name] = assert(loadfile("tasks/scheduler/events/tasks/" .. name .. ".lua"))(rfsuite.config)
    table.insert(wakeupHandlers, function() events[name].wakeup() end)
end

local tasksPerWakeup = math.max(1, math.floor((taskExecutionPercent / 100) * #wakeupHandlers))
local numHandlers = #wakeupHandlers

function events.wakeup()
    local currentTime = os_clock()

    if rfsuite.session.postConnectComplete and rfsuite.session.telemetryState then
        if telemetryStartTime == nil then telemetryStartTime = currentTime end

        if (currentTime - telemetryStartTime) < 2.5 then return end

        for i = 1, tasksPerWakeup do
            wakeupStep = (wakeupStep % numHandlers) + 1
            wakeupHandlers[wakeupStep]()
        end
    else
        telemetryStartTime = nil
        wakeupStep = 0
    end
end

function events.reset()
    telemetryStartTime = nil
    for _, name in ipairs(taskNames) do
        local subtask = events[name]
        if subtask and type(subtask.reset) == "function" then subtask.reset() end
    end
end

return events

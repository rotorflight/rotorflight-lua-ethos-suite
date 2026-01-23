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
local wakeupHandlers = {}

local taskNames = {"armflags", "governor", "craftname", "bbl", "craftimage"}
local taskExecutionPercent = 50

for _, name in ipairs(taskNames) do
    toolbox[name] = assert(loadfile("tasks/scheduled/toolbox/tasks/" .. name .. ".lua"))(rfsuite.config)
    table.insert(wakeupHandlers, function() toolbox[name].wakeup() end)
end

function toolbox.wakeup()

    if rfsuite.session.toolbox == nil then return end
    local currentTime = os.clock()

    if rfsuite.session.isConnected and rfsuite.session.telemetryState then
        if telemetryStartTime == nil then telemetryStartTime = currentTime end

        if (currentTime - telemetryStartTime) < 2.5 then return end

        local percent = taskExecutionPercent or 25
        local tasksPerWakeup = math.max(1, math.floor((percent / 100) * #wakeupHandlers))

        for i = 1, tasksPerWakeup do
            wakeupStep = (wakeupStep % #wakeupHandlers) + 1
            wakeupHandlers[wakeupStep]()
        end
    else
        telemetryStartTime = nil
        wakeupStep = 0
    end
end

function toolbox.reset() telemetryStartTime = nil end

return toolbox


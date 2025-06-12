--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local arg = { ... }
local config = arg[1]
local events = {}
local telemetryStartTime = nil
local wakeupStep = 0
local wakeupHandlers = {}

-- List of task module names (must match the .lua filenames)
local taskNames = { "telemetry", "switches", "flightmode", "maxmin", "timer", "rxmap" }
local taskExecutionPercent = 50 -- 50% of tasks will run each cycle

-- Dynamically load task modules and populate wakeupHandlers
for _, name in ipairs(taskNames) do
    events[name] = assert(rfsuite.compiler.loadfile("tasks/events/tasks/" .. name .. ".lua"))(rfsuite.config)
    table.insert(wakeupHandlers, function() events[name].wakeup() end)
end

function events.wakeup()
    local currentTime = os.clock()

    if rfsuite.session.isConnected and rfsuite.session.telemetryState then
        if telemetryStartTime == nil then
            telemetryStartTime = currentTime
        end

        -- Wait 2.5 seconds after telemetry becomes active
        if (currentTime - telemetryStartTime) < 2.5 then
            return
        end

        -- Determine how many tasks to run this cycle based on config
        local percent = taskExecutionPercent or 25  -- Default to 25% if not set
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

function events.reset()
    telemetryStartTime = nil
end

return events


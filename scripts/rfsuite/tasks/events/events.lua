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

--[[
Loads and initializes event handler modules for telemetry, switches, and flight mode.

Each event handler is loaded using the custom compiler's `loadfile` method, which loads the corresponding Lua file
from the "tasks/events/tasks/" directory. The loaded module is immediately invoked with the current configuration
(`rfsuite.config`) and assigned to the respective field in the `events` table.

- `events.telemetry`: Handles telemetry-related events.
- `events.switches`: Handles switch-related events.
- `events.flightmode`: Handles flight mode change events.

If any module fails to load, an error is raised due to the use of `assert`.
]]
events.telemetry = assert(rfsuite.compiler.loadfile("tasks/events/tasks/telemetry.lua"))(rfsuite.config)

events.switches = assert(rfsuite.compiler.loadfile("tasks/events/tasks/switches.lua"))(rfsuite.config)

events.flightmode = assert(rfsuite.compiler.loadfile("tasks/events/tasks/flightmode.lua"))(rfsuite.config)

--- Handles periodic wakeup events for the events module.
--  This function checks if the session is connected and telemetry is active.
--  If telemetry has just become active, it waits for 2.5 seconds before proceeding.
--  After the delay, it triggers wakeup handlers for telemetry, switches, and flight mode events.
--  If telemetry is not active, it resets the telemetry start time.
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

        events.telemetry.wakeup()
        events.switches.wakeup()
        events.flightmode.wakeup()
    else
        telemetryStartTime = nil
    end
end

--- Resets the telemetry start time.
function events.reset()
    telemetryStartTime = nil
end

return events

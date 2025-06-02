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

local flightmode = {}
local lastFlightMode = nil
local hasBeenInFlight = false

--------------------------------------------------------------------------------
-- Checks whether the model is currently in flight.
-- Returns true if telemetry is active, the model is armed, and one of:
--   • Governor source equals 4
--   • RPM > 500
--   • Throttle percent > 30
--------------------------------------------------------------------------------
function flightmode.inFlight()
    local telemetry = rfsuite.tasks.telemetry

    if not telemetry.active() then
        return false
    end
    if rfsuite.session.isArmed then
        local governor = telemetry.getSensorSource("governor")
        local rpm      = telemetry.getSensorSource("rpm")
        local throttle = telemetry.getSensorSource("throttle_percent")

        if governor and governor:value() == 4 then
            return true
        elseif rpm and rpm:value() > 500 then
            return true
        elseif throttle and throttle:value() > 30 then
            return true
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- Resets flight mode tracking and timers:
--   • Clears lastFlightMode and hasBeenInFlight flags
--------------------------------------------------------------------------------
function flightmode.reset()
    lastFlightMode = nil
    hasBeenInFlight = false
end

--------------------------------------------------------------------------------
-- Handles the wakeup logic for flight mode state transitions:
--   • Determines "preflight", "inflight", or "postflight"
--   • Logs mode transitions and updates model preferences as needed
--------------------------------------------------------------------------------
function flightmode.wakeup()

    local mode

    if flightmode.inFlight() then
        mode = "inflight"

        hasBeenInFlight = true

    else
        if hasBeenInFlight then
            mode = "postflight"
        else
            mode = "preflight"
        end
    end

    -- Log and update flight mode on transition
    if lastFlightMode ~= mode then
        rfsuite.utils.log("Flight mode: " .. mode, "info")
        rfsuite.session.flightMode = mode
        lastFlightMode = mode
    end
end

return flightmode

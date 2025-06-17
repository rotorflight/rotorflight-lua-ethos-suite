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

local throttleStartTime = nil -- Time when throttle first exceeded 0
local throttleDelaySeconds = 10 -- Delay before trusting throttle > 0


--- Determines if the aircraft is considered "in flight" based on telemetry and session data.
-- 
-- The function checks the following conditions in order of priority:
-- 1. If telemetry is inactive or the session is not armed, returns false.
-- 2. If a "governor" sensor is available and its value is between 4 and 8 (inclusive), returns true.
-- 3. If the throttle value is greater than 0 for a specified delay period (`throttleDelaySeconds`), returns true.
-- 4. Otherwise, returns false.
--
-- @return boolean True if the aircraft is considered in flight, false otherwise.
function flightmode.inFlight()
    local telemetry = rfsuite.tasks.telemetry

    if not telemetry.active() or not rfsuite.session.isArmed then
        throttleStartTime = nil
        return false
    end

    -- Priority 1: Governor
    local governor = telemetry.getSensor("governor")
    if governor then
        local g = governor
        if g ~= nil then
            return g == 4 or g == 5 or g == 6 or g == 7 or g == 8
        end
    end

    -- Priority 2: Throttle fallback with delay
    local now = rfsuite.clock
    local throttle = rfsuite.session.rx and rfsuite.session.rx.values and rfsuite.session.rx.values.throttle

    if throttle and throttle > 0 then
        if not throttleStartTime then
            throttleStartTime = now -- start timer
        elseif (now - throttleStartTime) >= throttleDelaySeconds then
            return true -- throttle has been above 0 long enough
        end
    else
        throttleStartTime = nil -- reset timer if throttle drops
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
    throttleStartTime = nil
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

    -- catch a hard power-off senario
    if rfsuite.session.flightMode == "inflight" and not rfsuite.session.isConnected  then
        mode = "postflight"
        hasBeenInFlight = false
    end

    -- Log and update flight mode on transition
    if lastFlightMode ~= mode then
        rfsuite.utils.log("Flight mode: " .. mode, "info")
        rfsuite.session.flightMode = mode
        lastFlightMode = mode
    end
end

return flightmode

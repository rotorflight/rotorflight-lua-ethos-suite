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

local throttleThreshold = 50 -- Throttle (%) required for flight mode transition

--- Determines if the aircraft is considered "in flight" based on telemetry and session data.
local function isGovernorActive(value)
    return type(value) == "number" and value >= 4 and value <= 8
end

--- Determines if the flight mode is considered "in flight".
-- This function checks two main conditions to decide if the model is in flight:
-- If the model is armed, proceed to the below
-- 1. If the governor sensor is active (highest priority).
-- 2. If the throttle has been above zero for a sustained period.
-- The function also ensures telemetry is active and the session is armed before proceeding.
-- @return boolean True if the model is considered in flight, false otherwise.
function flightmode.inFlight()
    local telemetry = rfsuite.tasks.telemetry

    if not telemetry.active() or not rfsuite.session.isArmed then
        return false
    end

    -- Priority 1: Governor sensor range
    local governor = telemetry.getSensor("governor")
    if isGovernorActive(governor) then
        return true
    end

    -- Priority 2: Throttle logic
    local rx = rfsuite.session.rx
    local throttle = rx and rx.values and rx.values.throttle

    if throttle and throttle > throttleThreshold then
        return true
    end

    return false
end

--- Resets the flight mode state.
-- This function clears the last flight mode, resets the flight status,
-- and clears the throttle start time. It is typically used to reinitialize
-- the flight mode tracking variables to their default states.
function flightmode.reset()
    lastFlightMode = nil
    hasBeenInFlight = false
end

--- Determines the current flight mode based on session state and flight status.
-- This function checks the current session's flight mode and connection status,
-- as well as the result of `flightmode.inFlight()`, to decide whether the mode
-- should be "preflight", "inflight", or "postflight".
-- It also manages the `hasBeenInFlight` flag to track if the system has ever been in flight.
-- @return string The determined flight mode: "preflight", "inflight", or "postflight".
local function determineMode()
    if rfsuite.flightmode.current == "inflight" and not rfsuite.session.isConnected then
        hasBeenInFlight = false
        return "postflight"
    end

    if flightmode.inFlight() then
        hasBeenInFlight = true
        return "inflight"
    end

    return hasBeenInFlight and "postflight" or "preflight"
end

--- Wakes up the flight mode task and updates the current flight mode if it has changed.
-- Determines the current flight mode using `determineMode()`. If the mode has changed since the last check,
-- logs the new flight mode, updates the session's flight mode, and stores the new mode as the last known mode.
function flightmode.wakeup()
    local mode = determineMode()

    if lastFlightMode ~= mode then
        rfsuite.utils.log("Flight mode: " .. mode, "info")
        rfsuite.flightmode.current = mode
        lastFlightMode = mode
    end
end

return flightmode

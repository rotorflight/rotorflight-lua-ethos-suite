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
-- Determines if the model is currently in flight.
--
-- Returns:
--   true if all the following conditions are met:
--     - Telemetry is active.
--     - The model is armed.
--     - One of the following is true:
--         • Governor sensor is present and its value is 4, 5, 6, 7, or 8.
--         • Governor sensor is present but not valid, and throttle percent > 30.
--         • Governor sensor is not present, and either RPM > 500 or throttle percent > 30.
--
-- Notes:
--   - If a valid governor value is detected, it takes precedence and the model is considered in flight.
--   - If the governor is present but not valid, RPM is ignored and only throttle percent is considered.
--   - If no governor is present, both RPM and throttle percent are considered.
--   - If all checks fail, the function returns the armed status as a fallback.
--------------------------------------------------------------------------------
function flightmode.inFlight()
    local telemetry = rfsuite.tasks.telemetry

    if not telemetry.active() or not rfsuite.session.isArmed then
        return false
    end

    local governor = telemetry.getSensorSource("governor")
    local rpm = telemetry.getSensorSource("rpm")
    local throttle = telemetry.getSensorSource("throttle_percent")

    local hasGovernor = false
    local validGovernor = false

    if governor then
        hasGovernor = true
        local g = governor:value()
        if g == 4 or g == 5 or g == 6 or g == 7 or g == 8 then
            validGovernor = true
        end
    end

    -- Governor is valid => trust it completely
    if validGovernor then
        return true
    end

    -- Governor is present but not valid => don't trust RPM
    if hasGovernor then
        -- fall through to throttle only
        if throttle and throttle:value() > 30 then
            return true
        end
    else
        -- No governor, we can trust RPM
        if rpm and rpm:value() > 500 then
            return true
        end
        if throttle and throttle:value() > 30 then
            return true
        end
    end

    -- we will enject yaw control check here

    -- Return false if no conditions are met
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

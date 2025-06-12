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
--         • Rudder control input is active (rudder channel value outside -300 to 300).
--
-- Notes:
--   - If a valid governor value is detected, it takes precedence and the model is considered in flight.
--   - If the governor is present but not valid, RPM is ignored and only throttle percent is considered.
--   - If no governor is present, both RPM and throttle percent are considered.
--   - If all checks fail, the function returns the armed status as a fallback.
--------------------------------------------------------------------------------
function flightmode.inFlight()
    local telemetry = rfsuite.tasks.telemetry

    -- Basic checks
    if not telemetry.active() or not rfsuite.session.isArmed then
        return false
    end

    -- Priority 1: Governor
    local governor = telemetry.getSensorSource("governor")
    if governor then
        local g = governor:value()
        if g ~= nil then
            return g == 4 or g == 5 or g == 6 or g == 7 or g == 8
        end
    end

    -- Priority 2: RPM
    local rpm = telemetry.getSensorSource("rpm")
    if rpm then
        local r = rpm:value()
        if r ~= nil then
            return r > 500
        end
    end

    -- Priority 3: Throttle
    local throttle = telemetry.getSensorSource("throttle_percent")
    if throttle then
        local t = throttle:value()
        if t ~= nil then
            return t > 30
        end
    end

    -- Priority 4: Rudder channel
    --if rfsuite.session.rxmap and rfsuite.session.rxmap.rudder then
    --    local channel = rfsuite.utils.getChannelValue(rfsuite.session.rxmap.rudder + 1)
    --    if channel ~= nil then
    --        return channel < -300 or channel > 300
    --    end
    --end

    -- If no source reported valid data, return false
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

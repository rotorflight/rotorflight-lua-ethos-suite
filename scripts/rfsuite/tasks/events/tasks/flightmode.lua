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
--   • Resets session timer fields (start, live, session)
--   • Loads persistent lifetime from ini (totalflighttime)
--------------------------------------------------------------------------------
function flightmode.reset()
    lastFlightMode = nil
    hasBeenInFlight = false

    rfsuite.session.timer = {}
    rfsuite.session.flightCounted = false

    -- Load total persistent lifetime from model preferences (INI)
    rfsuite.session.timer.lifetime = rfsuite.ini.getvalue(
        rfsuite.session.modelPreferences,
        "general",
        "totalflighttime"
    ) or 0

    -- Initialize session timer to zero for current power-on
    rfsuite.session.timer.session = 0
end

--------------------------------------------------------------------------------
-- Handles the wakeup logic for flight mode state transitions:
--   • Determines "preflight", "inflight", or "postflight"
--   • Manages session timer: start time, live time, and accumulated session time
--   • Increments flight counter if live time ≥ 25 seconds and not already counted
--   • Logs mode transitions and updates model preferences as needed
--------------------------------------------------------------------------------
function flightmode.wakeup()
    local now = os.clock()
    local mode

    if flightmode.inFlight() then
        mode = "inflight"

        if not rfsuite.session.timer.start then
            -- First arm segment since power-on
            rfsuite.session.timer.start = now
        end

        -- Calculate live time: accumulated session + current segment
        local currentSegment = now - rfsuite.session.timer.start
        rfsuite.session.timer.live = (rfsuite.session.timer.session or 0) + currentSegment

        hasBeenInFlight = true

        -- Increment flight counter when live time reaches 25s and not yet counted
        if rfsuite.session.timer.live >= 25 and not rfsuite.session.flightCounted then
            rfsuite.session.flightCounted = true

            if rfsuite.session.modelPreferences
               and rfsuite.ini.section_exists(rfsuite.session.modelPreferences, "general") then

                local currentValue = rfsuite.ini.getvalue(
                    rfsuite.session.modelPreferences,
                    "general",
                    "flightcount"
                ) or 0

                rfsuite.utils.log("Current flight count: " .. tostring(currentValue), "info")

                local newValue = currentValue + 1
                rfsuite.utils.log("Incrementing flight counter: " .. newValue, "info")

                rfsuite.ini.setvalue(
                    rfsuite.session.modelPreferences,
                    "general",
                    "flightcount",
                    newValue
                )
                rfsuite.ini.save_ini_file(
                    rfsuite.session.modelPreferencesFile,
                    rfsuite.session.modelPreferences
                )
            end
        end

    else
        if hasBeenInFlight then
            mode = "postflight"

            -- Accumulate last armed segment into session time
            if rfsuite.session.timer.start then
                local segment = now - rfsuite.session.timer.start
                rfsuite.session.timer.session = (rfsuite.session.timer.session or 0) + segment
                rfsuite.session.timer.start = nil
            end
            -- Remain in postflight until armed again or reset
        else
            mode = "preflight"
        end

        -- While not inflight, live time equals total session time
        rfsuite.session.timer.live = rfsuite.session.timer.session or 0
    end

    -- Log and update flight mode on transition
    if lastFlightMode ~= mode then
        rfsuite.utils.log("Flight mode: " .. mode, "info")
        rfsuite.session.flightMode = mode
        lastFlightMode = mode
    end
end

--------------------------------------------------------------------------------
-- Saves flight timers to INI on disconnect or shutdown:
--   • Updates totalflighttime = previous lifetime + this session's time
--   • Updates lastflighttime = this session's total time
--------------------------------------------------------------------------------
function flightmode.save()
    local newLifetime = (rfsuite.session.timer.lifetime or 0)
                      + (rfsuite.session.timer.session or 0)

    rfsuite.ini.setvalue(
        rfsuite.session.modelPreferences,
        "general",
        "totalflighttime",
        newLifetime
    )
    rfsuite.ini.setvalue(
        rfsuite.session.modelPreferences,
        "general",
        "lastflighttime",
        rfsuite.session.timer.session or 0
    )
    rfsuite.ini.save_ini_file(
        rfsuite.session.modelPreferencesFile,
        rfsuite.session.modelPreferences
    )
end

return flightmode

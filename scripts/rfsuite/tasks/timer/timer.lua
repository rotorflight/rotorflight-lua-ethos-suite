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

local timer = {}
local lastFlightMode = nil

--- Resets the flight timer session.
-- Logs the reset action, clears the last flight mode, and initializes a new timer session.
-- Sets the base lifetime from model preferences, resets session and lifetime counters,
-- and marks the flight as not counted.
function timer.reset()
    --rfsuite.utils.log("Resetting flight timers", "info")
    lastFlightMode = nil

    local timerSession = {}
    rfsuite.session.timer = timerSession
    rfsuite.session.flightCounted = false

    timerSession.baseLifetime = tonumber(
        rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "totalflighttime")
    ) or 0

    timerSession.session = 0
    timerSession.lifetime = timerSession.baseLifetime
    timerSession.live = 0
    timerSession.start = nil   
end

--- Saves the current flight timer values to the model preferences INI file.
-- This function retrieves the model preferences and preferences file from the session.
-- If the preferences file is not set, it logs a message and returns.
-- Otherwise, it updates the "totalflighttime" and "lastflighttime" values in the "general" section
-- of the preferences, then saves the updated preferences back to the INI file.
-- Logs actions for debugging and information purposes.
function timer.save()
    local prefs = rfsuite.session.modelPreferences
    local prefsFile = rfsuite.session.modelPreferencesFile

    if not prefsFile then
        rfsuite.utils.log("No model preferences file set, cannot save flight timers", "info")
        return 
    end

    rfsuite.utils.log("Saving flight timers to INI: " .. prefsFile, "info")

    if prefs then
        rfsuite.ini.setvalue(prefs, "general", "totalflighttime", rfsuite.session.timer.baseLifetime or 0)
        rfsuite.ini.setvalue(prefs, "general", "lastflighttime", rfsuite.session.timer.session or 0)
        rfsuite.ini.save_ini_file(prefsFile, prefs)
    end    
end

--- Finalizes the current flight segment by updating session and lifetime timers.
-- Calculates the duration of the current segment, updates the session and lifetime
-- timers accordingly, and saves the updated timer state.
-- @param now number The current time (in seconds or milliseconds, depending on context).
-- @usage
--   finalizeFlightSegment(os.clock())
local function finalizeFlightSegment(now)
    local timerSession = rfsuite.session.timer
    local prefs = rfsuite.session.modelPreferences

    local segment = now - timerSession.start
    timerSession.session = (timerSession.session or 0) + segment
    timerSession.start = nil

    if timerSession.baseLifetime == nil then
        timerSession.baseLifetime = tonumber(
            rfsuite.ini.getvalue(prefs, "general", "totalflighttime")
        ) or 0
    end

    timerSession.baseLifetime = timerSession.baseLifetime + segment
    timerSession.lifetime = timerSession.baseLifetime

    -- Only update INI for totalflighttime at the end of flight
    if prefs then
        rfsuite.ini.setvalue(prefs, "general", "totalflighttime", timerSession.baseLifetime)
    end
    timer.save()
end

--- Handles timer updates based on the current flight mode.
-- 
-- This function should be called periodically to update the timer session state.
-- It manages the start time, live session duration, and lifetime of the timer,
-- and updates persistent model preferences such as total flight time and flight count.
--
-- Behavior:
--   - In "inflight" mode:
--       - Initializes the timer start time if not already set.
--       - Updates the live session time and total lifetime.
--       - Persists the total flight time to model preferences.
--       - Increments and saves the flight count after 25 seconds of flight if not already counted.
--   - In other modes:
--       - Resets the live session time to the last session value.
--   - In "postflight" mode:
--       - Finalizes the flight segment if a flight was started.
--
-- Dependencies:
--   - Relies on `rfsuite.session` for session state.
--   - Uses `rfsuite.ini` for reading and writing model preferences.
--   - Calls `finalizeFlightSegment(now)` when appropriate.
function timer.wakeup()

    -- Yield if busy doing onConnect
    if rfsuite.tasks and rfsuite.tasks.onconnect and rfsuite.tasks.onconnect.active and rfsuite.tasks.onconnect.active() then
        return
    end

    local now = os.time()
    local timerSession = rfsuite.session.timer
    local prefs = rfsuite.session.modelPreferences
    local flightMode = rfsuite.flightmode.current

    lastFlightMode = flightMode

    if flightMode == "inflight" then
        if not timerSession.start then
            timerSession.start = now
        end

        local currentSegment = now - timerSession.start
        timerSession.live = (timerSession.session or 0) + currentSegment

        local computedLifetime = (timerSession.baseLifetime or 0) + currentSegment
        timerSession.lifetime = computedLifetime

        if timerSession.live >= 25 and not rfsuite.session.flightCounted then
            rfsuite.session.flightCounted = true

            if prefs and rfsuite.ini.section_exists(prefs, "general") then
                local count = rfsuite.ini.getvalue(prefs, "general", "flightcount") or 0
                rfsuite.ini.setvalue(prefs, "general", "flightcount", count + 1)
                rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, prefs)
            end
        end

    else
        timerSession.live = timerSession.session or 0
    end

    if flightMode == "postflight" and timerSession.start then
        finalizeFlightSegment(now)
    end
end

return timer

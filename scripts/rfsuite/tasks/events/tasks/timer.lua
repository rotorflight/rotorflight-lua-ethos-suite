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

--------------------------------------------------------------------------------
-- Resets flight mode tracking and timers on each “inflight” transition:
--   • Clears lastFlightMode
--   • Loads baseLifetime (= previous totalflighttime from INI)
--   • Initializes session (this flight’s time) to 0
--   • Sets lifetime = baseLifetime (for display), but we do NOT re-add every tick
--------------------------------------------------------------------------------
function timer.reset()
    rfsuite.utils.log("Resetting flight timers", "info")
    lastFlightMode = nil

    rfsuite.session.timer = {}
    rfsuite.session.flightCounted = false

    -- Load “baseLifetime” from INI (this is everything accumulated so far)
    rfsuite.session.timer.baseLifetime = tonumber(
        rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "totalflighttime")
    ) or 0

    -- This flight’s “session” starts at 0
    rfsuite.session.timer.session = 0

    -- For on-screen display, lifetime = baseLifetime (but we will not keep adding per tick)
    rfsuite.session.timer.lifetime = rfsuite.session.timer.baseLifetime
end

--------------------------------------------------------------------------------
-- Saves the current flight session and updated total to INI:
--   • Writes baseLifetime as “totalflighttime”
--   • Writes session as “lastflighttime”
--------------------------------------------------------------------------------
function timer.save()

    if not rfsuite.session.modelPreferencesFile then
        rfsuite.utils.log("No model preferences file set, cannot save flight timers", "info")
        return 
    end

    rfsuite.utils.log("Saving flight timers to INI: " .. rfsuite.session.modelPreferencesFile, "info")

    if rfsuite.session.modelPreferences and rfsuite.session.modelPreferencesFile then

        -- Save only the baseLifetime as “totalflighttime”
        rfsuite.ini.setvalue(
            rfsuite.session.modelPreferences,
            "general",
            "totalflighttime",
            rfsuite.session.timer.baseLifetime or 0
        )

        -- Save this flight’s duration as “lastflighttime”
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
end

--------------------------------------------------------------------------------
-- Wakeup handler (called periodically by the framework):
--   • Detects “inflight” / “postflight” transitions
--   • Computes live time for the current flight
--   • Updates computedLifetime = baseLifetime + currentSegment
--   • On landing, finalizes baseLifetime and writes to INI
--------------------------------------------------------------------------------
function timer.wakeup()
    local now = os.time()


    lastFlightMode = rfsuite.session.flightMode

    if rfsuite.session.flightMode == "inflight" then
        -- First tick in this arm segment: record start time
        if not rfsuite.session.timer.start then
            rfsuite.session.timer.start = now
        end

        -- Compute how many seconds we’ve been flying in this segment
        local currentSegment = now - rfsuite.session.timer.start

        -- “live” is session (previous flights in this power-cycle) + currentSegment
        rfsuite.session.timer.live = (rfsuite.session.timer.session or 0) + currentSegment

        -- computedLifetime = baseLifetime (all previous flights) + currentSegment
        local computedLifetime = (rfsuite.session.timer.baseLifetime or 0) + currentSegment
        rfsuite.session.timer.lifetime = computedLifetime

        -- Update INI so that if the app crashes mid-flight, we still have a rough total
        if rfsuite.session.modelPreferences then
            rfsuite.ini.setvalue(
                rfsuite.session.modelPreferences,
                "general",
                "totalflighttime",
                computedLifetime
            )
        end    

        -- Increment flight counter once when live >= 25s
        if rfsuite.session.timer.live >= 25 and not rfsuite.session.flightCounted then
            rfsuite.session.flightCounted = true
            if rfsuite.session.modelPreferences
               and rfsuite.ini.section_exists(rfsuite.session.modelPreferences, "general") then

                local currentValue = rfsuite.ini.getvalue(
                    rfsuite.session.modelPreferences,
                    "general",
                    "flightcount"
                ) or 0
                local newValue = currentValue + 1

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
        -- Not inflight: live time just equals whatever was in this session
        rfsuite.session.timer.live = rfsuite.session.timer.session or 0
    end

    -- Handle landing (“postflight”): finalize this segment once
    if rfsuite.session.flightMode == "postflight" then
        if rfsuite.session.timer.start then
            local segment = now - rfsuite.session.timer.start
            rfsuite.session.timer.session = (rfsuite.session.timer.session or 0) + segment
            rfsuite.session.timer.start = nil

            -- Ensure baseLifetime is loaded even if reset() was missed
            if rfsuite.session.timer.baseLifetime == nil then
                rfsuite.session.timer.baseLifetime = tonumber(
                    rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "totalflighttime")
                ) or 0
            end

            -- Add this segment once to baseLifetime
            rfsuite.session.timer.baseLifetime = rfsuite.session.timer.baseLifetime + segment

            -- Keep lifetime in sync (not strictly required; save() writes baseLifetime anyway)
            rfsuite.session.timer.lifetime = rfsuite.session.timer.baseLifetime

            timer.save()  -- Persist updated totals to INI
        end
    end
end

return timer

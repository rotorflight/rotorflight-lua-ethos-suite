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
-- Resets flight mode tracking and timers:
--   • Clears lastFlightMode flags
--   • Resets session timer fields (start, live, session)
--   • Loads persistent lifetime from ini (totalflighttime)
--------------------------------------------------------------------------------
function timer.reset()

    rfsuite.utils.log("Resetting flight timers", "info")

    lastFlightMode = nil


    rfsuite.session.timer = {}
    rfsuite.session.flightCounted = false

    -- Load total persistent lifetime from model preferences (INI)
    rfsuite.session.timer.lifetime = rfsuite.ini.getvalue(rfsuite.session.modelPreferences,
        "general",
        "totalflighttime"
    ) or 0

    -- Initialize session timer to zero for current power-on
    rfsuite.session.timer.session = 0
end

--------------------------------------------------------------------------------
-- Saves flight timers to INI on disconnect or shutdown:
--   • Updates totalflighttime = previous lifetime + this session's time
--   • Updates lastflighttime = this session's total time
--------------------------------------------------------------------------------
function timer.save()

    rfsuite.utils.log("Saving flight timers to INI: " ..  rfsuite.session.modelPreferencesFile, "info")


    rfsuite.ini.setvalue(
        rfsuite.session.modelPreferences,
        "general",
        "totalflighttime",
        rfsuite.session.timer.lifetime or 0
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

--------------------------------------------------------------------------------
-- Handles the wakeup logic for flight mode state transitions:
--   • Manages session timer: start time, live time, and accumulated session time
--   • Increments flight counter if live time ≥ 25 seconds and not already counted
--   • Logs mode transitions and updates model preferences as needed
--------------------------------------------------------------------------------
function timer.wakeup()
    local now = os.clock()

    -- Detect transition into 'inflight'
    if rfsuite.session.flightMode == "inflight" and lastFlightMode ~= "inflight" then
        timer.reset()
    end

    lastFlightMode = rfsuite.session.flightMode


    if rfsuite.session.flightMode == "inflight" then
        
        if not rfsuite.session.timer.start then
            -- First arm segment since power-on
            rfsuite.session.timer.start = now
        end

        -- Calculate live time: accumulated session + current segment
        local currentSegment = now - rfsuite.session.timer.start

        rfsuite.session.timer.live = (rfsuite.session.timer.session or 0) + currentSegment
        rfsuite.session.timer.lifetime = (rfsuite.session.timer.lifetime) or 0 + currentSegment

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
            end
        end
    else
        -- While not inflight, live time equals total session time
        rfsuite.session.timer.live = rfsuite.session.timer.session or 0    
    end


    if rfsuite.session.flightMode == "postflight" then
            -- Accumulate last armed segment into session time
            if rfsuite.session.timer.start then
                local segment = now - rfsuite.session.timer.start
                rfsuite.session.timer.session = (rfsuite.session.timer.session or 0) + segment
                rfsuite.session.timer.start = nil


                timer.save()  -- Save session time to INI

            end
    end

end



return timer

--[[

 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 * Some icons sourced from https://www.flaticon.com/

]]--
local arg = {...}
local config = arg[1]

local flightmode = {}
local lastFlightMode = nil
local hasBeenInFlight = false

function flightmode.reset()
    lastFlightMode = nil
    hasBeenInFlight = false
    rfsuite.session.timer = {}
    rfsuite.session.flightCounted = false
    -- Total persistent lifetime time (from ini)
    rfsuite.session.timer.lifetime = rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "totalflighttime") or 0
    -- Session time accumulates all arm segments this power-on
    rfsuite.session.timer.session = 0
end

function flightmode.wakeup()
    if not rfsuite.session.telemetryState then
        return
    end

    if rfsuite.session.onConnect.low then
        return
    end   

    local mode
    local now = os.clock()

    if rfsuite.utils.inFlight() then
        mode = "inflight"

        if rfsuite.session.timer.start == nil then
            -- First arm after power-on
            rfsuite.session.timer.start = now
        end

        -- Session: sum of all previous armed time + current segment so far
        local currentSegment = now - rfsuite.session.timer.start
        rfsuite.session.timer.live = (rfsuite.session.timer.session or 0) + currentSegment

        hasBeenInFlight = true

        -- Flight counter logic (using session time)
        if rfsuite.session.timer.live >= 25 and not rfsuite.session.flightCounted then
            rfsuite.session.flightCounted = true

            if rfsuite.session.modelPreferences and rfsuite.ini.section_exists(rfsuite.session.modelPreferences, "general") then
                local current_value = rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "flightcount")
                rfsuite.utils.log("Current flight count: " .. tostring(current_value), "info")

                local new_value = (current_value or 0) + 1
                rfsuite.utils.log("Incrementing flight counter: " .. new_value, "info")

                rfsuite.ini.setvalue(rfsuite.session.modelPreferences, "general", "flightcount", new_value)
                rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, rfsuite.session.modelPreferences)
            end
        end

    else
        if hasBeenInFlight then
            mode = "postflight"

            -- Accumulate this armed segment to session time
            if rfsuite.session.timer.start ~= nil then
                local segment = now - rfsuite.session.timer.start
                rfsuite.session.timer.session = (rfsuite.session.timer.session or 0) + segment
                rfsuite.session.timer.start = nil
            end
            -- Still stay in postflight mode until armed again or reset
        else
            mode = "preflight"
        end

        -- Show session total
        rfsuite.session.timer.live = rfsuite.session.timer.session
    end

    -- If model disconnects/powers down, add session to lifetime and reset session
    if lastFlightMode ~= mode then
        rfsuite.utils.log("Flight mode: " .. mode, "info")
        rfsuite.session.flightMode = mode
        lastFlightMode = mode
    end
end

-- Save to ini: call this at model disconnect/shutdown, or extend with a timer
function flightmode.save()
    local newLifetime = (rfsuite.session.timer.lifetime or 0) + (rfsuite.session.timer.session or 0)
    rfsuite.ini.setvalue(rfsuite.session.modelPreferences, "general", "totalflighttime", newLifetime)
    rfsuite.ini.setvalue(rfsuite.session.modelPreferences, "general", "lastflighttime", rfsuite.session.timer.session or 0)
    rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, rfsuite.session.modelPreferences)
end

return flightmode

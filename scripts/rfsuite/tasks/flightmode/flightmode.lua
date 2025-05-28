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
end

function flightmode.wakeup()

    if not rfsuite.session.telemetryState then
        return
    end

    local mode
    if rfsuite.utils.inFlight() then
        mode = "inflight"

        if rfsuite.session.timer.start == nil then
            rfsuite.utils.log("Starting inflight timer", "info")
            rfsuite.session.timer.start = os.clock()
        end

        -- Live running total while inflight
        local currentSegment = os.clock() - rfsuite.session.timer.start
        rfsuite.session.timer.live = (rfsuite.session.timer.accrued or 0) + currentSegment

        hasBeenInFlight  = true

        -- flight counter delay of 25 seconds before incrementing flight count
        local duration = os.clock() - rfsuite.session.timer.start
        if duration >= 25 and not rfsuite.session.flightCounted then
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
        if hasBeenInFlight  then
            mode = "postflight"

            -- Accumulate time once flight ends
            if rfsuite.session.timer.start ~= nil then
                local flightDuration = os.clock() - rfsuite.session.timer.start
                rfsuite.session.timer.accrued = (rfsuite.session.timer.accrued or 0) + flightDuration
                rfsuite.session.timer.start = nil
                rfsuite.utils.log("Accrued flight time: " .. rfsuite.session.timer.accrued, "info")

                -- Save the total flight time to model preferences
                local savedtime = rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "totalflighttime") or 0
                local totaltime = rfsuite.session.timer.accrued + savedtime

                rfsuite.ini.setvalue(rfsuite.session.modelPreferences, "general", "totalflighttime", totaltime)
                rfsuite.ini.setvalue(rfsuite.session.modelPreferences, "general", "lastflighttime", rfsuite.session.timer.accrued)
                rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, rfsuite.session.modelPreferences)
            end            

        else
            mode = "preflight"
        end

        -- While not inflight, live total is just the accumulated time
        rfsuite.session.timer.live = rfsuite.session.timer.total or 0
    end

    if lastFlightMode ~= mode then
        rfsuite.utils.log("Flight mode: " .. mode,"info")
        rfsuite.session.flightMode = mode
        lastFlightMode = mode
    end
end

return flightmode

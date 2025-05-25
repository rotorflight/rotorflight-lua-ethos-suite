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
end

function flightmode.wakeup()

    if not rfsuite.session.telemetryState then
        return
    end

    local mode
    if rfsuite.utils.inFlight() then
        mode = "inflight"
        hasBeenInFlight  = true
    else
        if hasBeenInFlight  then
            mode = "postflight"
        else
            mode = "preflight"
        end
    end

    if lastFlightMode ~= mode then
        rfsuite.utils.log("Flight mode: " .. mode,"info")
        rfsuite.session.flightMode = mode
        lastFlightMode = mode
        
        if mode == "inflight" then
            -- increment flight count
            if rfsuite.session.modelPreferences and rfsuite.ini.section_exists(rfsuite.session.modelPreferences, "general") then

                local current_value = rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "flightcount")
                rfsuite.utils.log("Current flight count: " .. tostring(current_value), "info")

                local new_value = (current_value or 0) + 1

                rfsuite.utils.log("Incrementing flight counter: " .. new_value, "info")

                rfsuite.ini.setvalue(rfsuite.session.modelPreferences, "general", "flightcount", new_value)

                rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, rfsuite.session.modelPreferences)

            end
        end

    end
end


return flightmode

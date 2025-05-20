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
    end
end


return flightmode

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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local arg = { ... }
local config = arg[1]
local timer = {}

local triggered = false
local lastBeepTime = nil

function timer.wakeup()
    local session = rfsuite.session
    local modelFlightTime = session and session.modelFlightTime
    local batteryConfig = session and session.batteryConfig
    local targetSeconds = batteryConfig and batteryConfig.modelFlightTime or 0

    -- Only trigger if the feature is configured and flight time is available
    if not targetSeconds or targetSeconds == 0 or not modelFlightTime or modelFlightTime == 0 then
        triggered = false
        lastBeepTime = nil
        return
    end

    -- Only trigger if we are armed / inflight
    if rfsuite.flightmode.current ~= "inflight" then
        triggered = false
        lastBeepTime = nil
        return
    end

    -- If flight time exceeds or equals the target, handle beeping
    if modelFlightTime >= targetSeconds then
        local now = rfsuite.clock
        if not triggered then
            rfsuite.utils.playFileCommon("beep.wav")
            triggered = true
            lastBeepTime = now
        elseif lastBeepTime and (now - lastBeepTime) >= 10 then
            rfsuite.utils.playFileCommon("beep.wav")
            lastBeepTime = now
        end
    else
        triggered = false
        lastBeepTime = nil
    end
end

function timer.reset()
    triggered = false
    lastBeepTime = nil
end

return timer

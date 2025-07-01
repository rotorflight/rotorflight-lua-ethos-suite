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
--[[ 
 * Copyright (C) Rotorflight Project
 * Timer event logic using configurable alerting.
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
]]--

local timer = {}

local triggered = false
local lastBeepTime = nil
local preLastBeepTime = nil
local postStartedAt = nil

function timer.wakeup()
    local prefs = rfsuite.preferences.timer or {}
    local session = rfsuite.session
    local modelFlightTime = session and session.modelFlightTime
    local batteryConfig = session and session.batteryConfig
    local targetSeconds = batteryConfig and batteryConfig.modelFlightTime or 0

    if not prefs.timeraudioenable then
        triggered = false
        lastBeepTime = nil
        preLastBeepTime = nil
        postStartedAt = nil
        return
    end

    if not targetSeconds or targetSeconds == 0 or not modelFlightTime or modelFlightTime == 0 then
        triggered = false
        lastBeepTime = nil
        preLastBeepTime = nil
        postStartedAt = nil
        return
    end

    if rfsuite.flightmode.current ~= "inflight" then
        triggered = false
        lastBeepTime = nil
        preLastBeepTime = nil
        postStartedAt = nil
        return
    end

    local now = rfsuite.clock
    local elapsedMode = prefs.elapsedalertmode or 0

    -- PRE-TIMER ALERT LOGIC
    if prefs.prealerton then
        local prePeriod = prefs.prealertperiod or 30
        local preInterval = prefs.prealertinterval or 10
        local preAlertStart = targetSeconds - prePeriod
        if modelFlightTime >= preAlertStart and modelFlightTime < targetSeconds then
            local sincePreAlert = modelFlightTime - preAlertStart
            if (sincePreAlert % preInterval) < 0.5 then
                if not preLastBeepTime or (now - preLastBeepTime) >= preInterval - 1 then
                    rfsuite.utils.playFileCommon("beep.wav")
                    preLastBeepTime = now
                end
            end
            triggered = false
            lastBeepTime = nil
            postStartedAt = nil
            return
        else
            preLastBeepTime = nil
        end
    else
        preLastBeepTime = nil
    end

    -- TIMER ELAPSED LOGIC
    if modelFlightTime >= targetSeconds then
        if not triggered then
            if elapsedMode == 0 then
                rfsuite.utils.playFileCommon("beep.wav")
            elseif elapsedMode == 1 then
                rfsuite.utils.playFileCommon("multibeep.wav")
            elseif elapsedMode == 2 then
                rfsuite.utils.playFile("events", "alerts/timerelapsed.wav")
            elseif elapsedMode == 3 then
                rfsuite.utils.playFile("status", "alerts/timer.wav")
                system.playNumber(targetSeconds, UNIT_SECOND)
            end
            triggered = true
            lastBeepTime = now
            postStartedAt = now
        end

        -- POST-TIMER ALERT LOGIC
        if prefs.postalerton then
            local postPeriod = prefs.postalertperiod or 60
            local postInterval = prefs.postalertinterval or 10
            local sincePostStart = (now - (postStartedAt or now))
            if sincePostStart < postPeriod then
                if not lastBeepTime or (now - lastBeepTime) >= postInterval then
                    rfsuite.utils.playFileCommon("beep.wav")
                    lastBeepTime = now
                end
            end
        end
    else
        triggered = false
        lastBeepTime = nil
        postStartedAt = nil
    end
end

function timer.reset()
    triggered = false
    lastBeepTime = nil
    preLastBeepTime = nil
    postStartedAt = nil
end

return timer

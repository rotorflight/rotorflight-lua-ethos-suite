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

local timer = {}

local triggered = false
local lastBeepTime = nil
local preLastBeepTime = nil
local postStartedAt = nil
local inflightStartTime = nil

function timer.wakeup()
    local prefs = rfsuite.preferences.timer or {}
    local session = rfsuite.session
    local targetSeconds = session and session.modelFlightTime or 0
    local now = rfsuite.clock

    -- Only set inflightStartTime if it has never been set and we enter inflight
    if rfsuite.flightmode.current == "inflight" and not inflightStartTime then
        inflightStartTime = now
    end

    if not prefs.timeraudioenable
        or not targetSeconds or targetSeconds == 0
        or not session then
        triggered = false
        lastBeepTime = nil
        preLastBeepTime = nil
        postStartedAt = nil
        inflightStartTime = nil
        return
    end

    if not inflightStartTime then
        return
    end

    local elapsed = now - inflightStartTime
    local elapsedMode = prefs.elapsedalertmode or 0

    -- PRE-TIMER ALERT LOGIC
    if prefs.prealerton then
        local prePeriod = prefs.prealertperiod or 30
        local preInterval = prefs.prealertinterval or 10
        local preAlertStart = targetSeconds - prePeriod
        if elapsed >= preAlertStart and elapsed < targetSeconds then
            if not preLastBeepTime or (now - preLastBeepTime) >= preInterval then
                rfsuite.utils.playFileCommon("beep.wav")
                preLastBeepTime = now
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
    if elapsed >= targetSeconds then
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
    inflightStartTime = nil
end

return timer

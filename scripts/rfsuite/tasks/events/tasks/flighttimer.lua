--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local timer = {}

local triggered = false
local lastBeepTimer = nil
local preLastBeepTimer = nil
local postStartedAt = nil

function timer.wakeup()
    local prefs = rfsuite.preferences.timer or {}
    local session = rfsuite.session
    local targetSeconds = session and session.modelPreferences and session.modelPreferences.battery.flighttime or 0

    local timerSession = session and session.timer
    local elapsed = (timerSession and timerSession.live) or 0
    local elapsedMode = prefs.elapsedalertmode or 0

    if not prefs.timeraudioenable or not targetSeconds or targetSeconds == 0 or not session then
        triggered = false
        lastBeepTimer = nil
        preLastBeepTimer = nil
        postStartedAt = nil
        return
    end

    if rfsuite.flightmode.current ~= "inflight" then
        preLastBeepTimer = nil
        lastBeepTimer = nil
        postStartedAt = nil
        return
    end

    if prefs.prealerton then
        local prePeriod = prefs.prealertperiod or 30
        local preInterval = prefs.prealertinterval or 10
        local preAlertStart = targetSeconds - prePeriod
        if elapsed >= preAlertStart and elapsed < targetSeconds then
            if not preLastBeepTimer or (elapsed - preLastBeepTimer) >= preInterval then
                rfsuite.utils.playFileCommon("beep.wav")
                preLastBeepTimer = elapsed
            end
            triggered = false
            lastBeepTimer = nil
            postStartedAt = nil
            return
        else
            if preLastBeepTimer ~= nil then preLastBeepTimer = elapsed end
        end
    else
        preLastBeepTimer = nil
    end

    if elapsed >= targetSeconds then
        if not triggered then
            if elapsedMode == 0 then
                rfsuite.utils.playFileCommon("beep.wav")
            elseif elapsedMode == 1 then
                rfsuite.utils.playFileCommon("multibeep.wav")
            elseif elapsedMode == 2 then
                rfsuite.utils.playFile("events", "alerts/elapsed.wav")
            elseif elapsedMode == 3 then
                rfsuite.utils.playFile("status", "alerts/timer.wav")
                system.playNumber(targetSeconds, UNIT_SECOND)
            end
            triggered = true
            lastBeepTimer = elapsed
            postStartedAt = elapsed
        end

        if prefs.postalerton then
            local postPeriod = prefs.postalertperiod or 60
            local postInterval = prefs.postalertinterval or 10
            if elapsed < (targetSeconds + postPeriod) then
                if not lastBeepTimer or (elapsed - lastBeepTimer) >= postInterval then
                    rfsuite.utils.playFileCommon("beep.wav")
                    lastBeepTimer = elapsed
                end
            else
                if lastBeepTimer ~= nil then lastBeepTimer = elapsed end
            end
        end
    else
        triggered = false
        lastBeepTimer = nil
        postStartedAt = nil
    end
end

function timer.reset()
    triggered = false
    lastBeepTimer = nil
    preLastBeepTimer = nil
    postStartedAt = nil
end

return timer

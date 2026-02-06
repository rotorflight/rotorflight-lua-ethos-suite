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

local utils = rfsuite.utils
local system_playNumber = system.playNumber

function timer.wakeup()
    local prefs = rfsuite.preferences.timer or {}
    
    if not prefs.timeraudioenable then
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

    local session = rfsuite.session
    local modelPrefs = session and session.modelPreferences
    local targetSeconds = (modelPrefs and modelPrefs.battery and modelPrefs.battery.flighttime) or 0

    if targetSeconds == 0 then
        triggered = false
        lastBeepTimer = nil
        preLastBeepTimer = nil
        postStartedAt = nil
        return
    end

    local timerSession = session.timer
    local elapsed = (timerSession and timerSession.live) or 0
    local elapsedMode = prefs.elapsedalertmode or 0

    if prefs.prealerton then
        local prePeriod = prefs.prealertperiod or 30
        local preAlertStart = targetSeconds - prePeriod
        
        if elapsed >= preAlertStart and elapsed < targetSeconds then
            local preInterval = prefs.prealertinterval or 10
            if not preLastBeepTimer or (elapsed - preLastBeepTimer) >= preInterval then
                utils.playFileCommon("beep.wav")
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
                utils.playFileCommon("beep.wav")
            elseif elapsedMode == 1 then
                utils.playFileCommon("multibeep.wav")
            elseif elapsedMode == 2 then
                utils.playFile("events", "alerts/elapsed.wav")
            elseif elapsedMode == 3 then
                utils.playFile("status", "alerts/timer.wav")
                system_playNumber(targetSeconds, UNIT_SECOND)
            end
            triggered = true
            lastBeepTimer = elapsed
            postStartedAt = elapsed
        end

        if prefs.postalerton then
            local postPeriod = prefs.postalertperiod or 60
            if elapsed < (targetSeconds + postPeriod) then
                local postInterval = prefs.postalertinterval or 10
                if not lastBeepTimer or (elapsed - lastBeepTimer) >= postInterval then
                    utils.playFileCommon("beep.wav")
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

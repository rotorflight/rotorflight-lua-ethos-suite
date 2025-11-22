--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local timer = {}
local lastFlightMode = nil

function timer.reset()

    lastFlightMode = nil

    local timerSession = {}
    rfsuite.session.timer = timerSession
    rfsuite.session.flightCounted = false

    timerSession.baseLifetime = tonumber(rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "totalflighttime")) or 0

    timerSession.session = 0
    timerSession.lifetime = timerSession.baseLifetime
    timerSession.live = 0
    timerSession.start = nil
end

function timer.save()
    local prefs = rfsuite.session.modelPreferences
    local prefsFile = rfsuite.session.modelPreferencesFile

    if not prefsFile then
        rfsuite.utils.log("No model preferences file set, cannot save flight timers", "info")
        return
    end

    rfsuite.utils.log("Saving flight timers to INI: " .. prefsFile, "info")

    if prefs then
        rfsuite.ini.setvalue(prefs, "general", "totalflighttime", rfsuite.session.timer.baseLifetime or 0)
        rfsuite.ini.setvalue(prefs, "general", "lastflighttime", rfsuite.session.timer.session or 0)
        rfsuite.ini.save_ini_file(prefsFile, prefs)
    end
end

local function finalizeFlightSegment(now)
    local timerSession = rfsuite.session.timer
    local prefs = rfsuite.session.modelPreferences

    local segment = now - timerSession.start
    timerSession.session = (timerSession.session or 0) + segment
    timerSession.start = nil

    if timerSession.baseLifetime == nil then timerSession.baseLifetime = tonumber(rfsuite.ini.getvalue(prefs, "general", "totalflighttime")) or 0 end

    timerSession.baseLifetime = timerSession.baseLifetime + segment
    timerSession.lifetime = timerSession.baseLifetime

    if prefs then rfsuite.ini.setvalue(prefs, "general", "totalflighttime", timerSession.baseLifetime) end
    timer.save()
end

function timer.wakeup()

    if rfsuite.tasks and rfsuite.tasks.onconnect and rfsuite.tasks.onconnect.active and rfsuite.tasks.onconnect.active() then return end

    local now = os.time()
    local timerSession = rfsuite.session.timer
    local prefs = rfsuite.session.modelPreferences
    local flightMode = rfsuite.flightmode.current

    lastFlightMode = flightMode

    if flightMode == "inflight" then
        if not timerSession.start then timerSession.start = now end

        local currentSegment = now - timerSession.start
        timerSession.live = (timerSession.session or 0) + currentSegment

        local computedLifetime = (timerSession.baseLifetime or 0) + currentSegment
        timerSession.lifetime = computedLifetime

        if timerSession.live >= 25 and not rfsuite.session.flightCounted then
            rfsuite.session.flightCounted = true

            if prefs and rfsuite.ini.section_exists(prefs, "general") then
                local count = rfsuite.ini.getvalue(prefs, "general", "flightcount") or 0
                rfsuite.ini.setvalue(prefs, "general", "flightcount", count + 1)
                rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, prefs)
            end
        end

    else
        timerSession.live = timerSession.session or 0
    end

    if flightMode == "postflight" and timerSession.start then finalizeFlightSegment(now) end
end

return timer

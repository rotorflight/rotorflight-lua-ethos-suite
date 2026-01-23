--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local timer = {}
local lastFlightMode = nil


local READ_DATA = {}

local pendingStatsSyncAt = nil
local pendingStatsSync   = false

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = v end
    return dst
end

local function saveToEeprom()
    local mspEepromWrite = {
        command = 250, 
        simulatorResponse = {}, 
        processReply = function() rfsuite.utils.log("EEPROM write command sent","info") end
    }
    rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)
end

local function writeStats()
    -- call is not present in older firmwares
    if not rfsuite.utils.apiVersionCompare(">=", "12.09") then return end

    local function toNumber(v, dflt)
        local n = tonumber(v)
        if n == nil then return dflt end
        return n
    end

    local prefs = rfsuite.session.modelPreferences
    if not prefs then return end

    local totalflighttime = toNumber(rfsuite.ini.getvalue(prefs, "general", "totalflighttime"), 0)
    local flightcount     = toNumber(rfsuite.ini.getvalue(prefs, "general", "flightcount"), 0)

    local API = rfsuite.tasks.msp.api.load("FLIGHT_STATS")
    API.setRebuildOnWrite(true)

    -- Seed ALL remote values first (prevents clobbering fields we don't touch)
    for k, v in pairs(READ_DATA or {}) do
        API.setValue(k, v)
    end

    -- Override the fields we actually own
    API.setValue("totalflighttime", totalflighttime)
    API.setValue("flightcount", flightcount)

    rfsuite.utils.log("Totalflight: " .. totalflighttime, "info")
    rfsuite.utils.log("Flightcount: " .. flightcount, "info")

    API.setCompleteHandler(function()
        rfsuite.utils.log("Synchronized flight stats to FBL", "info")
        saveToEeprom()
    end)

    API.write()
end


local function syncStatsToFBL()
    -- call is not present in older firmwares
    if not rfsuite.utils.apiVersionCompare(">=", "12.09") then return end

    local API = rfsuite.tasks.msp.api.load("FLIGHT_STATS")
    API.setCompleteHandler(function()
        -- snapshot remote
        local d = API.data()
        READ_DATA = copyTable(d.parsed)

        -- update values
        writeStats()
    end)
    API.read()

end

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

    -- defer FBL sync by 1 seconds to avoid clash with FC internal writes
    pendingStatsSync   = true
    pendingStatsSyncAt = os.time() + 1

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

    -- delayed sync with run only when disarmed
    -- doing when armed risks corrupting ongoing flight data
    if not rfsuite.session.isArmed then
        if pendingStatsSync and pendingStatsSyncAt and now >= pendingStatsSyncAt then
            -- must be connected and not mid-onconnect
            if rfsuite.session and rfsuite.session.isConnected then
                if not (rfsuite.tasks
                    and rfsuite.tasks.onconnect
                    and rfsuite.tasks.onconnect.active
                    and rfsuite.tasks.onconnect.active()) then

                    pendingStatsSync   = false
                    pendingStatsSyncAt = nil

                    rfsuite.utils.log("Starting delayed FLIGHT_STATS sync", "info")
                    syncStatsToFBL()
                end
            end
        end
    end    


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

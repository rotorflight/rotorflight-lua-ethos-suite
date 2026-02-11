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

local os_time = os.time
local utils = rfsuite.utils
local ini = rfsuite.ini

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = v end
    return dst
end

local function saveToEeprom()
    local mspEepromWrite = {
        command = 250, 
        uuid = "eeprom.syncstats.timer",
        simulatorResponse = {}, 
        processReply = function() utils.log("EEPROM write command sent","info") end
    }
    local ok, reason = rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)
    if not ok then
        utils.log("EEPROM enqueue rejected (" .. tostring(reason) .. ")", "info")
    end
end

local function writeStats()
    -- call is not present in older firmwares
    if not utils.apiVersionCompare(">=", "12.09") then return end

    local function toNumber(v, dflt)
        local n = tonumber(v)
        if n == nil then return dflt end
        return n
    end

    local prefs = rfsuite.session.modelPreferences
    if not prefs then return end

    local totalflighttime = toNumber(ini.getvalue(prefs, "general", "totalflighttime"), 0)
    local flightcount     = toNumber(ini.getvalue(prefs, "general", "flightcount"), 0)

    local API = rfsuite.tasks.msp.api.load("FLIGHT_STATS")
    API.setRebuildOnWrite(true)

    -- Seed ALL remote values first (prevents clobbering fields we don't touch)
    for k, v in pairs(READ_DATA or {}) do
        API.setValue(k, v)
    end

    -- Override the fields we actually own
    API.setValue("totalflighttime", totalflighttime)
    API.setValue("flightcount", flightcount)

    utils.log("Totalflight: " .. totalflighttime, "info")
    utils.log("Flightcount: " .. flightcount, "info")

    API.setCompleteHandler(function()
        utils.log("Synchronized flight stats to FBL", "info")
        saveToEeprom()
    end)

    API.write()
end


local function syncStatsToFBL()
    -- call is not present in older firmwares
    if not utils.apiVersionCompare(">=", "12.09") then return end

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
    local prefs = rfsuite.session.modelPreferences

    timerSession.baseLifetime = (prefs and tonumber(ini.getvalue(prefs, "general", "totalflighttime"))) or 0
    
    timerSession.session = 0
    timerSession.lifetime = timerSession.baseLifetime
    timerSession.live = 0
    timerSession.start = nil
end

function timer.save()
    local session = rfsuite.session
    local prefs = session.modelPreferences
    local prefsFile = session.modelPreferencesFile

    if not prefsFile then
        utils.log("No model preferences file set, cannot save flight timers", "info")
        return
    end

    utils.log("Saving flight timers to INI: " .. prefsFile, "info")

    if prefs then
        ini.setvalue(prefs, "general", "totalflighttime", rfsuite.session.timer.baseLifetime or 0)
        ini.setvalue(prefs, "general", "lastflighttime", rfsuite.session.timer.session or 0)
        ini.save_ini_file(prefsFile, prefs)
    end

    -- defer FBL sync by 1 seconds to avoid clash with FC internal writes
    pendingStatsSync   = true
    pendingStatsSyncAt = os_time() + 1

end

local function finalizeFlightSegment(now)
    local timerSession = rfsuite.session.timer
    local prefs = rfsuite.session.modelPreferences

    local segment = now - timerSession.start
    timerSession.session = (timerSession.session or 0) + segment
    timerSession.start = nil

    if timerSession.baseLifetime == nil then timerSession.baseLifetime = tonumber(ini.getvalue(prefs, "general", "totalflighttime")) or 0 end

    timerSession.baseLifetime = timerSession.baseLifetime + segment
    timerSession.lifetime = timerSession.baseLifetime

    if prefs then ini.setvalue(prefs, "general", "totalflighttime", timerSession.baseLifetime) end
    timer.save()
end

function timer.wakeup()
    local tasks = rfsuite.tasks
    if tasks and tasks.onconnect and tasks.onconnect.active and tasks.onconnect.active() then return end

    local now = os_time()
    local session = rfsuite.session
    local timerSession = session.timer
    local prefs = session.modelPreferences
    local flightMode = rfsuite.flightmode.current

    lastFlightMode = flightMode

    -- delayed sync with run only when disarmed
    -- doing when armed risks corrupting ongoing flight data
    if not session.isArmed then
        if pendingStatsSync and pendingStatsSyncAt and now >= pendingStatsSyncAt then
            -- must be connected and not mid-onconnect
            if session.isConnected then
                pendingStatsSync   = false
                pendingStatsSyncAt = nil

                utils.log("Starting delayed FLIGHT_STATS sync", "info")
                syncStatsToFBL()
            end
        end
    end    


    if flightMode == "inflight" then
        if not timerSession.start then timerSession.start = now end

        local currentSegment = now - timerSession.start
        timerSession.live = (timerSession.session or 0) + currentSegment

        local computedLifetime = (timerSession.baseLifetime or 0) + currentSegment
        timerSession.lifetime = computedLifetime

        if timerSession.live >= 25 and not session.flightCounted then
            session.flightCounted = true

            if prefs and ini.section_exists(prefs, "general") then
                local count = ini.getvalue(prefs, "general", "flightcount") or 0
                ini.setvalue(prefs, "general", "flightcount", count + 1)
                ini.save_ini_file(session.modelPreferencesFile, prefs)
            end
        end

    else
        timerSession.live = timerSession.session or 0
    end

    if flightMode == "postflight" and timerSession.start then finalizeFlightSegment(now) end
end

return timer

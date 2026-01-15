--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local sync = {}

local mspCallMade = false
local complete = false

-- Which API + fields are being synced
-- Each entry:
--   apiField: field name on FC side
--   iniSection/iniKey: where it lives locally
--   default: fallback if missing
local CFG = {
    apiName = "FLIGHT_STATS",

    fields = {
        { apiField = "flightcount",     iniSection = "general", iniKey = "flightcount",     default = 0 },
        { apiField = "totalflighttime", iniSection = "general", iniKey = "totalflighttime", default = 0 },
    }
}

local function toNumber(v, dflt)
    local n = tonumber(v)
    if n == nil then return dflt end
    return n
end

local function readLocal(prefs, section, key, dflt)
    if not prefs then return dflt end
    return toNumber(rfsuite.ini.getvalue(prefs, section, key), dflt)
end

local function writeLocal(prefs, section, key, value)
    if not prefs then return end
    rfsuite.ini.setvalue(prefs, section, key, value)
end

local function saveLocalIfPossible()
    local prefsFile = rfsuite.session.modelPreferencesFile
    local prefs = rfsuite.session.modelPreferences
    if prefsFile and prefs then
        rfsuite.ini.save_ini_file(prefsFile, prefs)
    end
end

local function logDecision(name, localV, remoteV, winV)
    -- keep it similar to your other onconnect tasks: log to info + connect
    local msg = string.format("%s sync: local=%s remote=%s -> %s",
        name, tostring(localV), tostring(remoteV), tostring(winV))
    rfsuite.utils.log(msg, "info")
    rfsuite.utils.log(msg, "connect")
end

local function applyWinnerToBoth(API, prefs)
    local wroteRemote = false
    local wroteLocal = false

    for _, f in ipairs(CFG.fields) do
        local localV  = readLocal(prefs, f.iniSection, f.iniKey, f.default)
        local remoteV = toNumber(API.readValue(f.apiField), f.default)

        local winV = localV
        if remoteV > winV then winV = remoteV end

        logDecision(f.apiField, localV, remoteV, winV)

        -- If local loses, update INI
        if localV ~= winV then
            writeLocal(prefs, f.iniSection, f.iniKey, winV)
            wroteLocal = true
        end

        -- If remote loses, update FC side
        if remoteV ~= winV then
            API.setValue(f.apiField, winV)
            wroteRemote = true
        end
    end

    if wroteLocal then
        saveLocalIfPossible()
        rfsuite.utils.log("Local INI updated (winner values)", "info")
        rfsuite.utils.log("Local INI updated (winner values)", "connect")
    end

    if wroteRemote then
        -- mirror timer.lua style: rebuild on write helps avoid partial state issues
        -- (you already use this pattern when syncing FLIGHT_STATS) :contentReference[oaicite:4]{index=4}
        API.setRebuildOnWrite(true)
        API.setCompleteHandler(function()
            rfsuite.utils.log("Remote FC updated (winner values)", "info")
            rfsuite.utils.log("Remote FC updated (winner values)", "connect")
            complete = true
        end)
        API.write()
    else
        -- nothing to write remotely; we’re done
        complete = true
    end
end

function sync.wakeup()
    if complete then return end

    -- onconnect pattern: wait for API version, avoid MSP while busy :contentReference[oaicite:5]{index=5} :contentReference[oaicite:6]{index=6}
    if rfsuite.session.apiVersion == nil then return end
    if rfsuite.session.mspBusy then return end

    -- Optional: gate by minimum firmware/API if this endpoint doesn’t exist on older FW
    -- (timer.lua checks >= 12.09 before using FLIGHT_STATS) :contentReference[oaicite:7]{index=7}
    if not rfsuite.utils.apiVersionCompare(">=", "12.09") then
        complete = true
        return
    end

    if mspCallMade then return end
    mspCallMade = true

    local prefs = rfsuite.session.modelPreferences

    local API = rfsuite.tasks.msp.api.load(CFG.apiName)
    API.setUUID("6a0a2f27-3ef6-4f2d-9dcf-8a1f4c4a6e88") -- change if you want a new UUID
    API.setCompleteHandler(function(self, buf)
        applyWinnerToBoth(API, prefs)
    end)
    API.read()
end

function sync.reset()
    mspCallMade = false
    complete = false
end

function sync.isComplete()
    return complete
end

return sync

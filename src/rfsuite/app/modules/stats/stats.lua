--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apidata = {
  api = {
    [1] = "FLIGHT_STATS_INI"
  },
  formdata = {
    labels = {},
    fields = {
      { t = "@i18n(app.modules.stats.totalflighttime)@", mspapi = 1, apikey = "totalflighttime" },
      { t = "@i18n(app.modules.stats.flightcount)@", mspapi = 1, apikey = "flightcount" }
    }
  }
}


local function postSave(s)
    -- s is provided by the save pipeline; be defensive and fall back to rfsuite.session
    local session = (s and s.session) or rfsuite.session
    if not session or not session.isConnected then return end
    if session.mspBusy then return end
    if session.apiVersion == nil then return end

    -- If your project gates FLIGHT_STATS by API version (as per timer.lua pattern),
    -- keep it here too so older FW doesn't error.
    if rfsuite.utils and rfsuite.utils.apiVersionCompare then
        if not rfsuite.utils.apiVersionCompare(">=", "12.09") then
            return
        end
    end

    local prefs = session.modelPreferences
    if not prefs then return end

    local function toNumber(v, dflt)
        local n = tonumber(v)
        if n == nil then return dflt end
        return n
    end

    -- Post-save: INI now contains the final values we want to push to FC
    local totalflighttime = toNumber(rfsuite.ini.getvalue(prefs, "general", "totalflighttime"), 0)
    local flightcount     = toNumber(rfsuite.ini.getvalue(prefs, "general", "flightcount"), 0)

    local API = rfsuite.tasks.msp.api.load("FLIGHT_STATS")
    API.setUUID("stats-postsave-sync")

    -- Mirror your usual write behaviour for stats (helps ensure remote cache refresh)
    API.setRebuildOnWrite(true)

    API.setValue("totalflighttime", totalflighttime)
    API.setValue("flightcount", flightcount)

    API.setCompleteHandler(function()
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log(
                string.format("PostSave: pushed stats to FC (time=%d count=%d)", totalflighttime, flightcount),
                "info"
            )
            rfsuite.utils.log("PostSave: remote flight stats updated", "connect")
        end
    end)

    API.write()
end


return {apidata = apidata, eepromWrite = false, reboot = false, API = {}, postSave = postSave}

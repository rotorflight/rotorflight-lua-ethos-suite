--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local enableWakeup = false
local syncStatsToFBLStart = false

local FBL_STATS = {} -- holder for fbl stats to sync

local apidata = {
  api = {
    [1] = "FLIGHT_STATS_INI"
  },
  formdata = {
    labels = {},
    fields = {
      { t = "@i18n(app.modules.stats.flightcount)@", mspapi = 1, apikey = "flightcount" } ,       
      { t = "@i18n(app.modules.stats.totalflighttime)@", mspapi = 1, apikey = "totalflighttime" }
    }
  }
}

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


local function postSave()


    -- merge old data sync with new deferred timer-based sync
    local prefs = rfsuite.session.modelPreferences
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
        API.setRebuildOnWrite(true)

        for i,v in pairs(FBL_STATS) do
            rfsuite.utils.log("Pre-Sync FBL_STATS: " .. i .. "=" .. tostring(v), "info")
            API.setValue(i, v)
        end

        API.setValue("totalflighttime", totalflighttime)
        API.setValue("flightcount", flightcount)

        API.setCompleteHandler(function()
                rfsuite.utils.log(
                    string.format("PostSave: pushed stats to FC (time=%d count=%d)", totalflighttime, flightcount),
                    "info"
                )
                rfsuite.utils.log("PostSave: remote flight stats updated", "connect")
                saveToEeprom()
        end)
        API.write()

end

local function postLoad(self)
    enableWakeup = true
    if rfsuite.utils.apiVersionCompare(">=", "12.09") then
        --  load updated stats from FC after load
            local API = rfsuite.tasks.msp.api.load("FLIGHT_STATS")
            API.setUUID("7a0a2f27-3ef6-4f2d-9dcf-8a1f4c4a6e88") 
            API.setCompleteHandler(function(self, buf)
                FBL_STATS = copyTable(API.data().parsed) 

                for i,v in pairs(FBL_STATS) do
                    rfsuite.utils.log("Loaded FBL_STATS: " .. i .. "=" .. tostring(v), "info")
                end

                rfsuite.utils.log("Loaded flight stats from FC after load", "info")
                rfsuite.app.triggers.closeProgressLoader = true
            end)
            API.read()
    else
        -- close loader if on older firmware where stats sync is not available
         rfsuite.app.triggers.closeProgressLoader = true
    end
end

local function wakeup()
    if not enableWakeup then return end
end

return {apidata = apidata, eepromWrite = false, reboot = false, API = {}, postSave = postSave, wakeup = wakeup, postLoad = postLoad}

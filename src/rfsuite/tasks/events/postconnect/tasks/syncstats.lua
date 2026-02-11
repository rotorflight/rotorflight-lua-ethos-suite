--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local sync = {}

local fetchData = false
local saveData  = false
local isComplete = false

local FBL_STATS = {} -- holder for fbl stats to sync
local LOCAL_STATS = {} -- holder for local stats to sync

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = v end
    return dst
end

local function saveToEeprom()
    local mspEepromWrite = {
        command = 250, 
        uuid = "eeprom.syncstats.postconnect",
        simulatorResponse = {}, 
        processReply = function() rfsuite.utils.log("EEPROM write command sent","info") end
    }
    local ok, reason = rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)
    if not ok then
        rfsuite.utils.log("EEPROM enqueue rejected (" .. tostring(reason) .. ")", "info")
    end
end

local function toNumber(v, dflt)
    local n = tonumber(v)
    if n == nil then return dflt end
    return n
end

function sync.wakeup()

    -- no api version info yet
    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.session.mspBusy then return end

    if rfsuite.session.mcu_id == nil then
        -- we need MCU ID first
        return
    end

    local prefs = rfsuite.session.modelPreferences
    if not prefs then return end

    -- we dont support this feature on older firmwares
    if rfsuite.utils.apiVersionCompare("<", "12.09") then
        isComplete = true
        return
    end


    -- fetch data from FC
    if fetchData == false then

        rfsuite.utils.log("Loading flight stats from RADIO before load", "info")
        LOCAL_STATS['totalflighttime'] = toNumber(rfsuite.ini.getvalue(prefs, "general", "totalflighttime"), 0)
        LOCAL_STATS['flightcount']     = toNumber(rfsuite.ini.getvalue(prefs, "general", "flightcount"), 0)

        local API = rfsuite.tasks.msp.api.load("FLIGHT_STATS")
        API.setUUID("7a5a2f27-2ef6-4f2d-9ecf-8a1f4c4a6e28") 
        API.setCompleteHandler(function(self, buf)
            FBL_STATS = copyTable(API.data().parsed) 

            rfsuite.utils.log("Loaded flight stats from FBL", "info")

            -- let's proceed to save
            saveData = true
        end)
        API.read()
    
        fetchData = true
    end

    if saveData == true then
    
        -- compare and decide which way we should sync
        local totalflighttimeRemote = toNumber(FBL_STATS['totalflighttime'], 0)
        local flightcountRemote     = toNumber(FBL_STATS['flightcount'], 0)

        local totalflighttimeLocal = LOCAL_STATS['totalflighttime']
        local flightcountLocal     = LOCAL_STATS['flightcount']

        rfsuite.utils.log("Total flight time - Remote: " .. tostring(totalflighttimeRemote) .. ", Local: " .. tostring(totalflighttimeLocal), "info")
        rfsuite.utils.log("Flight count - Remote: " .. tostring(flightcountRemote) .. ", Local: " .. tostring(flightcountLocal), "info")

        if totalflighttimeRemote > totalflighttimeLocal or flightcountRemote > flightcountLocal then
            -- remote is higher, update local
            rfsuite.ini.setvalue(prefs, "general", "totalflighttime", tostring(totalflighttimeRemote))
            rfsuite.ini.setvalue(prefs, "general", "flightcount", tostring(flightcountRemote))
            rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, prefs)

            rfsuite.utils.log("Updated radio flight stats from FBL", "info")
            rfsuite.utils.log("Updated radio flight stats from FBL", "console")

            isComplete = true

        elseif totalflighttimeRemote < totalflighttimeLocal or flightcountRemote < flightcountLocal then
            -- local is higher, update remote
            local API = rfsuite.tasks.msp.api.load("FLIGHT_STATS")
            API.setRebuildOnWrite(true)
            API.setUUID("7a5a2f27-2ef6-4f2d-7egf-8a1f4c4a6e28") 

            for i,v in pairs(FBL_STATS) do
                API.setValue(i, v)
            end

            API.setValue("totalflighttime", totalflighttimeLocal)
            API.setValue("flightcount", flightcountLocal)

            API.setCompleteHandler(function()
                rfsuite.utils.log("Updated FBL flight stats from radio", "info")
                rfsuite.utils.log("Updated FBL flight stats from radio", "console")
                saveToEeprom()
                isComplete = true
            end)
            API.write()
        else
            rfsuite.utils.log("Flight stats are already synchronized", "info")
            isComplete = true    
        end    
        
        saveData = false
    end

end

function sync.reset()
    isComplete = false
end

function sync.isComplete()
    return isComplete
end

return sync

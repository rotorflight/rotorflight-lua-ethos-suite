--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local fcversion = {}

local mspCallMade = false
local API_NAME = "FC_VERSION"

local function clearApiEntry()
    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if api and type(api.clearEntry) == "function" then
        api.clearEntry(API_NAME)
    end
end

function fcversion.wakeup()

    if rfsuite.session.apiVersion == nil then return end
    if rfsuite.session.mspBusy then return end

    if mspCallMade == false then

        mspCallMade = true

        local API = rfsuite.tasks.msp.api.load(API_NAME)
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.fcVersion = API.readVersion()
            rfsuite.session.rfVersion = API.readRfVersion()
            if rfsuite.session.fcVersion then 
                rfsuite.utils.log("FC version: " .. rfsuite.session.fcVersion, "info") 
                rfsuite.utils.log("FC version: " .. rfsuite.session.fcVersion, "connect")
            end    
            clearApiEntry()
        end)
        API.setErrorHandler(function() clearApiEntry() end)
        API.setUUID("22a683cb-dj0e-439f-8d04-04687c9360fu")
        API.read()
    end
end

function fcversion.reset()
    clearApiEntry()
    rfsuite.session.fcVersion = nil
    rfsuite.session.rfVersion = nil
    mspCallMade = false
end

function fcversion.isComplete() if rfsuite.session.fcVersion ~= nil then return true end end

return fcversion

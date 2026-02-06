--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")


-- Optimized locals to reduce global/table lookups
local utils = rfsuite.utils
local helpers = {}

function helpers.governorMode(callback)
    local session = rfsuite.session
    if (session.governorMode == nil ) then
        local msp = rfsuite.tasks.msp
        local API = msp and msp.api.load("GOVERNOR_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local governorMode = API.readValue("gov_mode")
            if governorMode then 
                utils.log("Governor mode: " .. governorMode, "debug") 
            end
            session.governorMode = governorMode
            if callback then callback(governorMode) end
        end)
        API.setUUID("e2a1c5b3-7f4a-4c8e-9d2a-3b6f8e2d9a1c")
        API.read()
    else
        if callback then callback(session.governorMode) end    
    end
end

function helpers.servoCount(callback)
    local session = rfsuite.session
    if (session.servoCount == nil) then
        local msp = rfsuite.tasks.msp
        local API = msp and msp.api.load("STATUS")
        API.setCompleteHandler(function(self, buf)
            session.servoCount = API.readValue("servo_count")
            if session.servoCount then 
                utils.log("Servo count: " .. session.servoCount, "debug") 
            end    
            if callback then callback(session.servoCount) end
        end)
        API.setUUID("d7e0db36-ca3c-4e19-9a64-40e76c78329c")
        API.read()
    else
        if callback then callback(session.servoCount) end    
    end
end

function helpers.servoOverride(callback)
    local session = rfsuite.session
    if (session.servoOverride == nil) then
        local msp = rfsuite.tasks.msp
        local API = msp and msp.api.load("SERVO_OVERRIDE")
        API.setCompleteHandler(function(self, buf)
            for i, v in pairs(API.data().parsed) do
                if v == 0 then
                    utils.log("Servo override: true (" .. i .. ")", "debug")
                    session.servoOverride = true
                end
            end
            if session.servoOverride == nil then session.servoOverride = false end
            if callback then callback(session.servoOverride) end
        end)
        API.setUUID("b9617ec3-5e01-468e-a7d5-ec7460d277ef")
        API.read()
    else
        if callback then callback(session.servoOverride) end    
    end
end

function helpers.mixerConfig(callback)
    local session = rfsuite.session
    if (session.tailMode == nil or session.swashMode == nil) then
        local msp = rfsuite.tasks.msp
        local API = msp and msp.api.load("MIXER_CONFIG")
        API.setCompleteHandler(function(self, buf)
            session.tailMode = API.readValue("tail_rotor_mode")
            session.swashMode = API.readValue("swash_type")
            if session.tailMode and session.swashMode then
                utils.log("Tail mode: " .. session.tailMode, "debug")
                utils.log("Swash mode: " .. session.swashMode, "debug")
            end
            if callback then callback(session.tailMode,session.swashMode) end
        end)
        API.setUUID("fbccd634-c9b7-4b48-8c02-08ef560dc515")
        API.read()
    else
        if callback then callback(session.tailMode,session.swashMode) end    
    end
end

function helpers.tailMode(callback)
    helpers.mixerConfig(function(tailMode, swashMode)
        if callback then callback(tailMode) end
    end)
end

function helpers.swashMode(callback)
    helpers.mixerConfig(function(tailMode, swashMode)
        if callback then callback(swashMode) end
    end)
end

return helpers
--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local helpers = {}

function helpers.governorMode(callback)
    if (rfsuite.session.governorMode == nil ) then
        local API = rfsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local governorMode = API.readValue("gov_mode")
            if governorMode then 
                rfsuite.utils.log("Governor mode: " .. governorMode, "debug") 
            end
            rfsuite.session.governorMode = governorMode
            if callback then callback(governorMode) end
        end)
        API.setUUID("e2a1c5b3-7f4a-4c8e-9d2a-3b6f8e2d9a1c")
        API.read()
    else
        if callback then callback(rfsuite.session.governorMode) end    
    end
end

function helpers.servoCount(callback)
    if (rfsuite.session.servoCount == nil) then
        local API = rfsuite.tasks.msp.api.load("STATUS")
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.servoCount = API.readValue("servo_count")
            if rfsuite.session.servoCount then 
                rfsuite.utils.log("Servo count: " .. rfsuite.session.servoCount, "debug") 
            end    
            if callback then callback(rfsuite.session.servoCount) end
        end)
        API.setUUID("d7e0db36-ca3c-4e19-9a64-40e76c78329c")
        API.read()
    else
        if callback then callback(rfsuite.session.servoCount) end    
    end
end

function helpers.servoOverride(callback)
    if (rfsuite.session.servoOverride == nil) then
        local API = rfsuite.tasks.msp.api.load("SERVO_OVERRIDE")
        API.setCompleteHandler(function(self, buf)
            for i, v in pairs(API.data().parsed) do
                if v == 0 then
                    rfsuite.utils.log("Servo override: true (" .. i .. ")", "debug")
                    rfsuite.session.servoOverride = true
                end
            end
            if rfsuite.session.servoOverride == nil then rfsuite.session.servoOverride = false end
            if callback then callback(rfsuite.session.servoOverride) end
        end)
        API.setUUID("b9617ec3-5e01-468e-a7d5-ec7460d277ef")
        API.read()
    else
        if callback then callback(rfsuite.session.servoOverride) end    
    end
end

function helpers.mixerConfig(callback)
    if (rfsuite.session.tailMode == nil or rfsuite.session.swashMode == nil) then
        local API = rfsuite.tasks.msp.api.load("MIXER_CONFIG")
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.tailMode = API.readValue("tail_rotor_mode")
            rfsuite.session.swashMode = API.readValue("swash_type")
            if rfsuite.session.tailMode and rfsuite.session.swashMode then
                rfsuite.utils.log("Tail mode: " .. rfsuite.session.tailMode, "debug")
                rfsuite.utils.log("Swash mode: " .. rfsuite.session.swashMode, "debug")
            end
            if callback then callback(rfsuite.session.tailMode,rfsuite.session.swashMode) end
        end)
        API.setUUID("fbccd634-c9b7-4b48-8c02-08ef560dc515")
        API.read()
    else
        if callback then callback(rfsuite.session.tailMode,rfsuite.session.swashMode) end    
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
--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local system = system


-- Optimized locals to reduce global/table lookups
local utils = rfsuite.utils
local helpers = {}

function helpers.governorMode(callback, owner)
    
    if (rfsuite.session.governorMode == nil ) then
        local msp = rfsuite.tasks.msp
        local API = msp and msp.api.load("GOVERNOR_CONFIG")
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        if API and owner and API.setOwner then API.setOwner(owner) end
        API.setCompleteHandler(function(self, buf)
            local governorMode = API.readValue("gov_mode")
            if governorMode then
                utils.log("Governor mode: " .. governorMode, "debug")
            end
            rfsuite.session.governorMode = governorMode
            API = nil
            if callback then callback(governorMode) end
        end)
        API.setUUID(utils.uuid and utils.uuid() or tostring(os.clock()))
        API.read()
    else
        if callback then callback(rfsuite.session.governorMode) end    
    end
end

function helpers.servoCount(callback, owner)
    if (rfsuite.session.servoCount == nil) then
        local msp = rfsuite.tasks.msp
        local API = msp and msp.api.load("STATUS")
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        if API and owner and API.setOwner then API.setOwner(owner) end
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.servoCount = API.readValue("servo_count")
            if rfsuite.session.servoCount then
                utils.log("Servo count: " .. rfsuite.session.servoCount, "debug")
            end
            API = nil
            if callback then callback(rfsuite.session.servoCount) end
        end)
        API.setUUID(utils.uuid and utils.uuid() or tostring(os.clock()))
        API.read()
    else
        if callback then callback(rfsuite.session.servoCount) end    
    end
end

function helpers.servoOverride(callback, owner)
    if (rfsuite.session.servoOverride == nil) then
        local msp = rfsuite.tasks.msp
        local API = msp and msp.api.load("SERVO_OVERRIDE")
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        if API and owner and API.setOwner then API.setOwner(owner) end
        API.setCompleteHandler(function(self, buf)
            for i, v in pairs(API.data().parsed) do
                if v == 0 then
                    utils.log("Servo override: true (" .. i .. ")", "debug")
                    rfsuite.session.servoOverride = true
                end
            end
            if rfsuite.session.servoOverride == nil then rfsuite.session.servoOverride = false end
            API = nil
            if callback then callback(rfsuite.session.servoOverride) end
        end)
        API.setUUID(utils.uuid and utils.uuid() or tostring(os.clock()))
        API.read()
    else
        if callback then callback(rfsuite.session.servoOverride) end    
    end
end


function helpers.servoBusEnabled(callback, owner)

    local FBUS_FUNCTIONMASK = 524288
    local SBUS_FUNCTIONMASK = 262144

    local function hasServoBusFunction(api)
        local data = api and api.data and api.data()
        local parsed = data and data.parsed
        if not parsed then return false end

        for i = 1, 12 do
            local functionMask = parsed["port_" .. i .. "_function_mask"]
            if functionMask == FBUS_FUNCTIONMASK or functionMask == SBUS_FUNCTIONMASK then
                return true
            end
        end

        return false
    end

    if (rfsuite.session.servoBusEnabled == nil) then
        local msp = rfsuite.tasks.msp
        local API = msp and msp.api.load("SERIAL_CONFIG")
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        if API and owner and API.setOwner then API.setOwner(owner) end
        API.setCompleteHandler(function()
            rfsuite.session.servoBusEnabled = hasServoBusFunction(API)
            API = nil
            if callback then callback(rfsuite.session.servoBusEnabled) end
        end)
        API.setUUID(utils.uuid and utils.uuid() or tostring(os.clock()))
        API.read()
    else
        if callback then callback(rfsuite.session.servoBusEnabled) end
    end
end

function helpers.mixerConfig(callback, owner)
    if (rfsuite.session.tailMode == nil or rfsuite.session.swashMode == nil) then
        local msp = rfsuite.tasks.msp
        local API = msp and msp.api.load("MIXER_CONFIG")
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        if API and owner and API.setOwner then API.setOwner(owner) end
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.tailMode = API.readValue("tail_rotor_mode")
            rfsuite.session.swashMode = API.readValue("swash_type")
            if system and system.getVersion and system.getVersion().simulation then
                local dev = rfsuite.preferences and rfsuite.preferences.developer
                local override = dev and dev.tailmode_override
                override = tonumber(override)
                if override == 0 or override == 1 then
                    rfsuite.session.tailMode = override
                    utils.log("Tail mode override (developer): " .. tostring(override), "debug")
                end
            end
            if rfsuite.session.tailMode and rfsuite.session.swashMode then
                utils.log("Tail mode: " .. rfsuite.session.tailMode, "debug")
                utils.log("Swash mode: " .. rfsuite.session.swashMode, "debug")
            end
            API = nil
            if callback then callback(rfsuite.session.tailMode, rfsuite.session.swashMode) end
        end)
        API.setUUID(utils.uuid and utils.uuid() or tostring(os.clock()))
        API.read()
    else
        if callback then callback(rfsuite.session.tailMode,rfsuite.session.swashMode) end    
    end
end

function helpers.tailMode(callback, owner)
    helpers.mixerConfig(function(tailMode, swashMode)
        if callback then callback(tailMode) end
    end, owner)
end

function helpers.swashMode(callback, owner)
    helpers.mixerConfig(function(tailMode, swashMode)
        if callback then callback(swashMode) end
    end, owner)
end


return helpers

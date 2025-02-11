--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
--
-- background processing of msp traffic
--
local arg = {...}
local config = arg[1]

local msp = {}

msp.activeProtocol = nil
msp.onConnectChecksInit = true

local protocol = assert(loadfile("tasks/msp/protocols.lua"))()

msp.sensor = sport.getSensor({primId = 0x32})
msp.mspQueue = mspQueue

-- set active protocol to use
msp.protocol = protocol.getProtocol()

-- preload all transport methods
msp.protocolTransports = {}
for i, v in pairs(protocol.getTransports()) do msp.protocolTransports[i] = assert(loadfile(v))() end

-- set active transport table to use
local transport = msp.protocolTransports[msp.protocol.mspProtocol]
msp.protocol.mspRead = transport.mspRead
msp.protocol.mspSend = transport.mspSend
msp.protocol.mspWrite = transport.mspWrite
msp.protocol.mspPoll = transport.mspPoll

msp.mspQueue = assert(loadfile("tasks/msp/mspQueue.lua"))()
msp.mspQueue.maxRetries = msp.protocol.maxRetries
msp.mspHelper = assert(loadfile("tasks/msp/mspHelper.lua"))()
msp.api = assert(loadfile("tasks/msp/api.lua"))()
assert(loadfile("tasks/msp/common.lua"))()

-- BACKGROUND checks
function msp.onConnectBgChecks()

    if msp.mspQueue ~= nil and msp.mspQueue:isProcessed() then

        -- set module to use. this happens on connect as
        -- it forces a recheck whenever the rx has been disconnected
        -- or a model swapped
        if rfsuite.rssiSensor then msp.sensor:module(rfsuite.rssiSensor:module()) end

        -- get the api version
        if rfsuite.config.apiVersion == nil and msp.mspQueue:isProcessed() then

            local API = msp.api.load("API_VERSION")
            API.setCompleteHandler(function(self, buf)
                rfsuite.config.apiVersion = API.readVersion()
                print("API version: " .. rfsuite.config.apiVersion)
            end)
            API.read()

        elseif rfsuite.config.clockSet == nil and msp.mspQueue:isProcessed() then

            local API = msp.api.load("RTC", 1)
            API.setCompleteHandler(function(self, buf)
                rfsuite.config.clockSet = true
                print("Sync clock: " .. os.clock())
            end)

            API.write()

            -- beep the clock
        elseif rfsuite.config.clockSet == true and rfsuite.config.clockSetAlart ~= true then
            -- this is unsual but needed because the clock sync does not return anything usefull
            -- to confirm its done! 
            rfsuite.utils.playFileCommon("beep.wav")
            rfsuite.config.clockSetAlart = true

            -- find tail and swash mode
        elseif (rfsuite.config.tailMode == nil or rfsuite.config.swashMode == nil) and msp.mspQueue:isProcessed() then

            local API = msp.api.load("MIXER_CONFIG")
            API.setCompleteHandler(function(self, buf)
                rfsuite.config.tailMode = API.readValue("tail_rotor_mode")
                rfsuite.config.swashMode = API.readValue("swash_type")
                print("Tail mode: " .. rfsuite.config.tailMode)
                print("Swash mode: " .. rfsuite.config.swashMode)
            end)
            API.read()

            -- get servo configuration
        elseif (rfsuite.config.servoCount == nil) and msp.mspQueue:isProcessed() then

            local API = msp.api.load("STATUS")
            API.setCompleteHandler(function(self, buf)
                rfsuite.config.servoCount = API.readValue("servo_count")
                print("Servo count: " .. rfsuite.config.servoCount)
            end)
            API.read()

            -- work out if fbl has any servos in overide mode
        elseif (rfsuite.config.servoOverride == nil) and msp.mspQueue:isProcessed() then

            local API = msp.api.load("SERVO_OVERRIDE")
            API.read()
            if API.readComplete() then
                for i,v in pairs(API.data().parsed) do
                    if v == 0 then
                        rfsuite.utils.log("Servo override: true (" .. i .. ")")
                        rfsuite.config.servoOverride = true
                    end    
                end
                if rfsuite.config.servoOverride == nil then rfsuite.config.servoOverride = false end
            end

            -- find out if we have a governor
        elseif (rfsuite.config.governorMode == nil) and msp.mspQueue:isProcessed() then

            local API = msp.api.load("GOVERNOR_CONFIG")
            API.setCompleteHandler(function(self, buf)
                local governorMode = API.readValue("gov_mode")
                rfsuite.utils.log("Governor mode: " .. governorMode)
                rfsuite.config.governorMode = governorMode
            end)
            API.read()

            -- get the model id
        elseif (rfsuite.config.modelID == nil) and msp.mspQueue:isProcessed() then

            local API = msp.api.load("PILOT_CONFIG")
            API.setCompleteHandler(function(self, buf)
                local model_id = API.readValue("model_id")
                print("Model id: " .. model_id)
                rfsuite.config.modelID = model_id
            end)
            API.read()

            -- find the craft name on the fbl
        elseif (rfsuite.config.craftName == nil) and msp.mspQueue:isProcessed() then

            local API = msp.api.load("NAME")
            API.read()
            if API.readComplete() and API.readValue("name") ~= nil then
                local data = API.data()

                rfsuite.config.craftName = API.readValue("name")

                -- set the model name to the craft name
                if rfsuite.config.syncCraftName == true and model.name and rfsuite.config.craftName ~= nil then
                    model.name(rfsuite.config.craftName)
                    lcd.invalidate()
                end

                if rfsuite.config.craftName and rfsuite.config.craftName ~= "" then print("Craft name: " .. rfsuite.config.craftName) end

                -- do this at end of last one
                msp.onConnectChecksInit = false
            end

        end
    end

end

function msp.resetState()
    rfsuite.config.servoOverride = nil
    rfsuite.config.servoCount = nil
    rfsuite.config.tailMode = nil
    rfsuite.config.apiVersion = nil
    rfsuite.config.clockSet = nil
    rfsuite.config.clockSetAlart = nil
    rfsuite.config.craftName = nil
    rfsuite.config.modelID = nil
end

function msp.wakeup()

    -- check what protocol is in use
    local telemetrySOURCE = system.getSource("Rx RSSI1")
    if telemetrySOURCE ~= nil then
        msp.activeProtocol = "crsf"
    else
        msp.activeProtocol = "smartPort"
    end

    if rfsuite.bg.wasOn == true then rfsuite.rssiSensorChanged = true end

    if rfsuite.rssiSensorChanged == true then

        rfsuite.utils.log("Switching protocol: " .. msp.activeProtocol)

        msp.protocol = protocol.getProtocol()

        -- set active transport table to use
        local transport = msp.protocolTransports[msp.protocol.mspProtocol]
        msp.protocol.mspRead = transport.mspRead
        msp.protocol.mspSend = transport.mspSend
        msp.protocol.mspWrite = transport.mspWrite
        msp.protocol.mspPoll = transport.mspPoll

        msp.resetState()
        msp.onConnectChecksInit = true
    end

    if rfsuite.rssiSensor ~= nil and rfsuite.bg.telemetry.active() == false then
        msp.resetState()
        msp.onConnectChecksInit = true
    end

    -- run the msp.checks

    local state

    if system:getVersion().simulation == true then
        state = true
    elseif rfsuite.rssiSensor then
        state = rfsuite.bg.telemetry.active()
    else
        state = false
    end

    if state == true then
        msp.mspQueue:processQueue()

        -- checks that run on each connection to the fbl
        if msp.onConnectChecksInit == true then 
            msp.onConnectBgChecks() 
        end
    else
        msp.mspQueue:clear()
    end
end

return msp

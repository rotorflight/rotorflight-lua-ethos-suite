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
msp.sensorTlm = sport.getSensor()
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
        if rfsuite.session.rssiSensor then msp.sensor:module(rfsuite.session.rssiSensor:module()) end

        -- get the api version
        if rfsuite.session.apiVersion == nil and msp.mspQueue:isProcessed() then

            local API = msp.api.load("API_VERSION")
            API.setCompleteHandler(function(self, buf)
                rfsuite.session.apiVersion = API.readVersion()
                rfsuite.utils.log("API version: " .. rfsuite.session.apiVersion,"info")
            end)
            API.read()

        end
        if rfsuite.session.apiVersion ~= nil then
            if rfsuite.session.clockSet == nil and msp.mspQueue:isProcessed() then

                local API = msp.api.load("RTC", 1)
                API.setCompleteHandler(function(self, buf)
                    rfsuite.session.clockSet = true
                    rfsuite.utils.log("Sync clock: " .. os.clock(),"info")
                end)

                API.write()
                -- find tail and swash mode
            elseif (rfsuite.session.tailMode == nil or rfsuite.session.swashMode == nil) and msp.mspQueue:isProcessed() then

                local API = msp.api.load("MIXER_CONFIG")
                API.setCompleteHandler(function(self, buf)
                    rfsuite.session.tailMode = API.readValue("tail_rotor_mode")
                    rfsuite.session.swashMode = API.readValue("swash_type")
                    rfsuite.utils.log("Tail mode: " .. rfsuite.session.tailMode,"info")
                    rfsuite.utils.log("Swash mode: " .. rfsuite.session.swashMode,"info")
                end)
                API.read()

                -- get servo configuration
            elseif (rfsuite.session.servoCount == nil) and msp.mspQueue:isProcessed() then

                local API = msp.api.load("STATUS")
                API.setCompleteHandler(function(self, buf)
                    rfsuite.session.servoCount = API.readValue("servo_count")
                    rfsuite.utils.log("Servo count: " .. rfsuite.session.servoCount,"info")
                end)
                API.read()

                -- work out if fbl has any servos in overide mode
            elseif (rfsuite.session.servoOverride == nil) and msp.mspQueue:isProcessed() then

                local API = msp.api.load("SERVO_OVERRIDE")
                API.read()
                if API.readComplete() then
                    for i,v in pairs(API.data().parsed) do
                        if v == 0 then
                            rfsuite.utils.log("Servo override: true (" .. i .. ")","info")
                            rfsuite.session.servoOverride = true
                        end    
                    end
                    if rfsuite.session.servoOverride == nil then rfsuite.session.servoOverride = false end
                end

                -- find out if we have a governor
            elseif (rfsuite.session.governorMode == nil) and msp.mspQueue:isProcessed() then

                local API = msp.api.load("GOVERNOR_CONFIG")
                API.setCompleteHandler(function(self, buf)
                    local governorMode = API.readValue("gov_mode")
                    rfsuite.utils.log("Governor mode: " .. governorMode,"info")
                    rfsuite.session.governorMode = governorMode
                end)
                API.read()

                -- get the model id
            elseif (rfsuite.session.modelID == nil) and msp.mspQueue:isProcessed() then

                local API = msp.api.load("PILOT_CONFIG")
                API.setCompleteHandler(function(self, buf)
                    local model_id = API.readValue("model_id")
                    rfsuite.utils.log("Model id: " .. model_id,"info")
                    rfsuite.session.modelID = model_id
                end)
                API.read()

                -- find the craft name on the fbl
            elseif (rfsuite.session.craftName == nil) and msp.mspQueue:isProcessed() then

                local API = msp.api.load("NAME")
                API.read()
                if API.readComplete() and API.readValue("name") ~= nil then
                    local data = API.data()

                    rfsuite.session.craftName = API.readValue("name")

                    -- set the model name to the craft name
                    if rfsuite.preferences.syncCraftName == true and model.name and rfsuite.session.craftName ~= nil then
                        rfsuite.utils.log("Setting model name to: " .. rfsuite.session.craftName,"info")
                        model.name(rfsuite.session.craftName)
                        lcd.invalidate()
                    end

                    if rfsuite.session.craftName and rfsuite.session.craftName ~= "" then 
                        rfsuite.utils.log("Craft name: " .. rfsuite.session.craftName,"info") 
                    end


                end

            elseif rfsuite.session.clockSet == true and rfsuite.session.clockSetAlart ~= true then
                -- this is unsual but needed because the clock sync does not return anything usefull
                -- to confirm its done! 
                rfsuite.utils.playFileCommon("beep.wav")
                rfsuite.session.clockSetAlart = true
                
                -- do this at end of last one
                msp.onConnectChecksInit = false
            end    
        end    
    end

end

function msp.resetState()
    rfsuite.session.servoOverride = nil
    rfsuite.session.servoCount = nil
    rfsuite.session.tailMode = nil
    rfsuite.session.apiVersion = nil
    rfsuite.session.clockSet = nil
    rfsuite.session.clockSetAlart = nil
    rfsuite.session.craftName = nil
    rfsuite.session.modelID = nil
end

function msp.wakeup()

    -- check if we have a telemetry source
    local telemetrySOURCE = rfsuite.tasks.telemetry.getSensorSource("rssi") 
    if telemetrySOURCE == nil then 
        return
    end

    if telemetrySOURCE:name() == "Rx RSSI1" or telemetrySOURCE:name() == "Rx RSSI1" then
        msp.activeProtocol = "crsf"
    else
        msp.activeProtocol = "smartPort"
    end

    if rfsuite.tasks.wasOn == true then rfsuite.session.rssiSensorChanged = true end

    if rfsuite.session.rssiSensorChanged == true then

        --rfsuite.utils.log("Switching protocol: " .. msp.activeProtocol)

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

    if rfsuite.session.rssiSensor ~= nil and rfsuite.tasks.telemetry.active() == false then
        msp.resetState()
        msp.onConnectChecksInit = true
    end

    -- run the msp.checks

    local state

    if system:getVersion().simulation == true then
        state = true
    elseif rfsuite.session.rssiSensor then
        state = rfsuite.tasks.telemetry.active()
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

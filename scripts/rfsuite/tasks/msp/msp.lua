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

            local API = msp.api.load("MSP_API_VERSION")
            API.read()  
            if API.readComplete() then
                rfsuite.config.apiVersion = API.readVersion()
                rfsuite.utils.log("API version: " .. rfsuite.config.apiVersion)
            end               

        -- sync the clock
        elseif rfsuite.config.clockSet == nil and msp.mspQueue:isProcessed() then

            local API = msp.api.load("MSP_SET_RTC")
            API.write()  
            if API.writeComplete() then
                rfsuite.config.clockSet = true
                rfsuite.utils.log("Sync clock: " .. os.clock())
            end                

        -- beep the clock
        elseif rfsuite.config.clockSet == true and rfsuite.config.clockSetAlart ~= true then
            -- this is unsual but needed because the clock sync does not return anything usefull
            -- to confirm its done! 
            rfsuite.utils.playFileCommon("beep.wav")
            rfsuite.config.clockSetAlart = true

        -- find tail and swash mode
        elseif (rfsuite.config.tailMode == nil or rfsuite.config.swashMode == nil) and msp.mspQueue:isProcessed() then
           
            local API = msp.api.load("MSP_MIXER_CONFIG")
            API.read()  
            if API.readComplete() then
                rfsuite.config.tailMode = API.readValue("tail_rotor_mode")     
                rfsuite.config.swashMode = API.readValue("swash_type")
                rfsuite.utils.log("Tail mode: " .. rfsuite.config.tailMode)
                rfsuite.utils.log("Swash mode: " .. rfsuite.config.swashMode)
            end                 

        -- get servo configuration
        elseif (rfsuite.config.servoCount == nil) and msp.mspQueue:isProcessed() then
 
           local API = msp.api.load("MSP_SERVO_CONFIGURATIONS")
           API.read()  
           if API.readComplete() then
                rfsuite.config.servoCount =  API.readValue("servo_count")
                rfsuite.utils.log("Servo count: " .. rfsuite.config.servoCount)
           end     

        -- work out if fbl has any servos in overide mode
        elseif (rfsuite.config.servoOverride == nil) and msp.mspQueue:isProcessed() then


            local API = msp.api.load("MSP_SERVO_OVERIDE")
            API.read(rfsuite.config.servoCount)  
            if API.readComplete() then
                    local data = API.data()
                    local buf = data['buffer']
                    for i = 0, rfsuite.config.servoCount do
                        buf.offset = i
                        local servoOverride = msp.mspHelper.readU8(buf)
                        if servoOverride == 0 then
                            rfsuite.utils.log("Servo overide: true")
                            rfsuite.config.servoOverride = true
                       end
                    end
                    if rfsuite.config.servoOverride == nil then rfsuite.config.servoOverride = false end
            end    

        -- find out if we have a governor
        elseif (rfsuite.config.governorMode == nil) and msp.mspQueue:isProcessed() then

            local API = msp.api.load("MSP_GOVERNOR_CONFIG")
            API.read()  
            if API.readComplete() then
                    local governorMode = API.readValue("gov_mode")
                    rfsuite.utils.log("Governor mode: " .. governorMode)
                    rfsuite.config.governorMode = governorMode
            end   

        -- find the craft name on the fbl
        elseif (rfsuite.config.craftName == nil) and msp.mspQueue:isProcessed() then

            local API = msp.api.load("MSP_NAME")
            API.read()  
            if API.readComplete() then
                    rfsuite.config.craftName  = API.readValue("name")

                    -- set the model name to the craft name
                    if rfsuite.config.syncCraftName == true and model.name and rfsuite.config.craftName ~= nil then
                        model.name(rfsuite.config.craftName)
                        lcd.invalidate()
                    end

                    rfsuite.utils.log("Craft name: " .. rfsuite.config.craftName)

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
        if msp.onConnectChecksInit == true then msp.onConnectBgChecks() end
    else
        msp.mspQueue:clear()
    end
end

return msp

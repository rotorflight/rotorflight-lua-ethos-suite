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

local protocol = assert(rfsuite.compiler.loadfile("tasks/msp/protocols.lua"))()


msp.mspQueue = mspQueue

-- set active protocol to use
msp.protocol = protocol.getProtocol()

-- preload all transport methods
msp.protocolTransports = {}
for i, v in pairs(protocol.getTransports()) do msp.protocolTransports[i] = assert(rfsuite.compiler.loadfile(v))() end

-- set active transport table to use
local transport = msp.protocolTransports[msp.protocol.mspProtocol]
msp.protocol.mspRead = transport.mspRead
msp.protocol.mspSend = transport.mspSend
msp.protocol.mspWrite = transport.mspWrite
msp.protocol.mspPoll = transport.mspPoll

msp.mspQueue = assert(rfsuite.compiler.loadfile("tasks/msp/mspQueue.lua"))()
msp.mspQueue.maxRetries = msp.protocol.maxRetries
msp.mspHelper = assert(rfsuite.compiler.loadfile("tasks/msp/mspHelper.lua"))()
msp.api = assert(rfsuite.compiler.loadfile("tasks/msp/api.lua"))()
msp.common = assert(rfsuite.compiler.loadfile("tasks/msp/common.lua"))()

local delayDuration = 2  -- seconds
local delayStartTime = nil
local delayPending = false

function msp.wakeup()

    if rfsuite.session.telemetrySensor == nil then return end

    if not msp.sensor then
        msp.sensor = sport.getSensor({primId = 0x32})
        msp.sensor:module(rfsuite.session.telemetrySensor:module())
    end
    
    if not msp.sensorTlm then
        msp.sensorTlm = sport.getSensor()
        msp.sensorTlm:module(rfsuite.session.telemetrySensor:module())
    end

    if rfsuite.session.resetMSP and not delayPending then
        delayStartTime = os.clock()
        delayPending = true
        rfsuite.session.resetMSP = false  -- Reset immediately
        rfsuite.utils.log("Delaying msp wakeup for " .. delayDuration .. " seconds","info")
        return  -- Exit early; wait starts now
    end

    if delayPending then
        if os.clock() - delayStartTime >= delayDuration then
            rfsuite.utils.log("Delay complete; resuming msp wakeup","info")
            delayPending = false
        else
            rfsuite.tasks.msp.mspQueue:clear()
            return  -- Still waiting; do nothing
        end
    end

   msp.activeProtocol = rfsuite.session.telemetryType

    if rfsuite.tasks.wasOn == true then rfsuite.session.telemetryTypeChanged = true end

    if rfsuite.session.telemetryTypeChanged == true then

        --rfsuite.utils.log("Switching protocol: " .. msp.activeProtocol)

        msp.protocol = protocol.getProtocol()

        -- set active transport table to use
        local transport = msp.protocolTransports[msp.protocol.mspProtocol]
        msp.protocol.mspRead = transport.mspRead
        msp.protocol.mspSend = transport.mspSend
        msp.protocol.mspWrite = transport.mspWrite
        msp.protocol.mspPoll = transport.mspPoll

        rfsuite.utils.session()
        msp.onConnectChecksInit = true
    end

    if rfsuite.session.telemetrySensor ~= nil and rfsuite.session.telemetryState == false then
        rfsuite.utils.session()
        msp.onConnectChecksInit = true
    end

    -- run the msp.checks

    local state

    if rfsuite.session.telemetrySensor then
        state = rfsuite.session.telemetryState
    else
        state = false
    end

    if state == true then
        
        msp.mspQueue:processQueue()

        -- checks that run on each connection to the fbl
        if msp.onConnectChecksInit == true then 
            if rfsuite.session.telemetrySensor then msp.sensor:module(rfsuite.session.telemetrySensor:module()) end
        end
    else
        msp.mspQueue:clear()
    end

end

function msp.reset()
    rfsuite.tasks.msp.mspQueue:clear()
    msp.sensor = nil
    msp.activeProtocol = nil
    msp.onConnectChecksInit = true
    delayStartTime = nil
    msp.sensorTlm = nil
    delayPending = false    
end

return msp

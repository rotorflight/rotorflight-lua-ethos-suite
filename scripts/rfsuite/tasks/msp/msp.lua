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
msp.common = assert(loadfile("tasks/msp/common.lua"))()


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

        msp.resetState()
        msp.onConnectChecksInit = true
    end

    if rfsuite.session.telemetrySensor ~= nil and rfsuite.session.telemetryState == false then
        msp.resetState()
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

return msp

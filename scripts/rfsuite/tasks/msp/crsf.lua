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
local transport = {}

-- CRSF Devices
local CRSF_ADDRESS_BETAFLIGHT = 0xC8
local CRSF_ADDRESS_RADIO_TRANSMITTER = 0xEA

-- CRSF Frame Types
local CRSF_FRAMETYPE_MSP_REQ = 0x7A -- response request using msp sequence as command
local CRSF_FRAMETYPE_MSP_RESP = 0x7B -- reply with 60 byte chunked binary
local CRSF_FRAMETYPE_MSP_WRITE = 0x7C -- write with 60 byte chunked binary

local crsfMspCmd = 0

--[[
This script configures the `transport` object to use the appropriate `popFrame` and `pushFrame` functions 
based on the availability of the `crsf.getSensor` function.

If `crsf.getSensor` is not nil, it retrieves the sensor object and assigns its `popFrame` and `pushFrame` 
methods to the `transport` object. Otherwise, it directly assigns the `crsf.popFrame` and `crsf.pushFrame` 
functions to the `transport` object.
]]
if crsf.getSensor ~= nil then
    local sensor = crsf.getSensor()
    transport.popFrame = function()
        return sensor:popFrame()
    end
    transport.pushFrame = function(x, y)
        return sensor:pushFrame(x, y)
    end
else
    transport.popFrame = function()
        return crsf.popFrame()
    end
    transport.pushFrame = function(x, y)
        return crsf.pushFrame(x, y)
    end
end

--[[
    Sends an MSP (MultiWii Serial Protocol) payload using CRSF (Crossfire) transport.

    @param payload (table) - The MSP payload to be sent.

    @return (boolean) - Returns true if the frame was successfully pushed, false otherwise.
]]
transport.mspSend = function(payload)
    local payloadOut = {CRSF_ADDRESS_BETAFLIGHT, CRSF_ADDRESS_RADIO_TRANSMITTER}
    for i = 1, #(payload) do payloadOut[i + 2] = payload[i] end
    return transport.pushFrame(crsfMspCmd, payloadOut)
end

--[[
    Sends an MSP (Multiwii Serial Protocol) request using CRSF (Crossfire) transport.

    @param cmd: The MSP command to be sent.
    @return: The result of the mspSendRequest function call.
]]
transport.mspRead = function(cmd)
    crsfMspCmd = CRSF_FRAMETYPE_MSP_REQ
    return rfsuite.tasks.msp.common.mspSendRequest(cmd, {})
end

--[[
    Function: transport.mspWrite
    Description: Sends an MSP (Multiwii Serial Protocol) write request using CRSF (Crossfire) protocol.
    Parameters:
        cmd (number) - The MSP command to be sent.
        payload (table) - The data payload to be sent with the command.
    Returns:
        (boolean) - The result of the mspSendRequest function indicating success or failure.
]]
transport.mspWrite = function(cmd, payload)
    crsfMspCmd = CRSF_FRAMETYPE_MSP_WRITE
    return rfsuite.tasks.msp.common.mspSendRequest(cmd, payload)
end

--[[
    Function: transport.mspPoll
    Description: Polls for MSP (Multiwii Serial Protocol) frames from the transport layer.
    Returns: 
        - mspData (table): A table containing the MSP data if a valid frame is received.
        - nil: If no valid frame is received.
    Notes:
        - The function continuously checks for frames until a valid MSP response frame is found or no frame is available.
        - It expects the frame to be of type CRSF_FRAMETYPE_MSP_RESP, originating from CRSF_ADDRESS_RADIO_TRANSMITTER and destined for CRSF_ADDRESS_BETAFLIGHT.
]]
transport.mspPoll = function()
    while true do
        local cmd, data = transport.popFrame()
        if cmd == CRSF_FRAMETYPE_MSP_RESP and data[1] == CRSF_ADDRESS_RADIO_TRANSMITTER and data[2] == CRSF_ADDRESS_BETAFLIGHT then
            local mspData = {}
            for i = 3, #data do mspData[i - 2] = data[i] end
            return mspData
        elseif cmd == nil then
            return nil
        end
    end
end

return transport

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

]]--
local transport = {}

-- CRSF Devices
local CRSF_ADDRESS_BETAFLIGHT = 0xC8
local CRSF_ADDRESS_RADIO_TRANSMITTER = 0xEA

-- CRSF Frame Types
local CRSF_FRAMETYPE_MSP_REQ = 0x7A -- response request using msp sequence as command
local CRSF_FRAMETYPE_MSP_RESP = 0x7B -- reply with 60 byte chunked binary
local CRSF_FRAMETYPE_MSP_WRITE = 0x7C -- write with 60 byte chunked binary

local crsfMspCmd = 0

if crsf.getSensor ~= nil then
    local sensor = crsf.getSensor()
    transport.popFrame = function() return sensor:popFrame() end
    transport.pushFrame = function(x,y) return sensor:pushFrame(x,y) end
else
    transport.popFrame = function() return crsf.popFrame() end
    transport.pushFrame = function(x,y) return crsf.pushFrame(x,y) end
end



transport.mspSend = function(payload)
    local payloadOut = {CRSF_ADDRESS_BETAFLIGHT, CRSF_ADDRESS_RADIO_TRANSMITTER}
    for i = 1, #(payload) do payloadOut[i + 2] = payload[i] end
    return transport.pushFrame(crsfMspCmd, payloadOut)
end

transport.mspRead = function(cmd)
    crsfMspCmd = CRSF_FRAMETYPE_MSP_REQ
    return mspSendRequest(cmd, {})
end

transport.mspWrite = function(cmd, payload)
    crsfMspCmd = CRSF_FRAMETYPE_MSP_WRITE
    return mspSendRequest(cmd, payload)
end

transport.mspPoll = function()
    while true do
        local cmd, data = transport.popFrame()
        if cmd == CRSF_FRAMETYPE_MSP_RESP and data[1] == CRSF_ADDRESS_RADIO_TRANSMITTER and data[2] == CRSF_ADDRESS_BETAFLIGHT then
            --[[
                        --rfsuite.utils.log("cmd:0x"..string.format("%X", cmd))
                        --rfsuite.utils.log("  data length: "..string.format("%u", #data))
                        for i=1,#data do
                                --rfsuite.utils.log("  ["..string.format("%u", i).."]:  0x"..string.format("%X", data[i]))
                        end
--]]
            local mspData = {}
            for i = 3, #data do mspData[i - 2] = data[i] end
            return mspData
        elseif cmd == nil then
            return nil
        end
    end
end

return transport

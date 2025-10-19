--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local transport = {}

local CRSF_ADDRESS_BETAFLIGHT = 0xC8
local CRSF_ADDRESS_RADIO_TRANSMITTER = 0xEA

local CRSF_FRAMETYPE_MSP_REQ = 0x7A
local CRSF_FRAMETYPE_MSP_RESP = 0x7B
local CRSF_FRAMETYPE_MSP_WRITE = 0x7C

local crsfMspCmd = 0

if crsf.getSensor ~= nil then
    local sensor = crsf.getSensor()
    transport.popFrame = function() return sensor:popFrame() end
    transport.pushFrame = function(x, y) return sensor:pushFrame(x, y) end
else
    transport.popFrame = function() return crsf.popFrame() end
    transport.pushFrame = function(x, y) return crsf.pushFrame(x, y) end
end

transport.mspSend = function(payload)
    local payloadOut = {CRSF_ADDRESS_BETAFLIGHT, CRSF_ADDRESS_RADIO_TRANSMITTER}
    for i = 1, #(payload) do payloadOut[i + 2] = payload[i] end
    return transport.pushFrame(crsfMspCmd, payloadOut)
end

transport.mspRead = function(cmd)
    crsfMspCmd = CRSF_FRAMETYPE_MSP_REQ
    return rfsuite.tasks.msp.common.mspSendRequest(cmd, {})
end

transport.mspWrite = function(cmd, payload)
    crsfMspCmd = CRSF_FRAMETYPE_MSP_WRITE
    return rfsuite.tasks.msp.common.mspSendRequest(cmd, payload)
end

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

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

local sensor

transport.popFrame = function(...)
    if not sensor then sensor = crsf.getSensor() end
    return sensor:popFrame(...)
end

transport.pushFrame = function(x, y)
    if not sensor then sensor = crsf.getSensor() end
    return sensor:pushFrame(x, y)
end

local payloadOut = {0,0}
transport.mspSend = function(payload)
    payloadOut[1], payloadOut[2] = CRSF_ADDRESS_BETAFLIGHT, CRSF_ADDRESS_RADIO_TRANSMITTER
    for i = 1, #payload do payloadOut[i+2] = payload[i] end
    for j = #payload+3, #payloadOut do payloadOut[j] = nil end -- trim
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
    local cmd, data = transport.popFrame(CRSF_FRAMETYPE_MSP_RESP, CRSF_FRAMETYPE_MSP_RESP)
    if not cmd then return nil end
    if data[1] ~= CRSF_ADDRESS_RADIO_TRANSMITTER or data[2] ~= CRSF_ADDRESS_BETAFLIGHT then
        return nil
    end
    local out = {}
    for i = 3, #data do out[i - 2] = data[i] end
    return out
end

return transport

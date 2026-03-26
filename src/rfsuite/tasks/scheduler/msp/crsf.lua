--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local transport = {}
local crsf = crsf

-- CRSF address definitions
local CRSF_ADDRESS_BETAFLIGHT        = 0xC8  -- FC device address
local CRSF_ADDRESS_RADIO_TRANSMITTER = 0xEA  -- TX module address

-- CRSF MSP frame types
local CRSF_FRAMETYPE_MSP_REQ   = 0x7A  -- MSP read request
local CRSF_FRAMETYPE_MSP_RESP  = 0x7B  -- MSP reply
local CRSF_FRAMETYPE_MSP_WRITE = 0x7C  -- MSP write request

-- Command type used when sending frames via CRSF
local crsfMspCmd = 0

-- Sensor object (lazy initialization)
local sensor
local mspCommon

-- Pop a CRSF frame
transport.popFrame = function(...)
    if not sensor then sensor = crsf.getSensor() end
    if not sensor then return nil end
    return sensor:popFrame(...)
end

-- Push a CRSF frame
transport.pushFrame = function(x, y)
    if not sensor then sensor = crsf.getSensor() end
    if not sensor then return nil end
    return sensor:pushFrame(x, y)
end

-- Outgoing payload buffer
local payloadOut = {0, 0}

-- Send MSP payload over CRSF
transport.mspSend = function(payload)
    -- First two entries in CRSF MSP frames are always: FROM, TO
    payloadOut[1] = CRSF_ADDRESS_BETAFLIGHT
    payloadOut[2] = CRSF_ADDRESS_RADIO_TRANSMITTER

    -- Copy MSP payload into CRSF buffer
    for i = 1, #payload do
        payloadOut[i + 2] = payload[i]
    end

    -- Trim any trailing leftover bytes from prior sends
    for j = #payload + 3, #payloadOut do
        payloadOut[j] = nil
    end

    return transport.pushFrame(crsfMspCmd, payloadOut)
end

-- Issue an MSP READ request over CRSF
transport.mspRead = function(cmd)
    crsfMspCmd = CRSF_FRAMETYPE_MSP_REQ
    if not mspCommon then mspCommon = rfsuite.tasks.msp.common end
    return mspCommon.mspSendRequest(cmd, {})
end

-- Issue an MSP WRITE request over CRSF
transport.mspWrite = function(cmd, payload)
    crsfMspCmd = CRSF_FRAMETYPE_MSP_WRITE
    if not mspCommon then mspCommon = rfsuite.tasks.msp.common end
    return mspCommon.mspSendRequest(cmd, payload)
end

local rxBuf = {}
-- Poll for MSP reply frames over CRSF
transport.mspPoll = function()
    -- Pop only MSP_RESP frames
    local cmd, data = transport.popFrame(CRSF_FRAMETYPE_MSP_RESP)
    if not cmd then return nil end

    -- Validate FROM/TO addresses in the returned data
    if data[1] ~= CRSF_ADDRESS_RADIO_TRANSMITTER
       or data[2] ~= CRSF_ADDRESS_BETAFLIGHT then
        return nil
    end

    -- Reuse rxBuf to avoid allocation
    for i = 1, #rxBuf do rxBuf[i] = nil end

    -- Extract MSP payload (skip CRSF routing bytes: [1]=Dest, [2]=Src)
    for i = 3, #data do
        rxBuf[i - 2] = data[i]
    end

    return rxBuf
end

return transport

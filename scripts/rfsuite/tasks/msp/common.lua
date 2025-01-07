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
-- Protocol version
local MSP_VERSION = (1 << 5)
local MSP_STARTFLAG = (1 << 4)

-- Sequence number for next MSP packet
local mspSeq = 0
local mspRemoteSeq = 0
local mspRxBuf = {}
local mspRxError = false
local mspRxSize = 0
local mspRxCRC = 0
local mspRxReq = 0
local mspStarted = false
local mspLastReq = 0
local mspTxBuf = {}
local mspTxIdx = 1
local mspTxCRC = 0

local function deepCopy(original)
    local copy
    if type(original) == "table" then
        copy = {}
        for key, value in next, original, nil do copy[deepCopy(key)] = deepCopy(value) end
        setmetatable(copy, deepCopy(getmetatable(original)))
    else -- number, string, boolean, etc
        copy = original
    end
    return copy
end

function mspProcessTxQ()
    if (#(mspTxBuf) == 0) then return false end
    -- if not sensor:idle() then  -- was protocol.push() -- maybe sensor:idle()  here??
    -- --rfsuite.utils.log("Sensor not idle... waiting to send cmd: "..tostring(mspLastReq))
    -- return true
    -- end
    rfsuite.utils.log("Sending mspTxBuf size " .. tostring(#mspTxBuf) .. " at Idx " .. tostring(mspTxIdx) .. " for cmd: " .. tostring(mspLastReq))

    local payload = {}
    payload[1] = mspSeq + MSP_VERSION
    mspSeq = (mspSeq + 1) & 0x0F
    if mspTxIdx == 1 then
        -- start flag
        payload[1] = payload[1] + MSP_STARTFLAG
    end
    local i = 2
    while (i <= rfsuite.bg.msp.protocol.maxTxBufferSize) and mspTxIdx <= #mspTxBuf do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        mspTxCRC = mspTxCRC ~ payload[i]
        i = i + 1
    end
    if i <= rfsuite.bg.msp.protocol.maxTxBufferSize then
        payload[i] = mspTxCRC
        i = i + 1
        -- zero fill
        while i <= rfsuite.bg.msp.protocol.maxTxBufferSize do
            payload[i] = 0
            i = i + 1
        end

        rfsuite.bg.msp.protocol.mspSend(payload)
        mspTxBuf = {}
        mspTxIdx = 1
        mspTxCRC = 0
        return false
    end
    rfsuite.bg.msp.protocol.mspSend(payload)
    return true
end

function mspSendRequest(cmd, payload)
    -- rfsuite.utils.log("Sending cmd "..cmd)
    -- busy
    if #(mspTxBuf) ~= 0 or not cmd then
        rfsuite.utils.log("Existing mspTxBuf is still being sent, failed send of cmd: " .. tostring(cmd))
        return nil
    end
    mspTxBuf[1] = #(payload)
    mspTxBuf[2] = cmd & 0xFF -- MSP command
    for i = 1, #(payload) do mspTxBuf[i + 2] = payload[i] & 0xFF end
    mspLastReq = cmd
end

local function mspReceivedReply(payload)
    -- rfsuite.utils.log("Starting mspReceivedReply")
    local idx = 1
    local status = payload[idx]

    local version = (status & 0x60) >> 5
    local start = (status & 0x10) ~= 0
    local seq = status & 0x0F

    idx = idx + 1
    rfsuite.utils.log(" msp sequence #:  " .. string.format("%u", seq))
    if start then
        -- start flag set
        mspRxBuf = {}
        mspRxError = (status & 0x80) ~= 0
        mspRxSize = payload[idx]
        mspRxReq = mspLastReq
        idx = idx + 1
        if version == 1 then
            -- rfsuite.utils.log("version == 1")
            mspRxReq = payload[idx]
            idx = idx + 1
        end
        mspRxCRC = mspRxSize ~ mspRxReq
        if mspRxReq == mspLastReq then mspStarted = true end
    elseif not mspStarted then
        -- rfsuite.utils.log("  mspReceivedReply: missing Start flag")
        return nil
    elseif ((mspRemoteSeq + 1) & 0x0F) ~= seq then
        mspStarted = false
        return nil
    end
    while (idx <= rfsuite.bg.msp.protocol.maxRxBufferSize) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        mspRxCRC = mspRxCRC ~ payload[idx]
        idx = idx + 1
    end
    if idx > rfsuite.bg.msp.protocol.maxRxBufferSize then
        rfsuite.utils.log("  mspReceivedReply:  payload continues into next frame.")
        -- Store the last sequence number so we can start there on the next continuation payload
        mspRemoteSeq = seq
        return false
    end
    mspStarted = false
    -- check CRC
    if mspRxCRC ~= payload[idx] and version == 0 then
        if rfsuite.app.Page ~= nil then if rfsuite.app.Page.mspChecksum then rfsuite.app.Page.mspChecksum(payload) end end
        rfsuite.utils.log("  mspReceivedReply:  payload checksum incorrect, message failed!")
        rfsuite.utils.log("        Calculated mspRxCRC:  0x" .. string.format("%X", mspRxCRC))
        rfsuite.utils.log("        CRC from payload:         0x" .. string.format("%X", payload[idx]))
        return nil
    end
    rfsuite.utils.log("  Got reply for cmd " .. mspRxReq)
    return true
end

--[[
local mspPollReplyScheduler = os.clock()
function mspPollReply()

        local now = os.clock()
        if (now - mspPollReplyScheduler) >= 0.05 then
                mspPollReplyScheduler = now      
                local mspData = rfsuite.bg.msp.protocol.mspPoll()
                if mspData ~= nil and mspReceivedReply(mspData) then
                        mspLastReq = 0
                        return mspRxReq, mspRxBuf, mspRxError
                else
                        return nil,nil,nil
                end
        else
                return nil,nil,nil
        end
end
]] --

--[[
function mspPollReply()

        local mspData = rfsuite.bg.msp.protocol.mspPoll()
        if mspData ~= nil and mspReceivedReply(mspData) then
                mspLastReq = 0
                return mspRxReq, mspRxBuf, mspRxError
        end

        return nil, nil, nil
end
]] --

function mspPollReply()
    local startTime = os.clock()
    while (os.clock() - startTime < 0.1) do
        local mspData = rfsuite.bg.msp.protocol.mspPoll()
        if mspData ~= nil and mspReceivedReply(mspData) then
            mspLastReq = 0
            return mspRxReq, mspRxBuf, mspRxError
        end
    end
    return nil, nil, nil
end

function mspClearTxBuf()
    mspTxBuf = {}
end

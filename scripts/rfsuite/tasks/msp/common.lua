--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MSP_VERSION = (1 << 5)
local MSP_STARTFLAG = (1 << 4)

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

local function mspProcessTxQ()
    if #mspTxBuf == 0 then return false end

    rfsuite.utils.log("Sending mspTxBuf size " .. tostring(#mspTxBuf) .. " at Idx " .. tostring(mspTxIdx) .. " for cmd: " .. tostring(mspLastReq), "debug")

    local payload = {}
    payload[1] = mspSeq + MSP_VERSION
    mspSeq = (mspSeq + 1) & 0x0F
    if mspTxIdx == 1 then payload[1] = payload[1] + MSP_STARTFLAG end

    local i = 2
    while (i <= rfsuite.tasks.msp.protocol.maxTxBufferSize) and mspTxIdx <= #mspTxBuf do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        mspTxCRC = mspTxCRC ~ payload[i]
        i = i + 1
    end

    if i <= rfsuite.tasks.msp.protocol.maxTxBufferSize then
        payload[i] = mspTxCRC
        for j = i + 1, rfsuite.tasks.msp.protocol.maxTxBufferSize do payload[j] = 0 end
        mspTxBuf = {}
        mspTxIdx = 1
        mspTxCRC = 0
        rfsuite.tasks.msp.protocol.mspSend(payload)
        return false
    end
    rfsuite.tasks.msp.protocol.mspSend(payload)
    return true
end

local function mspSendRequest(cmd, payload)
    if not cmd or type(payload) ~= "table" then
        rfsuite.utils.log("Invalid command or payload", "debug")
        return nil
    end
    if #mspTxBuf ~= 0 then
        rfsuite.utils.log("Existing mspTxBuf still sending, failed to send cmd: " .. tostring(cmd), "debug")
        return nil
    end
    mspTxBuf[1] = #payload
    mspTxBuf[2] = cmd & 0xFF
    for i = 1, #payload do mspTxBuf[i + 2] = payload[i] & 0xFF end
    mspLastReq = cmd
end

local function mspReceivedReply(payload)
    local idx = 1
    local status = payload[idx]
    local version = (status & 0x60) >> 5
    local start = (status & 0x10) ~= 0
    local seq = status & 0x0F
    idx = idx + 1

    if start then
        mspRxBuf = {}
        mspRxError = (status & 0x80) ~= 0
        mspRxSize = payload[idx]
        mspRxReq = mspLastReq
        idx = idx + 1
        if version == 1 then
            mspRxReq = payload[idx]
            idx = idx + 1
        end
        mspRxCRC = mspRxSize ~ mspRxReq
        if mspRxReq == mspLastReq then mspStarted = true end
    elseif not mspStarted or ((mspRemoteSeq + 1) & 0x0F) ~= seq then
        mspStarted = false
        return nil
    end

    while (idx <= rfsuite.tasks.msp.protocol.maxRxBufferSize) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        local value = tonumber(payload[idx])
        if value then
            mspRxCRC = mspRxCRC ~ value
        else
            rfsuite.utils.log("Non-numeric value at payload index " .. idx, "debug")
        end
        idx = idx + 1
    end

    if idx > rfsuite.tasks.msp.protocol.maxRxBufferSize then
        mspRemoteSeq = seq
        return false
    end

    mspStarted = false
    if mspRxCRC ~= payload[idx] and version == 0 then
        rfsuite.utils.log("Payload checksum incorrect, message failed!", "debug")
        return nil
    end
    return true
end

local function mspPollReply()
    local startTime = os.clock()

    while os.clock() - startTime < 0.15 do
        local mspData = rfsuite.tasks.msp.protocol.mspPoll()
        if mspData and mspReceivedReply(mspData) then
            mspLastReq = 0
            return mspRxReq, mspRxBuf, mspRxError
        end
    end
    return nil, nil, nil
end

local function mspClearTxBuf() mspTxBuf = {} end

return {mspProcessTxQ = mspProcessTxQ, mspSendRequest = mspSendRequest, mspPollReply = mspPollReply, mspClearTxBuf = mspClearTxBuf}

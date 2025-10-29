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
local mspDefaultVersion = 1
local mspTxVersion = 1

-- CRC8 Dallas/Maxim
local function crc8_update(crc, b)
    crc = (crc ~ (b & 0xFF)) & 0xFF
    for _ = 1, 8 do
        local mix = crc & 0x01
        crc = (crc >> 1) & 0xFF
        if mix ~= 0 then crc = (crc ~ 0x8C) & 0xFF end
    end
    return crc & 0xFF
end

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

-- Build v1 body
local function build_msp_v1_body(cmd, payload)
    local body = {}
    body[1] = #payload & 0xFF
    body[2] = cmd & 0xFF
    local chk = (body[1] ~ body[2]) & 0xFF
    for i=1,#payload do
        local b = payload[i] & 0xFF
        body[#body+1] = b
        chk = chk ~ b
    end
    body[#body+1] = chk & 0xFF
    return body
end

-- Build v2 body
local function build_msp_v2_body(cmd16, payload)
    local len = #payload & 0xFFFF
    local body = {}
    body[1] = (len     ) & 0xFF
    body[2] = (len >> 8) & 0xFF
    body[3] = (cmd16     ) & 0xFF
    body[4] = (cmd16 >> 8) & 0xFF
    local crc = 0
    for i=1,4 do crc = crc8_update(crc, body[i]) end
    for i=1,#payload do
        local b = payload[i] & 0xFF
        body[#body+1] = b
        crc = crc8_update(crc, b)
    end
    body[#body+1] = crc & 0xFF
    return body
end

local function mspSendRequest(cmd, payload, version)
    if not cmd or type(payload) ~= "table" then
        rfsuite.utils.log("Invalid command or payload", "debug")
        return nil
    end
    if #mspTxBuf ~= 0 then
        rfsuite.utils.log("Existing mspTxBuf still sending, failed to send cmd: " .. tostring(cmd), "debug")
        return nil
    end
    local useV =
        (version == 1 or version == 2) and version
        or ((cmd and cmd > 0xFF) and 2)
        or mspDefaultVersion

    if useV == 2 then
        local body = build_msp_v2_body(cmd, payload)
        for i = 1, #body do mspTxBuf[i] = body[i] end
        mspTxVersion = 2
    else
        local body = build_msp_v1_body(cmd, payload)
        for i = 1, #body do mspTxBuf[i] = body[i] end
        mspTxVersion = 1
    end

    mspLastReq = cmd
end

local function mspReceivedReply(payload)
    local idx = 1
    local status = payload[idx]
    local version = (status & 0x60) >> 5
    local start = (status & 0x10) ~= 0
    local seq = status & 0x0F
    idx = idx + 1

    local ver = (status & 0x60) >> 5
    if ver == 2 then
        local lenL = payload[idx] or 0; local lenH = payload[idx+1] or 0; idx = idx + 2
        local funcL = payload[idx] or 0; local funcH = payload[idx+1] or 0; idx = idx + 2
        mspRxSize = (lenH << 8) + lenL
        mspRxReq = (funcH << 8) + funcL
        local crc = 0
        crc = crc8_update(crc, lenL); crc = crc8_update(crc, lenH)
        crc = crc8_update(crc, funcL); crc = crc8_update(crc, funcH)
        mspRxBuf = {}
        local count = 0
        while count < mspRxSize and idx <= #payload - 1 do
            local b = payload[idx] & 0xFF
            mspRxBuf[#mspRxBuf+1] = b
            crc = crc8_update(crc, b)
            idx = idx + 1
            count = count + 1
        end
        local rxcrc = payload[idx] or 0
        if (crc & 0xFF) ~= (rxcrc & 0xFF) then
            rfsuite.utils.log("MSPv2 CRC mismatch", "debug")
            return nil
        end
        return true
    end

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

    while os.clock() - startTime < 0.1 do
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

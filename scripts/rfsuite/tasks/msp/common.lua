--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

-- MSPv2 uses bit 6 in the status byte; keep START flag in bit 4
local MSP_VERSION  = (1 << 6)  -- v2
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
local mspTxCRC = 0   -- kept for optional v1; unused for v2

-- v2 TX queue (no XOR), preserves your chunking + padding behavior
local function mspProcessTxQ()
    if #mspTxBuf == 0 then return false end

    rfsuite.utils.log("Sending mspTxBuf size " .. tostring(#mspTxBuf) ..
        " at Idx " .. tostring(mspTxIdx) .. " for cmd: " .. tostring(mspLastReq), "debug")

    local payload = {}
    payload[1] = mspSeq + MSP_VERSION
    mspSeq = (mspSeq + 1) & 0x0F
    if mspTxIdx == 1 then payload[1] = payload[1] + MSP_STARTFLAG end

    local i = 2
    -- copy bytes into transport payload up to max size
    while (i <= rfsuite.tasks.msp.protocol.maxTxBufferSize) and (mspTxIdx <= #mspTxBuf) do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        -- DO NOT XOR for v2
        i = i + 1
    end

    -- pad remainder with zeros (keeps your original framed size behavior)
    if i <= rfsuite.tasks.msp.protocol.maxTxBufferSize then
        for j = i, rfsuite.tasks.msp.protocol.maxTxBufferSize do payload[j] = 0 end
    end

    -- if we've exhausted TX buffer, reset; otherwise more chunks remain
    local more = (mspTxIdx <= #mspTxBuf)
    if not more then
        mspTxBuf = {}
        mspTxIdx = 1
        mspTxCRC = 0
    end

    rfsuite.tasks.msp.protocol.mspSend(payload)
    return more
end

-- Build v2 request buffer: flags(1), cmdLo(1), cmdHi(1), lenLo(1), lenHi(1), payload...
local function mspSendRequest(cmd, payload)
    if not cmd or type(payload) ~= "table" then
        rfsuite.utils.log("Invalid command or payload", "debug")
        return nil
    end
    if #mspTxBuf ~= 0 then
        rfsuite.utils.log("Existing mspTxBuf still sending, failed to send cmd: " .. tostring(cmd), "debug")
        return nil
    end

    local len = #payload
    mspTxBuf = {}
    mspTxBuf[1] = 0                         -- flags
    mspTxBuf[2] = (cmd & 0xFF)              -- cmdLo
    mspTxBuf[3] = ((cmd >> 8) & 0xFF)       -- cmdHi
    mspTxBuf[4] = (len & 0xFF)              -- lenLo
    mspTxBuf[5] = ((len >> 8) & 0xFF)       -- lenHi
    for i = 1, len do
        mspTxBuf[5 + i] = (payload[i] or 0) & 0xFF
    end

    mspTxIdx   = 1
    mspLastReq = cmd
    -- no XOR for v2
    return true
end

-- RX: parse v2 start chunk header; keep an optional v1 path for compatibility
local function mspReceivedReply(payload)
    local idx = 1
    local status = payload[idx]
    local version = (status & 0x60) >> 5
    local start = (status & 0x10) ~= 0
    local seq = status & 0x0F
    local err = (status & 0x80) ~= 0
    idx = idx + 1

    if start then
        mspRxBuf = {}
        mspRxError = err

        if version == 2 then
            -- MSPv2 header: flags, cmdLo, cmdHi, lenLo, lenHi
            local _flags = payload[idx]; idx = idx + 1
            local cmdLo = payload[idx]; idx = idx + 1
            local cmdHi = payload[idx]; idx = idx + 1
            local lenLo = payload[idx]; idx = idx + 1
            local lenHi = payload[idx]; idx = idx + 1

            mspRxReq  = ((cmdHi << 8) | cmdLo)
            mspRxSize = ((lenHi << 8) | lenLo)
            mspRxCRC  = 0  -- no XOR in v2

        else
            -- MSPv1 (legacy) header: len, cmd, payload..., XOR
            mspRxSize = payload[idx]; idx = idx + 1
            -- for v1 you provided request cmd in frame (v1 example), use it when present:
            mspRxReq = (version == 1) and payload[idx] or mspLastReq
            if version == 1 then idx = idx + 1 end
            mspRxCRC = (mspRxSize ~ mspRxReq)
        end

        if mspRxReq == mspLastReq then mspStarted = true end
    elseif not mspStarted or ((mspRemoteSeq + 1) & 0x0F) ~= seq then
        mspStarted = false
        return nil
    end

    -- copy up to maxRxBufferSize or until we hit declared size
    while (idx <= rfsuite.tasks.msp.protocol.maxRxBufferSize) and (#mspRxBuf < mspRxSize) do
        local b = payload[idx]
        mspRxBuf[#mspRxBuf + 1] = b
        if version ~= 2 then mspRxCRC = (mspRxCRC ~ (tonumber(b) or 0)) end
        idx = idx + 1
    end

    if idx > rfsuite.tasks.msp.protocol.maxRxBufferSize then
        mspRemoteSeq = seq
        return false
    end

    mspStarted = false

    if version ~= 2 then
        -- v1 optional trailing XOR byte
        if mspRxCRC ~= payload[idx] then
            rfsuite.utils.log("Payload checksum incorrect (v1 XOR)", "debug")
            return nil
        end
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

return {
    mspProcessTxQ = mspProcessTxQ,
    mspSendRequest = mspSendRequest,
    mspPollReply = mspPollReply,
    mspClearTxBuf = mspClearTxBuf
}

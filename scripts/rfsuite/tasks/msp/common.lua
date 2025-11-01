--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MSPV_DEFAULT = 2

local MSPV = MSPV_DEFAULT

local function version_bit()

    if MSPV == 2 then
        return (1 << 6)
    else
        return (1 << 5)
    end
end

local MSP_STARTFLAG = (1 << 4)

local mspSeq = 0
local mspRemoteSeq = 0
local mspLastReq = 0
local mspStarted = false

local mspTxBuf = {}
local mspTxIdx = 1
local mspTxCRC = 0

local mspRxBuf = {}
local mspRxReq = 0
local mspRxSize = 0
local mspRxError = false
local mspRxCRC = 0

local function log(msg, lvl) if rfsuite and rfsuite.utils and rfsuite.utils.log then rfsuite.utils.log(msg, lvl or "debug") end end

local function maxTx() return rfsuite.tasks.msp.protocol.maxTxBufferSize end
local function maxRx() return rfsuite.tasks.msp.protocol.maxRxBufferSize end

local function mspSendRequest(cmd, payload)
    if (type(cmd) ~= "number") or (type(payload) ~= "table") then
        log("mspSendRequest: bad args", "debug");
        return nil
    end
    if #mspTxBuf ~= 0 then
        log("mspSendRequest: busy (pending frame for cmd " .. tostring(mspLastReq) .. ")", "debug")
        return nil
    end

    local len = #payload
    mspTxBuf = {}
    mspTxIdx = 1
    mspTxCRC = 0

    if MSPV == 2 then

        local flags = 0
        mspTxBuf[1] = flags
        mspTxBuf[2] = (cmd & 0xFF)
        mspTxBuf[3] = ((cmd >> 8) & 0xFF)
        mspTxBuf[4] = (len & 0xFF)
        mspTxBuf[5] = ((len >> 8) & 0xFF)
        for i = 1, len do mspTxBuf[5 + i] = (payload[i] or 0) & 0xFF end

    else

        mspTxBuf[1] = (len & 0xFF)
        mspTxBuf[2] = (cmd & 0xFF)
        mspTxCRC = (mspTxBuf[1] ~ mspTxBuf[2])
        for i = 1, len do
            local b = (payload[i] or 0) & 0xFF
            mspTxBuf[2 + i] = b
            mspTxCRC = (mspTxCRC ~ b)
        end
        mspTxBuf[#mspTxBuf + 1] = (mspTxCRC & 0xFF)
    end

    mspLastReq = cmd
    return true
end

local function mspProcessTxQ()
    if #mspTxBuf == 0 then return false end

    log("Sending mspTxBuf size " .. tostring(#mspTxBuf) .. " at Idx " .. tostring(mspTxIdx) .. " for cmd: " .. tostring(mspLastReq), "debug")

    local payload = {}
    payload[1] = (mspSeq + version_bit())
    mspSeq = (mspSeq + 1) & 0x0F
    if mspTxIdx == 1 then payload[1] = payload[1] + MSP_STARTFLAG end

    local i = 2
    local max = maxTx()
    while (i <= max) and (mspTxIdx <= #mspTxBuf) do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        i = i + 1
    end

    if i <= max then for j = i, max do payload[j] = 0 end end

    local more = (mspTxIdx <= #mspTxBuf)
    if not more then
        mspTxBuf = {}
        mspTxIdx = 1
        mspTxCRC = 0
    end

    rfsuite.tasks.msp.protocol.mspSend(payload)
    return more
end

local function mspReceivedReply(payload)
    if (type(payload) ~= "table") or (#payload == 0) then return nil end

    local idx = 1
    local status = payload[idx];
    idx = idx + 1
    local err = ((status & 0x80) ~= 0)
    local start = ((status & MSP_STARTFLAG) ~= 0)
    local seq = (status & 0x0F)
    local ver = ((status & 0x60) >> 5)

    if start then

        mspRxBuf = {}
        mspRxError = err

        if ver == 2 then

            local flags = payload[idx];
            idx = idx + 1
            local cmdLo = payload[idx];
            idx = idx + 1
            local cmdHi = payload[idx];
            idx = idx + 1
            local lenLo = payload[idx];
            idx = idx + 1
            local lenHi = payload[idx];
            idx = idx + 1
            mspRxReq = ((cmdHi << 8) | cmdLo)
            mspRxSize = ((lenHi << 8) | lenLo)

            mspRxCRC = 0
        elseif ver == 1 then

            mspRxSize = payload[idx];
            idx = idx + 1
            mspRxReq = payload[idx];
            idx = idx + 1
            mspRxCRC = (mspRxSize ~ mspRxReq)
        else
            log("Unsupported MSP version in RX: " .. tostring(ver), "debug")
            return nil
        end

        if mspRxReq == mspLastReq then mspStarted = true end
    else
        if (not mspStarted) or (((mspRemoteSeq + 1) & 0x0F) ~= seq) then
            mspStarted = false
            log("RX out of sequence", "debug")
            return nil
        end
    end

    while (idx <= #payload) and (#mspRxBuf < mspRxSize) do
        local b = payload[idx]
        mspRxBuf[#mspRxBuf + 1] = b
        if ver == 1 then mspRxCRC = (mspRxCRC ~ (b or 0)) end
        idx = idx + 1
    end

    if #mspRxBuf < mspRxSize then
        mspRemoteSeq = seq
        return false
    end

    mspStarted = false

    if ver == 1 then

        if idx <= #payload then
            local tail = payload[idx]
            if mspRxCRC ~= tail then
                log("MSP v1 XOR mismatch", "debug")
                return nil
            end
        end
    end

    return true
end

local function mspPollReply()
    local startTime = os.clock()
    while (os.clock() - startTime) < 0.1 do
        local mspData = rfsuite.tasks.msp.protocol.mspPoll()
        if mspData and mspReceivedReply(mspData) then
            mspLastReq = 0
            return mspRxReq, mspRxBuf, mspRxError
        end
    end
    return nil, nil, nil
end

local function mspClearTxBuf()
    mspTxBuf = {}
    mspTxIdx = 1
    mspTxCRC = 0
end

local function setMSPVersion(v)
    if v == 1 or v == 2 then
        MSPV = v
        log("MSP version set to v" .. tostring(v), "debug")
    else
        log("setMSPVersion: ignored invalid value " .. tostring(v), "debug")
    end
end

local function getMSPVersion() return MSPV end

return {mspProcessTxQ = mspProcessTxQ, mspSendRequest = mspSendRequest, mspReceivedReply = mspReceivedReply, mspPollReply = mspPollReply, mspClearTxBuf = mspClearTxBuf, setMSPVersion = setMSPVersion, getMSPVersion = getMSPVersion}

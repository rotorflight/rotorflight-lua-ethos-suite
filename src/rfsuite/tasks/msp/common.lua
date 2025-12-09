--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local function proto() return rfsuite.tasks.msp.protocol end
local function maxTx() return proto().maxTxBufferSize end
local function maxRx() return proto().maxRxBufferSize end
local function pollBudget()
    local budget = (rfsuite.app and rfsuite.app.Page and rfsuite.app.Page.mspPollBudget)  or proto().mspPollBudget or 0.1
    return type(budget) == "function" and budget() or budget
end


local _mspVersion = 1
local MSP_VERSION_BIT = (1 << 5)
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

local function setProtocolVersion(v)
    v = tonumber(v)
    _mspVersion = (v == 2) and 2 or 1
end

local function getProtocolVersion() return _mspVersion end

local function _mkStatusByte(isStart)
    local versionBits = (_mspVersion == 2) and (2 << 5) or MSP_VERSION_BIT
    local status = (mspSeq + versionBits)
    if isStart then status = status + MSP_STARTFLAG end
    return status & 0x7F
end

local function mspClearTxBuf()
    mspTxBuf = {}
    mspTxIdx = 1
    mspTxCRC = 0
end

local function mspProcessTxQ()
    if #mspTxBuf == 0 then return false end

    local payload = {}
    payload[1] = _mkStatusByte(mspTxIdx == 1)
    mspSeq = (mspSeq + 1) & 0x0F

    local i = 2
    while (i <= maxTx()) and (mspTxIdx <= #mspTxBuf) do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        if _mspVersion == 1 then mspTxCRC = mspTxCRC ~ payload[i] end
        i = i + 1
    end

    if _mspVersion == 1 then
        if i <= maxTx() then
            payload[i] = mspTxCRC
            for j = i + 1, maxTx() do payload[j] = 0 end
            mspTxBuf, mspTxIdx, mspTxCRC = {}, 1, 0
            proto().mspSend(payload)
            return false
        else
            proto().mspSend(payload)
            return true
        end
    else
        for j = i, maxTx() do payload[j] = payload[j] or 0 end
        proto().mspSend(payload)
        if mspTxIdx > #mspTxBuf then
            mspTxBuf, mspTxIdx, mspTxCRC = {}, 1, 0
            return false
        end
        return true
    end
end

local function mspSendRequest(cmd, payload)
    if type(payload) ~= "table" or (not cmd) then return nil end
    if #mspTxBuf ~= 0 then return nil end

    if _mspVersion == 1 then
        mspTxBuf[1] = #payload
        mspTxBuf[2] = cmd & 0xFF
        for i = 1, #payload do mspTxBuf[i + 2] = payload[i] & 0xFF end
    else
        local len = #payload
        local cmd1 = cmd % 256
        local cmd2 = math.floor(cmd / 256) % 256
        local len1 = len % 256
        local len2 = math.floor(len / 256) % 256
        mspTxBuf = {0, cmd1, cmd2, len1, len2}
        for i = 1, len do mspTxBuf[#mspTxBuf + 1] = payload[i] % 256 end
    end

    mspLastReq = cmd
    mspTxIdx = 1
    mspTxCRC = 0
end

local function _receivedReply(payload)
    local idx = 1
    local status = payload[idx] or 0
    local versionBits = (status & 0x60) >> 5
    local start = (status & 0x10) ~= 0
    local seq = status & 0x0F
    idx = idx + 1

    if start then
        mspRxBuf = {}
        mspRxError = (status & 0x80) ~= 0

        if _mspVersion == 2 then
            local flags = payload[idx] or 0;
            idx = idx + 1
            local cmd1 = payload[idx] or 0;
            idx = idx + 1
            local cmd2 = payload[idx] or 0;
            idx = idx + 1
            local len1 = payload[idx] or 0;
            idx = idx + 1
            local len2 = payload[idx] or 0;
            idx = idx + 1
            mspRxReq = ((cmd2 & 0xFF) << 8) | (cmd1 & 0xFF)
            mspRxSize = ((((len2 & 0xFF) << 8) | (len1 & 0xFF)) & 0xFFFF)
            mspRxCRC = 0
            mspStarted = (mspRxReq == mspLastReq)
        else
            mspRxSize = payload[idx] or 0;
            idx = idx + 1
            mspRxReq = mspLastReq
            if versionBits == 1 then
                mspRxReq = payload[idx] or 0;
                idx = idx + 1
            end
            mspRxCRC = (mspRxSize ~ mspRxReq)
            mspStarted = (mspRxReq == mspLastReq)
        end
    else
        if (not mspStarted) or (((mspRemoteSeq + 1) & 0x0F) ~= seq) then
            mspStarted = false
            return nil
        end
    end

    while (idx <= maxRx()) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        if _mspVersion == 1 then
            local v = tonumber(payload[idx])
            if v then mspRxCRC = mspRxCRC ~ v end
        end
        idx = idx + 1
    end

    local needMore = (#mspRxBuf < mspRxSize)
    if needMore then
        mspRemoteSeq = seq
        return false
    end

    mspStarted = false

    if _mspVersion == 1 then
        local rxCRC = payload[idx] or 0
        if mspRxCRC ~= rxCRC and versionBits == 0 then return nil end
    end

    return true
end

local function mspPollReply()
    local budget = pollBudget() or 0.1
    local startTime = os.clock()
    while os.clock() - startTime < budget do
        local pkt = proto().mspPoll()
        if pkt and _receivedReply(pkt) then
            mspLastReq = 0
            return mspRxReq, mspRxBuf, mspRxError
        end
    end
    return nil, nil, nil
end

return {setProtocolVersion = setProtocolVersion, getProtocolVersion = getProtocolVersion, mspProcessTxQ = mspProcessTxQ, mspSendRequest = mspSendRequest, mspPollReply = mspPollReply, mspClearTxBuf = mspClearTxBuf}

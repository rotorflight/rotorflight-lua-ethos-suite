--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local _mspLogLevel = 0
local _mspHexDump = false
local _mspPrefix = "[MSP] "

local function _lev(name)
    name = tostring(name or ""):lower()
    if name == "off" then return 0 end
    if name == "basic" or name == "info" then return 1 end
    if name == "verbose" or name == "debug" then return 2 end
    if name == "trace" then return 3 end
    if tonumber(name) then return math.max(0, math.min(3, tonumber(name))) end
    return 2
end

local function setLogging(level, opts)
    _mspLogLevel = _lev(level)
    if type(opts) == "table" then
        if opts.hexdump ~= nil then _mspHexDump = opts.hexdump and true or false end
        if type(opts.prefix) == "string" then _mspPrefix = opts.prefix end
    end
    rfsuite.utils.log(_mspPrefix .. "logging set to level=" .. tostring(_mspLogLevel) .. (_mspHexDump and " (hexdump on)" or " (hexdump off)"), "debug")
end

local function getLogging() return {level = _mspLogLevel, hexdump = _mspHexDump, prefix = _mspPrefix} end

local function _log(level, msg) if _mspLogLevel >= level then rfsuite.utils.log(_mspPrefix .. msg, "info") end end

local function _hex(buf, maxLen)
    if not _mspHexDump or type(buf) ~= "table" then return end
    local n = math.min(#buf, maxLen or 64)
    local t = {}
    for i = 1, n do t[#t + 1] = string.format("%02X", (buf[i] or 0) & 0xFF) end
    rfsuite.utils.log(_mspPrefix .. "HEX[" .. tostring(n) .. "]: " .. table.concat(t, " "), "debug")
    if #buf > n then rfsuite.utils.log(_mspPrefix .. "(+" .. tostring(#buf - n) .. " more bytes)", "debug") end
end

local _mspVersion = 1
local function setProtocolVersion(v)
    v = tonumber(v)
    _mspVersion = (v == 2) and 2 or 1
    _log(1, "MSP protocol set to v" .. tostring(_mspVersion))
end
local function getProtocolVersion() return _mspVersion end

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

local function _mkStatusByte(isStart)
    local versionBits = (_mspVersion == 2) and (2 << 5) or MSP_VERSION_BIT
    local status = (mspSeq + versionBits)
    if isStart then status = status + MSP_STARTFLAG end
    return status & 0x7F
end

local function mspClearTxBuf()
    _log(2, "Clearing TX buffer (discard " .. tostring(#mspTxBuf) .. " bytes)")
    mspTxBuf = {}
    mspTxIdx = 1
    mspTxCRC = 0
end

local handlers = {v1 = {}, v2 = {}}

function handlers.v1.processTxQ()
    if #mspTxBuf == 0 then return false end

    _log(2, "TXQ(v1) size=" .. tostring(#mspTxBuf) .. " idx=" .. tostring(mspTxIdx) .. " lastReq=" .. tostring(mspLastReq))

    local payload = {}
    payload[1] = _mkStatusByte(mspTxIdx == 1)
    mspSeq = (mspSeq + 1) & 0x0F

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
        _log(3, "TX frame final chunk; CRC=" .. string.format("0x%02X", mspTxCRC))
        _hex(payload, rfsuite.tasks.msp.protocol.maxTxBufferSize)
        mspTxBuf, mspTxIdx, mspTxCRC = {}, 1, 0
        rfsuite.tasks.msp.protocol.mspSend(payload)
        return false
    end

    _log(3, "TX frame partial chunk sent (continuation)")
    _hex(payload, rfsuite.tasks.msp.protocol.maxTxBufferSize)
    rfsuite.tasks.msp.protocol.mspSend(payload)
    return true
end

function handlers.v1.sendRequest(cmd, payload)
    if not cmd or type(payload) ~= "table" then
        _log(1, "Refused to send: invalid command or payload")
        return nil
    end
    if #mspTxBuf ~= 0 then
        _log(1, "Busy: previous TX not finished, drop cmd=" .. tostring(cmd))
        return nil
    end
    mspTxBuf[1] = #payload
    mspTxBuf[2] = cmd & 0xFF
    for i = 1, #payload do mspTxBuf[i + 2] = payload[i] & 0xFF end
    mspLastReq = cmd
    mspTxIdx = 1
    mspTxCRC = 0

    _log(2, "Enqueued request cmd=" .. tostring(cmd) .. " len=" .. tostring(#payload))
    _hex(mspTxBuf, rfsuite.tasks.msp.protocol.maxTxBufferSize)
end

function handlers.v1.receivedReply(payload)
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

        _log(2, ("RX start: ver=%d seq=%d size=%d req=%d err=%s started=%s"):format(version, seq, mspRxSize, mspRxReq, tostring(mspRxError), tostring(mspStarted)))
    elseif not mspStarted or ((mspRemoteSeq + 1) & 0x0F) ~= seq then
        _log(1, ("RX out-of-seq or not started: last=%d got=%d started=%s"):format(mspRemoteSeq, seq, tostring(mspStarted)))
        mspStarted = false
        return nil
    end

    while (idx <= rfsuite.tasks.msp.protocol.maxRxBufferSize) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        local value = tonumber(payload[idx])
        if value then
            mspRxCRC = mspRxCRC ~ value
        else
            _log(1, "RX non-numeric value at payload[" .. idx .. "]")
        end
        idx = idx + 1
    end

    if idx > rfsuite.tasks.msp.protocol.maxRxBufferSize then
        mspRemoteSeq = seq
        _log(3, "RX continuation expected; seq=" .. tostring(seq) .. " collected=" .. tostring(#mspRxBuf) .. "/" .. tostring(mspRxSize))
        return false
    end

    mspStarted = false
    local rxCRC = payload[idx]
    if mspRxCRC ~= rxCRC and version == 0 then
        _log(1, ("RX CRC mismatch (v0): calc=0x%02X recv=0x%02X"):format(mspRxCRC & 0xFF, rxCRC & 0xFF))
        return nil
    end

    _log(2, ("RX complete: seq=%d len=%d req=%d err=%s"):format(seq, #mspRxBuf, mspRxReq, tostring(mspRxError)))
    _hex(mspRxBuf, rfsuite.tasks.msp.protocol.maxRxBufferSize)

    return true
end

function handlers.v1.pollReply()
    local startTime = os.clock()
    _log(3, "Polling for reply (100ms budget)")

    while os.clock() - startTime < 0.1 do
        local mspData = rfsuite.tasks.msp.protocol.mspPoll()
        if mspData then
            _log(3, "Polled data available")
            if handlers.v1.receivedReply(mspData) then
                _log(2, "Reply ready for lastReq=" .. tostring(mspLastReq))
                mspLastReq = 0
                return mspRxReq, mspRxBuf, mspRxError
            end
        end
    end
    _log(3, "Polling timed out (no complete reply)")
    return nil, nil, nil
end

function handlers.v2.processTxQ()
    if #mspTxBuf == 0 then return false end

    _log(2, "TXQ(v2) size=" .. tostring(#mspTxBuf) .. " idx=" .. tostring(mspTxIdx) .. " lastReq=" .. tostring(mspLastReq))

    local payload = {}
    payload[1] = _mkStatusByte(mspTxIdx == 1)
    mspSeq = (mspSeq + 1) % 16

    local i = 2
    while (i <= rfsuite.tasks.msp.protocol.maxTxBufferSize) and (mspTxIdx <= #mspTxBuf) do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        i = i + 1
    end

    for j = i, rfsuite.tasks.msp.protocol.maxTxBufferSize do payload[j] = payload[j] or 0 end

    _hex(payload, rfsuite.tasks.msp.protocol.maxTxBufferSize)
    rfsuite.tasks.msp.protocol.mspSend(payload)

    if mspTxIdx > #mspTxBuf then
        mspTxBuf, mspTxIdx, mspTxCRC = {}, 1, 0
        return false
    end

    return true
end

function handlers.v2.sendRequest(cmd, payload)
    if type(cmd) ~= "number" or type(payload) ~= "table" then
        _log(1, "Refused to send(v2): invalid command or payload")
        return nil
    end
    if #mspTxBuf ~= 0 then
        _log(1, "Busy(v2): previous TX not finished, drop cmd=" .. tostring(cmd))
        return nil
    end

    local len = #payload
    local cmd1 = cmd % 256
    local cmd2 = math.floor(cmd / 256) % 256
    local len1 = len % 256
    local len2 = math.floor(len / 256) % 256

    mspTxBuf = {0, cmd1, cmd2, len1, len2}
    for i = 1, len do mspTxBuf[#mspTxBuf + 1] = payload[i] % 256 end

    mspLastReq = cmd
    mspTxIdx = 1
    mspTxCRC = 0
    _log(2, "Enqueued(v2) cmd=" .. tostring(cmd) .. " len=" .. tostring(len))
    _hex(mspTxBuf, rfsuite.tasks.msp.protocol.maxTxBufferSize)
end

function handlers.v2.receivedReply(payload)
    local idx = 1
    local status = payload[idx] or 0
    local version = (status & 0x60) >> 5
    local start = (status & 0x10) ~= 0
    local seq = status & 0x0F
    idx = idx + 1

    if start then

        mspRxBuf = {}
        mspRxError = (status & 0x80) ~= 0

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
        mspRxSize = (((len2 & 0xFF) << 8) | (len1 & 0xFF)) & 0xFFFF
        mspRxCRC = 0
        mspStarted = (mspRxReq == mspLastReq)

        _log(2, ("RXv2 start: ver=%d seq=%d flags=0x%02X size=%d req=%d started=%s"):format(version, seq, flags, mspRxSize, mspRxReq, tostring(mspStarted)))
    else

        if (not mspStarted) or (((mspRemoteSeq + 1) & 0x0F) ~= seq) then
            _log(1, ("RXv2 out-of-seq or not started: last=%d got=%d started=%s"):format(mspRemoteSeq or -1, seq, tostring(mspStarted)))
            mspStarted = false
            return nil
        end
    end

    while (idx <= rfsuite.tasks.msp.protocol.maxRxBufferSize) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        idx = idx + 1
    end

    local needMore = (#mspRxBuf < mspRxSize)

    if needMore then

        mspRemoteSeq = seq

        if idx > rfsuite.tasks.msp.protocol.maxRxBufferSize then
            _log(3, "RXv2 continuation expected; seq=" .. tostring(seq) .. " collected=" .. tostring(#mspRxBuf) .. "/" .. tostring(mspRxSize))
        else

            _log(3, "RXv2 partial; awaiting more bytes (seq=" .. tostring(seq) .. " collected=" .. tostring(#mspRxBuf) .. "/" .. tostring(mspRxSize) .. ")")
        end
        return false
    end

    mspStarted = false
    _log(2, ("RXv2 complete: seq=%d len=%d req=%d err=%s"):format(seq, #mspRxBuf, mspRxReq, tostring(mspRxError)))
    _hex(mspRxBuf, rfsuite.tasks.msp.protocol.maxRxBufferSize)
    return true
end

function handlers.v2.pollReply()
    local startTime = os.clock()
    _log(3, "Polling for v2 reply (100ms budget)")
    while os.clock() - startTime < 0.1 do
        local mspData = rfsuite.tasks.msp.protocol.mspPoll()

        if mspData and handlers.v2.receivedReply(mspData) then
            mspLastReq = 0
            return mspRxReq, mspRxBuf, mspRxError
        end
    end
    return nil, nil, nil
end

local function _h() return (_mspVersion == 2) and handlers.v2 or handlers.v1 end
local function mspProcessTxQ() return _h().processTxQ() end
local function mspSendRequest(cmd, payload) return _h().sendRequest(cmd, payload) end
local function mspPollReply() return _h().pollReply() end

return {mspProcessTxQ = mspProcessTxQ, mspSendRequest = mspSendRequest, mspPollReply = mspPollReply, mspClearTxBuf = mspClearTxBuf, setLogging = setLogging, getLogging = getLogging, setProtocolVersion = setProtocolVersion, getProtocolVersion = getProtocolVersion}

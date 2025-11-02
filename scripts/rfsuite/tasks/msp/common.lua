--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

-- ===== Logging controls ======================================================
-- Levels: 0=off, 1=basic, 2=verbose, 3=trace
local _mspLogLevel = 3
local _mspHexDump   = false
local _mspPrefix    = "[MSP] "

local function _lev(name)
    name = tostring(name or ""):lower()
    if name == "off" then return 0 end
    if name == "basic" or name == "info" then return 1 end
    if name == "verbose" or name == "debug" then return 2 end
    if name == "trace" then return 3 end
    if tonumber(name) then return math.max(0, math.min(3, tonumber(name))) end
    return 2 -- default if unknown
end

local function setLogging(level, opts)
    _mspLogLevel = _lev(level)
    if type(opts) == "table" then
        if opts.hexdump ~= nil then _mspHexDump = opts.hexdump and true or false end
        if type(opts.prefix) == "string" then _mspPrefix = opts.prefix end
    end
    rfsuite.utils.log(_mspPrefix .. "logging set to level=" .. tostring(_mspLogLevel) ..
        (_mspHexDump and " (hexdump on)" or " (hexdump off)"), "debug")
end

local function getLogging()
    return { level = _mspLogLevel, hexdump = _mspHexDump, prefix = _mspPrefix }
end

local function _log(level, msg)
    if _mspLogLevel >= level then
        print(_mspPrefix .. msg)
    end
end

local function _hex(buf, maxLen)
    if not _mspHexDump or type(buf) ~= "table" then return end
    local n = math.min(#buf, maxLen or 64)
    local t = {}
    for i = 1, n do t[#t + 1] = string.format("%02X", (buf[i] or 0) & 0xFF) end
    rfsuite.utils.log(_mspPrefix .. "HEX[" .. tostring(n) .. "]: " .. table.concat(t, " "), "debug")
    if #buf > n then
        rfsuite.utils.log(_mspPrefix .. "(+" .. tostring(#buf - n) .. " more bytes)", "debug")
    end
end
-- ============================================================================

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

    _log(2, "TXQ size=" .. tostring(#mspTxBuf) ..
        " idx=" .. tostring(mspTxIdx) .. " lastReq=" .. tostring(mspLastReq))

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
        _log(3, "TX frame final chunk; CRC=" .. string.format("0x%02X", mspTxCRC))

        _hex(payload, rfsuite.tasks.msp.protocol.maxTxBufferSize)

        mspTxBuf = {}
        mspTxIdx = 1
        mspTxCRC = 0
        rfsuite.tasks.msp.protocol.mspSend(payload)
        return false
    end

    _log(3, "TX frame partial chunk sent (continuation)")
    _hex(payload, rfsuite.tasks.msp.protocol.maxTxBufferSize)

    rfsuite.tasks.msp.protocol.mspSend(payload)
    return true
end

local function mspSendRequest(cmd, payload)
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

        _log(2, ("RX start: ver=%d seq=%d size=%d req=%d err=%s started=%s")
            :format(version, seq, mspRxSize, mspRxReq, tostring(mspRxError), tostring(mspStarted)))
    elseif not mspStarted or ((mspRemoteSeq + 1) & 0x0F) ~= seq then
        _log(1, ("RX out-of-seq or not started: last=%d got=%d started=%s")
            :format(mspRemoteSeq, seq, tostring(mspStarted)))
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
        _log(3, "RX continuation expected; seq=" .. tostring(seq) ..
            " collected=" .. tostring(#mspRxBuf) .. "/" .. tostring(mspRxSize))
        return false
    end

    mspStarted = false
    local rxCRC = payload[idx]
    if mspRxCRC ~= rxCRC and version == 0 then
        _log(1, ("RX CRC mismatch (v0): calc=0x%02X recv=0x%02X"):format(mspRxCRC & 0xFF, rxCRC & 0xFF))
        return nil
    end

    _log(2, ("RX complete: seq=%d len=%d req=%d err=%s")
        :format(seq, #mspRxBuf, mspRxReq, tostring(mspRxError)))
    _hex(mspRxBuf, rfsuite.tasks.msp.protocol.maxRxBufferSize)

    return true
end

local function mspPollReply()
    local startTime = os.clock()
    _log(3, "Polling for reply (100ms budget)")

    while os.clock() - startTime < 0.1 do
        local mspData = rfsuite.tasks.msp.protocol.mspPoll()
        if mspData then
            _log(3, "Polled data available")
            if mspReceivedReply(mspData) then
                _log(2, "Reply ready for lastReq=" .. tostring(mspLastReq))
                mspLastReq = 0
                return mspRxReq, mspRxBuf, mspRxError
            end
        end
    end
    _log(3, "Polling timed out (no complete reply)")
    return nil, nil, nil
end

local function mspClearTxBuf()
    _log(2, "Clearing TX buffer (discard " .. tostring(#mspTxBuf) .. " bytes)")
    mspTxBuf = {}
    mspTxIdx = 1
    mspTxCRC = 0
end

-- Public API (added set/get logging for comprehensive debugging)
return {
    mspProcessTxQ = mspProcessTxQ,
    mspSendRequest = mspSendRequest,
    mspPollReply = mspPollReply,
    mspClearTxBuf = mspClearTxBuf,
    setLogging = setLogging,
    getLogging = getLogging
}

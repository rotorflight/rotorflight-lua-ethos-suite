--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")


-- Optional protocol trace logger (raw frames). Inert unless enabled.
local function plog(dir, cmd, payload, extra)
    local m = rfsuite.tasks and rfsuite.tasks.msp
    local logger = m and m.proto_logger
    if not (logger and logger.enabled and logger.log) then return end
    local protoName = (m.protocol and m.protocol.mspProtocol) or "?"
    local qid = (m.mspQueue and m.mspQueue.currentMessage and m.mspQueue.currentMessage._qid) or nil
    local qidTxt = qid and (" QID=" .. tostring(qid)) or ""
    logger.log(dir, protoName, cmd, payload, (extra or "") .. qidTxt)
end

-- Convenience wrappers for protocol buffer sizes
local function proto() return rfsuite.tasks.msp.protocol end
local function maxTx() return proto().maxTxBufferSize end
local function maxRx() return proto().maxRxBufferSize end

local _mspVersion = 1
local MSP_VERSION_BIT = (1 << 5)     -- Default V1 version bit
local MSP_STARTFLAG   = (1 << 4)     -- Indicates start of a new frame

-- Sequencing and buffers
local mspSeq        = 0              -- Local transmit sequence
local mspRemoteSeq  = 0              -- Remote receive sequence
local mspRxBuf      = {}             -- Incoming payload buffer
local mspRxError    = false          -- Error flag from remote
local mspRxSize     = 0              -- Expected RX payload size
local mspRxCRC      = 0              -- Accumulated CRC for V1
local mspRxReq      = 0              -- Command ID of reply
local mspStarted    = false          -- True when in middle of multi-frame RX
local mspLastReq    = 0              -- Command ID we last sent
local mspTxBuf      = {}             -- Outgoing payload buffer
local mspTxIdx      = 1              -- Write pointer into TX buffer
local mspTxCRC      = 0              -- Running CRC for V1

-- Set protocol: only 1 or 2 are valid
local function setProtocolVersion(v)
    v = tonumber(v)
    _mspVersion = (v == 2) and 2 or 1
end

-- Computes poll timeout budget dynamically based on message size
local function pollBudget()
    -- These tuning knobs determine how aggressively polling scales
    local TUNE = {
        threshold_windows = 6,   -- Boost after N poll windows
        step_seconds      = 0.03,-- Extra seconds per window beyond threshold
        cap_seconds       = 0.35 -- Hard max
    }

    -- Protocol-specific throughput
    local proto   = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.protocol or {}
    -- Default poll budget: keep this modest to reduce instruction burn on the radio.
    -- Large/slow payloads still get additional budget via the boost logic below.
    local base    = proto.mspPollBudget or 0.07
    local perPoll = proto.maxRxBufferSize or 6

    -- Determine cost of currently pending message
    local q   = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
    local msg = q and q.currentMessage
    local rx  = (msg and msg.minBytes) or 0
    local tx  = (msg and msg.payload and #msg.payload) or 0
    local pending = math.max(rx, tx)

    -- Compute boost when message size is large
    local threshold = (TUNE.threshold_windows * perPoll)
    local boost = 0
    if perPoll > 0 and pending > threshold then
        local extraWindows = math.ceil((pending - threshold) / perPoll)
        boost = extraWindows * TUNE.step_seconds
    end

    local final = base + boost
    if final > TUNE.cap_seconds then final = TUNE.cap_seconds end

    return final
end

local function getProtocolVersion() return _mspVersion end

-- Build the MSP status byte (version bits + seq + start flag)
local function _mkStatusByte(isStart)
    local versionBits = (_mspVersion == 2) and (2 << 5) or MSP_VERSION_BIT
    local status = (mspSeq + versionBits)
    if isStart then status = status + MSP_STARTFLAG end
    return status & 0x7F
end

-- Reset TX buffer state
local function mspClearTxBuf()
    mspTxBuf = {}
    mspTxIdx = 1
    mspTxCRC = 0
end

-- Process TX buffer into protocol-sized packets
local function mspProcessTxQ()
    if #mspTxBuf == 0 then return false end

    local payload = {}
    payload[1] = _mkStatusByte(mspTxIdx == 1) -- Mark start of frame
    mspSeq = (mspSeq + 1) & 0x0F

    -- Fill payload until maxTx or TX buffer exhausted
    local i = 2
    while (i <= maxTx()) and (mspTxIdx <= #mspTxBuf) do
        payload[i] = mspTxBuf[mspTxIdx]
        mspTxIdx = mspTxIdx + 1
        if _mspVersion == 1 then mspTxCRC = mspTxCRC ~ payload[i] end
        i = i + 1
    end

    if _mspVersion == 1 then
        -- For V1, include CRC when final packet
        if i <= maxTx() then
            payload[i] = mspTxCRC
            for j = i + 1, maxTx() do payload[j] = 0 end
            mspTxBuf, mspTxIdx, mspTxCRC = {}, 1, 0
            plog("TX", mspLastReq, payload, "ST=" .. tostring(payload[1] or 0) .. " TXIDX=" .. tostring(mspTxIdx) .. " TXBUF=" .. tostring(#mspTxBuf))
            proto().mspSend(payload)
            return false
        else
            plog("TX", mspLastReq, payload, "ST=" .. tostring(payload[1] or 0) .. " TXIDX=" .. tostring(mspTxIdx) .. " TXBUF=" .. tostring(#mspTxBuf))
            proto().mspSend(payload)
            return true
        end
    else
        -- V2 pads unused bytes but CRC is handled differently
        for j = i, maxTx() do payload[j] = payload[j] or 0 end
            plog("TX", mspLastReq, payload, "ST=" .. tostring(payload[1] or 0) .. " TXIDX=" .. tostring(mspTxIdx) .. " TXBUF=" .. tostring(#mspTxBuf))
            proto().mspSend(payload)
        if mspTxIdx > #mspTxBuf then
            mspTxBuf, mspTxIdx, mspTxCRC = {}, 1, 0
            return false
        end
        return true
    end
end

-- Format and queue an MSP request for transmission
local function mspSendRequest(cmd, payload)
    if type(payload) ~= "table" or (not cmd) then return false end
    if #mspTxBuf ~= 0 then return false end -- TX already busy

    if _mspVersion == 1 then
        -- V1: length + cmd + payload
        mspTxBuf[1] = #payload
        mspTxBuf[2] = cmd & 0xFF
        for i = 1, #payload do mspTxBuf[i + 2] = payload[i] & 0xFF end
    else
        -- V2: flags=0, CMD16, LEN16
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

    return true
end

-- Internal: process one reply packet
local function _receivedReply(payload)
    local idx = 1
    local status = payload[idx] or 0
    local versionBits = (status & 0x60) >> 5
    local start = (status & 0x10) ~= 0
    local seq = status & 0x0F
    idx = idx + 1

    if start then
        -- Start of new frame
        mspRxBuf = {}
        mspRxError = (status & 0x80) ~= 0

        if _mspVersion == 2 then
            -- Parse V2 header
            local flags = payload[idx] or 0; idx = idx + 1
            local cmd1 = payload[idx] or 0;   idx = idx + 1
            local cmd2 = payload[idx] or 0;   idx = idx + 1
            local len1 = payload[idx] or 0;   idx = idx + 1
            local len2 = payload[idx] or 0;   idx = idx + 1
            mspRxReq = ((cmd2 & 0xFF) << 8) | (cmd1 & 0xFF)
            mspRxSize = ((((len2 & 0xFF) << 8) | (len1 & 0xFF)) & 0xFFFF)
            mspRxCRC = 0
            mspStarted = (mspRxReq == mspLastReq)
        else
            -- Parse V1 header
            mspRxSize = payload[idx] or 0; idx = idx + 1
            mspRxReq = mspLastReq
            if versionBits == 1 then
                mspRxReq = payload[idx] or 0; idx = idx + 1
            end
            mspRxCRC = (mspRxSize ~ mspRxReq)
            mspStarted = (mspRxReq == mspLastReq)
        end
    else
        -- Continuation frame: ensure sequencing is correct
        if (not mspStarted) or (((mspRemoteSeq + 1) & 0x0F) ~= seq) then
            mspStarted = false
            mspRxBuf = {}
            mspRxSize = 0
            mspRxCRC = 0
            mspRemoteSeq = 0
            return nil
        end
    end

    -- Copy payload bytes
    while (idx <= maxRx()) and (#mspRxBuf < mspRxSize) do
        mspRxBuf[#mspRxBuf + 1] = payload[idx]
        if _mspVersion == 1 then
            local v = tonumber(payload[idx])
            if v then mspRxCRC = mspRxCRC ~ v end
        end
        idx = idx + 1
    end

    -- Not complete yet
    local needMore = (#mspRxBuf < mspRxSize)
    if needMore then
        mspRemoteSeq = seq
        return false
    end

    mspStarted = false

    -- V1 CRC check
    if _mspVersion == 1 then
        local rxCRC = payload[idx] or 0
        if mspRxCRC ~= rxCRC and versionBits == 0 then return nil end
    end

    return true
end

-- Poll until a complete MSP reply or timeout
local function mspPollReply()
    -- NOTE: This function is called from the MSP queue wakeup. Historically it could "block"
    -- (spin in a loop) for up to mspPollBudget seconds, which is expensive on Ethos.
    -- We now support a non-blocking "slice" mode: poll a small amount each wakeup and
    -- complete multi-packet replies over multiple frames.
    local protoCfg = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.protocol or {}

    local budget = pollBudget() or 0.1
    local now = os.clock

    -- Non-blocking slice mode (recommended for S.Port).
    -- Keeps CPU load smooth by limiting per-wakeup work.
    local nonBlocking = (protoCfg.mspNonBlocking == true)
    local sliceSeconds = protoCfg.mspPollSliceSeconds or 0.006
    local slicePolls   = protoCfg.mspPollSlicePolls or 4

    -- When idle (no in-flight RX + no outstanding request), cap the poll window so
    -- we don't spin burning max instructions waiting for nothing.
    local idleCap = 0.02
    local inflight0 = mspStarted or (mspLastReq ~= 0)

    -- In slice mode, always clamp the poll window. Give a slightly larger slice while inflight.
    local window
    if nonBlocking then
        window = inflight0 and (sliceSeconds * 2) or sliceSeconds
    else
        window = inflight0 and budget or math.min(budget, idleCap)
    end

    local deadline = now() + window

    -- Hoist lookups (avoid repeated globals + proto() table walks)
    local p = proto()
    local mspPoll = p and p.mspPoll
    if not mspPoll then
        return nil, nil, nil
    end

    local receivedReply = _receivedReply

    -- Fast path: when idle, bail quickly on nil (avoid instruction burn).
    -- Slow path: when a reply is in progress / outstanding request, allow more gaps.
    local MAX_NIL_IDLE     = 4
    local MAX_NIL_INFLIGHT = nonBlocking and math.max(2, slicePolls) or 16

    -- Hard cap on total poll iterations per wakeup to prevent instruction spikes.
    local MAX_POLLS = nonBlocking and slicePolls or 24

    local nilPolls = 0

    local polls = 0
    while now() < deadline do
        polls = polls + 1
        if polls > MAX_POLLS then
            return nil, nil, nil
        end
        local pkt = mspPoll()

        if pkt == nil then
            nilPolls = nilPolls + 1

            -- "In-flight" if we're mid frame OR we have an outstanding request we're waiting on.
            -- (mspStarted is set by _receivedReply() once it sees a valid start for our last request.)
            local inflight = mspStarted or (mspLastReq ~= 0)

            local maxNil = inflight and MAX_NIL_INFLIGHT or MAX_NIL_IDLE
            if nilPolls >= maxNil then
                return nil, nil, nil
            end
        else
            nilPolls = 0

            -- Defensive: if transport ever returns non-table, treat as junk/no-data.
            if type(pkt) == "table" then
                plog("RX", mspLastReq, pkt, "ST=" .. tostring(pkt[1] or 0))
                -- Catch rare decode hard-fails without killing the script.
                -- IMPORTANT: On decode error we *do not* reset mspLastReq or state; next wakeup can continue.
                local ok, done = pcall(receivedReply, pkt)
                if ok and done then
                    plog("RXDONE", mspRxReq, mspRxBuf, "ERR=" .. tostring(mspRxError) .. " SIZE=" .. tostring(#mspRxBuf))
                    mspLastReq = 0
                    return mspRxReq, mspRxBuf, mspRxError
                end
            end
        end
    end

    return nil, nil, nil
end


return {
    setProtocolVersion = setProtocolVersion,
    getProtocolVersion = getProtocolVersion,
    mspProcessTxQ      = mspProcessTxQ,
    mspSendRequest     = mspSendRequest,
    mspPollReply       = mspPollReply,
    mspClearTxBuf      = mspClearTxBuf
}


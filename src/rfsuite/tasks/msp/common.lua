-- MSPv2 byte-framing engine (sequencing, chunking).
--
-- MSPv2-only: this rebuild's floor is Rotorflight 2.3 / MSP API >= 12.09,
-- which always speaks MSPv2, so there is no v1 wire format, no version
-- negotiation, and no CRC (MSPv2 frames over these transports don't carry
-- one at this layer -- unlike v1). Older-firmware compatibility code has
-- been deliberately left out rather than kept dormant.
--
-- Protocol-agnostic: talks to whatever transport was registered via
-- setTransport() (see transport_sport.lua / transport_crsf.lua). Private to
-- the background task subsystem -- nothing outside tasks/msp/ should load
-- this file directly; go through lib/bus.lua's "msp.request" topic
-- instead (see tasks/background.lua).
--
-- Adapted from rotorflight-lua-ethos-suite's tasks/scheduler/msp/common.lua
-- (arithmetic/native-bitop framing, proven in production for both S.Port
-- and CRSF), simplified: no protocol trace logger, no adaptive poll-budget
-- tuning, no dependency on any shared session table -- the transport is an
-- explicit local instead of a global lookup.

local os_clock = os.clock
local math_floor = math.floor

local MSP_VERSION_BITS = 2 << 5 -- MSPv2 version bits
local MSP_STARTFLAG = 1 << 4

local mspSeq = 0
local mspRemoteSeq = 0
local mspRxBuf = {}
local mspRxError = false
local mspRxSize = 0
local mspRxReq = 0
local mspStarted = false
local mspLastReq = 0
local mspLastReqIsWrite = false
local mspTxBuf = {}
local mspTxIdx = 1

-- {mspSend = fn(payload, isWrite), mspPoll = fn() -> payload|nil,
--  maxTxBufferSize = n, maxRxBufferSize = n}
local transport = nil

local function setTransport(t)
  transport = t
end

local function maxTx() return transport.maxTxBufferSize end
local function maxRx() return transport.maxRxBufferSize end

local function mkStatusByte(isStart)
  local status = mspSeq + MSP_VERSION_BITS
  if isStart then status = status + MSP_STARTFLAG end
  return status & 0x7F
end

local function mspClearTxBuf()
  mspTxBuf, mspTxIdx = {}, 1
end

-- Process TX buffer into protocol-sized packets; returns true while more
-- frames remain to be sent.
local function mspProcessTxQ()
  if #mspTxBuf == 0 then return false end

  local payload = {}
  payload[1] = mkStatusByte(mspTxIdx == 1)
  mspSeq = (mspSeq + 1) & 0x0F

  local limit = maxTx()
  local i = 2
  while (i <= limit) and (mspTxIdx <= #mspTxBuf) do
    payload[i] = mspTxBuf[mspTxIdx]
    mspTxIdx = mspTxIdx + 1
    i = i + 1
  end
  for j = i, limit do payload[j] = payload[j] or 0 end

  transport.mspSend(payload, mspLastReqIsWrite)

  if mspTxIdx > #mspTxBuf then
    mspClearTxBuf()
    return false
  end
  return true
end

-- Format and queue an MSP request for transmission. `isWrite` only matters
-- to transports (like CRSF) that distinguish read vs write at the link
-- layer; ignored otherwise.
local function mspSendRequest(cmd, payload, isWrite)
  if type(payload) ~= "table" or not cmd then return false end
  if #mspTxBuf ~= 0 then return false end -- TX already busy

  local len = #payload
  local cmd1 = cmd % 256
  local cmd2 = math_floor(cmd / 256) % 256
  local len1 = len % 256
  local len2 = math_floor(len / 256) % 256
  mspTxBuf = {0, cmd1, cmd2, len1, len2}
  for i = 1, len do mspTxBuf[#mspTxBuf + 1] = payload[i] % 256 end

  mspLastReq = cmd
  mspLastReqIsWrite = isWrite and true or false
  mspTxIdx = 1
  return true
end

-- Internal: process one reply packet. Returns true once a full reply has
-- been assembled (possibly across several calls, for multi-frame replies).
local function receivedReply(payload)
  local idx = 1
  local status = payload[idx] or 0
  local start = (status & 0x10) ~= 0
  local seq = status & 0x0F
  idx = idx + 1

  if start then
    mspRxBuf = {}
    mspRxError = (status & 0x80) ~= 0

    idx = idx + 1 -- skip flags byte
    local cmd1 = payload[idx] or 0; idx = idx + 1
    local cmd2 = payload[idx] or 0; idx = idx + 1
    local len1 = payload[idx] or 0; idx = idx + 1
    local len2 = payload[idx] or 0; idx = idx + 1
    mspRxReq = ((cmd2 & 0xFF) << 8) | (cmd1 & 0xFF)
    mspRxSize = ((len2 & 0xFF) << 8) | (len1 & 0xFF)
    mspStarted = (mspRxReq == mspLastReq)
  else
    if (not mspStarted) or (((mspRemoteSeq + 1) & 0x0F) ~= seq) then
      mspStarted = false
      mspRxBuf, mspRxSize, mspRemoteSeq = {}, 0, 0
      return nil
    end
  end

  while (idx <= maxRx()) and (#mspRxBuf < mspRxSize) do
    mspRxBuf[#mspRxBuf + 1] = payload[idx]
    idx = idx + 1
  end

  if #mspRxBuf < mspRxSize then
    mspRemoteSeq = seq
    return false -- continues in the next frame
  end

  mspStarted = false
  return true
end

-- Poll for a complete MSP reply. Non-blocking: bounded to a small wall-time
-- slice per call so a slow/absent transport can't stall the task's wakeup.
-- Multi-frame replies are reassembled across successive calls.
local function mspPollReply()
  if not transport then return nil, nil, nil end
  local deadline = os_clock() + 0.005
  while os_clock() < deadline do
    local pkt = transport.mspPoll()
    if pkt == nil then
      return nil, nil, nil
    end
    if type(pkt) == "table" then
      local ok, done = pcall(receivedReply, pkt)
      if ok and done then
        mspLastReq = 0
        return mspRxReq, mspRxBuf, mspRxError
      end
    end
  end
  return nil, nil, nil
end

-- Drain stale replies out of the transport's incoming-frame queue. Bounded
-- the same way mspPollReply() above is (a small wall-time slice, not an
-- unconditional drain) -- frames can back up on a busy link, and for the
-- S.Port transport a single transport.mspPoll() call already walks its
-- whole native frame buffer looking for a match, so an uncapped `while
-- transport.mspPoll() do end` here could otherwise churn through an
-- unbounded backlog in one wakeup with no yield point. Any frames left
-- over past the deadline are harmless leftovers -- nothing here acts on
-- their contents, and the next mspPollReply() simply keeps draining them.
local function mspClearBufs()
  mspClearTxBuf()
  if transport then
    local deadline = os_clock() + 0.01
    while os_clock() < deadline and transport.mspPoll() do end
  end
end

return {
  setTransport = setTransport,
  mspSendRequest = mspSendRequest,
  mspProcessTxQ = mspProcessTxQ,
  mspPollReply = mspPollReply,
  mspClearBufs = mspClearBufs,
}

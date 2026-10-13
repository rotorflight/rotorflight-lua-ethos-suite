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

-- Optional Ethos 26.1.3+ instruction budget. Cache the capability once; older
-- radios keep the existing drain behaviour. Leave headroom for the rest of
-- the background wakeup; this is a cooperative bound, not preemption.
local getInstructionsUsage = system and system.getInstructionsUsage
local DRAIN_INSTRUCTION_LIMIT = 60

local math_floor = math.floor

local MSP_VERSION_BITS = 2 << 5 -- MSPv2 version bits
local MSP_STARTFLAG = 1 << 4

-- Bounds on the two drain loops below. They are different bounds on purpose,
-- because the two loops throw away different things -- see each one's own
-- comment.
--
-- mspPollReply() assembles a reply, so its bound is wall time: a frame count
-- that actually bound it would slice one long reply across wakeups, and the
-- slice is not harmless (see POLL_SLICE_SECONDS for what makes it survivable).
local POLL_SLICE_SECONDS = 0.003
-- mspClearBufs() discards frames without looking at them, so its bound is a
-- frame count: nothing there is lost by stopping early.
local CLEAR_FRAME_CAP = 2

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
-- MSP reply frames received, ever -- accepted or discarded. Only its change
-- matters: see mspRxFrameCount().
local mspRxFrames = 0
-- Replies dropped part-way because a continuation frame broke the sequence,
-- ever, plus the details of the latest one: see mspRxBreakInfo().
local mspRxBreaks = 0
local mspRxBreakExpected, mspRxBreakGot, mspRxBreakBytes, mspRxBreakSize = 0, 0, 0, 0

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
  if type(payload) ~= "table" or not cmd or type(cmd) ~= "number" then return false end
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

  -- A new request also invalidates whatever the *previous* one left
  -- half-assembled. mspStarted/mspRxBuf/mspRxSize/mspRemoteSeq are only
  -- reset on a completed reply (mspPollReply) or a transport swap
  -- (mspClearBufs), so a request that died between two reply frames left
  -- mspStarted true with a partial mspRxBuf behind it. The orphaned
  -- continuation frames then passed the sequence check in receivedReply()
  -- -- which knows nothing about which command they belong to -- and were
  -- appended to the *next* command's payload. Reset all four here, so
  -- receivedReply()'s start flag is the only thing that may open a buffer.
  mspStarted = false
  mspRxBuf, mspRxSize, mspRemoteSeq = {}, 0, 0
  mspRxError = false

  return true
end

-- Internal: process one reply packet. Returns true once a full reply has
-- been assembled (possibly across several calls, for multi-frame replies).
local function receivedReply(payload)
  mspRxFrames = mspRxFrames + 1
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
      if mspStarted then
        mspRxBreaks = mspRxBreaks + 1
        mspRxBreakExpected = (mspRemoteSeq + 1) & 0x0F
        mspRxBreakGot = seq
        mspRxBreakBytes = #mspRxBuf
        mspRxBreakSize = mspRxSize
      end
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
-- Multi-frame replies are reassembled across successive calls -- the assembly
-- state lives in upvalues, so stopping early just resumes on the next call.
--
-- The slice is the one place in this file where the work and the bound are not
-- interchangeable, and the coupling is worth stating: a resend discards the
-- half-assembled reply. mspSendRequest() resets mspStarted/mspRxBuf/
-- mspRxRemoteSeq on every send, because a new command's continuation frames
-- would otherwise be appended to the previous one's payload. So a reply that
-- needs more than one wakeup to assemble is only safe because processQueue()
-- re-arms lastSent on every wakeup it sees a reply frame arrive
-- (queue.lua's mspRxFrameCount check), which suppresses the resend for as long
-- as frames keep coming. Slicing therefore holds as long as consecutive
-- wakeups stay inside DEFAULT_RETRY_DELAY -- a period far longer than the 0.05s
-- the rest of this subsystem already schedules its session poll at.
--
-- 5ms was well above what the work needs. The issue asks for 1-2ms; 3ms is the
-- smallest cut that changes nothing bin/msp_queue/verify_msp_queue.lua already
-- pins -- that gate's clock charges a millisecond per clock read rather than per
-- frame, so the frames one call can take there is slice/1ms, and at 2ms it stops
-- being able to take a minimal two-frame reply inside one wakeup (two of its
-- cases go red). Re-basing that gate's clock model is what would unlock 1-2ms;
-- until then this is the measured limit of the cut, not a preference.
--
-- bin/perf/verify_clock_budgets.lua pins the number and the slicing case
-- together, because the second one is what says how far it may be cut at all.
local function mspPollReply()
  if not transport then return nil, nil, nil end
  local deadline = os_clock() + POLL_SLICE_SECONDS
  while os_clock() < deadline do
    if getInstructionsUsage and getInstructionsUsage() >= DRAIN_INSTRUCTION_LIMIT then break end
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

-- Drain stale replies out of the transport's incoming-frame queue. Bounded by
-- a frame count rather than by a wall-time deadline: frames can back up on a
-- busy link, and for the S.Port transport a single transport.mspPoll() call
-- already walks its whole native frame buffer looking for a match, so an
-- uncapped `while transport.mspPoll() do end` here could churn through an
-- unbounded backlog in one wakeup with no yield point -- and a deadline
-- checked between polls cannot bound that inner walk either. What this loop
-- can honour is a number of frames.
--
-- Any frames left over past the cap are harmless leftovers -- nothing here
-- acts on their contents, mspLastReq is 0 so they cannot be matched against a
-- request either, and the next mspPollReply() simply keeps draining them.
local function mspClearBufs()
  mspClearTxBuf()
  mspLastReq = 0
  mspStarted = false
  mspRxBuf, mspRxSize, mspRemoteSeq = {}, 0, 0
  mspRxError = false
  if transport then
    for _ = 1, CLEAR_FRAME_CAP do
      if getInstructionsUsage and getInstructionsUsage() >= DRAIN_INSTRUCTION_LIMIT then break end
      if not transport.mspPoll() then break end
    end
  end
end

return {
  setTransport = setTransport,
  mspSendRequest = mspSendRequest,
  mspProcessTxQ = mspProcessTxQ,
  mspPollReply = mspPollReply,
  mspClearBufs = mspClearBufs,
  -- Exported separately from mspClearBufs because the two answer different
  -- questions. mspClearBufs() is a transport swap: throw away the queue AND
  -- drain the link's stale incoming frames. mspClearTxBuf() is narrower --
  -- just hand back a half-built outgoing message -- which is what a caller
  -- needs when it abandons a single message and intends to keep using the
  -- same transport. Draining the RX side there too would swallow a reply
  -- that is already on its way for the *next* request.
  mspClearTxBuf = mspClearTxBuf,
  -- Grows by one for every MSP reply frame received, including frames
  -- receivedReply() discards. The queue watches it change to tell an FC
  -- that is still sending from a silent link: see queue.lua's
  -- processQueue() for why a discarded frame counts too.
  mspRxFrameCount = function() return mspRxFrames end,
  -- Diagnostics only: how many replies were dropped part-way on a sequence
  -- break, and for the latest one the sequence number expected, the one
  -- that arrived, and how many of how many payload bytes were assembled.
  mspRxBreakInfo = function()
    return mspRxBreaks, mspRxBreakExpected, mspRxBreakGot, mspRxBreakBytes, mspRxBreakSize
  end,
  -- The drain bounds, exported only so bin/perf/verify_clock_budgets.lua can
  -- pin the numbers themselves. Hard-coding them in the harness instead would
  -- let a loosened budget pass, because "never spends more than N" stays green
  -- at any larger N.
  POLL_SLICE_SECONDS = POLL_SLICE_SECONDS,
  CLEAR_FRAME_CAP = CLEAR_FRAME_CAP,
}

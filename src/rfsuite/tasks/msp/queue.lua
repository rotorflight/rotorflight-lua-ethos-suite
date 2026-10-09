-- A single flat MSP request queue: FIFO + one in-flight message + a retry
-- counter. Private to the background task subsystem -- the only way
-- anything else may add work to it is via lib/bus.lua's "msp.request"
-- topic (see tasks/background.lua), never by loading this file directly.
--
-- Adapted from rotorflight-lua-ethos's RF2/MSP/mspQueue.lua: one flat
-- object, no per-request promise/future, replies delivered via a plain
-- callback (`processReply`) stored on the same message table that was
-- queued.
--
-- This file used to force a full `collectgarbage()` in _finish(), i.e. on
-- *every* completed message, justified above as "that same file's deliberate
-- RAM discipline". That rationale did not survive contact with
-- docs/memory-and-module-lifecycle.md section 9: a live A/B log there measured
-- a forced full collect as making no difference to RAM growth at all, because
-- a full cycle can only reclaim what is genuinely unreachable. The call
-- therefore bought nothing in memory, on a path that runs on every background
-- task wakeup. (Its cost is a separate question and is *not* established here:
-- measured on desktop Lua 5.3, one forced collect at a few hundred KB of live
-- heap costs a few hundredths of a millisecond and scales with the heap -- see
-- the printed figures in bin/msp_gc/verify_msp_disconnect.lua. What that costs
-- on a radio is unmeasured.) The incremental collector reclaims these message
-- tables on its own, on its own schedule.
--
-- Queue:clear() keeps its collect: it is rare (transport swap, arming,
-- disconnect) and lands on a real teardown, which is the one place a forced
-- cycle is worth having.
--
-- IMPORTANT: this module takes the shared tasks/msp/common.lua *instance*
-- as a constructor argument (Queue.new(common)) rather than loading its own
-- copy via loadfile(). loadfile() has no require()-style caching -- two
-- independent loadfile("tasks/msp/common.lua") calls (one here, one in
-- tasks/background.lua) would produce two separate module instances, each with
-- its own `transport` upvalue, and setTransport() on one would never be
-- seen by the other. There must be exactly one common.lua instance,
-- created once by tasks/background.lua and handed to both setTransport() and
-- this queue.
--
-- Message shape: {
--   command = <MSP command id>,
--   payload = {...} | nil,              -- omit/{} for parameterless reads
--   isWrite = true | nil,                -- only matters to CRSF (frame type)
--   processReply = function(message, buf) ... end,
--   errorHandler = function(reason) ... end,   -- reason: "timeout"|"max_retries"|
--                                              -- "callback_error"|"queue_error"|...
--   simulatorResponse = {...},           -- reply bytes used in the Ethos simulator
--   retryDelay = <seconds added to the 0.8s default>,
--   maxRetries = <default 5>,
--   clearQueue = true,                    -- handled by tasks/background.lua before add()
-- }

local Queue = {}
Queue.__index = Queue
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local debugLog = requireModule("lib/debug_log.lua")

local DEFAULT_RETRY_DELAY = 0.8
local DEFAULT_MAX_RETRIES = 5
local MAX_PENDING = 20
local EMPTY_PAYLOAD = {}

-- Computed once at load, the same way tasks/session.lua does for its own
-- simulator gate: system.getVersion() crosses the C++/Lua boundary and
-- allocates a table per call, and whether the script runs in the Ethos
-- simulator cannot change while the script is running. Re-deriving it on every
-- tick bought one table and one boundary crossing per wakeup for a constant.
local isSim = system.getVersion().simulation == true

-- A page's processReply/errorHandler runs inside the background task's
-- wakeup (issue #2363). Ethos does not stop a task whose wakeup raises: it logs
-- the error and calls wakeup again -- measured in the WASM simulator, Ethos
-- 26.1.3, 1020 errors in a row from taskWakeup() and the task was still being
-- called; not measured on a radio. What an error does cost is the rest of that
-- tick, and taskWakeup() runs the scheduler (session, audio events, logging)
-- after the queue, so one that repeats starves all of it on every tick. So both
-- are called under pcall: the failure is printed, the queue carries on, and the
-- page is told through its errorHandler where there is one.
--
-- Printed, not swallowed -- and at most once a second per call site, because a
-- reply that fails will fail again on the next poll of the same page. The
-- count of lines held back goes on the next line that does get through.
local REPORT_INTERVAL = 1
local lastReportAt = {}
local suppressed = {}

-- Lua lets error() carry any value, and converting one can raise: a table with
-- a __tostring that throws would make the report itself the second failure, and
-- Queue:wakeup() calls report() outside its pcall. So the conversion is guarded
-- and falls back to the type.
local function errorText(err)
  local ok, text = pcall(tostring, err)
  if ok and type(text) == "string" then return text end
  return "<error of type " .. type(err) .. ">"
end

local function report(site, err)
  local now = os.clock()
  local last = lastReportAt[site]
  if last and (now - last) >= 0 and (now - last) < REPORT_INTERVAL then
    suppressed[site] = (suppressed[site] or 0) + 1
    return
  end
  lastReportAt[site] = now
  local held = suppressed[site]
  suppressed[site] = nil
  print("[msp queue] " .. site .. " failed: " .. errorText(err)
    .. (held and (" (+" .. held .. " suppressed)") or ""))
end

local function notifyError(message, reason)
  if message then debugLog.msp("ERR", message.command, message.payload, reason) end
  local handler = message and message.errorHandler
  if handler then
    local ok, err = pcall(handler, reason)
    if not ok then report("errorHandler", err) end
  end
end

function Queue.new(common)
  return setmetatable({
    common = common,
    pending = {},
    current = nil,
    lastSent = nil,
    retryCount = 0,
    rxFrames = 0,
    rxBreaks = 0,
    lastTickAt = nil,
  }, Queue)
end

function Queue:isProcessed()
  return not self.current and #self.pending == 0
end

function Queue:add(message)
  if not message or not message.command or type(message.command) ~= "number" or (message.payload and type(message.payload) ~= "table") then
    notifyError(message, "invalid_request")
    return false
  end
  if #self.pending >= MAX_PENDING then
    notifyError(message, "queue_full")
    return false
  end

  self.pending[#self.pending + 1] = message
  return true
end

-- Drops everything in-flight/queued -- called on transport swap (see
-- tasks/background.lua's checkTransportChange()), which a mid-reboot
-- telemetry-link dropout triggers just as readily as a real protocol
-- change. Self-caught bug, found live: this used to wipe self.current/
-- self.pending with no notification at all, so a page waiting on that
-- message's callback (e.g. app/page_runtime.lua's performSave(), which
-- only closes its "Saving..." dialog and re-enables Save/Reload from
-- processReply/errorHandler) never heard back -- neither success nor
-- error, no eventual max_retries timeout either, since the message was
-- gone from the queue entirely, not merely slow. The dialog then had no
-- event left that could ever close it, short of reloading the whole
-- script. Snapshot both before resetting queue state so a handler that
-- itself calls Queue:add() (e.g. a retry) lands in the already-cleared
-- queue, not the one about to be discarded.
--
-- Also called on disconnect (tasks/session.lua's setConnected()) and on
-- arming (its updateArmState()) -- a link that went away takes the queue with
-- it, and the next handshake must not queue FIFO behind a backlog that can no
-- longer be answered.
--
-- The collectgarbage() here is the one full cycle this file keeps, and it is
-- deliberate: clear() is rare and lands on a real teardown, which is the only
-- place a forced cycle earns its cost. By clearing droppedCurrent and
-- droppedPending before calling collectgarbage(), the dropped messages and
-- payloads are immediately reclaimed along with what the surrounding teardown
-- left behind. _finish() below is the hot path and does not have even that.
function Queue:clear()
  local droppedCurrent = self.current
  local droppedPending = self.pending
  self.pending = {}
  self.current = nil
  self.lastSent = nil
  self.retryCount = 0
  self.common.mspClearBufs()
  if droppedCurrent then notifyError(droppedCurrent, "cleared") end
  for i = 1, #droppedPending do notifyError(droppedPending[i], "cleared") end
  droppedCurrent = nil
  droppedPending = nil
  collectgarbage()
end

local function popFirst(list)
  return table.remove(list, 1)
end

-- Retires whatever message is in flight.
--
-- The shared TX buffer in tasks/msp/common.lua belongs to the *message* being
-- sent, not to the queue, and mspSendRequest() refuses to arm a new one while
-- that buffer is still populated. So retiring a message has to hand the buffer
-- back -- otherwise a message that died between two of its frames left the
-- buffer occupied for the rest of the script's life, and from then on every
-- mspSendRequest() returned false without putting a byte on the wire, mspLastReq
-- was never updated, mspPollReply() could never match, and each new message
-- burned its whole retry budget before dying on max_retries. All MSP traffic
-- dead, no error and no timeout to show for it, and the only way out was
-- reloading the script.
--
-- Doing it here rather than at the individual abort sites makes that a
-- property of "a message ended" instead of something each new `return` has to
-- remember.
--
-- No forced GC cycle here, unlike the other teardown boundary in this file:
-- Queue:clear() is rare and lands on a real teardown, while processQueue()
-- runs this on every background task wakeup. The header comment says what a
-- full collect does and does not buy; bin/msp_gc/verify_msp_disconnect.lua
-- pins both halves of that.
function Queue:_finish()
  self.common.mspClearTxBuf()
  self.current = nil
  self.lastSent = nil
  self.retryCount = 0
end

-- Abort the in-flight message: retire it, then report the reason. The message
-- is snapshotted before _finish() because that clears self.current, and the
-- handler has to be the one belonging to the message that was just abandoned.
function Queue:abortCurrent(reason)
  local msg = self.current
  self:_finish()
  notifyError(msg, reason or "aborted")
  return msg
end

function Queue:_deliver(buf)
  local msg = self.current
  self:_finish()
  if msg.processReply then
    -- The queue is already clear of this message (see _finish() above), so a
    -- failing callback leaves nothing half-done on this side.
    local ok, err = pcall(msg.processReply, msg, buf)
    if not ok then
      report("processReply", err)
      notifyError(msg, "callback_error")
    end
  end
end

function Queue:processQueue()
  if self:isProcessed() then return end

  if not self.current then
    self.current = popFirst(self.pending)
    self.retryCount = 0
    self.lastSent = nil
  end

  local msg = self.current
  local payload = msg.payload or EMPTY_PAYLOAD
  if not msg.command or type(msg.command) ~= "number" or type(payload) ~= "table" then
    return self:abortCurrent("invalid_request")
  end

  local common = self.common

  if isSim then
    if not msg.simulatorResponse then
      debugLog.msp("SIM", msg.command, msg.payload, "no_response")
      return self:abortCurrent("no_response")
    end
    debugLog.msp("SIM>", msg.command, msg.payload)
    debugLog.msp("SIM<", msg.command, msg.simulatorResponse)
    self:_deliver(msg.simulatorResponse)
    return
  end

  local retryDelay = DEFAULT_RETRY_DELAY + (msg.retryDelay or 0)
  local maxRetries = msg.maxRetries or DEFAULT_MAX_RETRIES
  local now = os.clock()

  if not self.lastSent or (now - self.lastSent) >= retryDelay then
    -- Only give up once a *previous* send's own retryDelay window has
    -- fully elapsed with no reply -- never fail the message in the same
    -- breath as firing a fresh (re)send, which would judge that attempt
    -- before it had any chance at a reply. Self-caught bug: this used to
    -- resend and immediately check retryCount > maxRetries in the same
    -- call, so the last permitted retry was always declared failed on
    -- arrival instead of getting its own window -- effectively giving
    -- every message one fewer real attempt than maxRetries promised.
    if self.lastSent and self.retryCount > maxRetries then
      return self:abortCurrent("max_retries")
    end
    -- The return value used to be dropped on the floor, which made a refused
    -- hand-off indistinguishable from a successful send: lastSent and
    -- retryCount were advanced either way, so maxRetries was reached after
    -- 6 x 0.8s of wall clock with not one byte having left the radio. Count
    -- real hand-offs only, and say so out loud when there was none.
    if common.mspSendRequest(msg.command, payload, msg.isWrite) then
      debugLog.msp("TX", msg.command, payload, "try=" .. tostring(self.retryCount + 1))
      self.lastSent = now
      self.retryCount = self.retryCount + 1
      self.rxFrames = common.mspRxFrameCount()
    else
      debugLog.msp("TX!", msg.command, payload, "tx_busy")
    end
  end

  -- One frame per wakeup, deliberately. Both transports hand the frame to
  -- Ethos's pushFrame(), and mspProcessTxQ() ignores whether it was
  -- accepted. Draining a whole multi-frame write in one tick (#2411) broke
  -- every save on hardware -- the burst outruns what pushFrame() will
  -- queue, so the FC never sees a complete write. An abandoned mid-send
  -- write no longer poisons the link either way, since _finish() hands the
  -- TX buffer back.
  common.mspProcessTxQ()

  local cmd, buf, err = common.mspPollReply()

  -- Never resend while the FC is still sending. retryDelay used to count
  -- from the send alone, so a reply longer than the window (a 448-byte
  -- reply is ~90 S.Port frames) was cut off by a resend
  -- part-way through, and every attempt died the same way until
  -- max_retries failed the page load.
  --
  -- Frames this side discards count as well. When one reply frame is lost
  -- on the link, the rest of that reply keeps arriving and is discarded
  -- (it no longer follows the sequence). A request sent into that stream
  -- gets an answer with no start frame: the firmware's sendMspReply()
  -- (telemetry/msp_shared.c) only clears its static headerSent when a
  -- reply finishes, not when a new request replaces it, so every
  -- continuation frame of the new answer is discarded too. Waiting for
  -- retryDelay of silence lets the old reply finish first, so the resend
  -- gets a proper start frame.
  --
  -- A reply dropped part-way (a lost frame) then costs one full resend.
  local rxFrames = common.mspRxFrameCount()
  if rxFrames ~= self.rxFrames then
    self.rxFrames = rxFrames
    if self.lastSent then self.lastSent = now end
  end

  -- MSP-log only: a reply dropped part-way on a sequence break. got past
  -- expected means frames were lost; gap is the time since the previous
  -- tick, long gaps pointing at an overflowed Ethos frame queue.
  if debugLog.mspEnabled() then
    local breaks, expected, got, bytes, size = common.mspRxBreakInfo()
    if breaks ~= self.rxBreaks then
      self.rxBreaks = breaks
      debugLog.msp("SEQ", msg.command, EMPTY_PAYLOAD, string.format(
        "expected=%d got=%d bytes=%d/%d gap=%dms", expected, got, bytes, size,
        math.floor(((now - (self.lastTickAt or now)) * 1000) + 0.5)))
    end
  end
  self.lastTickAt = now

  if cmd == msg.command and not err then
    debugLog.msp("RX", cmd, buf)
    self:_deliver(buf)
  elseif err then
    debugLog.msp("ERR", msg.command, msg.payload or EMPTY_PAYLOAD, err)
    self:abortCurrent(err)
  end
end

-- What the background task calls every tick. processQueue() reaches into the
-- transport (Ethos's pushFrame()/popFrame()), and an error from there used to
-- leave the task through taskWakeup(). Here it is printed, the message that was
-- in flight is retired with "queue_error", and the next one gets its turn.
--
-- The state is reset by hand first rather than through _finish(): _finish()
-- reaches into the transport too, and if that is what just failed, retiring
-- through it would fail the same way and leave self.current set -- the same
-- error again on every tick, and the queue stuck behind it.
function Queue:wakeup()
  local ok, err = pcall(self.processQueue, self)
  if ok then return end
  report("processQueue", err)

  local msg = self.current
  self.current = nil
  self.lastSent = nil
  self.retryCount = 0
  local cleared, clearErr = pcall(self.common.mspClearTxBuf)
  if not cleared then report("mspClearTxBuf", clearErr) end
  notifyError(msg, "queue_error")
end

return Queue

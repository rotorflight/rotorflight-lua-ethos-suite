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
--   errorHandler = function(reason) ... end,   -- reason: "timeout"|"max_retries"
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

local function notifyError(message, reason)
  if message then debugLog.msp("ERR", message.command, message.payload, reason) end
  local handler = message and message.errorHandler
  if handler then
    handler(reason)
  end
end

function Queue.new(common)
  return setmetatable({
    common = common,
    pending = {},
    current = nil,
    lastSent = nil,
    retryCount = 0,
  }, Queue)
end

function Queue:isProcessed()
  return not self.current and #self.pending == 0
end

function Queue:add(message)
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

-- Retires whatever message is in flight. This is the per-message teardown
-- boundary, and it deliberately does NOT force a full GC cycle: it buys no
-- memory (header comment) and processQueue() runs it on every background task
-- wakeup, so there is no reason to put it on the task's hot path.
--
-- Hand back the shared TX buffer in tasks/msp/common.lua and reset the retry
-- counter so the next message starts with clean state.
function Queue:_finish()
  if self.common.mspClearTxBuf then
    self.common.mspClearTxBuf()
  end
  self.current = nil
  self.lastSent = nil
  self.retryCount = 0
end

function Queue:_deliver(buf)
  local msg = self.current
  self:_finish()
  if msg.processReply then
    msg.processReply(msg, buf)
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
  local common = self.common
  local isSim = system.getVersion().simulation == true

  if isSim then
    if not msg.simulatorResponse then
      debugLog.msp("SIM", msg.command, msg.payload, "no_response")
      self:_finish()
      notifyError(msg, "no_response")
      return
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
      local handler = msg.errorHandler
      self:_finish()
      if handler then handler("max_retries") end
      return
    end
    local payload = msg.payload or EMPTY_PAYLOAD
    common.mspSendRequest(msg.command, payload, msg.isWrite)
    debugLog.msp("TX", msg.command, payload, "try=" .. tostring(self.retryCount + 1))
    self.lastSent = now
    self.retryCount = self.retryCount + 1
  end

  common.mspProcessTxQ()
  local cmd, buf, err = common.mspPollReply()

  if cmd == msg.command and not err then
    debugLog.msp("RX", cmd, buf)
    self:_deliver(buf)
  elseif err then
    debugLog.msp("ERR", msg.command, msg.payload or EMPTY_PAYLOAD, err)
    local handler = msg.errorHandler
    self:_finish()
    if handler then handler(err) end
  end
end

return Queue

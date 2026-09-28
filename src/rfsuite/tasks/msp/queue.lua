-- A single flat MSP request queue: FIFO + one in-flight message + a retry
-- counter. Private to the background task subsystem -- the only way
-- anything else may add work to it is via lib/bus.lua's "msp.request"
-- topic (see tasks/background.lua), never by loading this file directly.
--
-- Adapted from rotorflight-lua-ethos's RF2/MSP/mspQueue.lua: one flat
-- object, no per-request promise/future, replies delivered via a plain
-- callback (`processReply`) stored on the same message table that was
-- queued. `collectgarbage()` is called at every teardown boundary,
-- following that same file's deliberate RAM discipline.
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
function Queue:_finish()
  self.common.mspClearTxBuf()
  self.current = nil
  self.lastSent = nil
  self.retryCount = 0
  collectgarbage()
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
  local payload = msg.payload or EMPTY_PAYLOAD
  if not msg.command or type(msg.command) ~= "number" or type(payload) ~= "table" then
    return self:abortCurrent("invalid_request")
  end

  local common = self.common
  local isSim = system.getVersion().simulation == true

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

  if cmd == msg.command and not err then
    debugLog.msp("RX", cmd, buf)
    self:_deliver(buf)
  elseif err then
    debugLog.msp("ERR", msg.command, msg.payload or EMPTY_PAYLOAD, err)
    self:abortCurrent(err)
  end
end

return Queue

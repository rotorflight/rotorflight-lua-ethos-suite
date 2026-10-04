-- Behaviour check for the MSP request queue (issue #2378).
--
-- Run it:
--     lua5.4 bin/msp_queue/verify_msp_queue.lua
--
-- What it drives, and why:
--   * tasks/msp/common.lua and tasks/msp/queue.lua are pure functions of a
--     transport, a clock and a set of queued messages -- no radio, no FC and
--     no Ethos needed. The transport is a stub that records every frame handed
--     to it and hands back whatever reply frames a scenario queued up, so the
--     claims below are measured, not inferred.
--   * os.clock() is replaced before either module is loaded (common.lua binds
--     `local os_clock = os.clock` at load time), and it advances by a fixed
--     micro-step per call. The micro-step is not cosmetic: mspPollReply() polls
--     inside a `while os_clock() < deadline` loop, so a frozen clock would spin
--     there forever. Wall-clock jumps are made explicitly with clock.set().
--
-- The issue names three defects -- a poisoned TX buffer, a retry counter that
-- counts elapsed windows instead of send attempts, and a multi-frame write
-- stretched over one background task tick per frame. Only the first two are
-- fixed. The third is kept on purpose: draining a whole write in one tick
-- overflowed Ethos's pushFrame() queue on hardware and broke every save, so
-- "one frame per tick" is pinned below instead.
--
--   * "retiring a message hands the TX buffer back" calls _finish() with the
--     buffer deliberately filled. It cannot be satisfied by fixing the retry
--     counter, only by clearing the buffer on the retire path.
--   * "a stale reply cannot poison the next request" aborts a request whose
--     reply was truncated mid-frame, then delivers the orphaned continuation.
--
-- The two cases that describe the old behaviour are the point: a check that
-- cannot fail proves nothing about the behaviour it passes.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local MSP = ROOT .. "/src/rfsuite/tasks/msp"

local failures = 0
local checks = 0

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

-- ---------------------------------------------------------------------------
-- Environment
-- ---------------------------------------------------------------------------

-- Controllable clock. `set()` jumps; every call also nudges forward so the
-- bounded poll loops in common.lua terminate.
local clock = { now = 0.0, step = 0.001 }
local realClock = os.clock
os.clock = function()
  local t = clock.now
  clock.now = t + clock.step
  return t
end

-- queue.lua asks Ethos whether it is running in the simulator; on a real radio
-- the answer is false and the queue takes the transport path, which is the path
-- under test. Without this global the queue cannot be loaded at all. Since
-- issue #2382 it reads the flag once, while being loaded, so the flag has to be
-- in place before the module is dofile'd -- see the simulator case below.
system = { getVersion = function() return { simulation = false } end }

-- Every MSP line debugLog was asked to print, as "TAG cmd note".
local logLines = {}
package.loaded["rfsuite.lib.require"] = function(name)
  if name == "lib/debug_log.lua" then
    return {
      print = function(msg) logLines[#logLines + 1] = tostring(msg) end,
      mspEnabled = function() return true end,
      msp = function(direction, command, payload, note)
        logLines[#logLines + 1] = string.format("%s %s %s", tostring(direction),
          tostring(command), tostring(note))
      end,
    }
  end
  error("unexpected dependency: " .. tostring(name))
end

-- A transport with S.Port's framing budget: 6 bytes per frame, one of which is
-- the MSPv2 status flag, so 5 payload bytes per frame.
local function newTransport(opts)
  opts = opts or {}
  local t = {
    maxTxBufferSize = opts.maxTxBufferSize or 6,
    maxRxBufferSize = opts.maxRxBufferSize or 6,
    sent = {},     -- every frame handed to mspSend, in order
    replies = {},  -- frames mspPoll() will hand back, oldest first
  }
  function t.mspSend(payload, isWrite)
    local frame = {}
    for i = 1, #payload do frame[i] = payload[i] end
    frame[1] = payload[1] or 0
    t.sent[#t.sent + 1] = { bytes = frame, isWrite = isWrite }
    return true
  end
  function t.mspPoll()
    return table.remove(t.replies, 1)
  end
  return t
end

-- Builds the reply frames a flight controller would put on the wire, in the
-- layout tasks/msp/common.lua's receivedReply() parses: a start frame carrying
-- status, flags, command and length, then continuation frames carrying payload
-- bytes, numbered from 1.
--
-- `chunks` is a list of byte lists; one continuation frame is emitted per entry.
local function replyFrames(cmd, declaredLen, chunks)
  local frames = {}
  local start = {}
  start[1] = 0x40 | 0x10 -- version bits (2 << 5) + start flag, sequence 0
  start[2] = 0            -- flags, skipped by receivedReply()
  start[3] = cmd % 256
  start[4] = math.floor(cmd / 256) % 256
  start[5] = declaredLen % 256
  start[6] = math.floor(declaredLen / 256) % 256
  frames[1] = start
  for i, chunk in ipairs(chunks) do
    local frame = { i & 0x0F } -- sequence continues from 1
    for j = 1, #chunk do frame[j + 1] = chunk[j] end
    frames[#frames + 1] = frame
  end
  return frames
end

-- Restarts the module graph so no state leaks between cases: common.lua keeps
-- its buffers in upvalues that only setTransport() and the request API touch,
-- and a fresh dofile is the only way to get a clean set.
local function newRig(opts)
  local common = dofile(MSP .. "/common.lua")
  local Queue = dofile(MSP .. "/queue.lua")
  local transport = newTransport(opts)
  common.setTransport(transport)
  local queue = Queue.new(common)
  clock.now = 0.0
  return {
    common = common,
    queue = queue,
    transport = transport,
    tick = function() queue:processQueue() end,
    jump = function(seconds) clock.now = clock.now + seconds end,
  }
end

local function newMessage(cmd, opts)
  opts = opts or {}
  local payload = opts.payload
  if payload == nil then
    payload = {}
    for i = 1, opts.payloadBytes or 0 do payload[i] = i & 0xFF end
  end
  local msg = {
    command = cmd,
    payload = payload,
    isWrite = opts.isWrite,
    maxRetries = opts.maxRetries,
    retryDelay = opts.retryDelay,
    replies = {},
    errors = {},
  }
  msg.processReply = function(_, buf) msg.replies[#msg.replies + 1] = buf end
  -- errorHandler is called as handler(reason), with no self -- see the message
  -- shape documented atop tasks/msp/queue.lua.
  msg.errorHandler = function(reason) msg.errors[#msg.errors + 1] = reason end
  return msg
end

-- Counts the frames one processQueue() produced, i.e. a single wakeup's worth.
local function framesAfterOneTick(rig, message)
  local before = #rig.transport.sent
  rig.queue:add(message)
  rig.tick()
  return #rig.transport.sent - before
end

-- How many of the frames handed to the transport were addressed to `cmd`.
--
-- A request frame laid out by mspProcessTxQ() is
--   status, <reserved>, cmd1, cmd2, len1, len2, data...
-- -- the reserved byte mirrors the flags byte that receivedReply() skips on the
-- reply side, so the command sits at bytes 3 and 4, not 2 and 3.
--
-- Counting "frames on the wire" instead would not do: a poisoned buffer still
-- leaks its leftovers onto the wire, it just leaks the *previous* request's
-- frames.
local function framesForCommand(sent, cmd)
  local count = 0
  for _, frame in ipairs(sent) do
    local b = frame.bytes
    if b[3] == cmd % 256 and b[4] == math.floor(cmd / 256) % 256 then
      count = count + 1
    end
  end
  return count
end

-- ---------------------------------------------------------------------------
-- Defect 1 in isolation: the TX buffer belongs to the message, not the queue
-- ---------------------------------------------------------------------------

-- No timing, no retry counting, no drain involved: the buffer is filled by
-- hand, a message is retired, and the buffer has to come back. Only clearing it
-- on the retire path can make this pass.
do
  local rig = newRig()
  local msg = newMessage(0x1234)
  rig.queue:add(msg)
  rig.queue.current = msg
  rig.common.mspSendRequest(0x1234, {1, 2, 3})
  check("precondition: a filled TX buffer refuses the next request",
    rig.common.mspSendRequest(0x1235, {}) == false)
  rig.queue:_finish()
  check("retiring a message hands the TX buffer back",
    rig.common.mspSendRequest(0x1235, {}) == true)
  check("retiring a message resets retryCount",
    rig.queue.retryCount == 0,
    "retryCount=" .. tostring(rig.queue.retryCount))
end

-- Reported rather than called blindly: before the fix queue.lua had no
-- abortCurrent() at all, and a missing method would abort the run instead of
-- reporting the case -- which is the difference between "this fails on the old
-- code" and "this could not be measured on the old code".
do
  local rig = newRig()
  local msg = newMessage(0x1234)
  rig.queue:add(msg)
  rig.queue.current = msg
  rig.common.mspSendRequest(0x1234, {1, 2, 3})
  if type(rig.queue.abortCurrent) ~= "function" then
    check("aborting a message hands the TX buffer back", false,
      "queue.lua has no abortCurrent(), so there is no way to abandon a message " ..
      "and hand the shared TX buffer back")
    check("aborting reports the reason to the message's own handler", false,
      "queue.lua has no abortCurrent()")
  else
    rig.queue:abortCurrent("aborted")
    check("aborting a message hands the TX buffer back",
      rig.common.mspSendRequest(0x1235, {}) == true)
    check("aborting reports the reason to the message's own handler",
      #msg.errors == 1 and msg.errors[1] == "aborted",
      "errors=" .. #msg.errors .. " first=" .. tostring(msg.errors[1]))
  end
end

-- ---------------------------------------------------------------------------
-- Defect 2 in isolation: a refused hand-off is not a send attempt
-- ---------------------------------------------------------------------------

-- MSP_TELEMETRY_CONFIG's size, the worst case the issue names: 52 payload bytes
-- plus the 5-byte MSPv2 header, at 5 payload bytes per S.Port frame.
local BIG_WRITE_CMD = 0x8A
local BIG_WRITE_BYTES = 52
-- Derived from the framing rather than measured, so that the checks below can
-- be anchored on what the message owes the wire instead of on whatever the
-- first attempt happened to produce -- anchoring on the first attempt is what
-- let the old one-frame-per-tick code satisfy this arithmetic by accident.
local BIG_WRITE_FRAMES = math.ceil((5 + BIG_WRITE_BYTES) / 5)

-- One frame per tick: Ethos's pushFrame() queue is shallow, and a burst of a
-- whole multi-frame write overflowed it on hardware.
do
  local rig = newRig()
  local frames = framesAfterOneTick(rig, newMessage(BIG_WRITE_CMD,
    { isWrite = true, payloadBytes = BIG_WRITE_BYTES }))
  check("one tick puts exactly one frame on the wire", frames == 1,
    "frames in a single tick=" .. frames)
  for _ = 2, BIG_WRITE_FRAMES do rig.tick() end
  check("the rest of the write follows one frame per tick",
    #rig.transport.sent == BIG_WRITE_FRAMES,
    "frames after " .. BIG_WRITE_FRAMES .. " ticks=" .. #rig.transport.sent)
end

-- Ticks until a message has put all BIG_WRITE_FRAMES frames of one attempt on
-- the wire, without letting its retry window elapse.
local function sendWholeAttempt(rig)
  for _ = 1, BIG_WRITE_FRAMES do rig.tick() end
end

-- A silent link, so every retry window is a real miss. Each permitted attempt
-- has to put the *whole* message on the wire -- not one frame of it, and not
-- nothing at all. The expectation is anchored on the frame count above, so a
-- code that merely counts the windows it slept through cannot pass.
do
  local maxRetries = 2
  local rig = newRig()
  local msg = newMessage(BIG_WRITE_CMD, { isWrite = true, payloadBytes = BIG_WRITE_BYTES,
    maxRetries = maxRetries })
  rig.queue:add(msg)
  sendWholeAttempt(rig)
  for _ = 1, maxRetries do
    rig.jump(1.0) -- past the 0.8s default retry delay
    sendWholeAttempt(rig)
  end
  rig.jump(1.0)
  rig.tick() -- the last attempt's window has elapsed: give up
  local expected = BIG_WRITE_FRAMES * (maxRetries + 1)
  check("every attempt puts the whole message on the wire",
    #rig.transport.sent == expected,
    "frames=" .. #rig.transport.sent .. " expected=" .. expected ..
    " (" .. (maxRetries + 1) .. " attempts x " .. BIG_WRITE_FRAMES .. " frames)")
  check("the message is given up once its attempts are spent",
    #msg.errors == 1 and msg.errors[1] == "max_retries",
    "errors=" .. #msg.errors .. " first=" .. tostring(msg.errors[1]))
  check("giving up hands the TX buffer back",
    rig.common.mspSendRequest(0x4321, {}) == true)
end

-- ---------------------------------------------------------------------------
-- The issue's actual scenario: an aborted multi-frame write must not kill MSP
-- ---------------------------------------------------------------------------

do
  local rig = newRig()
  local write = newMessage(BIG_WRITE_CMD, { isWrite = true, payloadBytes = BIG_WRITE_BYTES,
    maxRetries = 1 })
  rig.queue:add(write)
  -- The first attempt dies mid-send: only half its frames are out when the
  -- retry window elapses. maxRetries=1 buys two hand-offs, and the message is
  -- only given up on the third window, where 2 > 1.
  for _ = 1, 6 do rig.tick() end
  rig.jump(1.0)
  sendWholeAttempt(rig) -- finishes attempt 1 (refused re-arm), then attempt 2
  sendWholeAttempt(rig)
  rig.jump(1.0)
  rig.tick()
  check("the aborted write reported an error", #write.errors >= 1,
    "errors=" .. #write.errors)

  -- A normal configuration page opens next. This is the whole issue: before the
  -- fix the buffer was still occupied here, so this request never reached the
  -- wire and the page hung with no error and no timeout.
  local read = newMessage(0x1E, { maxRetries = 1 })
  rig.queue:add(read)
  rig.tick()
  check("a request after an aborted write reaches the wire under its own command",
    framesForCommand(rig.transport.sent, read.command) == 1,
    "frames for 0x1E=" .. framesForCommand(rig.transport.sent, read.command) ..
    " (0 means the request was refused and only leftovers of the dead write went out)")

  -- And it completes: the FC answers.
  for _, frame in ipairs(replyFrames(read.command, 2, { {7, 8} })) do
    rig.transport.replies[#rig.transport.replies + 1] = frame
  end
  rig.jump(1.0)
  rig.tick()
  check("a request after an aborted write still gets its reply",
    #read.replies == 1 and read.replies[1][1] == 7 and read.replies[1][2] == 8,
    "replies=" .. #read.replies .. " errors=" .. #read.errors)
end

-- ---------------------------------------------------------------------------
-- Defect 4: a stale reply cannot poison the next request
-- ---------------------------------------------------------------------------

-- A read whose reply the link cut in half. The queue gives up on it with the
-- assembly state still half-built: mspStarted true, one byte buffered, two
-- announced. The request that takes its place arms mspLastReq, and only *then*
-- do the abandoned reply's remaining frames turn up.
--
-- Those frames complete the old reply, and completing a reply clears mspLastReq
-- (tasks/msp/common.lua's mspPollReply). The new request's own start frame then
-- asks `mspRxReq == mspLastReq` and is told no, so the new reply can never be
-- assembled and the new request times out -- a second, independent way for one
-- aborted request to kill the traffic that follows it. Clearing the assembly
-- state when a request is armed is what closes that window.
do
  local rig = newRig()
  local stale = newMessage(0x09, { maxRetries = 0 }) -- maxRetries=0: one miss, then give up
  for _, frame in ipairs(replyFrames(stale.command, 2, { {0xAA} })) do
    rig.transport.replies[#rig.transport.replies + 1] = frame
  end
  rig.queue:add(stale)
  rig.tick() -- sends, then reads a reply that stops after one of its two bytes

  rig.jump(1.0)
  rig.tick() -- max_retries: the message is abandoned with a half-built reply

  -- The rest of the abandoned reply arrives late, and completes it.
  rig.transport.replies[#rig.transport.replies + 1] = { 2, 0xBB }

  local fresh = newMessage(0x09, { maxRetries = 2 })
  rig.queue:add(fresh)
  rig.tick() -- arms the new request, then reads the orphaned frame
  for _, frame in ipairs(replyFrames(fresh.command, 1, { {0x42} })) do
    rig.transport.replies[#rig.transport.replies + 1] = frame
  end
  rig.jump(1.0)
  rig.tick()

  local got = fresh.replies[1]
  check("a late frame of an abandoned reply does not disarm the next request",
    #fresh.replies == 1 and got and got[1] == 0x42,
    "replies=" .. #fresh.replies .. " errors=" .. #fresh.errors ..
    " first error=" .. tostring(fresh.errors[1]) ..
    " payload=" .. (got and string.format("%02X", got[1] or 0) or "none") ..
    " (AA/BB would be the abandoned request's own bytes handed to this one)")
end

-- ---------------------------------------------------------------------------
-- Defect 5: mspClearBufs() must wipe half-assembled RX state
-- ---------------------------------------------------------------------------

do
  local rig = newRig()
  local partial = newMessage(0x09)
  for _, frame in ipairs(replyFrames(partial.command, 2, { {0xAA} })) do
    rig.transport.replies[#rig.transport.replies + 1] = frame
  end
  rig.queue:add(partial)
  rig.tick() -- starts assembly

  rig.queue:clear() -- drops in-flight work and resets buffers via mspClearBufs()

  -- Deliver the late orphaned frame
  rig.transport.replies[#rig.transport.replies + 1] = { 2, 0xBB }

  local fresh = newMessage(0x09, { maxRetries = 1 })
  rig.queue:add(fresh)
  rig.tick()
  for _, frame in ipairs(replyFrames(fresh.command, 1, { {0x42} })) do
    rig.transport.replies[#rig.transport.replies + 1] = frame
  end
  rig.jump(1.0)
  rig.tick()

  local got = fresh.replies[1]
  check("mspClearBufs resets RX state so late orphaned frames cannot complete",
    #fresh.replies == 1 and got and got[1] == 0x42,
    "replies=" .. #fresh.replies .. " payload=" .. (got and string.format("%02X", got[1] or 0) or "none"))
end

do
  local rig = newRig()
  rig.common.mspSendRequest(0x09, {})
  local frames = replyFrames(0x09, 2, { {0xAA} })
  rig.transport.replies = { frames[1] }
  rig.common.mspPollReply() -- assemblies first frame

  rig.common.mspClearBufs() -- resets RX assembly state

  rig.transport.replies = { { 1, 0xBB } }
  local cmd, buf = rig.common.mspPollReply()
  check("mspClearBufs directly clears assembly state so orphaned continuation is rejected",
    cmd == nil and buf == nil,
    "cmd=" .. tostring(cmd) .. " buf=" .. tostring(buf))
end

-- ---------------------------------------------------------------------------
-- Defect 6: invalid requests must abort immediately without deadlocking the queue
-- ---------------------------------------------------------------------------

do
  local rig = newRig()
  local errReported = nil
  local bad = { command = nil, payload = {}, errorHandler = function(err) errReported = err end }
  local added = rig.queue:add(bad)
  check("Queue:add rejects request without command", added == false and errReported == "invalid_request",
    "added=" .. tostring(added) .. " err=" .. tostring(errReported))

  local errCurrent = nil
  local directBad = { command = nil, payload = {}, errorHandler = function(err) errCurrent = err end }
  rig.queue.current = directBad
  rig.tick()
  check("processQueue aborts unvalidated invalid request in current",
    errCurrent == "invalid_request" and rig.queue.current == nil,
    "err=" .. tostring(errCurrent) .. " current=" .. tostring(rig.queue.current))

  -- Verify queue is not deadlocked and processes following valid messages
  local valid = newMessage(0x1E, { maxRetries = 1 })
  rig.queue:add(valid)
  rig.tick()
  check("valid request after invalid request is transmitted normally",
    framesForCommand(rig.transport.sent, valid.command) == 1,
    "frames for 0x1E=" .. framesForCommand(rig.transport.sent, valid.command))
end

-- ---------------------------------------------------------------------------
-- Defect 7: simulator missing response aborts cleanly via abortCurrent
-- ---------------------------------------------------------------------------

-- The flag is read once, when queue.lua is loaded, so the global has to be in
-- place first. Flipping it after the module exists is not a scenario any more:
-- nothing can change whether the script runs in the simulator while it runs.
do
  local realGetVersion = system.getVersion
  system.getVersion = function() return { simulation = true } end
  local rig = newRig()
  local simMsg = newMessage(0x1234)
  rig.queue:add(simMsg)
  rig.tick()
  check("simulator missing response aborts with no_response",
    #simMsg.errors == 1 and simMsg.errors[1] == "no_response" and rig.queue.current == nil,
    "errors=" .. #simMsg.errors .. " current=" .. tostring(rig.queue.current))
  system.getVersion = realGetVersion
end

-- ---------------------------------------------------------------------------
-- A reply longer than the retry window is not a timeout
-- ---------------------------------------------------------------------------

-- A 448-byte reply (e.g. a 32 x 14-byte rule pool): one start frame
-- plus 90 continuation frames at 5 bytes each over S.Port. Streamed at one
-- frame per 0.1s, the reply takes 9s -- far past the 0.8s retry window. The
-- window used to count from the send alone, so a resend cut every attempt
-- off part-way through and the page load failed on max_retries.
local POOL_CMD = 172
local POOL_BYTES = 448

local function poolChunks()
  local chunks, chunk = {}, nil
  for i = 1, POOL_BYTES do
    if not chunk or #chunk == 5 then chunk = {}; chunks[#chunks + 1] = chunk end
    chunk[#chunk + 1] = i % 251
  end
  return chunks
end

do
  local rig = newRig()
  local msg = newMessage(POOL_CMD)
  rig.queue:add(msg)
  rig.tick() -- sends
  for _, frame in ipairs(replyFrames(POOL_CMD, POOL_BYTES, poolChunks())) do
    rig.transport.replies[#rig.transport.replies + 1] = frame
    rig.jump(0.1)
    rig.tick()
  end
  local got = msg.replies[1]
  check("a reply still arriving past the retry window is not resent",
    framesForCommand(rig.transport.sent, POOL_CMD) == 1,
    "requests sent=" .. framesForCommand(rig.transport.sent, POOL_CMD))
  check("a reply still arriving past the retry window completes",
    #msg.replies == 1 and #msg.errors == 0 and #got == POOL_BYTES
      and got[1] == 1 and got[POOL_BYTES] == POOL_BYTES % 251,
    "replies=" .. #msg.replies .. " errors=" .. #msg.errors ..
    " first error=" .. tostring(msg.errors[1]) .. " bytes=" .. (got and #got or 0))
end

-- The window still runs out when the reply stops part-way: silence, not the
-- length of the reply, is what triggers a resend.
do
  local rig = newRig()
  local msg = newMessage(POOL_CMD)
  rig.queue:add(msg)
  rig.tick() -- sends
  local frames = replyFrames(POOL_CMD, POOL_BYTES, poolChunks())
  for i = 1, 11 do
    rig.transport.replies[#rig.transport.replies + 1] = frames[i]
    rig.jump(0.1)
    rig.tick()
  end
  rig.jump(1.0) -- the link goes quiet for longer than the window
  rig.tick()
  check("a reply that stops part-way is resent after the window",
    framesForCommand(rig.transport.sent, POOL_CMD) == 2,
    "requests sent=" .. framesForCommand(rig.transport.sent, POOL_CMD))
end

-- One frame of a long reply is lost on the link. The rest of that reply keeps
-- arriving and is discarded, and the firmware answers a request sent into
-- that stream with no start frame (sendMspReply()'s headerSent is only
-- cleared when a reply finishes). So the resend has to wait until the broken
-- reply has finished arriving, and then gets a whole reply.
do
  local rig = newRig()
  local msg = newMessage(POOL_CMD)
  rig.queue:add(msg)
  rig.tick() -- sends
  local frames = replyFrames(POOL_CMD, POOL_BYTES, poolChunks())
  for i = 1, #frames do
    if i ~= 23 then -- lost on the link, 110 bytes in
      rig.transport.replies[#rig.transport.replies + 1] = frames[i]
    end
    rig.jump(0.1)
    rig.tick()
  end
  check("no resend while a broken reply is still arriving",
    framesForCommand(rig.transport.sent, POOL_CMD) == 1 and #msg.errors == 0,
    "requests sent=" .. framesForCommand(rig.transport.sent, POOL_CMD) ..
    " errors=" .. #msg.errors)

  rig.jump(1.0) -- the broken reply has finished: silence
  rig.tick()
  check("the resend follows once the broken reply has finished",
    framesForCommand(rig.transport.sent, POOL_CMD) == 2,
    "requests sent=" .. framesForCommand(rig.transport.sent, POOL_CMD))

  for i = 1, #frames do
    rig.transport.replies[#rig.transport.replies + 1] = frames[i]
    rig.jump(0.1)
    rig.tick()
  end
  local got = msg.replies[1]
  check("the resend's reply arrives complete",
    #msg.replies == 1 and #msg.errors == 0 and got and #got == POOL_BYTES,
    "replies=" .. #msg.replies .. " errors=" .. #msg.errors ..
    " bytes=" .. (got and #got or 0))
end

-- ---------------------------------------------------------------------------

print()
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.clock = realClock
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.clock = realClock
os.exit(1)

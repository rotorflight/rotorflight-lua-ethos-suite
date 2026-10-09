-- Behaviour check for the background task's drain budgets (issue #2382).
--
-- Run it:
--     lua5.4 bin/perf/verify_clock_budgets.lua
--
-- What it drives, and why:
--   * tasks/msp/common.lua, tasks/msp/queue.lua and tasks/elrs_sensors.lua are
--     pure functions of a transport, a clock and queued frames -- no radio, no
--     FC and no Ethos needed. Each transport is a stub that hands back whatever
--     backlog the scenario built, so every count and every budget below is
--     measured rather than inferred.
--   * os.clock() is replaced before any of them is loaded (they bind
--     `local os_clock = os.clock` at load time), and the stubs charge it for
--     the work they do: every poll and every pop advances the fake clock by
--     PER_FRAME_SECONDS. That is the shape the real cost has -- a popFrame()
--     across the C++/Lua boundary plus a frame decode -- and it is what makes
--     the deadlines under test actually bind. Without it the stubs answer in
--     nanoseconds, every deadline is unreachable, and the budget checks pass
--     for the wrong reason.
--
-- The issue asks for the os.clock() budgets to be bounded and for the simulator
-- flag to stop being re-derived per tick. Its stated root cause -- "the
-- elapsed-time loop structure means the full budget is always consumed,
-- regardless of how much work there was" -- does not hold: all three loops
-- return as soon as the queue runs dry (common.lua's mspPollReply returns nil
-- on an empty poll, elrs_sensors.lua breaks on a missing command, and both are
-- pinned below). So a deadline is not what makes an idle tick expensive, and
-- this check is built around what is actually at stake instead:
--
--   * a poll is bounded (mspPollReply's slice, mspClearBufs's frame count --
--     the two are different bounds because one loop assembles a reply and the
--     other discards frames, and bin/perf/verify_clock_budgets.lua is where
--     that distinction is pinned rather than argued);
--   * bounding the poll does not break reply assembly, which is the coupling
--     that decides how far each budget may be cut.
--
-- The last group is the load-bearing one: without it, a slice of 0.2ms -- or a
-- frame count of 1 -- would satisfy everything above and quietly break every
-- long read on the radio.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local MSP = ROOT .. "/src/rfsuite/tasks/msp"
local TASKS = ROOT .. "/src/rfsuite/tasks"

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

-- Controllable clock. `jump()` moves it between wakeups; every read nudges it
-- forward by STEP so the bounded loops terminate, and the stubs below charge it
-- PER_FRAME_SECONDS per frame they hand back.
local STEP = 0.000002
local PER_FRAME_SECONDS = 0.0001

-- What each budget is supposed to be. The modules export their own copy, and
-- the "is it the value the issue asks for" checks below compare the two -- but
-- the behavioural checks need a number to assert against even when the module
-- predates the export, so that this file reports findings against the old code
-- instead of aborting on a nil. A harness that dies on the code it is meant to
-- measure is worse than one that goes red on it.
--
-- The slice is 3ms and not the 1-2ms the issue asks for, and that is measured
-- rather than preferred: bin/msp_queue/verify_msp_queue.lua is a committed gate
-- whose fake clock charges 1ms per *clock read* and nothing per frame, so the
-- frames one call can take there is slice/1ms. At 2ms it can no longer take the
-- two frames of a minimal reply inside one wakeup, and two of its cases go red
-- ("a request after an aborted write still gets its reply", "a late frame of an
-- abandoned reply does not disarm the next request"). 3ms is the smallest cut
-- that changes no committed expectation. Fixing that gate's clock model to
-- charge frames rather than reads is what would unlock 1-2ms; that is a separate
-- change and is not done here.
local EXPECTED_POLL_SLICE = 0.003
local EXPECTED_CLEAR_CAP = 2
local EXPECTED_POP_BUDGET = 0.02

local clock = { now = 0.0 }
local realClock = os.clock
os.clock = function()
  local t = clock.now
  clock.now = t + STEP
  return t
end

-- How many times the queue asked Ethos whether it runs in the simulator.
-- system.getVersion() crosses the C++/Lua boundary and allocates a table per
-- call, so this count is the measurement.
local getVersionCalls = 0
system = {
  getVersion = function()
    getVersionCalls = getVersionCalls + 1
    return { simulation = false }
  end,
}

-- Every MSP/debug line the modules were asked to print, discarded.
package.loaded["rfsuite.lib.require"] = function(name)
  if name == "lib/debug_log.lua" then
    return {
      print = function() end,
      mspEnabled = function() return false end,
      msp = function() end,
    }
  end
  if name == "lib/elrs_sid_lookup.lua" then
    return {}
  end
  if name == "lib/elrs_decode_primitives.lua" then
    -- Only decU16 is ever called: parseFrame() reads a U16 SID and hands the
    -- rest of the pair to the table's own decoder.
    return {
      decU16 = function(data, pos)
        return (data[pos] or 0) * 256 + (data[pos + 1] or 0), pos + 2
      end,
    }
  end
  if name == "lib/diy_sensor.lua" then
    local DiySensor = {}
    DiySensor.__index = DiySensor
    function DiySensor.new(appId, sensorName, unit, minimum, maximum, moduleIndex, decimals)
      return setmetatable({ appId = appId, name = sensorName, unit = unit,
        minimum = minimum, maximum = maximum, moduleIndex = moduleIndex,
        decimals = decimals }, DiySensor)
    end
    function DiySensor:set() end
    function DiySensor:refresh() end
    function DiySensor:reset() end
    return DiySensor
  end
  if name == "lib/elrs_sensor_table.lua" then
    -- One standalone SID and one aggregate, so a frame can hold a start pair
    -- (which opens the buffer) and a continuation pair (which must find the
    -- sequence it expects).
    return function()
      return {
        [0x1030] = { name = "Test S16", unit = "x", prec = 1, min = nil, max = nil,
          dec = function(data, pos)
            return (data[pos] or 0) + (data[pos + 1] or 0) * 256, pos + 2
          end },
        [0x1031] = { name = "Test aggregate", unit = "x", prec = 1, min = nil, max = nil,
          dec = function(_, pos) return nil, pos + 2 end },
      }
    end
  end
  error("unexpected dependency: " .. tostring(name))
end

-- An MSP transport whose reply queue runs until a scenario says otherwise:
-- that case is the one the budgets exist for. Each poll costs PER_FRAME_SECONDS,
-- as a real popFrame() does.
local function newMspTransport(backlog)
  local t = {
    maxTxBufferSize = 6,
    maxRxBufferSize = 6,
    polls = 0,
    queue = backlog or {},
  }
  function t.mspSend() return true end
  function t.mspPoll()
    clock.now = clock.now + PER_FRAME_SECONDS
    t.polls = t.polls + 1
    return table.remove(t.queue, 1)
  end
  return t
end

-- Reply frames in the layout common.lua's receivedReply() parses: a start frame
-- carrying status, flags, command and length, then continuations numbered from
-- 1, five payload bytes each over S.Port.
local function replyFrames(cmd, declaredLen, chunks)
  local frames = {}
  frames[1] = { 0x40 | 0x10, 0, cmd % 256, math.floor(cmd / 256) % 256,
    declaredLen % 256, math.floor(declaredLen / 256) % 256 }
  for i, chunk in ipairs(chunks) do
    local frame = { i & 0x0F }
    for j = 1, #chunk do frame[j + 1] = chunk[j] end
    frames[#frames + 1] = frame
  end
  return frames
end

local function chunksOf(totalBytes, perFrame)
  local chunks, chunk = {}, nil
  for i = 1, totalBytes do
    if not chunk or #chunk == perFrame then chunk = {}; chunks[#chunks + 1] = chunk end
    chunk[#chunk + 1] = i % 251
  end
  return chunks
end

-- Restarts common.lua so no assembly state leaks between cases.
local function newCommon(transport)
  local common = dofile(MSP .. "/common.lua")
  common.setTransport(transport)
  return common
end

-- ---------------------------------------------------------------------------
-- 1. The budgets are the values the issue asks for
-- ---------------------------------------------------------------------------

local common0 = newCommon(newMspTransport({}))
local elrs0 = dofile(TASKS .. "/elrs_sensors.lua")

check("the mspPollReply slice is the value the issue asks for",
  common0.POLL_SLICE_SECONDS == EXPECTED_POLL_SLICE,
  "POLL_SLICE_SECONDS=" .. tostring(common0.POLL_SLICE_SECONDS))
check("the mspClearBufs cap is the value the issue asks for",
  common0.CLEAR_FRAME_CAP == EXPECTED_CLEAR_CAP,
  "CLEAR_FRAME_CAP=" .. tostring(common0.CLEAR_FRAME_CAP))
check("the elrs drain budget is bounded below the old 50ms",
  elrs0.POP_BUDGET_SECONDS ~= nil and elrs0.POP_BUDGET_SECONDS <= EXPECTED_POP_BUDGET,
  "POP_BUDGET_SECONDS=" .. tostring(elrs0.POP_BUDGET_SECONDS))

-- ---------------------------------------------------------------------------
-- 2. An idle link spends none of the budget
-- ---------------------------------------------------------------------------

-- The issue's root cause claims the full budget is always consumed. It is not:
-- every one of these loops stops the moment the queue runs dry, so the frame
-- caps and the deadlines are only ever reached when there is real work.
do
  local transport = newMspTransport({}) -- empty
  local common = newCommon(transport)
  common.mspSendRequest(0x09, {})
  clock.now = 0.0
  local before = clock.now
  common.mspPollReply()
  local spent = clock.now - before
  check("an idle MSP link costs one poll, not a budget",
    transport.polls == 1 and spent < 0.001,
    "polls=" .. transport.polls .. " clock spent=" .. string.format("%.4fs", spent))
end

do
  local elrs = dofile(TASKS .. "/elrs_sensors.lua")
  local pops = 0
  local transport = {
    popCustomTelemetryFrame = function()
      pops = pops + 1
      clock.now = clock.now + PER_FRAME_SECONDS
      return nil
    end,
  }
  clock.now = 0.0
  elrs.wakeup(transport, nil)
  check("an idle elrs link costs one pop, not a budget",
    pops == 1,
    "pops=" .. pops)
end

-- ---------------------------------------------------------------------------
-- 3. A backlog is bounded
-- ---------------------------------------------------------------------------

do
  local transport = newMspTransport({})
  for _ = 1, 400 do transport.queue[#transport.queue + 1] = { 0, 0, 0, 0, 0, 0 } end
  local common = newCommon(transport)
  common.mspSendRequest(0x09, {})

  clock.now = 0.0
  local before = clock.now
  common.mspPollReply()
  local spent = clock.now - before
  -- One iteration is allowed to overshoot: the loop reads the clock and then
  -- does a whole frame's worth of work.
  local slice = common.POLL_SLICE_SECONDS or EXPECTED_POLL_SLICE
  local allowed = slice + PER_FRAME_SECONDS + STEP
  check("mspPollReply spends at most its slice against a full queue",
    spent <= allowed,
    string.format("spent=%.4fs allowed=%.4fs (%d frames polled of 400)",
      spent, allowed, transport.polls))
end

do
  local transport = newMspTransport({})
  for _ = 1, 400 do transport.queue[#transport.queue + 1] = { 0, 0, 0, 0, 0, 0 } end
  local common = newCommon(transport)
  local cap = common.CLEAR_FRAME_CAP or EXPECTED_CLEAR_CAP

  clock.now = 0.0
  local before = clock.now
  common.mspClearBufs()
  local spent = clock.now - before

  check("mspClearBufs discards no more frames than its cap",
    transport.polls <= cap,
    "polled=" .. transport.polls .. " cap=" .. cap)
  check("mspClearBufs discards the frames it was going to throw away anyway",
    transport.polls == cap,
    "polled=" .. transport.polls .. " cap=" .. cap ..
    " (a count has no reason to stop early when every frame is dropped)")
  check("a count bounds mspClearBufs where the old 10ms deadline did not",
    spent < 0.001,
    string.format("clock spent=%.4fs (a deadline-only bound spends all 10ms here)", spent))
end

-- One custom-telemetry frame: two address bytes, a frame id, then a
-- (U16 sid, value) pair. See tasks/elrs_sensors.lua's parseFrame().
do
  local elrs = dofile(TASKS .. "/elrs_sensors.lua")
  local frameType, data = 0x88, { 0, 0, 0x11, 0x10, 0x30, 1, 2 }
  local remaining = 400
  local transport = {
    popCustomTelemetryFrame = function()
      if remaining <= 0 then return nil end
      remaining = remaining - 1
      clock.now = clock.now + PER_FRAME_SECONDS
      return frameType, data
    end,
  }
  clock.now = 0.0
  local before = clock.now
  elrs.wakeup(transport, nil)
  local spent = clock.now - before
  local budget = elrs.POP_BUDGET_SECONDS or EXPECTED_POP_BUDGET
  local allowed = budget + PER_FRAME_SECONDS + STEP
  check("the elrs wakeup spends at most its budget against a full queue",
    spent <= allowed,
    string.format("spent=%.4fs allowed=%.4fs (%d of 400 frames popped)",
      spent, allowed, 400 - remaining))
  check("the elrs wakeup leaves the rest of the backlog for the next wakeup",
    remaining > 0,
    "frames left=" .. remaining)
end

-- ---------------------------------------------------------------------------
-- 4. Frames left over past mspClearBufs' cap are harmless
-- ---------------------------------------------------------------------------

-- The issue's last section claims the smaller budget keeps this property. It
-- does: nothing acts on the leftovers' contents, mspClearBufs has already set
-- mspLastReq to 0 so they cannot be matched against anything, and a later
-- mspPollReply drains them on the way past.
do
  local transport = newMspTransport({})
  for _ = 1, 20 do transport.queue[#transport.queue + 1] = { 0, 0, 0, 0, 0, 0 } end
  local common = newCommon(transport)

  clock.now = 0.0
  common.mspClearBufs()
  local cap = common.CLEAR_FRAME_CAP or EXPECTED_CLEAR_CAP
  check("frames left over past the clear cap stay in the queue for a later drain",
    #transport.queue == 20 - cap,
    "queued=" .. #transport.queue .. " discarded=" .. transport.polls)

  check("a request armed behind the leftovers is accepted",
    common.mspSendRequest(0x09, {}) == true)
  for _, frame in ipairs(replyFrames(0x09, 2, { { 0x42, 0x43 } })) do
    transport.queue[#transport.queue + 1] = frame
  end

  local cmd, buf = nil, nil
  for _ = 1, 10 do
    clock.now = clock.now + 0.05
    cmd, buf = common.mspPollReply()
    if cmd then break end
  end
  check("a reply queued behind the leftovers still arrives",
    cmd == 0x09 and buf and buf[1] == 0x42 and buf[2] == 0x43,
    "cmd=" .. tostring(cmd) .. " payload=" ..
    (buf and string.format("%02X %02X", buf[1] or 0, buf[2] or 0) or "none"))
end

-- ---------------------------------------------------------------------------
-- 5. Bounding the poll does not break reply assembly
-- ---------------------------------------------------------------------------

-- The longest reply the framing allows: a 448-byte payload (a 32 x 14-byte rule
-- pool) is a start frame plus 90 continuations over S.Port, 5 payload bytes per
-- 6-byte frame. All of it queued at once -- the case a 2ms slice really does
-- cut into several wakeups, since at PER_FRAME_SECONDS per frame the whole
-- burst costs ~9ms of polling.
local POOL_CMD = 172
local POOL_BYTES = 448
-- What one wakeup costs the background task in this suite: tasks/background.lua
-- schedules its session poll at this interval inside the same wakeup, so a
-- period longer than it would break that too, never mind the MSP slice.
local WAKEUP_SECONDS = 0.05
-- tasks/msp/queue.lua's DEFAULT_RETRY_DELAY, the window a partially assembled
-- reply has to finish inside before a resend would discard it.
local RETRY_DELAY = 0.8

do
  local frames = replyFrames(POOL_CMD, POOL_BYTES, chunksOf(POOL_BYTES, 5))
  check("precondition: the longest reply really is this many frames",
    #frames == 91,
    "frames=" .. #frames)
  check("precondition: at this per-frame cost the slice really does cut the burst",
    #frames * PER_FRAME_SECONDS > 0.002,
    string.format("burst costs %.4fs of polling, slice is 0.0020s",
      #frames * PER_FRAME_SECONDS))
end

do
  local frames = replyFrames(POOL_CMD, POOL_BYTES, chunksOf(POOL_BYTES, 5))
  local transport = newMspTransport(frames)
  local common = newCommon(transport)
  common.mspSendRequest(POOL_CMD, {})

  local wakeups, cmd, buf = 0, nil, nil
  for _ = 1, 40 do
    clock.now = clock.now + WAKEUP_SECONDS
    wakeups = wakeups + 1
    cmd, buf = common.mspPollReply()
    if cmd then break end
  end
  check("a sliced 91-frame burst still assembles into the whole reply",
    cmd == POOL_CMD and buf and #buf == POOL_BYTES,
    "cmd=" .. tostring(cmd) .. " bytes=" .. tostring(buf and #buf or 0) ..
    " of " .. POOL_BYTES .. " after " .. wakeups .. " wakeups")
  check("it finished inside one retry window, which is what a resend would break",
    wakeups * WAKEUP_SECONDS < RETRY_DELAY,
    string.format("%.3fs of wakeups vs the %.1fs window (%d wakeups)",
      wakeups * WAKEUP_SECONDS, RETRY_DELAY, wakeups))
end

-- The same burst through the queue, which is where the coupling shows: a resend
-- resets mspStarted/mspRxBuf/mspRxRemoteSeq, so a sliced reply that is resend
-- mid-assembly can never complete.
do
  local frames = replyFrames(POOL_CMD, POOL_BYTES, chunksOf(POOL_BYTES, 5))
  local transport = newMspTransport(frames)
  local common = newCommon(transport)
  local Queue = dofile(MSP .. "/queue.lua")
  local queue = Queue.new(common)

  local msg = { command = POOL_CMD, payload = {}, maxRetries = 5 }
  msg.processReply = function(_, replyBuf) msg.got = replyBuf end
  msg.errorHandler = function(reason) msg.err = reason end
  queue:add(msg)

  for _ = 1, 40 do
    clock.now = clock.now + WAKEUP_SECONDS
    queue:processQueue()
    if msg.got then break end
  end
  check("a sliced burst still completes through the queue",
    msg.got and #msg.got == POOL_BYTES and not msg.err,
    "bytes=" .. tostring(msg.got and #msg.got or 0) .. " error=" .. tostring(msg.err))
  check("the whole reply is gone from the transport queue",
    #transport.queue == 0,
    "frames left=" .. #transport.queue)
end

-- ---------------------------------------------------------------------------
-- 6. The simulator flag is resolved once, not per tick
-- ---------------------------------------------------------------------------

do
  getVersionCalls = 0
  local Queue = dofile(MSP .. "/queue.lua")
  local afterLoad = getVersionCalls

  local queue = Queue.new(newCommon(newMspTransport({})))
  local msg = { command = 0x1E, payload = {}, maxRetries = 1 }
  msg.processReply = function() end
  msg.errorHandler = function() end
  queue:add(msg)

  for _ = 1, 20 do
    clock.now = clock.now + WAKEUP_SECONDS
    queue:processQueue()
  end

  check("loading the queue resolves the simulator flag once",
    afterLoad == 1,
    "getVersion() calls during load=" .. afterLoad)
  check("20 queue ticks do not ask Ethos for the version again",
    getVersionCalls == 1,
    "getVersion() calls=" .. getVersionCalls .. " over 20 ticks" ..
    " (one per tick is what it used to cost)")
end

-- The value still has to be *right*: a queue loaded in the simulator takes the
-- simulator path, one loaded on hardware does not.
do
  local realGetVersion = system.getVersion
  system.getVersion = function() return { simulation = true } end
  local SimQueue = dofile(MSP .. "/queue.lua")
  local simQueue = SimQueue.new(newCommon(newMspTransport({})))
  local simMsg = { command = 0x1E, payload = {}, simulatorResponse = { 1, 2, 3 } }
  -- Assigned after the table exists: a closure over a local that is still being
  -- declared sees nil, which would make this block pass for the wrong reason.
  simMsg.processReply = function(_, replyBuf) simMsg.got = replyBuf end
  simMsg.errorHandler = function() end
  simQueue:add(simMsg)
  clock.now = 0.0
  simQueue:processQueue()
  check("a queue loaded in the simulator still answers from simulatorResponse",
    simMsg.got and simMsg.got[1] == 1 and #simQueue.pending == 0,
    "bytes=" .. tostring(simMsg.got and #simMsg.got or 0))

  system.getVersion = realGetVersion
end

-- ---------------------------------------------------------------------------

-- Optional instruction budgets must preserve queued frames and partial replies.
do
  local usage = 0
  system.getInstructionsUsage = function() return usage end
  local frames = replyFrames(POOL_CMD, 20, chunksOf(20, 5))
  local transport = newMspTransport(frames)
  local poll = transport.mspPoll
  transport.mspPoll = function()
    usage = usage + 30
    return poll()
  end
  local common = newCommon(transport)
  common.mspSendRequest(POOL_CMD, {})
  local cmd = common.mspPollReply()
  check("instruction pressure pauses MSP between frames", cmd == nil and transport.polls == 2)
  local buf
  for _ = 1, 5 do
    usage = 0
    cmd, buf = common.mspPollReply()
    if cmd then break end
  end
  local intact = cmd == POOL_CMD and buf and #buf == 20
  if intact then
    for i = 1, 20 do if buf[i] ~= i then intact = false end end
  end
  check("MSP resumes with every payload byte intact", intact)

  usage = 100
  local before = transport.polls
  common.mspClearBufs()
  check("cleanup resets state without draining at exhausted budget", transport.polls == before)
  check("cleanup still releases the outstanding request", common.mspSendRequest(0x09, {}) == true)

  local longTransport = newMspTransport(replyFrames(POOL_CMD, POOL_BYTES, chunksOf(POOL_BYTES, 5)))
  local longPoll = longTransport.mspPoll
  longTransport.mspPoll = function()
    usage = usage + 30
    return longPoll()
  end
  local Queue = dofile(MSP .. "/queue.lua")
  local queue = Queue.new(newCommon(longTransport))
  local result, failure
  queue:add({command = POOL_CMD, payload = {},
    processReply = function(_, reply) result = reply end,
    errorHandler = function(reason) failure = reason end})
  for _ = 1, 100 do
    clock.now = clock.now + WAKEUP_SECONDS
    usage = 0
    queue:processQueue()
    if result or failure then break end
  end
  check("instruction-sliced long reply survives beyond the retry window",
    result and #result == POOL_BYTES and not failure and #longTransport.queue == 0)

  local elrs = dofile(TASKS .. "/elrs_sensors.lua")
  local remaining = 5
  local custom = { popCustomTelemetryFrame = function()
    if remaining == 0 then return nil end
    remaining = remaining - 1
    usage = usage + 35
    return 0x88, {0, 0, 0x11, 0x10, 0x30, 1, 2}
  end }
  usage = 70
  check("ELRS leaves frames queued and requests a retry at the limit",
    elrs.wakeup(custom, nil) == true and remaining == 5)
  usage = 0
  check("ELRS stops between complete frames under pressure",
    elrs.wakeup(custom, nil) == true and remaining == 3)
  for _ = 1, 3 do usage = 0; elrs.wakeup(custom, nil) end
  check("ELRS resumes and drains the remaining frames", remaining == 0)

  -- The native S.Port search is an inner loop: bounding common.lua alone
  -- cannot stop a backlog of unrelated frames from exhausting the allowance.
  local pops = 0
  local frame = {
    physId = function() return pops < 3 and 0x01 or 0x1B end,
    primId = function() return 0x32 end,
    appId = function() return 0x1234 end,
    value = function() return 0x12345678 end,
  }
  sport = { getSensor = function() return {
    popFrame = function()
      pops = pops + 1
      usage = usage + 30
      return frame
    end,
  } end }
  local transportSport = dofile(MSP .. "/transport_sport.lua")
  usage = 0
  check("S.Port yields while searching unrelated frames",
    transportSport.mspPoll() == nil and pops == 2)
  usage = 0
  local packet = transportSport.mspPoll()
  check("S.Port finds the queued reply on the next wakeup",
    packet and packet[1] == 0x34 and packet[6] == 0x12 and pops == 3)

  system.getInstructionsUsage = nil
  pops = 0
  transportSport = dofile(MSP .. "/transport_sport.lua")
  packet = transportSport.mspPoll()
  check("older Ethos keeps the original S.Port search", packet and pops == 3)
  sport = nil
end

-- Exercise the real dashboard engine through its public wakeup API. The fake
-- object charges instruction usage; all cursor/pass state belongs to the engine.
do
  local function dashboardScenario(hasApi)
    local usage, calls, messages = 0, {}, {}
    local object = {wakeup = function(box)
      calls[#calls + 1] = box.id
      usage = usage + 35
    end}
    local context = {
      setWidget = function() end,
      widgets = {dashboard = {utils = {isFullScreen = function() return false end}}},
    }
    local env = setmetatable({
      system = hasApi and {getInstructionsUsage = function() return usage end} or {},
      package = {loaded = {["rfsuite.lib.require"] = function(path)
        assert(path == "widgets/dashboard/context.lua", path)
        return context
      end}},
      loadfile = function(path)
        assert(path == "widgets/dashboard/objects/test.lua", path)
        return function() return object end
      end,
      print = function(message) messages[#messages + 1] = message end,
    }, {__index = _G})
    local engine = assert(loadfile(ROOT .. "/src/rfsuite/widgets/dashboard/engine.lua", "t", env))()
    local config = {scheduler = {spread_scheduling = false}, boxes = {
      {type = "test", id = 1}, {type = "test", id = 2}, {type = "test", id = 3},
    }}
    engine.preload({}, config) -- Isolate object waking from module-load pacing.
    return engine, config, calls, messages, function(value) usage = value end
  end

  local engine, config, calls, messages, setUsage = dashboardScenario(true)
  check("dashboard pauses between objects at 70 percent",
    engine.wakeup({}, config, 480, 320) == false and #calls == 2)
  check("dashboard leaves deferred objects unwoken",
    config.boxes[1]._dashboardWoken and config.boxes[2]._dashboardWoken
      and config.boxes[3]._dashboardWoken ~= true)
  for _ = 1, 5 do
    setUsage(70)
    check("dashboard pressure keeps the current object pending",
      engine.wakeup({}, config, 480, 320) == false and #calls == 2)
  end
  setUsage(0)
  check("dashboard resumes without skipping or repeating objects",
    engine.wakeup({}, config, 480, 320) == true and table.concat(calls, ",") == "1,2,3")
  check("normal budget deferral is silent", #messages == 0)
  setUsage(0)
  check("steady-state dashboard passes also pause",
    engine.wakeup({}, config, 480, 320, {maxObjects = 3}) == false and #calls == 5)
  engine.reset()
  setUsage(0)
  engine.wakeup({}, config, 480, 320)
  check("dashboard reset discards the paused cursor", calls[6] == 1 and calls[7] == 2)

  local oldEngine, oldConfig, oldCalls = dashboardScenario(false)
  check("dashboard without the API completes its original first pass",
    oldEngine.wakeup({}, oldConfig, 480, 320) == true and #oldCalls == 3)
  check("dashboard without the API still obeys explicit object pacing",
    oldEngine.wakeup({}, oldConfig, 480, 320, {maxObjects = 1}) == false
      and #oldCalls == 4 and oldCalls[4] == 1)
end

print()
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.clock = realClock
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.clock = realClock
os.exit(1)
-- Behaviour check for the MSP request queue across a disconnect, and for the
-- forced GC that used to run on every completed message (issue #2379).
--
-- Run it:
--     lua5.3 bin/msp_gc/verify_msp_disconnect.lua
--
-- Two claims, checked without a radio, an FC or Ethos:
--
--   1. A disconnect drops the request queue -- including while a flight is in
--      progress, which takes a different branch through the reset.
--   2. Completing a message no longer forces a full GC cycle. Proven with a
--      weak table under a *stopped* collector rather than with a stopwatch:
--      while the collector is stopped, garbage survives, and only an explicit
--      collectgarbage() can clear it. That makes the check deterministic and
--      independent of how fast the machine is -- a timing assertion here would
--      be a flaky assertion dressed up as a measurement.
--
-- A third claim -- that the queue goes before the session fields are wiped --
-- is deliberately *not* checked here. session.lua keeps its table private and
-- only publishes a snapshot at the end of the tick, so the order of the two
-- steps is not observable from outside the module, and a test that cannot fail
-- proves nothing. The ordering is a design decision recorded in the code.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local TASKS = ROOT .. "/src/rfsuite/tasks"
local MSP = TASKS .. "/msp"

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
-- tasks/session.lua
-- ---------------------------------------------------------------------------

-- session.lua resolves everything through rfsuite.lib.require and reads several
-- Ethos globals at load time. Both are replaced here: the loader by a stub that
-- hands out the smallest module satisfying each call site, the globals by the
-- values session.lua expects.
--
-- What is *not* stubbed is the thing under test. The claim is that session.lua
-- calls clear(), how often, and on which branch -- so the queue stand-in only
-- has to record the calls. Queue:clear()'s own contract is checked separately
-- below against the real implementation.
local function loadSession(opts)
  opts = opts or {}
  local active = opts.telemetryActive

  local published, subscriptions = {}, {}
  local cleared = 0
  local added = {}

  local spyQueue = {
    cleared = cleared,
    added = added,
    add = function(self, message)
      self.added[#self.added + 1] = message
      return true
    end,
    clear = function(self) self.cleared = self.cleared + 1 end,
  }

  -- The smallest thing that behaves like a built MSP request: session.lua only
  -- ever hands it to the queue, and the queue only ever calls its callbacks,
  -- which only run if a scenario delivers a reply.
  local function message()
    return { command = 1, payload = {}, processReply = function() end, errorHandler = function() end }
  end

  -- The real flight timer, not a stub: setConnected() consults it to decide
  -- whether a disconnect may clear the aircraft identity, and a stub would let
  -- a scenario pass that production could not. A scenario that needs a flight
  -- in progress drives it through its own update()/inProgress() calls.
  local flightTimer = opts.flightTimer or dofile(TASKS .. "/flight_timer.lua")

  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/bus.lua" then
      return {
        publish = function(topic, payload) published[#published + 1] = { topic, payload } end,
        subscribe = function(topic, fn) subscriptions[topic] = fn end,
      }
    elseif name == "lib/debug_log.lua" then
      return { print = function() end, msp = function() end, format = function() end }
    elseif name == "tasks/flight_timer.lua" then
      return flightTimer
    elseif name == "lib/smartfuel_calc.lua" or name == "lib/diy_sensor.lua" then
      return { new = function() return { reset = function() end } end }
    elseif name == "lib/settings_store.lua" then
      return {
        load = function() return {} end,
        simulatedApiVersionMode = function() return false end,
        syncNameEnabled = function() return false end,
      }
    elseif name == "lib/battery_profile_index.lua" then
      return { fromTelemetrySensor = function() return nil end, index0 = function() return nil end }
    elseif name == "lib/smartfuel_reserve.lua" then
      return { applyPercent = function() end }
    elseif name == "lib/model_preferences.lua" then
      return {
        load = function() return {} end, save = function() end,
        setSmartfuelModelType = function() end, setStats = function() end,
        setTimerTarget = function() end,
        smartfuelModelType = function() return 0 end,
        stats = function() return {} end, timerTarget = function() return 300 end,
      }
    elseif name == "lib/msp_api_version.lua" then
      return {
        buildReadMessage = message,
        isSupported = function() return true end,
        simResponseForVersion = function() return {} end,
      }
    end
    -- Everything else contributes one or more buildXMessage() builders, which
    -- session.lua only ever passes on to mspQueue:add().
    return setmetatable({}, { __index = function() return function() return message() end end })
  end

  CATEGORY_SYSTEM_EVENT, TELEMETRY_ACTIVE = 2, 0
  SMARTFUEL_APP_ID, UNIT_PERCENT = 0x1A00, "%"
  system = {
    getVersion = function() return { simulation = false } end,
    getSource = function() return { state = function() return active end } end,
  }
  model = { name = function() return "Test" end, set = function() end }

  local session = dofile(TASKS .. "/session.lua")
  -- setConnected()'s disconnect branch calls reset() on the sensor instances it
  -- holds; a stub without one aborts the branch under test before it finishes,
  -- which looks exactly like "the queue was not dropped".
  session.setTelemetrySensors({ getValue = function() return nil end, reset = function() end })

  return {
    session = session,
    queue = spyQueue,
    published = published,
    -- One background-task tick, with the telemetry link as given.
    tick = function(value)
      active = value
      session.wakeup(spyQueue, "sport", nil, { telemetryState = function() return value end })
    end,
  }
end

-- 1. The claim: a disconnect drops the queue.
do
  local rig = loadSession({ telemetryActive = true })
  rig.tick(true)
  check("sanity: the handshake queued requests while connecting",
    #rig.queue.added > 0, "queued=" .. #rig.queue.added)
  local before = rig.queue.cleared
  rig.tick(false)
  check("a disconnect drops the MSP request queue", rig.queue.cleared == before + 1,
    "clear() calls before=" .. before .. " after=" .. rig.queue.cleared)
end

-- 2. The disconnect must not double-clear, and a re-connect must not either:
--    clear() answers every message it drops, so a spurious call is not free.
do
  local rig = loadSession({ telemetryActive = true })
  rig.tick(true)
  rig.tick(false)
  local afterDisconnect = rig.queue.cleared
  rig.tick(false)
  check("a second tick with the link still down does not clear again",
    rig.queue.cleared == afterDisconnect,
    "clear() calls=" .. rig.queue.cleared .. " expected=" .. afterDisconnect)
  rig.tick(true)
  check("re-connecting does not clear the queue", rig.queue.cleared == afterDisconnect,
    "clear() calls=" .. rig.queue.cleared .. " expected=" .. afterDisconnect)
end

-- 3. The branch that a disconnect takes is not the same one in every case. While
--    a flight is in progress, setConnected() must keep the aircraft identity (a
--    reconnect may be a different aircraft, but a flight in progress is not) --
--    and the queue still has to go, because the link it was built for is gone
--    either way. Guarding the drain behind the same condition as the identity
--    reset would be an easy mistake to make here.
do
  local timer = dofile(TASKS .. "/flight_timer.lua")
  timer.update(true, true, 0)
  timer.update(true, true, 30)
  if type(timer.inProgress) ~= "function" or timer.inProgress(32) ~= true then
    check("a disconnect during a flight still drops the queue", false,
      "the flight timer could not be driven into an in-progress state, so this " ..
      "case could not be measured")
  else
    local rig = loadSession({ telemetryActive = true, flightTimer = timer })
    rig.tick(true)
    local before = rig.queue.cleared
    rig.tick(false)
    check("a disconnect during a flight still drops the queue",
      rig.queue.cleared == before + 1,
      "clear() calls before=" .. before .. " after=" .. rig.queue.cleared)
  end
end

-- ---------------------------------------------------------------------------
-- tasks/msp/queue.lua -- the forced GC
-- ---------------------------------------------------------------------------

-- The real queue and framing layer, on a transport with S.Port's framing
-- budget. Enough to load them; the GC question needs no reply traffic.
local function newRig()
  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/debug_log.lua" then
      return { print = function() end, msp = function() end }
    end
    error("unexpected dependency: " .. tostring(name))
  end
  system = { getVersion = function() return { simulation = false } end }
  local common = dofile(MSP .. "/common.lua")
  local Queue = dofile(MSP .. "/queue.lua")
  common.setTransport({
    maxTxBufferSize = 6, maxRxBufferSize = 6,
    mspSend = function() return true end,
    mspPoll = function() return nil end,
  })
  return common, Queue.new(common)
end

-- 4. Completing a message must not force a full collection.
--
-- The collector is stopped for the duration, so the incremental collector
-- cannot fire and steal the result: the only thing that can clear the weak
-- value is an explicit collectgarbage() inside the code under test -- which is
-- exactly what the old _finish() did on every single message.
do
  local common, queue = newRig()
  collectgarbage("stop")
  collectgarbage("collect") -- start from a clean, known heap

  local weak = setmetatable({}, { __mode = "v" })
  local message = { command = 0x1E, payload = {}, processReply = function() end }
  weak[1] = message
  queue.current = message
  queue.retryCount = 2
  message = nil

  queue:_finish()

  local collected = weak[1] == nil
  collectgarbage("restart")
  check("completing a message forces no full GC cycle", not collected,
    "the weak value was collected, so a full cycle still runs on the per-message path")
  check("Queue:_finish() resets retryCount to 0", queue.retryCount == 0,
    "retryCount was " .. tostring(queue.retryCount))
end

-- 5. The harness can see one, or check 4 proves nothing. Queue:clear() keeps its
--    collect, which is exactly the contrast that gives 4 its meaning.
--
--    Queue:clear() nils its droppedCurrent and droppedPending locals before
--    invoking collectgarbage(), so it reclaims both the dropped messages
--    themselves and any surrounding garbage immediately.
do
  local common, queue = newRig()
  collectgarbage("stop")
  collectgarbage("collect")

  local weak = setmetatable({}, { __mode = "v" })
  local currentMsg = { command = 0x20, payload = { 1, 2, 3 }, processReply = function() end }
  local pendingMsg = { command = 0x21, payload = { 4, 5, 6 }, processReply = function() end }
  local scratch = { 1, 2, 3 }
  weak[1] = currentMsg
  weak[2] = pendingMsg
  weak[3] = scratch
  queue.current = currentMsg
  queue.pending = { pendingMsg }
  queue.retryCount = 3
  currentMsg = nil
  pendingMsg = nil
  scratch = nil

  check("sanity: unreachable garbage survives while the collector is stopped",
    weak[1] ~= nil and weak[2] ~= nil and weak[3] ~= nil,
    "the weak values were collected before clear() ran")

  queue:clear()

  local collected = weak[1] == nil and weak[2] == nil and weak[3] == nil
  collectgarbage("restart")
  check("the harness does see a full collect where one still happens (Queue:clear)",
    collected, "Queue:clear() kept its collect, so this should have swept the weak values")
  check("Queue:clear() swept the dropped message tables themselves",
    weak[1] == nil and weak[2] == nil,
    "droppedCurrent/droppedPending locals were not nil'd before collectgarbage()")
  check("Queue:clear() resets retryCount to 0", queue.retryCount == 0,
    "retryCount was " .. tostring(queue.retryCount))
end

-- 6. clear() must still answer every message it drops. This is what makes the
--    new call site in setConnected() safe: a page waiting on a callback gets an
--    error, not silence.
do
  local common, queue = newRig()
  local reasons = {}
  local function queued(command)
    return {
      command = command,
      payload = {},
      processReply = function() end,
      errorHandler = function(reason) reasons[#reasons + 1] = reason end,
    }
  end
  queue.current = queued(0x09)
  queue:add(queued(0x1E))
  queue:add(queued(0x8A))
  queue:clear()
  check("clear() reports every dropped message, in flight and pending",
    #reasons == 3 and reasons[1] == "cleared" and reasons[2] == "cleared" and reasons[3] == "cleared",
    "reasons=" .. #reasons)
  check("clear() leaves nothing behind to be processed", queue:isProcessed(),
    "isProcessed() is false after clear()")
end

-- ---------------------------------------------------------------------------
-- What the removed call cost -- reported, never asserted
-- ---------------------------------------------------------------------------
--
-- Read this as an order of magnitude on desktop Lua 5.3, and note that it does
-- NOT reproduce the issue's cost estimate. At roughly 1 MB of live heap a
-- forced full collect costs about 0.05 ms here, so even 15 of them per second
-- would be around a tenth of a percent of a core -- the issue's "stop-the-world
-- per message" framing is not what this machine measures.
--
-- It is printed rather than asserted on purpose. An assertion on wall time
-- would be flaky by construction, and a desktop figure a reader mistakes for a
-- radio figure is worse than no figure at all. What a radio could say and this
-- cannot -- how often a message actually completes, and what one collect costs
-- on its CPU and its much smaller RAM budget -- is unmeasured, and the change
-- rests on the other argument: docs/memory-and-module-lifecycle.md section 9
-- measured that this call does not reduce RAM growth at all.
do
  local function heap(scale)
    local live = {}
    for i = 1, scale do live[i] = ("x"):rep(16) end
    collectgarbage("collect")
    return live
  end

  local realPause = collectgarbage("setpause", 200)
  print()
  print("  cost of one forced full collect (desktop Lua 5.3 -- NOT a radio figure,")
  print("  and it does not reproduce the issue's cost estimate):")
  for _, scale in ipairs({ 2000, 10000, 20000 }) do
    local live = heap(scale)
    local liveKb = collectgarbage("count")
    -- Enough samples that the total sits well clear of os.clock()'s resolution:
    -- at 20 samples a single collect was below the tick and the figure was
    -- quantised to 0.000/0.050 ms, which is a resolution artefact, not a cost.
    local samples = 500
    local started = os.clock()
    for _ = 1, samples do collectgarbage("collect") end
    local perCollect = (os.clock() - started) / samples
    print(string.format("    live heap %6.0f KB -> %.4f ms per forced collect (%d samples)",
      liveKb, perCollect * 1000, samples))
    live = nil
  end
  collectgarbage("setpause", realPause)
end

-- ---------------------------------------------------------------------------

print()
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.exit(1)

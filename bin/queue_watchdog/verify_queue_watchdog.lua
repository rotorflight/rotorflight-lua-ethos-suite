-- Behaviour check for the stall watchdog and the pipeline revival (issue #2363).
--
-- Run it from the repository root:
--     lua5.4 bin/queue_watchdog/verify_queue_watchdog.lua
--
-- What it drives, and why:
--   * The real lib/task_watchdog.lua against a controllable clock.
--   * The wiring in tasks/background.lua by reading its source: the stall check
--     has to run before the queue is used, the beat after the scheduler, and the
--     revival has to rebuild both and register the subtasks through the one
--     path taskInit uses.
--
-- Why a harness at all: with the per-call guards in place, one failing
-- callback no longer skips the rest of a tick -- but an error ahead of the
-- heartbeat publish still skips it on every tick, and Ethos keeps calling the
-- wakeup (measured in the WASM simulator). The task then stays alive and
-- silent, which is what this covers. Nothing in the build or the package step
-- reaches it.
--
-- Pinned:
--   * a task that never completed a tick is not due;
--   * a beat holds the watchdog closed until the threshold, and only the
--     threshold opens it -- past it, due() stays true until the next beat;
--   * a second builder value is honoured, and os.clock() is the default clock;
--   * every revival is counted;
--   * taskWakeup checks due() before the queue and beats after the scheduler;
--   * the revival rebuilds queue and scheduler, registers through
--     registerSubtasks, publishes its count, and does not re-subscribe the bus;
--   * taskInit keeps its two subscriptions and loads sim_sensors only in the
--     simulator.
--
-- A check that cannot fail proves nothing, so the clock check is run against a
-- copy of the watchdog with the threshold blown open, and the ordering check
-- against a copy of background.lua with the beat moved ahead of the scheduler.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

local checks, failures = 0, 0

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

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local content = f:read("*a")
  f:close()
  return (content:gsub("\r\n", "\n"))
end

local function loadChunk(source, name)
  return assert(load(source, "@" .. name))
end

print("Background-task stall watchdog and pipeline revival (issue #2363)")

-- The watchdog itself, against a clock the harness owns.
local realClock = os.clock
local clock = {now = 0.0}
os.clock = function()
  local t = clock.now
  clock.now = t + 0.001
  return t
end

local Watchdog = loadChunk(readFile(SUITE .. "/lib/task_watchdog.lua"), "task_watchdog.lua")()

do
  local w = Watchdog.new(3)
  check("a task that has not started a tick is not due",
    w:due(10) == false, "due before any start")

  w:start(10)
  check("a started tick holds the watchdog closed", w:due(12.999) == false)
  check("the threshold opens it, and not a moment earlier",
    w:due(12.999) == false and w:due(13) == true)
  check("past the threshold due() stays true", w:due(99) == true)
  w:start(20)
  check("a later tick does not postpone the stall", w:due(21) == true,
    "the mark must stay where the first tick started")
  w:beat()
  check("a beat closes it again", w:due(101) == false)

  w:noteRevival()
  w:noteRevival()
  check("every revival is counted", w.revivals == 2, w.revivals)

  local short = Watchdog.new(1)
  short:start(10)
  check("a second builder value is honoured", short:due(11) == true)

  local defaults = Watchdog.new(3)
  defaults:start()
  check("os.clock() is the default clock", defaults:due() == false)
end

-- The wiring in tasks/background.lua.
local background = readFile(SUITE .. "/tasks/background.lua")

local function orderPin(source, first, second)
  local i = source:find(first, 1, true)
  local j = source:find(second, 1, true)
  return i ~= nil and j ~= nil and i < j
end

-- One function's own text. Pins that search the whole file match the first
-- occurrence anywhere, which is how a pin ends up reading a line from another
-- function and passing for the wrong reason.
local function functionBody(source, header)
  local from = assert(source:find(header, 1, true), "header not found: " .. header)
  local to = assert(source:find("\nend", from, 1, true), "end not found: " .. header)
  return source:sub(from, to)
end

do
  local wakeupBody = functionBody(background, "local function taskWakeup()")
  -- Markers carry the line's own indentation: a bare "scheduler:wakeup()"
  -- also appears in the comment above it, and a pin that matches the comment
  -- passes for the wrong reason.
  check("taskWakeup checks due() before it uses the queue",
    orderPin(wakeupBody, "if watchdog:due(now) then revivePipeline(now) end",
             "\n  mspQueue:wakeup()\n"))
  check("the start comes before the queue, the beat after the scheduler ran",
    orderPin(wakeupBody, "\n  watchdog:start(now)\n", "\n  mspQueue:wakeup()\n")
      and orderPin(wakeupBody, "\n  scheduler:wakeup()\n", "\n  watchdog:beat()\n"))
  check("taskInit and the revival register through the one path",
    background:find("local function registerSubtasks()", 1, true) ~= nil
      and background:find("  registerSubtasks()", 1, true) ~= nil
      and select(2, background:gsub("\n  registerSubtasks()", "")) == 2,
    select(2, background:gsub("\n  registerSubtasks()", "")) .. " call sites")
  check("taskInit keeps its two bus subscriptions",
    select(2, background:gsub("bus%.subscribe%(", "")) == 2)
  check("taskInit still loads sim_sensors only in the simulator",
    orderPin(background, "if system.getVersion().simulation == true then",
             "simSensors = simSensors or requireModule(\"tasks/sim_sensors.lua\")"))
  check("the published status carries the revival count",
    background:find("revivals = watchdog.revivals,", 1, true) ~= nil)

  local reviveFrom = background:find("local function revivePipeline(now)", 1, true)
  local reviveTo = background:find("\nend", reviveFrom, 1, true)
  local reviveBody = background:sub(reviveFrom, reviveTo)  check("the revival rebuilds the queue inside its own body",
    reviveBody:find("mspQueue = requireModule(\"tasks/msp/queue.lua\").new(mspCommon)", 1, true) ~= nil)
  check("the revival rebuilds the scheduler inside its own body",
    reviveBody:find("scheduler = Scheduler.new()", 1, true) ~= nil)
  check("the revival puts the replacement in before clearing the old queue",
    reviveBody:find("local oldQueue = mspQueue", 1, true) ~= nil
      and orderPin(reviveBody, "mspQueue = requireModule(\"tasks/msp/queue.lua\").new(mspCommon)",
                   "pcall(oldQueue.clear, oldQueue)"))
  check("the clear runs on the old queue, not the replacement",
    reviveBody:find("pcall(oldQueue.clear, oldQueue)", 1, true) ~= nil)
  check("the revival counts as a recovered tick",
    reviveBody:find("watchdog:beat()", 1, true) ~= nil)
  check("the revival does not re-subscribe the bus handlers",
    reviveBody:find("bus.subscribe", 1, true) == nil)
end

-- Can-fail: the clear pin against a copy that drops the old queue silently.
do
  local dropped = (background:gsub("\n  local cleared, clearErr = pcall%(oldQueue%.clear, oldQueue%)\n", "\n", 1))
  check("the clear of the old queue could be located", dropped ~= background)
  check("without that clear the pin goes red (this check can go red)",
    dropped:find("pcall(oldQueue.clear, oldQueue)", 1, true) == nil)
end

-- Can-fail: the clock check against a watchdog whose threshold can never open.
do
  -- Positive control: with the threshold intact this sequence IS due. Without
  -- it, a check that reads "not due" passes for any reason at all.
  local w0 = Watchdog.new(3)
  w0:start(10)
  check("the threshold check can go red at all", w0:due(13) == true)

  local open = readFile(SUITE .. "/lib/task_watchdog.lua")
  open = (open:gsub("%>= self%.stallSeconds", ">= math.huge", 1))
  check("the threshold replacement could be located", open:find(">= math.huge", 1, true) ~= nil)
  local Broken = loadChunk(open, "task_watchdog_open.lua")()
  local w = Broken.new(3)
  w:start(10)
  check("without a threshold the watchdog never opens (this check can go red)",
    w:due(13) == false, "a blown-open threshold has to read as not due")
end

-- Can-fail: the ordering check against a copy with the beat moved ahead.
do
  local moved = (background:gsub("\n  watchdog:beat%(now%)\n", "", 1))
  moved = (moved:gsub("\n  scheduler:wakeup%(%)%s*\n",
                     "\n  watchdog:beat(now)\n  scheduler:wakeup()\n", 1))
  check("the beat could be moved ahead of the scheduler", moved ~= background)
  check("with the beat ahead of the scheduler the pin goes red (this check can go red)",
    not orderPin(moved, "\n  scheduler:wakeup()\n", "\n  watchdog:beat(now)\n"))
end

os.clock = realClock

print(string.format("%s: %d checks, %d failure(s)",
  failures == 0 and "PASSED" or "FAILED", checks, failures))
os.exit(failures == 0 and 0 or 1)

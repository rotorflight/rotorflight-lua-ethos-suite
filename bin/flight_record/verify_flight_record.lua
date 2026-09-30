-- Behaviour check for the flight record across a link loss.
--
-- Run it:
--     lua5.3 bin/flight_record/verify_flight_record.lua --self-test
--
-- What it drives, and why:
--   * tasks/flight_timer.lua is a pure function of (connected, armed, now), so
--     the whole state machine can be stepped without a radio, an FC or Ethos.
--   * tasks/logging.lua decides between holding one CSV open and starting a
--     second one. Its loader is stubbed and its file writes are redirected into
--     a scratch directory, so the test can count the files a flight produces.
--
-- Every case states what it expects, and the two that describe the old
-- behaviour are the point: a check that cannot fail proves nothing about the
-- behaviour it passes.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
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
-- tasks/flight_timer.lua
-- ---------------------------------------------------------------------------

-- Counts the flightCounted and finishedSegment events a scenario produces,
-- which is what session.lua turns into stats.flightcount and totalflighttime.
-- Every finished segment is kept, because a scenario can close two flights and
-- asserting on only the last one would not see the first.
local function runTimer(steps)
  local timer = dofile(TASKS .. "/flight_timer.lua")
  local counts, segments, live = 0, {}, nil
  for _, step in ipairs(steps) do
    local _, snapshot, event = timer.update(step[1], step[2], step[3])
    if event then
      if event.flightCounted then counts = counts + 1 end
      if event.finishedSegment then segments[#segments + 1] = event.finishedSegment end
    end
    live = snapshot.timerLive
  end
  return {
    flightCounts = counts,
    segments = segments,
    finishedSegments = #segments,
    firstSegment = segments[1],
    lastSegment = segments[#segments],
    live = live,
  }
end

local GRACE = 30
local COUNT_AT = 25

-- 1. An ordinary flight, no link loss. The behaviour that has to stay put.
do
  local r = runTimer({
    {true, true, 0}, {true, true, 10}, {true, true, 30}, {true, false, 40},
  })
  check("plain flight: counted once at 25s", r.flightCounts == 1,
    "flightCounts=" .. r.flightCounts)
  check("plain flight: one finished segment of 40s", r.finishedSegments == 1 and r.lastSegment == 40,
    "segments=" .. r.finishedSegments .. " last=" .. tostring(r.lastSegment))
end

-- 2. A two-second link drop mid-flight: the case the issue is about.
--
-- The expected duration is 47s, not the 50s of wall clock between arming and
-- disarming: the three seconds the link was down are not flight, the pilot had
-- no link and no control. A check that counted them would be asserting that
-- outage time belongs to the flight.
do
  local r = runTimer({
    {true, true, 0}, {true, true, 30},          -- 30s flown, counted once
    {false, nil, 32},                            -- 2s gap
    {true, true, 35}, {true, true, 45},          -- 12s more
    {true, false, 50},
  })
  check("brief drop: the flight is still counted once", r.flightCounts == 1,
    "flightCounts=" .. r.flightCounts .. " (2 would double-count the same flight)")
  check("brief drop: one finished segment", r.finishedSegments == 1,
    "segments=" .. r.finishedSegments)
  check("brief drop: 30s plus 15s is one flight of 47s", r.lastSegment == 47,
    "lastSegment=" .. tostring(r.lastSegment))
end

-- 3. The drop before the count threshold: the joined flight is 22s of flight
-- time, which is under the threshold, so it counts nothing -- but it is still
-- one flight and one segment, not two. The threshold is measured from the start
-- of the flight, so the pre-drop 12s count towards it.
do
  local r = runTimer({
    {true, true, 0}, {true, true, 10},
    {false, nil, 12}, {true, true, 15}, {true, true, 20}, {true, false, 25},
  })
  check("brief drop early: 22s of flight stays under the 25s threshold", r.flightCounts == 0,
    "flightCounts=" .. r.flightCounts)
  check("brief drop early: one segment of 22s", r.finishedSegments == 1 and r.lastSegment == 22,
    "segments=" .. r.finishedSegments .. " last=" .. tostring(r.lastSegment))
end

-- 3b. The same shape, but long enough to cross the threshold. This is the case
-- that separates "measured from the flight's start" from "measured from the
-- resume point": the pre-drop leg alone is already past 25s, so a threshold read
-- from the resume point would report the 5s leg and never count this flight.
do
  local r = runTimer({
    {true, true, 0}, {true, true, 30},
    {false, nil, 32}, {true, true, 35}, {true, true, 40},
    {true, false, 45},
  })
  check("drop after the threshold: counted from the flight's start", r.flightCounts == 1,
    "flightCounts=" .. r.flightCounts .. " (the 30s leg already passed 25s)")
  check("drop after the threshold: one flight of 42s", r.finishedSegments == 1 and r.lastSegment == 42,
    "segments=" .. r.finishedSegments .. " last=" .. tostring(r.lastSegment))
end

-- 4. A gap longer than the grace window: two flights, the first one banked.
--    The link stays down across two ticks on purpose -- a link normally stays
--    down for many, and a second one must not wipe the flight being held open.
do
  local r = runTimer({
    {true, true, 0}, {true, true, 30},
    {false, nil, 32},
    {false, nil, 32 + GRACE + 1},               -- still down, grace now expired
    {true, true, 32 + GRACE + 2},               -- reconnects armed, too late
    {true, true, 62 + GRACE + 2},               -- 30s into the new flight
    {true, false, 72 + GRACE + 2},
  })
  check("long gap: the first flight is closed", r.finishedSegments == 2,
    "segments=" .. r.finishedSegments)
  check("long gap: the first flight keeps its 32s", r.firstSegment == 32,
    "firstSegment=" .. tostring(r.firstSegment))
  check("long gap: the second flight is its own 40s", r.lastSegment == 40,
    "lastSegment=" .. tostring(r.lastSegment))
  check("long gap: the second flight is counted again", r.flightCounts == 2,
    "flightCounts=" .. r.flightCounts .. " (a second flight must be able to count)")
end

-- 5. The pack swap from the issue, step by step: armed, flight, land, disarm,
--    unplug, new pack, arm. This must never end up as one record.
do
  local r = runTimer({
    {true, true, 0}, {true, true, 30}, {true, false, 35},   -- flight one, landed
    {false, nil, 40}, {true, false, 45},                     -- unplugged, new pack
    {true, true, 50}, {true, true, 75}, {true, false, 80},   -- flight two
  })
  check("pack swap: two finished segments", r.finishedSegments == 2,
    "segments=" .. r.finishedSegments .. " (1 would merge two flights)")
  check("pack swap: counted twice, once per flight", r.flightCounts == 2,
    "flightCounts=" .. r.flightCounts)
  check("pack swap: each flight reports its own time", r.lastSegment == 30,
    "lastSegment=" .. tostring(r.lastSegment) .. " (expected 30s for the second flight)")
end

-- 6. Disarmed while the link is down: the flight was over, so it stays over.
--    update() only runs on real ticks, so the second flight is sampled at 25s
--    while armed; that is what it takes for the threshold to be seen.
do
  local r = runTimer({
    {true, true, 0}, {true, true, 30},
    {false, nil, 32},
    {true, false, 34},                          -- reconnects, pilot had disarmed
    {true, true, 40}, {true, true, 65}, {true, false, 70},
  })
  check("disarmed while down: the held flight is closed, not resumed", r.finishedSegments == 2,
    "segments=" .. r.finishedSegments)
  check("disarmed while down: the next flight is its own", r.flightCounts == 2,
    "flightCounts=" .. r.flightCounts)
end

-- 7. resumable() is the signal tasks/logging.lua reads, and it has to expire.
--    Reported rather than called blindly: a missing function is a failed check,
--    not a crashed run, so the report still reaches the cases below it.
do
  local timer = dofile(TASKS .. "/flight_timer.lua")
  timer.update(true, true, 0)
  timer.update(true, true, 30)
  timer.update(false, nil, 32)
  if type(timer.resumable) ~= "function" then
    check("resumable() exists for the log writer", false,
      "flight_timer has no resumable(), so nothing can tell a held flight from a finished one")
  else
    check("resumable is true right after an armed link loss", timer.resumable(33) == true,
      "resumable(33)=" .. tostring(timer.resumable(33)))
    check("resumable is false once the grace window has passed",
      timer.resumable(32 + GRACE + 1) == false,
      "resumable(63)=" .. tostring(timer.resumable(32 + GRACE + 1)))
    check("inProgress is true right after an armed link loss",
      timer.inProgress(33) == true,
      "inProgress(33)=" .. tostring(timer.inProgress(33)))
    check("inProgress is false once the grace window has passed",
      timer.inProgress(32 + GRACE + 1) == false,
      "inProgress(63)=" .. tostring(timer.inProgress(32 + GRACE + 1)))
  end
  local fresh = dofile(TASKS .. "/flight_timer.lua")
  check("resumable is false when nothing was held open",
    type(fresh.resumable) ~= "function" or fresh.resumable(0) == false)
  check("inProgress is false when nothing was held open",
    type(fresh.inProgress) ~= "function" or fresh.inProgress(0) == false)
end

-- 8. reset() still means reset, because session.lua and the app both rely on it.
do
  local timer = dofile(TASKS .. "/flight_timer.lua")
  timer.update(true, true, 0)
  timer.update(true, true, 30)
  timer.reset()
  local s = timer.current()
  check("reset clears the session, the live time and the count",
    s.timerSession == 0 and s.timerLive == 0 and s.timerFlightCounted == false,
    "session=" .. s.timerSession .. " live=" .. s.timerLive .. " counted=" .. tostring(s.timerFlightCounted))
  check("inProgress is false after reset", timer.inProgress() == false)
end

-- ---------------------------------------------------------------------------
-- tasks/logging.lua
-- ---------------------------------------------------------------------------

-- logging.lua resolves its dependencies through rfsuite.lib.require and writes
-- to "LOGS:/...", which is a mount that only exists on a radio. Both are
-- replaced here: the loader by a stub, the paths by a scratch directory, so the
-- only thing under test is the decision to hold a file open or open a new one.
local function loadLogging(scratch)
  local log = {}      -- every line debugLog was asked to print
  local started = {}  -- every file the logger opened for writing
  local handlers = {} -- the bus subscriptions, so the test can deliver them

  -- lib/require.lua *returns* the require function, so package.loaded holds the
  -- function itself, not a factory that would hand one back.
  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/bus.lua" then
      return {
        -- logging.lua keeps its own copy of the session and fills it from this
        -- event alone, so the handler has to be captured and called for real.
        -- Swallowing it here is what made the file count come out zero.
        subscribe = function(event, fn) handlers[event] = fn end,
      }
    elseif name == "lib/settings_store.lua" then
      return {
        load = function() return {} end,
        loggingEnabled = function() return true end,
        loggingSampleInterval = function() return 0 end,
      }
    elseif name == "lib/debug_log.lua" then
      return { print = function(msg) log[#log + 1] = msg end }
    elseif name == "lib/ini.lua" or name == "lib/atomic_write.lua" then
      -- The real modules, not stubs: start() and writeModelIni() now stage
      -- their file and swap it in, and a stub here would hide that the swap
      -- lands on the scratch path. They resolve each other through this very
      -- stub, which is the same chain a radio walks.
      local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
      if package.loaded[key] == nil then
        package.loaded[key] = dofile(ROOT .. "/src/rfsuite/" .. name)
      end
      return package.loaded[key]
    end
    error("unexpected dependency: " .. tostring(name))
  end

  local realOpen, realMkdir = io.open, os.mkdir
  local realRename, realRemove = os.rename, os.remove
  local function redirect(path)
    return (tostring(path):gsub("^LOGS:", scratch))
  end
  io.open = function(path, mode)
    local handle = realOpen(redirect(path), mode)
    -- Only the CSV counts: start() also writes logs.ini, and the claim under
    -- test is about flight records, not about the model name beside them.
    -- The header is staged, so the handle a new log opens is on "<file>.csv.tmp"
    -- -- the match is deliberately not anchored, or every flight would count
    -- zero files and the scenarios below would pass for the wrong reason.
    if handle and tostring(mode) == "w" and tostring(path):match("%.csv") then
      started[#started + 1] = tostring(path)
    end
    return handle
  end
  -- The staged write swaps the temp file into place with os.rename/os.remove,
  -- which are not redirected by the io.open above -- so a save would try to
  -- rename a "LOGS:" path that does not exist off a radio, and every log would
  -- fail to start.
  os.rename = function(old, new) return realRename(redirect(old), redirect(new)) end
  os.remove = function(path) return realRemove(redirect(path)) end
  -- Lua 5.3 as built on this workstation has no os.mkdir, and the logger's
  -- safeMkdir() skips the call silently when it is absent -- so without this the
  -- log directory is never created and every open fails, which looks exactly
  -- like "the logger never started". The harness supplies the capability, one
  -- level at a time, which is the order ensureDir() asks for.
  os.mkdir = function(path)
    local target = redirect(path)
    return os.execute('mkdir "' .. target .. '" 2>nul') == 0
  end

  local ok, mod = pcall(dofile, TASKS .. "/logging.lua")
  if not ok then
    io.open, os.mkdir, os.rename, os.remove = realOpen, realMkdir, realRename, realRemove
    error(mod)
  end
  -- The overrides stay in place for the whole scenario: the logger opens its
  -- file from wakeup(), not while it is being loaded, so restoring them here
  -- would send every write back to a "LOGS:" path that does not exist off a
  -- radio and the file count would be zero for that reason alone.
  local function restore()
    io.open, os.mkdir, os.rename, os.remove = realOpen, realMkdir, realRename, realRemove
  end
  return mod, started, log, handlers, restore
end

-- One step: deliver the session the way session.lua would, then let the logger
-- do its work for this tick.
local function step(ctx, connected, armed, resumable)
  ctx.handlers["session.update"]({
    connected = connected,
    isArmed = armed,
    flightResumable = resumable,
    mcuId = "FC123",
    craftName = "Test",
  })
  ctx.logging.wakeup("crsf")
end

local function scratchDir(name)
  local dir = os.getenv("TEMP") or os.getenv("TMP") or "."
  return dir .. "/rfsuite_flight_record_" .. name
end

local function runLogScenario(name, steps)
  local scratch = scratchDir(name)
  os.execute("rmdir /s /q " .. scratch:gsub("/", "\\") .. " 2>nul")
  local logging, started, log, handlers, restore = loadLogging(scratch)
  local ctx = { logging = logging, handlers = handlers }
  logging.setSettings({})
  logging.setTelemetrySensors({
    getValue = function(_, sensor)
      if sensor == "voltage" then return 22.0 end
      if sensor == "current" then return 10.0 end
      if sensor == "rpm" then return 3000 end
      return 0
    end,
  })
  for _, s in ipairs(steps) do step(ctx, s[1], s[2], s[3]) end
  restore()
  return #started, log
end

-- The flight the issue is about: armed, a two-second gap, still armed.
do
  local files = runLogScenario("one_flight", {
    {true, true, false},   -- armed, link up: one file opens
    {false, nil, true},    -- link lost mid-flight, flight still open
    {true, true, false},   -- reconnects armed: the same file, resumed (resumable now false)
    {true, true, false},
  })
  check("log: a brief armed link loss keeps one file", files == 1,
    "files opened=" .. files .. " (2 means one flight was split)")
end

-- The pack swap, step by step. It must never end up as one file.
do
  local files = runLogScenario("pack_swap", {
    {true, true, false},   -- flight one
    {true, false, false},  -- landed and disarmed
    {false, nil, false},   -- unplugged
    {true, false, false},  -- new pack, still disarmed
    {true, true, false},   -- armed again: flight two
  })
  check("log: a pack swap produces a second file", files == 2,
    "files opened=" .. files .. " (1 would merge two flights)")
end

-- A flight that ended while the link was down must not be merged into the next.
do
  local files = runLogScenario("disarmed_down", {
    {true, true, false},   -- flight one
    {false, nil, true},    -- link lost mid-flight
    {true, false, true},   -- reconnects, but the pilot had disarmed
    {true, true, false},   -- next flight
  })
  check("log: a flight that ended during the outage is not merged", files == 2,
    "files opened=" .. files)
end

-- A gap past the grace window ends the record, even though the pilot never
-- disarmed. The window is what stops a reconnect hours later from inheriting a
-- flight that was abandoned.
do
  local files = runLogScenario("grace_expired", {
    {true, true, false},   -- flight one
    {false, nil, true},    -- link lost, flight held open
    {false, nil, false},   -- the window expires, so nothing is held any more
    {true, true, false},   -- reconnects armed: a new record
  })
  check("log: an expired grace window ends the record", files == 2,
    "files opened=" .. files .. " (1 would inherit a flight that was abandoned)")
end

-- ---------------------------------------------------------------------------

print()
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.exit(1)

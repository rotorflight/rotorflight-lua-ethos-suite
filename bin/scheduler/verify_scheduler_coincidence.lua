-- Measurement pin for issue #2439: how often a telemetry read shares one
-- scheduler pass with the 0.25 s audio tasks.
--
-- Run it:
--     lua5.4 bin/scheduler/verify_scheduler_coincidence.lua
--
-- What it drives, and why:
--   * The REAL src/rfsuite/tasks/scheduler.lua. os.clock() is replaced before
--     the scheduler runs (it reads os.clock() at wakeup time), and the harness
--     advances that clock by one pass period per pass.
--   * The intervals are READ FROM THE SOURCE: the scheduler:add(...) lines in
--     tasks/background.lua and TELEMETRY_VALUE_INTERVAL in tasks/session.lua.
--     They are not copied. If an interval changes, the first checks go red and
--     the measurement has to be taken again, instead of silently measuring the
--     old value.
--   * The telemetry gate lives as a local function in session.lua, so it is
--     modelled here as the same few lines inside the "session" task. A check
--     pins the lines of session.lua that the model copies.
--
-- What it measures: the share of telemetry reads that run in the same scheduler
-- pass as audio_events. It is reported for the pass periods listed below, which
-- are stated cadences, not a measurement of the Ethos radio. The radio's
-- wakeup cadence is NOT measured here, so these numbers say how the scheduler
-- behaves under each cadence, not how often it happens on the sender.
--
-- What it pins, and why each one can go red:
--   1. Instrument: at a fixed 125 ms pass every telemetry read coincides with
--      audio_events. If the model is broken and audio never runs, this goes red.
--   2. Not structural: at a fixed 5 ms pass the same intervals coincide far less
--      often than always. The issue claims coincidence is guaranteed by the
--      interval table alone; this pins that it is not.
--   3. Staggering is not a general fix: audio at 0.3 s drops the 125 ms share to
--      a third, but at 100 ms it rises above the current 0.25 s value. A change
--      that stops this check from going red has to re-measure before it claims a
--      fix.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SCHEDULER = ROOT .. "/src/rfsuite/tasks/scheduler.lua"
local BACKGROUND = ROOT .. "/src/rfsuite/tasks/background.lua"
local SESSION = ROOT .. "/src/rfsuite/tasks/session.lua"

local failures = 0
local checks = 0

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s%s", label, detail and ("  -- " .. detail) or ""))
  end
end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path)
  local s = f:read("a")
  f:close()
  return s
end

-- Only the four tasks that run on the radio are looked at. sim_sensors is
-- registered only in simulation and is not part of the measurement.
local WANTED = {"session", "logging", "audio_events", "audio_switches"}

local function registeredIntervals(src)
  local found = {}
  for name, value in src:gmatch('scheduler:add%("([%w_]+)",%s*([%d%.]+)') do
    found[name] = tonumber(value)
  end
  return found
end

local bgSrc = readFile(BACKGROUND)
local sessionSrc = readFile(SESSION)
local intervals = registeredIntervals(bgSrc)

print("source")
for _, name in ipairs(WANTED) do
  check(string.format("background.lua registers %s", name), intervals[name] ~= nil)
end

local SESSION_IV = intervals["session"]
local LOG_IV = intervals["logging"]
local AUDIO_IV = intervals["audio_events"]
local TELEMETRY_IV = tonumber(sessionSrc:match("local TELEMETRY_VALUE_INTERVAL%s*=%s*([%d%.]+)"))

check("session task runs every 0.05 s", SESSION_IV == 0.05, tostring(SESSION_IV))
check("audio_events and audio_switches run at the same interval",
  intervals["audio_switches"] == AUDIO_IV, tostring(intervals["audio_switches"]))
check("audio_events runs every 0.25 s", AUDIO_IV == 0.25, tostring(AUDIO_IV))
check("telemetry read interval is 0.5 s (session.lua)", TELEMETRY_IV == 0.5, tostring(TELEMETRY_IV))

-- The gate that the model below copies. If session.lua changes this logic, the
-- model no longer describes the code and the measurement has to be revisited.
check("session.lua gate skips while not yet due",
  sessionSrc:find("if nextAt and now < nextAt then", 1, true) ~= nil)
check("session.lua gate reschedules from the current time",
  sessionSrc:find("nextScheduledAt[key] = now + interval", 1, true) ~= nil)
check("telemetry is gated through shouldRunScheduled",
  sessionSrc:find('shouldRunScheduled("telemetry", TELEMETRY_VALUE_INTERVAL, now)', 1, true) ~= nil)

-- The simulated clock. scheduler.lua calls os.clock() inside wakeup().
local realClock = os.clock
local simClock = 0
os.clock = function() return simClock end

local scheduler = dofile(SCHEDULER)

local SEED = 12345

-- One simulated run. Returns reads, coincident, share.
local function simulate(audioInterval, passPeriod, jittered, seconds)
  simClock = 0
  local seed = SEED
  local function rnd()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
  end

  local sched = scheduler.new()
  local gate = {}
  local function shouldRun(key, interval, now)
    local nextAt = gate[key]
    if nextAt and now < nextAt then return false end
    gate[key] = now + interval
    return true
  end

  local telemetryThisPass, audioThisPass = false, false
  sched:add("session", SESSION_IV, function(now)
    if shouldRun("telemetry", TELEMETRY_IV, now) then telemetryThisPass = true end
  end)
  sched:add("logging", LOG_IV, function() end)
  sched:add("audio_events", audioInterval, function() audioThisPass = true end)
  sched:add("audio_switches", audioInterval, function() end)

  local reads, coincident = 0, 0
  local t = 0
  while t < seconds do
    simClock = t
    telemetryThisPass, audioThisPass = false, false
    sched:wakeup()
    if telemetryThisPass then
      reads = reads + 1
      if audioThisPass then coincident = coincident + 1 end
    end
    local step = passPeriod
    if jittered then step = passPeriod * (0.8 + 0.4 * rnd()) end
    t = t + step
  end
  return reads, coincident, reads > 0 and coincident / reads or 0
end

local SECONDS = 120

print("measurement")
local _, _, shareCurrent125 = simulate(AUDIO_IV, 0.125, false, SECONDS)
check("1. fixed 125 ms pass: every telemetry read coincides with audio_events",
  shareCurrent125 == 1.0, string.format("share=%.3f", shareCurrent125))

local _, _, shareCurrent5 = simulate(AUDIO_IV, 0.005, false, SECONDS)
check("2. fixed 5 ms pass: coincidence is far from guaranteed (below 5 %)",
  shareCurrent5 < 0.05, string.format("share=%.3f", shareCurrent5))

local _, _, shareCurrent100 = simulate(0.25, 0.1, false, SECONDS)
local _, _, shareStagger100 = simulate(0.3, 0.1, false, SECONDS)
local _, _, shareStagger125 = simulate(0.3, 0.125, false, SECONDS)
check("3a. audio at 0.3 s still reaches a third at 125 ms, not zero",
  shareStagger125 > 0.25 and shareStagger125 < 0.5,
  string.format("share=%.3f", shareStagger125))
check("3b. audio at 0.3 s is worse than 0.25 s at 100 ms (the stagger is not a general fix)",
  shareStagger100 > shareCurrent100,
  string.format("0.3 s=%.3f  0.25 s=%.3f", shareStagger100, shareCurrent100))

print()
os.clock = realClock
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.exit(1)

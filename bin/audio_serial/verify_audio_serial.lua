-- Behaviour check for serialised state-change announcements (issue #2503).
--
-- Run it from the repository root:
--     lua5.4 bin/audio_serial/verify_audio_serial.lua
--
-- What it drives, and why:
--   * The real tasks/audio_events.lua, loaded with the bus, the settings store,
--     the engine type, system audio and os.clock stubbed, and driven one wakeup
--     at a time on a controllable clock. The wakeup runs every 0.25 s, which is
--     the interval tasks/background.lua schedules this task at.
--   * Every file and number the task asks the radio to play is logged with the
--     clock value it was asked at, so a test can see which calls landed in the
--     same wakeup.
--
-- Why a harness at all: the arming, profile, battery and governor announcements
-- used to run back to back with no gate between them. The radio cuts a running
-- file when the next one starts, so the pilot heard the last call of the
-- wakeup and lost the rest. The gate that would have serialised them existed
-- and was wired only into the adjustment path.
--
-- Pinned:
--   * a change that arrives while another announcement is still playing waits,
--     and is spoken once the first is over, not in the same wakeup;
--   * the waiting change is compared again on the next wakeup, so it is spoken
--     without being repeated;
--   * a single change is still spoken at once, with no added delay;
--   * a governor change waits behind a profile announcement and is spoken once;
--   * a change still waiting when the link drops is not spoken after a reconnect.
--
-- A check that cannot fail proves nothing, so the last check strips the gate
-- from a copy of the task and requires the profile call to land in the same
-- wakeup as the arming call there. That check passes on the copy because the
-- copy does what the bug did; if it ever fails, the instrument has gone blind.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local SUITE_PREFIX = SUITE .. "/"
local AUDIO_PATH = SUITE .. "/tasks/audio_events.lua"

local checks, failures = 0, 0

-- The real print, held before anything below replaces the globals this file
-- uses for its own output.
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
  else
    failures = failures + 1
    out(string.format("  FAIL  %s", label))
    if detail then out("        " .. tostring(detail)) end
  end
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local content = f:read("*a")
  f:close()
  -- CRLF to LF: the patterns below anchor on the source text, and a stray CR
  -- would quietly stop them matching under core.autocrlf=true checkouts.
  return (content:gsub("\r\n", "\n"))
end

-- The task loads its own modules with loadfile() and a path that has no
-- directory part; on the radio the working directory is src/rfsuite. Same
-- redirect the other audio harnesses use, for the same reason.
package.path = SUITE_PREFIX .. "?.lua;" .. package.path
_G.PREFIX = SUITE_PREFIX
local realLoadfile = loadfile
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (SUITE_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

local savedSystem = _G.system
local savedOsClock = os.clock
local savedRequire = package.loaded["rfsuite.lib.require"]

-- One fresh task per scenario, so its upvalues (the speaking clock, the held
-- changes, the previous values) cannot carry between them. `source` replaces
-- the file the task is loaded from, which is what the can-fail check uses.
local function newRig(events, source)
  -- The store fills the keys a scenario does not set from its defaults. The loss vibrate switch
  -- defaults on (#2312), so a rig that leaves it out gets the same default.
  local merged = {telemetry_lost_haptic = true}
  for key, value in pairs(events or {}) do merged[key] = value end
  events = merged
  local handlers = {}
  local log = {}
  local clock = 0

  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/bus.lua" then
      return {
        subscribe = function(topic, fn) handlers[topic] = fn end,
        publish = function() end,
      }
    elseif name == "lib/settings_store.lua" then
      return {
        load = function() return {events = events} end,
        audioEvents = function(s) return s.events or {} end,
        audioTimer = function() return {} end,
      }
    elseif name == "lib/engine_type.lua" then
      return {isElectric = function() return true end}
    end
    return loadfile(name)()
  end

  _G.system = {
    playFile = function(path)
      log[#log + 1] = {t = clock, s = path:match("([^/]+)$")}
    end,
    playNumber = function(value)
      log[#log + 1] = {t = clock, s = "num:" .. tostring(value)}
    end,
    playHaptic = function() log[#log + 1] = {t = clock, s = "haptic"} end,
    getAudioVoice = function() return "en/default" end,
  }
  os.clock = function() return clock end

  local audio = assert(load(source or readFile(AUDIO_PATH), "@" .. AUDIO_PATH))()

  local rig = {}
  function rig.setClock(t) clock = t end
  function rig.step(snapshot)
    handlers["session.update"](snapshot)
    handlers["settings.update"]({events = events})
    audio.wakeup()
  end
  -- Everything played so far, as "time what" pairs, in the order it was asked.
  function rig.timeline()
    local parts = {}
    for i = 1, #log do
      parts[i] = string.format("%.2f %s", log[i].t, log[i].s)
    end
    return table.concat(parts, "; ")
  end
  return rig
end

-- Steps the same snapshot on every wakeup from `from` to `to`, 0.25 s apart.
local function runTo(rig, from, to, snapshot)
  local t = from
  while t <= to + 1e-9 do
    rig.setClock(t)
    rig.step(snapshot)
    t = t + 0.25
  end
end

-- Initialises at 0 and sees the same state at 0.25, so the next wakeup is the
-- first one that can announce a change.
local function seed(rig, snapshot)
  rig.setClock(0); rig.step(snapshot)
  rig.setClock(0.25); rig.step(snapshot)
end

out("state changes in one wakeup are spoken one after another (issue #2503)")

do
  local rig = newRig({armflags = true, pid_profile = true, rate_profile = true})
  seed(rig, {connected = true, isArmed = false, pidProfile = 1, rateProfile = 1})
  runTo(rig, 0.50, 3.00, {connected = true, isArmed = true, pidProfile = 2, rateProfile = 2})
  local expected = "0.50 armed.wav; 1.00 profile.wav; 1.00 num:2; 2.25 rates.wav; 2.25 num:2"
  check("arming, then profile, then rates, each in its own wakeup, each spoken once",
    rig.timeline() == expected, "got: " .. rig.timeline())
end

do
  local rig = newRig({armflags = true})
  seed(rig, {connected = true, isArmed = false})
  runTo(rig, 0.50, 2.00, {connected = true, isArmed = true})
  check("a single change is still spoken at once, and only once",
    rig.timeline() == "0.50 armed.wav", "got: " .. rig.timeline())
end

do
  local rig = newRig({pid_profile = true, governor = true})
  seed(rig, {connected = true, isArmed = true, pidProfile = 1, governorMode = 1, governorState = 1})
  runTo(rig, 0.50, 2.50, {connected = true, isArmed = true, pidProfile = 2, governorMode = 1, governorState = 2})
  check("a governor change waits behind a profile announcement and is spoken once",
    rig.timeline() == "0.50 profile.wav; 0.50 num:2; 1.75 spoolup.wav",
    "got: " .. rig.timeline())
end

do
  local rig = newRig({armflags = true, pid_profile = true})
  seed(rig, {connected = true, isArmed = false, pidProfile = 1})
  rig.setClock(0.50); rig.step({connected = true, isArmed = true, pidProfile = 2})
  rig.setClock(0.75); rig.step({connected = false})
  rig.setClock(1.00); rig.step({connected = true, isArmed = true, pidProfile = 2})
  runTo(rig, 1.25, 3.00, {connected = true, isArmed = true, pidProfile = 2})
  check("a change still waiting when the link drops is not spoken after the reconnect",
    rig.timeline() == "0.50 armed.wav", "got: " .. rig.timeline())
end

-- A waiting arming change must not hide the armed model from the telemetry-lost
-- alert. The alert is judged on the last armed state the task saw, not on the
-- announcement baseline, which a waiting change keeps behind.
do
  local rig = newRig({armflags = true, pid_profile = true, telemetry_lost = true})
  seed(rig, {connected = true, isArmed = false, pidProfile = 1})
  rig.setClock(0.50); rig.step({connected = true, isArmed = false, pidProfile = 2})
  rig.setClock(0.75); rig.step({connected = true, isArmed = true, pidProfile = 2})
  rig.setClock(1.00); rig.step({connected = false})
  check("a link drop right after a waiting arming change still raises the telemetry-lost alert",
    rig.timeline() == "0.50 profile.wav; 0.50 num:2; 1.00 haptic", "got: " .. rig.timeline())
end

-- Can-fail: take the gate out of announceProfile() in a copy of the task. The
-- profile call then lands in the same wakeup as the arming call, and this
-- check must go red.
do
  local source = readFile(AUDIO_PATH)
  local gate = "if not canSpeak(now) then holdPrevious[key] = true; return end"
  local start, stop = source:find(gate, 1, true)
  check("the profile gate could be located in announceProfile()", start ~= nil)
  if start then
    local stripped = source:sub(1, start - 1) .. source:sub(stop + 1)
    local rig = newRig({armflags = true, pid_profile = true}, stripped)
    seed(rig, {connected = true, isArmed = false, pidProfile = 1})
    rig.setClock(0.50); rig.step({connected = true, isArmed = true, pidProfile = 2})
    check("without the profile gate the profile call lands in the arming wakeup (this check can go red)",
      rig.timeline():find("0.50 profile.wav", 1, true) ~= nil, "got: " .. rig.timeline())
  end
end

-- Put back what the rig replaced, so nothing after this file sees a stub.
_G.system = savedSystem
os.clock = savedOsClock
package.loaded["rfsuite.lib.require"] = savedRequire

out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

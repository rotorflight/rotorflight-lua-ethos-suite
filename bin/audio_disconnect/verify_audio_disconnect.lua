-- Behaviour check for the link-loss edge of tasks/audio_events.lua (issue #2437).
--
-- Run it from the repository root:
--     lua5.4 bin/audio_disconnect/verify_audio_disconnect.lua
--
-- What it drives, and why:
--   * The real tasks/audio_events.lua, loaded with the same stubs the serial
--     harness uses (bus, settings store, engine type, system audio, os.clock),
--     and driven one wakeup at a time on a controllable clock.
--   * The disconnected branch of wakeup() is entered on a link loss and every
--     tick after it. The reset that belongs to the falling edge runs once per
--     outage, not on every tick while the link is down. The check below pins
--     what that edge must still do: forget the outage state, announce the loss
--     of an armed model once, and announce the recovery once.
--
-- Pinned:
--   * a change made while the link is down is not spoken after the reconnect;
--   * the loss of an armed model is announced, and so is the recovery, and a
--     second outage is announced as well, so the falling edge re-arms after a
--     reconnect instead of latching for the rest of the session.
--
-- A check that cannot fail proves nothing, so the last check removes the
-- re-arm from a copy of the task and requires the second outage to go silent
-- there. That passes on the copy because the copy does what the bug would do;
-- if it ever fails, the instrument has gone blind.

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

out("the falling edge runs once per outage and re-arms after each reconnect (issue #2437)")

-- A change made while the link is down is not spoken after the reconnect: the
-- first connected wakeup only takes the baseline, as before.
do
  local rig = newRig({armflags = true, pid_profile = true})
  seed(rig, {connected = true, isArmed = false, pidProfile = 1})
  rig.setClock(0.50); rig.step({connected = false})
  rig.setClock(0.75); rig.step({connected = false, pidProfile = 2})
  rig.setClock(1.00); rig.step({connected = true, isArmed = false, pidProfile = 2})
  runTo(rig, 1.25, 3.00, {connected = true, isArmed = false, pidProfile = 2})
  check("a change made while the link is down is not spoken after the reconnect",
    rig.timeline() == "", "got: " .. rig.timeline())
end

-- The loss of an armed model is announced and so is the recovery. The second
-- outage must be announced too, which only happens if the falling edge re-armed
-- on the reconnect.
do
  local rig = newRig({armflags = true, telemetry_lost = true})
  seed(rig, {connected = true, isArmed = false})
  rig.setClock(0.50); rig.step({connected = true, isArmed = true})
  rig.setClock(1.00); rig.step({connected = false})
  rig.setClock(1.50); rig.step({connected = true, isArmed = true})
  rig.setClock(2.00); rig.step({connected = false})
  rig.setClock(2.50); rig.step({connected = true, isArmed = true})
  local timeline = rig.timeline()
  local lossCount = 0
  for _ in timeline:gmatch("haptic") do lossCount = lossCount + 1 end
  check("the loss and the recovery of an armed model are announced for each of two outages",
    timeline:find("2.00 ", 1, true) ~= nil and lossCount == 4,
    "got: " .. timeline)
end

-- Can-fail: remove the re-arm of the falling edge from a copy of the task. The
-- second outage then goes silent, which is the bug this scenario exists to catch.
do
  local source = readFile(AUDIO_PATH)
  local rearm = "disconnectApplied = false -- re-arm the falling edge"
  local start, stop = source:find(rearm, 1, true)
  check("the falling-edge re-arm could be located in wakeup()", start ~= nil)
  if start then
    local stripped = source:sub(1, start - 1) .. source:sub(stop + 1)
    local rig = newRig({armflags = true, telemetry_lost = true}, stripped)
    seed(rig, {connected = true, isArmed = false})
    rig.setClock(0.50); rig.step({connected = true, isArmed = true})
    rig.setClock(1.00); rig.step({connected = false})
    rig.setClock(1.50); rig.step({connected = true, isArmed = true})
    rig.setClock(2.00); rig.step({connected = false})
    rig.setClock(2.50); rig.step({connected = true, isArmed = true})
    check("without the re-arm the second outage is silent (this check can go red)",
      rig.timeline():find("2.00 ", 1, true) == nil, "got: " .. rig.timeline())
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

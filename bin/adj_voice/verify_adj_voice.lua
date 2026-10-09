-- Behaviour check for in-flight adjustment announcements (issue #2315).
--
-- Run it from the repository root:
--     lua5.4 bin/adj_voice/verify_adj_voice.lua
--
-- What it drives, and why:
--   * The real tasks/audio_events.lua, loaded with the bus, the settings store,
--     the engine type, system audio and os.clock stubbed, and driven one wakeup
--     at a time against a controllable clock. The wakeup runs every 0.25 s,
--     which is the interval tasks/background.lua schedules this task at.
--   * The adjustment words resolve through playFile()'s en/default fallback, so
--     the spoken name of function 14 is the three words under adjfunctions/.
--
-- Why a harness at all: the announcement is reached by nothing in the build or
-- the package step, and the failure is quiet in the direction that matters. The
-- task used to speak the first step of a burst and drop every step that landed
-- while that number was still playing, so three clicks on a trim switch
-- announced a value the model no longer had.
--
-- Pinned:
--   * a burst of steps says one number, and it is the last one;
--   * nothing is said until the value has stood still for the settle window;
--   * a function change says the name once, followed by the settled value;
--   * a step that settles while an announcement is still playing is spoken
--     afterwards, not dropped;
--   * adj_v = false keeps a value-only change silent, adj_f = false keeps a
--     function change with constant value silent, function 0 says nothing,
--     and a change still waiting when the link drops is not spoken later.
--
-- A check that cannot fail proves nothing, so the last check strips the settle
-- guard from a copy of the task and requires the burst to be announced from its
-- first step there. If that check stops turning red, the instrument has gone
-- blind.

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
-- redirect the audio harness uses, for the same reason.
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

local function spokenValues(rig)
  local values = {}
  for i = 1, #rig.spoken do values[i] = tostring(rig.spoken[i].value) end
  return table.concat(values, ",")
end

-- One fresh task per scenario, so the task's own upvalues (the settle window,
-- the pending change, the speaking clock) cannot carry between them. `source`
-- replaces the file the task is loaded from, which is what the can-fail check
-- uses.
local function newRig(events, source)
  local handlers = {}
  local played, spoken = {}, {}

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
    playFile = function(path) played[#played + 1] = path end,
    playNumber = function(value, unit, decimals)
      spoken[#spoken + 1] = {value = value, unit = unit, decimals = decimals}
    end,
    playHaptic = function() end,
    getAudioVoice = function() return "en/default" end,
  }

  local clock = 0
  os.clock = function() return clock end

  local audio = assert(load(source or readFile(AUDIO_PATH), "@" .. AUDIO_PATH))()

  local rig = {spoken = spoken}
  function rig.setClock(t) clock = t end
  function rig.step(snapshot)
    handlers["session.update"](snapshot)
    handlers["settings.update"]({events = events})
    audio.wakeup()
  end
  function rig.count(file)
    local n = 0
    for _, path in ipairs(played) do
      if path:find(file, 1, true) then n = n + 1 end
    end
    return n
  end
  return rig
end

-- Seeds function 14 ("pitch p gain") at 50 and leaves the clock at 0.25.
local function newAdjRig(events, source)
  local rig = newRig(events, source)
  rig.setClock(0); rig.step({connected = true, adjFunction = 14, adjValue = 50})    -- initialize
  rig.setClock(0.25); rig.step({connected = true, adjFunction = 14, adjValue = 50}) -- seen
  return rig
end

-- Three steps 0.25 s apart.
local function adjBurst(rig)
  rig.setClock(0.50); rig.step({connected = true, adjFunction = 14, adjValue = 51})
  rig.setClock(0.75); rig.step({connected = true, adjFunction = 14, adjValue = 52})
  rig.setClock(1.00); rig.step({connected = true, adjFunction = 14, adjValue = 53})
end

out("in-flight adjustments settle before they are spoken (issue #2315)")

do
  local rig = newAdjRig({adj_v = true})
  adjBurst(rig)
  check("nothing is spoken while the value is still moving",
    #rig.spoken == 0, "spoke " .. spokenValues(rig))
  rig.setClock(1.25); rig.step({connected = true, adjFunction = 14, adjValue = 53}) -- 0.25 < 0.35
  check("nothing is spoken before the settle window has passed",
    #rig.spoken == 0, "spoke " .. spokenValues(rig))
  rig.setClock(1.50); rig.step({connected = true, adjFunction = 14, adjValue = 53}) -- 0.50 >= 0.35
  check("a burst of steps says one number, and it is the last one",
    spokenValues(rig) == "53", "spoke " .. spokenValues(rig))
  rig.setClock(3.00); rig.step({connected = true, adjFunction = 14, adjValue = 53})
  check("a settled value is not repeated",
    spokenValues(rig) == "53", "spoke " .. spokenValues(rig))
  check("a value-only change does not say the function's name",
    rig.count("adjfunctions/") == 0, rig.count("adjfunctions/") .. " word(s)")
end

-- The function changes on the first step of the burst.
do
  local rig = newAdjRig({adj_f = true, adj_v = true})
  rig.setClock(0.50); rig.step({connected = true, adjFunction = 15, adjValue = 30})
  rig.setClock(0.75); rig.step({connected = true, adjFunction = 15, adjValue = 31})
  check("a function change is not announced while the value is still moving",
    rig.count("adjfunctions/") == 0 and #rig.spoken == 0,
    rig.count("adjfunctions/") .. " word(s), spoke " .. spokenValues(rig))
  rig.setClock(1.00); rig.step({connected = true, adjFunction = 15, adjValue = 31})
  rig.setClock(1.25); rig.step({connected = true, adjFunction = 15, adjValue = 31})
  check("a function change says the three words of its name once",
    rig.count("adjfunctions/pitch.wav") == 1 and rig.count("adjfunctions/i.wav") == 1
      and rig.count("adjfunctions/gain.wav") == 1 and rig.count("adjfunctions/") == 3,
    rig.count("adjfunctions/") .. " word(s)")
  check("the name is followed by the settled value",
    spokenValues(rig) == "31", "spoke " .. spokenValues(rig))

  -- Name and number take 3 * 0.45 + 0.6 s from 1.25, so the task is still
  -- speaking until 3.2. A step that settles inside that has to wait, not go.
  rig.setClock(1.50); rig.step({connected = true, adjFunction = 15, adjValue = 32})
  rig.setClock(2.00); rig.step({connected = true, adjFunction = 15, adjValue = 32})
  rig.setClock(3.00); rig.step({connected = true, adjFunction = 15, adjValue = 32})
  check("a step that settles during an announcement is held back",
    spokenValues(rig) == "31", "spoke " .. spokenValues(rig))
  rig.setClock(3.25); rig.step({connected = true, adjFunction = 15, adjValue = 32})
  check("and is spoken once the announcement is over",
    spokenValues(rig) == "31,32", "spoke " .. spokenValues(rig))
  check("without the name a second time",
    rig.count("adjfunctions/") == 3, rig.count("adjfunctions/") .. " word(s)")
end

do
  local rig = newAdjRig({adj_f = true, adj_v = false})
  adjBurst(rig)
  rig.setClock(2.00); rig.step({connected = true, adjFunction = 14, adjValue = 53})
  check("adj_v = false keeps a value-only change silent",
    #rig.spoken == 0 and rig.count("adjfunctions/") == 0,
    rig.count("adjfunctions/") .. " word(s), spoke " .. spokenValues(rig))
end

do
  local rig = newAdjRig({adj_f = true, adj_v = false})
  rig.setClock(0.50); rig.step({connected = true, adjFunction = 15, adjValue = 50})
  rig.setClock(0.70); rig.step({connected = true, adjFunction = 15, adjValue = 51})
  rig.setClock(0.90); rig.step({connected = true, adjFunction = 15, adjValue = 51})
  check("pending function announcement restarts settle window on value change when adj_v is false",
    #rig.spoken == 0 and rig.count("adjfunctions/") == 0,
    rig.count("adjfunctions/") .. " word(s), spoke " .. spokenValues(rig))
  rig.setClock(1.10); rig.step({connected = true, adjFunction = 15, adjValue = 51})
  check("and speaks settled function and value after settle window",
    spokenValues(rig) == "51" and rig.count("adjfunctions/") == 3,
    rig.count("adjfunctions/") .. " word(s), spoke " .. spokenValues(rig))
end

do
  local rig = newAdjRig({adj_f = false, adj_v = true})
  -- Function changes from 14 to 15, value stays at initial 50.
  rig.setClock(0.50); rig.step({connected = true, adjFunction = 15, adjValue = 50})
  rig.setClock(1.50); rig.step({connected = true, adjFunction = 15, adjValue = 50})
  check("adj_f = false keeps a function change silent when value is unchanged",
    #rig.spoken == 0 and rig.count("adjfunctions/") == 0,
    rig.count("adjfunctions/") .. " word(s), spoke " .. spokenValues(rig))
end

do
  local rig = newAdjRig({adj_f = true, adj_v = true})
  rig.setClock(0.50); rig.step({connected = true, adjFunction = 0, adjValue = 0})
  rig.setClock(1.50); rig.step({connected = true, adjFunction = 0, adjValue = 0})
  check("function 0 says nothing",
    #rig.spoken == 0 and rig.count("adjfunctions/") == 0,
    rig.count("adjfunctions/") .. " word(s), spoke " .. spokenValues(rig))
end

do
  local rig = newAdjRig({adj_v = true})
  adjBurst(rig)
  rig.setClock(1.25); rig.step({connected = false})
  rig.setClock(1.50); rig.step({connected = true, adjFunction = 14, adjValue = 53}) -- initialize
  rig.setClock(2.50); rig.step({connected = true, adjFunction = 14, adjValue = 53})
  check("a change still waiting when the link drops is not spoken later",
    #rig.spoken == 0, "spoke " .. spokenValues(rig))
end

-- Can-fail: strip the settle guard and require the burst to be announced from
-- its first step. If this stops turning red, the checks above prove nothing.
do
  local source = readFile(AUDIO_PATH)
  local stripped = source:gsub(
    "if %(now %- adjChangedAt%) < ADJ_SETTLE_SECONDS then return end", "", 1)
  check("the settle guard could be located in announceAdjustment()", stripped ~= source)
  local rig = newAdjRig({adj_v = true}, stripped)
  adjBurst(rig)
  check("without the settle guard the first step of a burst is spoken (this check can go red)",
    #rig.spoken >= 1 and rig.spoken[1].value == 51, "spoke " .. spokenValues(rig))
end

-- Put back what the rig replaced, so nothing after this file sees a stub.
_G.system = savedSystem
os.clock = savedOsClock
package.loaded["rfsuite.lib.require"] = savedRequire
_G.loadfile = realLoadfile

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

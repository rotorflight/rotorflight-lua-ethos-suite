-- Behaviour check for the SmartFuel callout steps (#2757): which percentages are spoken for each
-- "Callout percent" choice, as the pilot's Fuel page labels them.
--
-- Run it (from the repository root):
--     lua5.4 bin/smartfuel_callout_steps/verify_smartfuel_callout_steps.lua
--     lua5.4 bin/smartfuel_callout_steps/verify_smartfuel_callout_steps.lua --self-test
--
-- Drives the real src/rfsuite/tasks/audio_events.lua with the bus, the settings store and the
-- system calls stubbed. The fuel value falls one percent per wakeup from 100 to 1, and the check
-- records the percentages spoken. It pins:
--   1. "Every 5%" speaks every 5 percent, from 95 down to 5 (#2757);
--   2. "Default" speaks at 10 percent only (the 100 step can never be crossed);
--   3. "10" speaks at 90 down to 10;
--   4. "50" speaks at 50 and 10 (the steps in its table);
--   5. the Fuel page's default is the Default choice (0), the value a new store holds.
--
-- Self-test: with the old "Every 5%" table ({50, 5}) check 1 must go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local AUDIO_PATH = SUITE .. "/tasks/audio_events.lua"
local FUEL_PAGE = SUITE .. "/app/pages/settings_audio_events_fuel.lua"

local out = print
local checks, failures = 0, 0
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
  -- CRLF to LF, so the patterns below match on any checkout.
  return (content:gsub("\r\n", "\n"))
end

-- The percentages spoken by one run of the task, for one callout step.
-- `source` lets the self-test load a modified copy of the task.
local function spokenSteps(step, source)
  local events = {smartfuel = true, smartfuelcallout = step, smartfuelrepeats = 1, smartfuelhaptic = false}
  local handlers = {}
  local spoken = {}
  local clock = 0

  local savedRequire = package.loaded["rfsuite.lib.require"]
  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/bus.lua" then
      return {subscribe = function(topic, fn) handlers[topic] = fn end, publish = function() end}
    elseif name == "lib/settings_store.lua" then
      return {
        load = function() return {events = events} end,
        audioEvents = function(s) return s.events or {} end,
        audioTimer = function() return {} end,
      }
    elseif name == "lib/engine_type.lua" then
      return {isElectric = function() return false end}
    end
    return loadfile(SUITE .. "/" .. name)()
  end

  local savedSystem, savedOsClock, savedPercent = _G.system, os.clock, _G.UNIT_PERCENT
  _G.UNIT_PERCENT = "%"
  _G.system = {
    playFile = function() end,
    playNumber = function(value, unit)
      if unit == "%" then spoken[#spoken + 1] = value end
    end,
    playHaptic = function() end,
    getAudioVoice = function() return "en/default" end,
  }
  os.clock = function() return clock end

  local ok, err = pcall(function()
    local audio = assert(load(source or readFile(AUDIO_PATH), "@" .. AUDIO_PATH))()
    -- The first reading seeds the comparison (no sound); then one percent per wakeup, ten seconds apart.
    for fuel = 100, 1, -1 do
      clock = (100 - fuel) * 10
      handlers["session.update"]({connected = true, fuelPercent = fuel})
      handlers["settings.update"]({events = events})
      audio.wakeup()
    end
  end)

  package.loaded["rfsuite.lib.require"] = savedRequire
  _G.system, os.clock, _G.UNIT_PERCENT = savedSystem, savedOsClock, savedPercent
  if not ok then error(err) end
  return spoken
end

local function listOf(values)
  return table.concat(values, ",")
end

local function range(from, to, by)
  local t = {}
  for v = from, to, by do t[#t + 1] = v end
  return t
end

local function describe(values)
  return "spoken=" .. listOf(values)
end

-- The steps as the Fuel page's choices give them: Default is 0, Every 5% is 5, and so on.
local EVERY_5 = range(95, 5, -5)
local DEFAULT = {10}
local EVERY_10 = range(90, 10, -10)
local FIFTY = {50, 10}

print("the callout steps, as the Fuel page's choices speak them")
do
  local every5 = spokenSteps(5)
  check("1. Every 5% speaks 95, 90 ... 5", listOf(every5) == listOf(EVERY_5), describe(every5))

  local default = spokenSteps(0)
  check("2. Default speaks at 10 percent only", listOf(default) == listOf(DEFAULT), describe(default))

  local every10 = spokenSteps(10)
  check("3. Every 10% speaks 90 ... 10", listOf(every10) == listOf(EVERY_10), describe(every10))

  local fifty = spokenSteps(50)
  check("4. 50% speaks 50 and 10", listOf(fifty) == listOf(FIFTY), describe(fifty))
end

print("the Fuel page's default")
do
  local page = readFile(FUEL_PAGE)
  local default = page:match('"smartfuelcallout",%s*FUEL_CHOICES,%s*{default = (%d+)}')
  check("5. the Callout percent default is the Default choice (0)", default == "0",
    "default=" .. tostring(default))
end

-- ---------------------------------------------------------------------------
-- self-test: the old "Every 5%" table went red on check 1.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the old Every 5% table ({50, 5}) must go red on check 1")
  local source = readFile(AUDIO_PATH)
  local mutated, replacements = source:gsub("%[5%] = {95, 90, 85, 80, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30, 25, 20, 15, 10, 5},",
    "[5] = {50, 5},", 1)
  check("self-test: the Every 5% table was found in the task exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    local old = spokenSteps(5, mutated)
    check("self-test: with the old table Every 5% no longer speaks every 5 percent (check 1 goes red)",
      listOf(old) ~= listOf(EVERY_5), describe(old))
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

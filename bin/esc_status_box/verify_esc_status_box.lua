-- Behaviour check for the speed controller's status box (issue #2354): the telemetry sources that
-- carry the status word and the signature, the session that reads them, and the dashboard text
-- object that shows the verdict in words, coloured by level.
--
-- Run it:
--     lua5.4 bin/esc_status_box/verify_esc_status_box.lua
--
-- What it drives, and why:
--   * lib/telemetry_sensors_sport.lua and lib/telemetry_sensors_crsf.lua, real: the appIds of
--     ESC1 Status and ESC1 Model, the firmware's own (smartport.c 0x5128/0x5129, crsf.c 0x104E/0x104F).
--   * tasks/session.lua, real, through a copy that exports its session table and its
--     updateEscStatus (the only change is that export). It reads the two values from telemetry and
--     publishes a change once.
--   * widgets/dashboard/objects/text/escstatus.lua, real, with the real dashboard context. The
--     text is the verdict's marker, the colour follows the level, and "--" shows where no
--     controller answers. A verdict is decoded again only when the inputs change.
--
-- Against unpatched master the telemetry sources, the session fields and the escstatus object do
-- not exist, so the checks fail at their first step.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"
local TASKS = SUITE .. "/tasks"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then f:close() return name end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then path = resolvePath(path) end
  if env ~= nil then return realLoadfile(path, mode, env)
  elseif mode ~= nil then return realLoadfile(path, mode)
  else return realLoadfile(path) end
end

local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(resolvePath(name))
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

-- The radio's globals the modules touch at load time: anything they read is a stand-in.
local function anyStub()
  return setmetatable({}, {__index = function() return function() return anyStub() end end,
    __call = function() return anyStub() end})
end
-- lcd.RGB returns the channels, so a colour can be compared with the one the theme names.
lcd = setmetatable({RGB = function(r, g, b) return {r, g, b} end},
  {__index = function() return function() return anyStub() end end})
system = anyStub()
model = anyStub()

local failures, checks = 0, 0
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

-- The sensor-source files name CATEGORY_TELEMETRY_SENSOR, which the radio defines.
CATEGORY_TELEMETRY_SENSOR = 1
local function appIdOf(sources, name)
  local entries = sources[name]
  return entries and entries[1] and entries[1].appId or nil
end

-- ---------------------------------------------------------------------------
-- 1. Telemetry sources carry the firmware's appIds
-- ---------------------------------------------------------------------------

print("telemetry sources")
local sport = dofile(SUITE .. "/lib/telemetry_sensors_sport.lua")
local crsf = dofile(SUITE .. "/lib/telemetry_sensors_crsf.lua")
check("S.Port: ESC1 Status is 0x5128", appIdOf(sport, "esc_status") == 0x5128,
  string.format("got %s", tostring(appIdOf(sport, "esc_status"))))
check("S.Port: ESC1 Model is 0x5129", appIdOf(sport, "esc_model") == 0x5129,
  string.format("got %s", tostring(appIdOf(sport, "esc_model"))))
check("CRSF: ESC1 Status is 0x104E", appIdOf(crsf, "esc_status") == 0x104E,
  string.format("got %s", tostring(appIdOf(crsf, "esc_status"))))
check("CRSF: ESC1 Model is 0x104F", appIdOf(crsf, "esc_model") == 0x104F,
  string.format("got %s", tostring(appIdOf(crsf, "esc_model"))))

-- ---------------------------------------------------------------------------
-- 2. The session reads the two values and publishes a change once
-- ---------------------------------------------------------------------------

print("tasks/session.lua")
local sessionSource = assert(io.open(TASKS .. "/session.lua", "rb")):read("a"):gsub("\r\n", "\n")
local exporting, n = sessionSource:gsub("\nreturn {\n",
  "\nreturn {\n  _session = session,\n  _updateEscStatus = updateEscStatus,\n", 1)
assert(n == 1, "could not add the test export to session.lua")
local session = assert(load(exporting, "=session_under_test"))()
local S = session._session

local telemetryValues = {}
local telemetry = {
  getValue = function(_, name) return telemetryValues[name] end,
  reset = function() end,
}
session.setTelemetrySensors(telemetry)

telemetryValues = {esc_status = 1, esc_model = 0x4B}
S.escStatusWord, S.escSignature = nil, nil
session._updateEscStatus("sport")
check("the session holds the status word read from telemetry", S.escStatusWord == 1,
  "held=" .. tostring(S.escStatusWord))
check("the session holds the signature read from telemetry", S.escSignature == 0x4B,
  "held=" .. tostring(S.escSignature))

telemetryValues = {esc_status = 1, esc_model = 0x4B}
session._updateEscStatus("sport")
check("an unchanged reading is not re-stored", S.escStatusWord == 1 and S.escSignature == 0x4B)

telemetryValues = {esc_status = 8, esc_model = 0x4B}
session._updateEscStatus("sport")
check("a changed status word is stored", S.escStatusWord == 8)

-- ---------------------------------------------------------------------------
-- 3. The dashboard object shows the verdict, coloured by level
-- ---------------------------------------------------------------------------

print("dashboard: escstatus text object")
local context = requireModule("widgets/dashboard/context.lua")
local box = requireModule("widgets/dashboard/objects/text/escstatus.lua")
local T = requireModule("lib/esc_status_text.lua")
local ESC = requireModule("lib/esc_status.lua")

local function showFor(signature, word)
  context.session.escSignature = signature
  context.session.escStatusWord = word
  local b = {}
  box.wakeup(b)
  return b
end

local ORANGE = {255, 165, 0}
local RED = {255, 0, 0}

-- A colour is compared by its channels: the theme resolves a name to a table of its own.
local function sameColor(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

local ok1 = showFor(0x4B, 0)
check("a Kontronik with no flags shows OK", ok1._currentDisplayValue == T.ok, tostring(ok1._currentDisplayValue))
check("and keeps the text colour", not sameColor(ok1._currentLevelColor, ORANGE) and not sameColor(ok1._currentLevelColor, RED))

local err = showFor(0x4B, 1)
check("an error shows the condition's text", err._currentDisplayValue == T.undervoltage,
  tostring(err._currentDisplayValue))
check("an error is red", sameColor(err._currentLevelColor, RED), tostring(err._currentLevelColor))

local warn = showFor(0x4B, 8)
check("a warning shows its text", warn._currentDisplayValue == T.current_warning,
  tostring(warn._currentDisplayValue))
check("a warning is orange", sameColor(warn._currentLevelColor, ORANGE), tostring(warn._currentLevelColor))

local none = showFor(nil, nil)
check("no controller answering shows the no-value text, not a verdict", none._currentDisplayValue == "--",
  tostring(none._currentDisplayValue))

local restart = showFor(0xFF, nil)
check("a restart request shows RESTART, in orange", restart._currentDisplayValue == T.restart
  and sameColor(restart._currentLevelColor, ORANGE), tostring(restart._currentDisplayValue))

-- Caching: the same inputs give the same verdict table, not a new decode on every wakeup.
local first = showFor(0x4B, 1)
local verdictOnce = first._verdict
box.wakeup(first)
check("the verdict is not decoded again for unchanged inputs", first._verdict == verdictOnce)
local changed = showFor(0x4B, 8)
check("a changed status word gives a new verdict", changed._verdict ~= verdictOnce
  and changed._currentDisplayValue == T.current_warning)

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

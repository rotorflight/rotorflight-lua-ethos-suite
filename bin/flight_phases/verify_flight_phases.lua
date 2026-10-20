-- Behaviour check for the dashboard's flight phases (issue #2352): the tracker's five phases,
-- the layout each one draws with, and the holds that depend on them.
--
-- Run it:
--     lua5.4 bin/flight_phases/verify_flight_phases.lua
--
-- What it drives, and why:
--   * lib/flight_stats.lua, real: the session's flight phase is fed the session fields it reads
--     (connected, isArmed, governorState, throttlePercent) tick by tick, and the phase it returns
--     is checked (#2344 moved it out of the dashboard). There is no radio channel here (CATEGORY_CHANNEL is nil), so flight is read from
--     the telemetry throttle, the path a radio without a resolved RX map takes.
--   * flight_stats.layoutPhase: armed draws preflight and offline draws postflight, because themes
--     have three layouts. The bar gauge hold rule in objects/gauge/bar.lua is not run here: that
--     module needs the whole widget, so that change is covered by review only.
--
-- Against unpatched master the tracker has no armed or offline phase, so the checks fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

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

-- No radio channel in the harness: the telemetry throttle decides flight.
CATEGORY_CHANNEL = nil
system = {}

local flightStats = requireModule("lib/flight_stats.lua")

-- A widget as the tracker sees it. `tick` feeds one state and returns the phase.
local function newWidget()
  local widget = {connected = false, isArmed = false, governorState = 0, throttlePercent = 0}
  local tracker = flightStats.new()
  local function tick(connected, armed, throttle, governor)
    widget.connected = connected
    widget.isArmed = armed
    widget.throttlePercent = throttle or 0
    widget.governorState = governor or 0
    return tracker:update(widget)
  end
  return tick, tracker
end

-- ---------------------------------------------------------------------------
-- 1. Preflight, armed, flight, postflight
-- ---------------------------------------------------------------------------

print("a flight from the ground")
do
  local tick = newWidget()
  check("connected and disarmed: preflight", tick(true, false) == "preflight")
  check("armed on the ground: armed (not preflight)", tick(true, true, 0) == "armed")
  check("still armed on the ground: armed", tick(true, true, 0) == "armed")
  check("throttle up while armed: inflight", tick(true, true, 60) == "inflight")
  check("armed with the throttle back down: still inflight, not postflight", tick(true, true, 0) == "inflight")
  check("disarmed after the flight: postflight", tick(true, false, 0) == "postflight")
end

print("a flight that ends with the battery unplugged")
do
  local tick = newWidget()
  tick(true, true, 0)
  tick(true, true, 60)
  check("the link drops after the flight: offline", tick(false, false, 0) == "offline")
  check("it stays offline while the link is down", tick(false, false, 0) == "offline")
  -- The dashboard always closed the flight here; the rule now lives in the session phase.
  check("a connection returns: the finished flight is closed, preflight", tick(true, false, 0) == "preflight")
end

print("no flight, then the link drops")
do
  local tick = newWidget()
  tick(true, false, 0)
  check("disconnect without a flight: preflight, not offline", tick(false, false, 0) == "preflight")
end

print("governor counts as flight")
do
  local tick = newWidget()
  tick(true, true, 0)
  check("armed with the governor active (state 4): inflight", tick(true, true, 0, 4) == "inflight")
end

-- ---------------------------------------------------------------------------
-- 2. Layouts: three to draw with
-- ---------------------------------------------------------------------------

print("layout phase")
check("armed draws the preflight layout", flightStats.layoutPhase("armed") == "preflight")
check("offline draws the postflight layout", flightStats.layoutPhase("offline") == "postflight")
check("preflight is unchanged", flightStats.layoutPhase("preflight") == "preflight")
check("inflight is unchanged", flightStats.layoutPhase("inflight") == "inflight")
check("postflight is unchanged", flightStats.layoutPhase("postflight") == "postflight")

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

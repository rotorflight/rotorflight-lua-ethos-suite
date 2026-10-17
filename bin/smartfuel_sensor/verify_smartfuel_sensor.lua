-- Behaviour check for the Smart Fuel sensor as Ethos sees it (Rob Thomson's
-- report, 2026-10-17: "sensor lost" as soon as the model is disarmed).
--
-- Run it from the repository root:
--     lua5.4 bin/smartfuel_sensor/verify_smartfuel_sensor.lua
--
-- What it drives, and why:
--   * lib/diy_sensor.lua with a stub sensor, driven on a controllable clock at the
--     cadence tasks/session.lua's updateFuel() runs at: every 0.5 s, plus a little
--     scheduler slop (0.52 s per call). Ethos shows a telemetry sensor as lost when it
--     gets no value for 4 s, so the gap between two pushes of an unchanged value has
--     to stay well under that.
--   * lib/smartfuel_calc.lua, the local estimator, on a voltage curve with a disarm
--     in the middle. Right after a disarm the pack voltage rises as the load goes
--     away, the estimate starts again, and the estimator used to answer a bare nil.
--     session.lua wrote that nil to the sensor, which resets it.
--
-- Pinned:
--   * an unchanged Smart Fuel value is pushed again within 2.5 s, every time;
--   * a value that changes is pushed at once;
--   * a nil from the estimator while it re-settles carries the reason "settling"
--     on every tick, so the caller can keep the last value;
--   * a nil with no reason is only returned when the inputs are really missing.
--
-- Can-fail: the 4.0 s window of the old code is loaded from a copy, and the copy
-- must miss the 2.5 s bound. The session guard itself is a single line in
-- tasks/session.lua and is checked by reading the source, because that file needs
-- the whole task to run.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local SUITE_PREFIX = SUITE .. "/"
local DIY_PATH = SUITE .. "/lib/diy_sensor.lua"
local CALC_PATH = SUITE .. "/lib/smartfuel_calc.lua"
local SESSION_PATH = SUITE .. "/tasks/session.lua"

local checks, failures = 0, 0
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
  return (content:gsub("\r\n", "\n"))
end

local savedSystem, savedModel, savedOsClock = _G.system, _G.model, os.clock
local savedRequire = package.loaded["rfsuite.lib.require"]

local realLoadfile = loadfile
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (SUITE_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

-- The modules these two files require. Only the names they use are provided.
local function installRequire()
  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/debug_log.lua" then
      return {print = function() end, format = function() end, msp = function() end, enabled = function() return false end}
    elseif name == "lib/ethos_version.lua" then
      return {atLeast = function() return false end}
    end
    return assert(realLoadfile(SUITE_PREFIX .. name))()
  end
end

-- A stub telemetry sensor: records every value that is pushed, and resets.
local function newStubSensor(log, clock)
  local sensor = {}
  function sensor:name() return self end
  function sensor:appId() return self end
  function sensor:physId() return self end
  function sensor:module() return self end
  function sensor:unit() return self end
  function sensor:protocolUnit() return self end
  function sensor:decimals() return self end
  function sensor:protocolDecimals() return self end
  function sensor:minimum() return self end
  function sensor:maximum() return self end
  function sensor:value(v) log[#log + 1] = {t = clock.t, v = v} end
  function sensor:rawValue(v) log[#log + 1] = {t = clock.t, v = v} end
  function sensor:reset() log[#log + 1] = {t = clock.t, reset = true} end
  return sensor
end

-- Runs a DiySensor (loaded from `source`) through `seconds` of the session's
-- updateFuel() cadence with a constant value, then returns the pushes it made.
local function pushesWithConstantValue(source, seconds)
  local clock = {t = 0}
  local log = {}
  _G.system = {getSource = function() return nil end}
  _G.model = {createSensor = function() return newStubSensor(log, clock) end}
  os.clock = function() return clock.t end
  installRequire()
  local DiySensor = assert(load(source, "@" .. DIY_PATH))()
  local sensor = DiySensor.new(0x5FE1, "Smart Fuel", nil, -1, 100)
  sensor:set(50, true)
  local t = 0
  while t < seconds do
    t = t + 0.52
    clock.t = t
    sensor:set(50, true)
  end
  return log
end

local function maxGap(log)
  local gap, last = 0, nil
  for _, entry in ipairs(log) do
    if not entry.reset then
      if last then gap = math.max(gap, entry.t - last) end
      last = entry.t
    end
  end
  return gap, last ~= nil
end

out("Smart Fuel is re-pushed often enough that Ethos keeps it (Rob Thomson, 2026-10-17)")

do
  local log = pushesWithConstantValue(readFile(DIY_PATH), 60)
  local gap, enough = maxGap(log)
  check("an unchanged value is pushed again within 2.5 s, for a minute", enough and gap <= 2.5,
    string.format("largest gap %.2f s over %d pushes", gap, #log))
end

do
  local clock = {t = 0}
  local log = {}
  _G.system = {getSource = function() return nil end}
  _G.model = {createSensor = function() return newStubSensor(log, clock) end}
  os.clock = function() return clock.t end
  installRequire()
  local DiySensor = assert(load(readFile(DIY_PATH), "@" .. DIY_PATH))()
  local sensor = DiySensor.new(0x5FE1, "Smart Fuel", nil, -1, 100)
  sensor:set(50, true)
  clock.t = 0.5; sensor:set(50, true)
  clock.t = 1.0; sensor:set(51, true)
  check("a changed value is pushed at once", #log == 2 and log[#log].v == 51,
    "pushes: " .. #log)
end

-- Can-fail: the same run with the old 4.0 s window must miss the bound.
do
  local source = readFile(DIY_PATH)
  local stripped, count = source:gsub("local STALE_REFRESH_SECONDS = 2%.0", "local STALE_REFRESH_SECONDS = 4.0", 1)
  check("the stale window could be located in diy_sensor.lua", count == 1)
  local gap = maxGap(pushesWithConstantValue(stripped, 60))
  check("the old 4.0 s window misses the 2.5 s bound (this check can go red)", gap > 2.5,
    string.format("largest gap %.2f s", gap))
end

out("the estimator says why it is answering nil")

-- Pack voltage on a 3S pack, feeding the estimator on the 0.25 s wakeup cadence.
local function estimatorRig()
  local clock = {t = 0}
  _G.system = {getSource = function() return nil end}
  os.clock = function() return clock.t end
  installRequire()
  local SmartFuel = assert(load(readFile(CALC_PATH), "@" .. CALC_PATH))()
  return SmartFuel.new(), clock
end

local function inputs(voltage, isArmed)
  return {
    voltage = voltage, cellCount = 3, packCapacity = 2200, minV = 3.3, fullV = 4.2,
    warningPercent = 20, isArmed = isArmed, consumption = 0,
    voltageFallPerSecond = 0.01, chargeDropPerSecond = 0.005,
  }
end

do
  local est, clock = estimatorRig()
  local value = nil
  for _ = 1, 40 do
    clock.t = clock.t + 0.25
    value = est:update(inputs(12.3, true))
  end
  check("the estimate is available once the armed pack has settled", value ~= nil)

  -- Disarm and the voltage rises as the load goes away.
  local bareNil, reasonsOk, returnedAgain = 0, true, false
  for i = 1, 40 do
    clock.t = clock.t + 0.25
    local v, why = est:update(inputs(12.6, false))
    if v == nil then
      if why ~= "settling" then bareNil = bareNil + 1 end
      if why == nil then reasonsOk = false end
    else
      returnedAgain = true
    end
    if i == 1 then
      check("the disarm with rising voltage restarts the estimate, and says so",
        v == nil and why == "settling", string.format("value %s reason %s", tostring(v), tostring(why)))
    end
  end
  check("while it re-settles, every nil says it is settling", bareNil == 0 and reasonsOk,
    "bare nils: " .. bareNil)
  check("and the estimate comes back within 10 s", returnedAgain)
end

do
  local est = estimatorRig()
  local v, why = est:update(inputs(nil, true))
  check("a missing voltage is still a plain nil, with no reason", v == nil and why == nil,
    string.format("reason %s", tostring(why)))
end

out("the session keeps the last value while the estimator settles")

do
  local source = readFile(SESSION_PATH)
  check("updateFuel() calls refresh() during settling instead of skipping the push",
    source:find("if percent == nil and settling then", 1, true) ~= nil)
  check("and the estimator's reason reaches it", source:find("percent, settling = localSmartFuel:update({", 1, true) ~= nil)
end

-- Integration: simulate updateFuel()'s cadence during a settling period and
-- verify that the sensor never goes more than 2.5 s without a push.
do
  local clock = {t = 0}
  local log = {}
  _G.system = {getSource = function() return nil end}
  _G.model = {createSensor = function() return newStubSensor(log, clock) end}
  os.clock = function() return clock.t end
  installRequire()
  local DiySensor = assert(load(readFile(DIY_PATH), "@" .. DIY_PATH))()
  local sensor = DiySensor.new(0x5FE1, "Smart Fuel", nil, -1, 100)

  -- Arm phase: push a real value so lastValue is known.
  sensor:set(72, true)
  clock.t = 0.5; sensor:set(72, true)
  clock.t = 1.0; sensor:set(72, true)

  -- Settling phase: call refresh() every 0.52 s (as session.lua would) for 5 s.
  local settlingStart = clock.t
  while clock.t < settlingStart + 5.0 do
    clock.t = clock.t + 0.52
    sensor:refresh()
  end

  -- Measure the largest gap in pushes during the settling window.
  local gap = maxGap(log)
  check("sensor stays alive during settling: max push gap <= 2.5 s", gap <= 2.5,
    string.format("largest gap %.2f s over %d pushes", gap, #log))
end

-- Put back what the harness replaced, so nothing after this file sees a stub.
_G.system, _G.model = savedSystem, savedModel
os.clock = savedOsClock
package.loaded["rfsuite.lib.require"] = savedRequire
_G.loadfile = realLoadfile

out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

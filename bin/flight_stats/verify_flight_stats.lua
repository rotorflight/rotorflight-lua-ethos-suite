-- Behaviour check for lib/flight_stats.lua (#2344): the session's flight phase and the
-- flight extremes, which the dashboard used to keep in the widget.
--
-- Run it:
--     lua5.4 bin/flight_stats/verify_flight_stats.lua
--
-- The module is fed a session-shaped table tick by tick (connected, isArmed, mcuId,
-- governorState, throttlePercent and the recorded values) and the phase, the extremes
-- and the headspeed variance are checked. The reset rules (reconnect, a different
-- craft, a new flight) are the ones dashboard.lua's update() applied before #2344.
-- There is no radio channel here (CATEGORY_CHANNEL is nil), so flight is read from the
-- governor state or the telemetry throttle.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  print(string.format("  %s  %s%s", ok and "ok  " or "FAIL", label, (not ok and detail) and ("  (" .. detail .. ")") or ""))
end

CATEGORY_CHANNEL = nil

-- The sensor reader the session passes: the same values the dashboard shows. No
-- transport is set here, so it reads the session fields and never a live source.
local READ = assert(loadfile(ROOT .. "/src/rfsuite/lib/live_sensors.lua"))().read

-- A fresh copy of the module, so each section starts from clean state.
local function newFlightStats()
  package.loaded["rfsuite.lib.flight_stats"] = nil
  return assert(loadfile(ROOT .. "/src/rfsuite/lib/flight_stats.lua"))().new()
end

-- One tick with a session-shaped table. `values` adds recorded values or overrides.
-- Every tick is 0.5 s, the cadence of the powered gate, so four ticks are its 2 s.
local clock = 0
local function tick(fs, connected, armed, values, mcu)
  local s = {connected = connected, isArmed = armed, mcuId = mcu or "craft-A",
    governorState = nil, throttlePercent = 0}
  for k, v in pairs(values or {}) do s[k] = v end
  clock = clock + 0.5
  return fs:update(s, READ, clock)
end

local function sample(rpm, current, extra)
  local v = {voltage = 22.2, consumption = 100, current = current, rpm = rpm,
    linkQuality = 90, tempEsc = 40, tempMcu = 30, becVoltage = 6.0, fuelPercent = 80}
  for k, x in pairs(extra or {}) do v[k] = x end
  return v
end

print("a flight, a link loss, a reconnect")
do
  local fs = newFlightStats()
  check("disarmed with the link up is preflight", tick(fs, true, false) == "preflight")
  check("armed on the ground is armed", tick(fs, true, true) == "armed")
  check("throttle above 35 is inflight",
    tick(fs, true, true, sample(2000, 30, {throttlePercent = 60})) == "inflight")
  check("the in-flight values are recorded, the rpm minimum waits for the powered gate",
    fs.stats.maxRpm == 2000 and fs.stats.minRpm == nil and fs.stats.minVoltage == 22.2)
  check("armed with the throttle low after flight holds inflight",
    tick(fs, true, true, sample(1900, 10)) == "inflight")
  check("the values taken while holding are recorded", fs.stats.rpm.count == 2 and fs.stats.maxRpm == 2000)
  check("disarming after flight is postflight", tick(fs, true, false) == "postflight")
  check("values in postflight are not recorded",
    tick(fs, true, false, sample(500, 5)) == "postflight" and fs.stats.rpm.count == 2)
  check("link loss after flight is offline", tick(fs, false, false) == "offline")
  check("offline keeps the extremes", fs.stats.maxRpm == 2000)
  check("reconnect closes the flight: preflight", tick(fs, true, false) == "preflight")
  check("reconnect clears the extremes", fs.stats.maxRpm == nil)
end

print("a new flight and a different craft")
do
  local fs = newFlightStats()
  tick(fs, true, true)
  tick(fs, true, true, sample(2000, 30, {throttlePercent = 60}))
  tick(fs, true, false)
  tick(fs, true, true)
  check("a second flight starts from its own extremes",
    tick(fs, true, true, sample(2400, 40, {throttlePercent = 60})) == "inflight"
    and fs.stats.maxRpm == 2400 and fs.stats.rpm.count == 1)
  tick(fs, false, false)
  check("a different craft drops the phase", tick(fs, true, false, nil, "craft-B") == "preflight")
  check("a different craft drops the extremes", fs.stats.maxRpm == nil)
  check("a different craft drops the headspeed variance", fs.headspeedVariancePct == nil)
end

print("what counts as flight")
do
  local g = newFlightStats()
  tick(g, true, true)
  check("governor state 4 is in flight with the throttle low", tick(g, true, true, {governorState = 4}) == "inflight")
  local g2 = newFlightStats()
  tick(g2, true, true)
  check("governor state 2 is not in flight", tick(g2, true, true, {governorState = 2}) == "armed")
  local d = newFlightStats()
  tick(d, true, false)
  check("a disconnect without a flight is preflight, not offline", tick(d, false, false) == "preflight")
end

print("recorded values")
do
  local r = newFlightStats()
  tick(r, true, true)
  for _, rpm in ipairs({1000, 1200, 1400}) do
    tick(r, true, true, sample(rpm, rpm / 100, {governorState = 4}))
  end
  check("rpm average of 1000, 1200, 1400 is 1200", r.stats.rpm.avg == 1200)
  check("rpm max, and no rpm minimum before 2 s under power", r.stats.maxRpm == 1400 and r.stats.minRpm == nil)
  check("current has three samples", r.stats.current.count == 3)
  check("headspeed variance is 17 percent for 1400 against the average 1200", r.headspeedVariancePct == 17)
  check("watts is voltage times current", r.stats.maxWatts == 22.2 * 14)
  check("every recorded value has min, max and an average entry",
    r.stats.minFuelPercent == 80 and r.stats.maxBecVoltage == 6.0 and r.stats.temp_esc.avg == 40
    and r.stats.link.count == 3 and r.stats.minConsumption == 100)
  check("rpm has one sample per tick: the headspeed alias is not counted twice",
    r.stats.rpm.count == 3)

  local c = newFlightStats()
  tick(c, true, true)
  tick(c, true, true, sample(1500, 10, {governorState = 4, batteryConfig = {cellCount = 6}}))
  check("cell voltage is the pack voltage over the cell count (22.2 V, 6 cells)",
    c.stats.minCellVoltage ~= nil and math.abs(c.stats.minCellVoltage - 3.7) < 1e-9)
  check("no cell count, no cell voltage", r.stats.minCellVoltage == nil)

  local before = r.stats.rpm.count
  tick(r, true, true, {governorState = 4, rpm = nil})
  check("a missing value is skipped, not recorded as zero", r.stats.rpm.count == before)

  r:reset()
  check("reset flight clears the phase and the extremes",
    r.phase == "preflight" and r.stats.maxRpm == nil and r.headspeedVariancePct == nil)
end


print("powered gate for the rpm and current minima")
do
  -- With a governor: spool-up readings never make the minimum.
  local g = newFlightStats()
  tick(g, true, true)
  -- Spool-up (governor 2) with the throttle up: in flight, but not under power yet.
  tick(g, true, true, sample(300, 0, {governorState = 2, throttlePercent = 60}))
  tick(g, true, true, sample(600, 0, {governorState = 2, throttlePercent = 60}))
  for _ = 1, 3 do tick(g, true, true, sample(1500, 20, {governorState = 4})) end
  check("ACTIVE for less than 2 s: no minimum yet", g.stats.minRpm == nil and g.stats.minCurrent == nil)
  tick(g, true, true, sample(1500, 20, {governorState = 4}))
  check("ACTIVE for 2 s: the minimum is the flight's, not the spool-up's",
    g.stats.minRpm == 1500 and g.stats.minCurrent == 20, "minRpm=" .. tostring(g.stats.minRpm))
  check("the entry minimum the dashboard reads is gated the same way",
    g.stats.rpm.min == 1500 and g.stats.current.min == 20)
  check("the maximum keeps the whole flight phase", g.stats.maxRpm == 1500 and g.stats.rpm.count == 6)
  tick(g, true, true, sample(1400, 25, {governorState = 4}))
  check("a lower reading under power lowers the minimum", g.stats.minRpm == 1400 and g.stats.minCurrent == 20)
  tick(g, true, true, sample(800, 2, {governorState = 5}))
  check("throttle hold closes the gate: 800 rpm is not a minimum", g.stats.minRpm == 1400 and g.stats.minCurrent == 20)
  check("other minima are not gated", g.stats.minVoltage == 22.2)

  -- A zero rpm reading is not a headspeed.
  local z = newFlightStats()
  tick(z, true, true)
  -- Bypass (governor 9) is flight by the throttle, not by the governor state.
  for _ = 1, 4 do tick(z, true, true, sample(1500, 10, {governorState = 9, throttlePercent = 60})) end
  tick(z, true, true, sample(0, 10, {governorState = 9, throttlePercent = 60}))
  check("BYPASS counts as powered, and 0 rpm is never the minimum", z.stats.minRpm == 1500)

  -- Without a governor state: driven for 2 s, and the reading of 2 s ago is offered.
  local f = newFlightStats()
  tick(f, true, true)
  for _ = 1, 7 do tick(f, true, true, sample(1500, 10, {throttlePercent = 60})) end
  check("no governor: driven for less than 4 s in total, no minimum yet", f.stats.minRpm == nil)
  tick(f, true, true, sample(1500, 10, {throttlePercent = 60}))
  check("no governor: driven 2 s plus 2 s, the minimum is taken", f.stats.minRpm == 1500)
  for _ = 1, 3 do tick(f, true, true, sample(600, 10, {throttlePercent = 60})) end
  tick(f, true, true, sample(600, 0, {throttlePercent = 0}))
  check("no governor: the head slowing at the end of a driven stretch never counts", f.stats.minRpm == 1500)

  -- A new flight closes the gate again.
  tick(g, true, false)
  tick(g, true, true)
  tick(g, true, true, sample(1300, 5, {governorState = 4}))
  check("a new flight starts with the gate closed", g.stats.minRpm == nil and g.stats.maxRpm == 1300)
end

print("layouts")
do
  package.loaded["rfsuite.lib.flight_stats"] = nil
  local m = assert(loadfile(ROOT .. "/src/rfsuite/lib/flight_stats.lua"))()
  check("armed draws preflight, offline draws postflight",
    m.layoutPhase("armed") == "preflight" and m.layoutPhase("offline") == "postflight"
    and m.layoutPhase("inflight") == "inflight")
end

print(string.rep("-", 60))
print(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  print("")
  print("FAILED")
  os.exit(1)
end
print("ALL CHECKS PASSED")

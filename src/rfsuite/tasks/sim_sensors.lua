-- Ethos-simulator-only sim sensors: fabricates DIY telemetry sensors for the
-- sim/sensors/*.lua keys, so the whole app (dashboards, telemetry pages,
-- tasks/session.lua's own sensor lookups via lib/telemetry_sensors.lua's
-- "sim" candidates) has something to read inside the Ethos simulator, the
-- same as it would off real MSP/telemetry hardware. Loaded (loadfile'd) and
-- scheduled by tasks/background.lua only when
-- system.getVersion().simulation == true -- never touched otherwise, so
-- real hardware pays zero cost for this file existing.
--
-- Mirrors rotorflight-lua-ethos-suite's tasks/scheduler/sensors/sim.lua,
-- trimmed hard:
--   - One lib/diy_sensor.lua instance per sensor instead of a bespoke
--     sensors.uid/lastvalue/lastupdate table -- that primitive already does
--     create-once + skip-unchanged + stale-refresh (same simplification
--     tasks/elrs_sensors.lua already made for its own per-SID sensors).
--   - No dropAutoDiscoveredSensors sweep: that existed to clear generic
--     telemetry-derived sensor sources Ethos's simulator can auto-populate
--     at *real* appId ranges (RSSI, voltage, etc.) that could otherwise
--     collide with auto-discovery. These sensors all live at
--     0x5001-0x5027, a range nothing else in this suite or Ethos itself
--     ever populates, so there is nothing to drop.
--   - appId/unit/decimals/range values copied straight from that original's
--     tasks/scheduler/telemetry/sources/sim.lua (uid/unit/dec/min/max
--     fields) -- kept identical so the appIds line up with
--     lib/telemetry_sensors.lua's own "sim" candidates table.
--
-- Each sensor's *value* comes from sim/sensors/<key>.lua, a `return <n>`
-- script the bin/sensors/ desktop editor overwrites -- re-read every
-- wakeup (not cached) so edits made there show up live without a script
-- reload.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local DiySensor = requireModule("lib/diy_sensor.lua")

-- key -> {uid, unit, dec, min, max}, copied from
-- rotorflight-lua-ethos-suite's tasks/scheduler/telemetry/sources/sim.lua.
-- Display names are plain English (no i18n) -- same convention
-- tasks/elrs_sensors.lua's own aggregate decoders already use for
-- simulator/debug-only sensor labels.
local SENSORS = {
  armflags         = {uid = 0x5001, name = "Arm Flags",        unit = nil,               dec = nil, min = 0,     max = 2},
  voltage          = {uid = 0x5002, name = "Voltage",          unit = UNIT_VOLT,          dec = 2,   min = 0,     max = 3000},
  rpm              = {uid = 0x5003, name = "Headspeed",        unit = UNIT_RPM,           dec = nil, min = 0,     max = 2000},
  current          = {uid = 0x5004, name = "Current",          unit = UNIT_AMPERE,        dec = 0,   min = 0,     max = 300},
  temp_esc         = {uid = 0x5005, name = "ESC Temp",         unit = UNIT_DEGREE,        dec = 0,   min = 0,     max = 100},
  temp_mcu         = {uid = 0x5006, name = "MCU Temp",         unit = UNIT_DEGREE,        dec = 0,   min = 0,     max = 100},
  fuel             = {uid = 0x5007, name = "Fuel",             unit = UNIT_PERCENT,       dec = 0,   min = 0,     max = 100},
  consumption      = {uid = 0x5008, name = "Consumption",      unit = UNIT_MILLIAMPERE_HOUR, dec = 0, min = 0,    max = 5000},
  governor         = {uid = 0x5009, name = "Governor",         unit = nil,                dec = 0,   min = 0,     max = 200},
  adj_f            = {uid = 0x5010, name = "Adjust Function",  unit = nil,                dec = 0,   min = 0,     max = 10},
  adj_v            = {uid = 0x5011, name = "Adjust Value",     unit = nil,                dec = 0,   min = 0,     max = 2000},
  pid_profile      = {uid = 0x5012, name = "PID Profile",      unit = nil,                dec = 0,   min = 0,     max = 6},
  rate_profile     = {uid = 0x5013, name = "Rate Profile",     unit = nil,                dec = 0,   min = 0,     max = 6},
  throttle_percent = {uid = 0x5014, name = "Throttle %",       unit = nil,                dec = 0,   min = 0,     max = 100},
  armdisableflags  = {uid = 0x5015, name = "Arm Disable Flags", unit = nil,               dec = nil, min = 0,     max = 65536},
  altitude         = {uid = 0x5016, name = "Altitude",         unit = UNIT_METER,         dec = 0,   min = 0,     max = 50000},
  bec_voltage      = {uid = 0x5017, name = "BEC Voltage",      unit = UNIT_VOLT,          dec = 2,   min = 0,     max = 3000},
  cell_count       = {uid = 0x5018, name = "Cell Count",       unit = nil,                dec = 0,   min = 0,     max = 50},
  accx             = {uid = 0x5019, name = "Accel X",          unit = UNIT_G,             dec = 3,   min = -4000, max = 4000},
  accy             = {uid = 0x5020, name = "Accel Y",          unit = UNIT_G,             dec = 3,   min = -4000, max = 4000},
  accz             = {uid = 0x5021, name = "Accel Z",          unit = UNIT_G,             dec = 3,   min = -4000, max = 4000},
  attyaw           = {uid = 0x5022, name = "Yaw Attitude",     unit = UNIT_DEGREE,        dec = 1,   min = -1800, max = 3600},
  attroll          = {uid = 0x5023, name = "Roll Attitude",    unit = UNIT_DEGREE,        dec = 1,   min = -1800, max = 3600},
  attpitch         = {uid = 0x5024, name = "Pitch Attitude",   unit = UNIT_DEGREE,        dec = 1,   min = -1800, max = 3600},
  groundspeed      = {uid = 0x5025, name = "Ground Speed",     unit = UNIT_KNOT,          dec = 1,   min = -1800, max = 3600},
  battery_profile  = {uid = 0x5026, name = "Battery Profile",  unit = nil,                dec = 0,   min = 0,     max = 6},
  tailspeed        = {uid = 0x5027, name = "Tail Speed",       unit = UNIT_RPM,           dec = nil, min = 0,     max = 65535},
}

-- key -> DiySensor instance, built once from SENSORS above. Module index
-- left at lib/diy_sensor.lua's own default (0) -- these aren't tied to any
-- real RF module bay.
local sensors = {}
for key, def in pairs(SENSORS) do
  sensors[key] = DiySensor.new(def.uid, def.name, def.unit, def.min, def.max, nil, def.dec)
end

-- Loads sim/sensors/<key>.lua (a `return <value>` script) and returns its
-- result, or nil if the file is missing/errors -- same "silently skip"
-- behaviour as that original's own utils.simSensors(), minus its unrelated
-- LOGS:/rfsuite/sensors mkdir side effect.
local function readValue(key)
  local chunk = loadfile("sim/sensors/" .. key .. ".lua")
  if not chunk then return nil end
  local ok, value = pcall(chunk)
  if not ok then return nil end
  return value
end

-- Telemetry-state override: the Ethos simulator's own TELEMETRY_ACTIVE flag
-- (what tasks/session.lua's wakeup() otherwise reads via `tlm:state()`) can
-- flap in the simulator -- that original's own tasks/tasks.lua has a
-- comment calling this out by name ("avoid TELEMETRY_ACTIVE flapping") and
-- always trusts its own rfsuite.simevent.telemetry_state instead whenever
-- running in sim. sim/sensors/simevent_telemetry_state.lua backs the
-- editor's "Telemetry State" switch (0 = Enabled, 1 = Disabled, matching
-- bin/sensors/sensors.xml's Option values) -- read at the same 2-second
-- cadence as the sensors above (that original polled it once a second, via
-- its own separate scheduler entry; folding it into this task's own
-- wakeup avoids a second scheduler entry for one boolean).
local telemetryStateOverride = true -- fail open, matches that original's own
                                     -- `rfsuite.simevent = {telemetry_state = true}` boot default

local function readTelemetryStateOverride()
  local chunk = loadfile("sim/sensors/simevent_telemetry_state.lua")
  if not chunk then return end
  local ok, value = pcall(chunk)
  if ok and value ~= nil then telemetryStateOverride = (value == 0) end
end

-- Re-read + push interval is owned by the caller -- tasks/background.lua
-- schedules this at a 2-second interval (matches that original's own
-- default config.sim.wakeupInterval), so no need to duplicate the
-- throttling here.
local function wakeup()
  readTelemetryStateOverride()

  for key, sensor in pairs(sensors) do
    local value = readValue(key)
    if value ~= nil then sensor:set(value, true) end
  end
end

-- tasks/session.lua reads this every wakeup (much more often than the
-- 2-second cadence above re-reads the underlying file) to override its own
-- `tlm:state()` read while running in the simulator.
local function telemetryState()
  return telemetryStateOverride
end

-- Exported for symmetry with this suite's other per-connection sensor
-- modules (tasks/elrs_sensors.lua, lib/telemetry_sensors.lua), but nothing
-- currently calls it: unlike those, a simulated "reconnect" never means a
-- different aircraft with different capabilities, so there is nothing that
-- needs forgetting between sim sessions. Forgets each DIY sensor's resolved
-- Ethos source so a fresh connection would re-resolve from scratch, if a
-- future caller ever needs that.
local function reset()
  for _, sensor in pairs(sensors) do sensor:reset() end
end

return {wakeup = wakeup, reset = reset, telemetryState = telemetryState}

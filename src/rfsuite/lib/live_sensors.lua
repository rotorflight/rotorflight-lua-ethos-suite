-- Live telemetry sources and the dashboard's sensor values (#2344).
--
-- Moved here from widgets/dashboard/context.lua so the session reads the same values
-- the dashboard shows while it records the flight extremes, with the dashboard closed.
-- Both share this one copy, so there is a single source cache for both.
--
-- read(state, name) takes any table with the session's field names (the session
-- itself, or the dashboard widget, which copies them from the session snapshot).

if package.loaded["rfsuite.lib.live_sensors"] then
  return package.loaded["rfsuite.lib.live_sensors"]
end

local live_sensors = {}

local liveSourceCache = {}
local liveMissRetryAt = {}
local liveMissCount = {}
local liveRevalidateAt = {}
-- Same fix as lib/telemetry_sensors.lua's own MISS_RETRY_INITIAL/_MAX: a flat
-- 5s lockout from the first miss meant a box whose sensor simply hadn't
-- broadcast yet (common right after connect) stayed blank for up to 5s
-- rather than the fraction of a second it actually took to start
-- broadcasting. Exponential backoff keeps the same eventual 5s cap for a
-- sensor that's genuinely absent on this build, while resolving a merely-late
-- one much sooner.
local LIVE_MISS_RETRY_INITIAL = 0.5
local LIVE_MISS_RETRY_MAX = 5.0
local LIVE_MISS_RETRY_MULTIPLIER = 2
-- Same fix as lib/telemetry_sensors.lua's own REVALIDATE_INTERVAL, ported
-- here after noticing this cache never got it: liveSensorSource() picks the
-- *first* candidate that resolves and, unlike the miss path above, kept it
-- forever with no way back through the candidate list. If that first hit is
-- a stale/unwired duplicate sensor slot -- or one Ethos discovered before it
-- ever carried a real reading -- the box using it (e.g. the header's rssi
-- step-gauge) gets stuck showing that slot's value (often 0/nil) for the
-- rest of the session, exactly the "populates once, then stops updating"
-- symptom lib/telemetry_sensors.lua's own comment describes. Re-running the
-- scan every LIVE_REVALIDATE_INTERVAL seconds gives a better candidate that
-- shows up later a chance to take over, without rescanning every wakeup.
local LIVE_REVALIDATE_INTERVAL = 8.0

local LIVE_SENSOR_CANDIDATES = {
  sport = {
    rssi = {
      {appId = 0xF010, subId = 0},
    },
    voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0210},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0211},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0218},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x021A},
    },
    consumption = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250},
    },
    current = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0208},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201},
    },
    throttle_percent = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5440},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x51A4},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5269},
    },
    rpm = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0500},
    },
    tailspeed = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0501},
    },
    link = {
      {appId = 0xF101, subId = 0},
      "RSSI",
    },
    vfr = {
      {appId = 0xF010, subId = 0},
    },
    smartfuel = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1},
    },
    temp_esc = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0418},
    },
    temp_mcu = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0400},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401},
    },
    bec_voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0901},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0219},
    },
    altitude = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0100},
    },
  },
  crsf = {
    -- subId=2 is the dedicated Link Quality field on firmware that broadcasts
    -- Rotorflight's newer CRSF telemetry frame (probed pre-rewrite via a
    -- 0xEE01 marker sensor -- see tasks/scheduler/telemetry/telemetry.lua's
    -- detectSourceMode() in the pre-rewrite tree). Older firmware without
    -- that marker never exposed subId=2 at all and instead used this
    -- subIdStart/subIdEnd range (see that same tree's
    -- sources/crsf_legacy.lua), which is what "link" below also uses as its
    -- structured candidate. Kept as a plain fallback here rather than fully
    -- reviving the old two-table firmware-format split: it stops rssi being
    -- permanently stuck on nil for old-firmware users, though the range's
    -- value is raw antenna RSSI rather than a true 0-100 LQ%, so it may not
    -- land on this box's step gauge as cleanly as subId=2 does.
    rssi = {
      {crsfId = 0x14, subId = 2},
      {crsfId = 0x14, subIdStart = 0, subIdEnd = 1},
    },
    voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1011},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1041},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1051},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1080},
    },
    consumption = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013},
    },
    current = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x104A},
    },
    throttle_percent = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1035},
    },
    rpm = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C0},
    },
    tailspeed = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C1},
    },
    link = {
      {crsfId = 0x14, subIdStart = 0, subIdEnd = 1},
      "Rx RSSI1",
    },
    -- Same rssi/subId=2 fallback reasoning as above -- vfr mirrors rssi
    -- one-for-one in this table (see sensorValue()'s `name == "rssi" or
    -- name == "vfr"` branch, which already treats them identically).
    vfr = {
      {crsfId = 0x14, subId = 2},
      {crsfId = 0x14, subIdStart = 0, subIdEnd = 1},
    },
    smartfuel = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1},
    },
    temp_esc = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1047},
    },
    temp_mcu = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3},
    },
    bec_voltage = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1081},
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1049},
    },
    altitude = {
      {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10B2},
    },
  },
}

local function normalizeLiveSensorName(name)
  if name == "headspeed" then return "rpm" end
  return name
end

local function liveProtocol(state)
  local protocol = state and state.mspTransport
  if protocol == "sport" or protocol == "crsf" then return protocol end
  return nil
end

local function liveSensorSource(protocol, name)
  name = normalizeLiveSensorName(name)
  if not protocol or not name then return nil end

  local byProtocol = liveSourceCache[protocol]
  if not byProtocol then
    byProtocol = {}
    liveSourceCache[protocol] = byProtocol
  end

  local now = os.clock()
  local source = byProtocol[name]
  if source then
    local revalidate = liveRevalidateAt[protocol]
    local dueAt = revalidate and revalidate[name]
    if not dueAt or now < dueAt then return source end
    -- Due for a recheck: fall through and re-scan candidates instead of
    -- trusting this cached source forever (see LIVE_REVALIDATE_INTERVAL's
    -- comment above).
    byProtocol[name] = nil
    source = nil
  end

  local misses = liveMissRetryAt[protocol]
  if misses and misses[name] and now < misses[name] then return nil end

  local candidates = LIVE_SENSOR_CANDIDATES[protocol] and LIVE_SENSOR_CANDIDATES[protocol][name]
  if not candidates then return nil end
  for i = 1, #candidates do
    source = system.getSource(candidates[i])
    if source then
      byProtocol[name] = source
      if misses then misses[name] = nil end
      local missCounts = liveMissCount[protocol]
      if missCounts then missCounts[name] = nil end
      local revalidate = liveRevalidateAt[protocol]
      if not revalidate then
        revalidate = {}
        liveRevalidateAt[protocol] = revalidate
      end
      revalidate[name] = now + LIVE_REVALIDATE_INTERVAL
      return source
    end
  end

  if not misses then
    misses = {}
    liveMissRetryAt[protocol] = misses
  end
  local missCounts = liveMissCount[protocol]
  if not missCounts then
    missCounts = {}
    liveMissCount[protocol] = missCounts
  end
  local count = (missCounts[name] or 0) + 1
  missCounts[name] = count
  local interval = math.min(LIVE_MISS_RETRY_INITIAL * (LIVE_MISS_RETRY_MULTIPLIER ^ (count - 1)), LIVE_MISS_RETRY_MAX)
  misses[name] = now + interval
  return nil
end

local function liveSensorValue(protocol, name)
  local source = liveSensorSource(protocol, name)
  if not source then return nil end
  if source.state and source:state() == false then return nil end
  return source:value()
end

local function sensorValue(widget, name)
  if not widget then return nil end
  if widget.connected ~= true then return nil end
  local protocol = liveProtocol(widget)
  if name == "voltage" then return widget.voltage or liveSensorValue(protocol, name), "V" end
  if name == "cell_voltage" then
    local cells = widget.batteryConfig and tonumber(widget.batteryConfig.cellCount)
    local voltage = tonumber(widget.voltage) or tonumber(liveSensorValue(protocol, "voltage"))
    if cells and cells > 0 and voltage then return voltage / cells, "V" end
    return nil, "V"
  end
  if name == "consumption" or name == "smartconsumption" then return widget.consumption or liveSensorValue(protocol, "consumption"), "mAh" end
  if name == "current" then return widget.current or liveSensorValue(protocol, name), "A" end
  if name == "throttle_percent" then return widget.throttlePercent or liveSensorValue(protocol, name), "%" end
  if name == "rpm" or name == "headspeed" then return widget.rpm or liveSensorValue(protocol, name), "rpm" end
  if name == "tailspeed" then return liveSensorValue(protocol, name), "rpm" end
  if name == "link" then return widget.linkQuality or liveSensorValue(protocol, name), "dB" end
  if name == "rssi" or name == "vfr" then return liveSensorValue(protocol, name), "%" end
  if name == "smartfuel" or name == "fuel" then return widget.fuelPercent or liveSensorValue(protocol, "smartfuel"), "%" end
  if name == "watts" then
    local voltage = tonumber(widget.voltage) or tonumber(liveSensorValue(protocol, "voltage"))
    local current = tonumber(widget.current) or tonumber(liveSensorValue(protocol, "current"))
    if voltage and current then return voltage * current, "W" end
    return nil, "W"
  end
  -- Derived, not measured: the current as a percentage of the speed controller's own limit (#2355).
  -- Nil where no limit is on file for the model, which a box draws as `--`.
  if name == "esc_load" then
    local limit = tonumber(widget.escCurrentLimit)
    local current = tonumber(widget.current) or tonumber(liveSensorValue(protocol, "current"))
    if limit and limit > 0 and current then return current / limit * 100, "%" end
    return nil, "%"
  end
  if name == "governor" then return widget.governorState end
  if name == "pid_profile" then return widget.pidProfile end
  if name == "rate_profile" then return widget.rateProfile end
  if name == "battery_profile" then return widget.batteryProfile end
  if name == "temp_mcu" then return widget.tempMcu or liveSensorValue(protocol, name), "°C" end
  if name == "temp_esc" then return widget.tempEsc or liveSensorValue(protocol, name), "°C" end
  if name == "bec_voltage" then return widget.becVoltage or liveSensorValue(protocol, name), "V" end
  if name == "altitude" then return liveSensorValue(protocol, name), "m" end
  if name == "armflags" then
    if widget.isArmed == true then return 1 end
    if widget.isArmed == false then return 0 end
  end
  if name == "armdisableflags" then return widget.armDisableFlags end
  return nil
end

live_sensors.source = liveSensorSource
live_sensors.value = liveSensorValue
live_sensors.read = sensorValue

-- Drops the resolved sources and the miss backoff, as a theme reload did before.
function live_sensors.reset()
  for _, t in ipairs({liveSourceCache, liveMissRetryAt, liveMissCount}) do
    for key in pairs(t) do t[key] = nil end
  end
end

package.loaded["rfsuite.lib.live_sensors"] = live_sensors
return live_sensors

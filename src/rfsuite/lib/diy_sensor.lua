-- Thin wrapper around Ethos's model.createSensor(), used to make a
-- locally-computed value (something this rebuild derives itself rather
-- than reading off the air -- currently just the local smartfuel
-- fallback, see tasks/session.lua) show up as a normal telemetry sensor,
-- so anything else on the radio -- dashboards, logs, voice packs -- can
-- read it the same way it would read any FC-broadcast sensor. Mirrors
-- rotorflight-lua-ethos-suite's tasks/scheduler/sensors/smart.lua
-- (`createOrUpdateSensor`), trimmed down hard.
--
-- Deliberately much smaller than that original:
--   - One instance == one appId (create with DiySensor.new(...), same
--     per-instance-state convention as lib/smartfuel_calc.lua's
--     SmartFuel.new()) -- no per-appId cache table, no sensor-mode-
--     signature/module-change bookkeeping, no separate positive/negative
--     caches.
--   - Fixed to telemetry module 0, matching the existing "always module 0"
--     simplification already accepted in tasks/msp/transport_sport.lua
--     (this rebuild has no multi-module telemetry selection).
--   - Only meant to be used when nothing else is already broadcasting the
--     value: the caller (tasks/session.lua) only calls set() while doing
--     its own local fallback calculation, never as a mirror of a value
--     that's already arriving over the air -- so there is no "push the
--     same value back into the FC's own sensor" step every wakeup like the
--     original does.
--
-- CPU note: everything after the first successful resolve is O(1) -- a
-- couple of comparisons -- so a once-per-wakeup caller can call set()
-- unconditionally; it will not touch the Ethos sensor API unless the
-- value actually changed or the stale-refresh window elapsed.

local os_clock = os.clock
local system_getSource = system.getSource
local model_createSensor = model.createSensor
local requireModule = assert(loadfile("lib/require.lua"))()
local debugLog = requireModule("lib/debug_log.lua")

-- Ethos before 26.1 only supports :value(v); 26.1+ wants :rawValue(v)
-- instead. This can't be a runtime capability probe (`if sensor.rawValue
-- then ...`): the method is bound on the sensor userdata's metatable
-- regardless of firmware version, so it reads as present on 1.6.x too --
-- calling it there creates the sensor (all the plain setters still work)
-- but the value never actually populates. Needs an explicit version gate
-- instead, same as rotorflight-lua-ethos-suite's master branch
-- (tasks/scheduler/sensors/*.lua's own `useRawValue`).
local ethosVersion = requireModule("lib/ethos_version.lua")
local useRawValue = ethosVersion.atLeast({26, 1, 0})

local function pushValue(sensor, v)
  if useRawValue then
    sensor:rawValue(v)
  else
    sensor:value(v)
  end
end

-- Re-pushed at least this often even when the value hasn't changed, so
-- Ethos doesn't treat an unchanging DIY sensor as stale/no-signal.
local STALE_REFRESH_SECONDS = 4.0

-- Default RF-module index, matching the existing "always module 0"
-- simplification in tasks/msp/transport_sport.lua. Overridable per
-- instance (see `moduleIndex` below) -- the original's own ELRS sensor
-- creation hardcodes module 1 instead, matching CRSF/ELRS commonly running
-- on the radio's external RF module bay rather than the internal one.
local DEFAULT_MODULE_INDEX = 0

local DiySensor = {}
DiySensor.__index = DiySensor

function DiySensor.new(appId, name, unit, minimum, maximum, moduleIndex, decimals)
  return setmetatable({
    appId = appId,
    name = name,
    unit = unit,
    minimum = minimum or -1000000000,
    maximum = maximum or 1000000000,
    moduleIndex = moduleIndex or DEFAULT_MODULE_INDEX,
    decimals = decimals,
    sensor = nil,
    resolved = false,
    lastValue = nil,
    lastPushAt = 0,
  }, DiySensor)
end

-- `connected` gates *creation* only (mirrors the original's wait for
-- session.telemetrySensor before calling model.createSensor) -- once
-- resolved, further calls are free even if connected is stale/false for a
-- tick.
function DiySensor:_resolve(connected)
  if self.resolved then return self.sensor end
  if not connected then return nil end

  local existing = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = self.appId})
  if existing then
    self.sensor = existing
    self.resolved = true
    debugLog.format("[diy_sensor] %s (appId=0x%04X) already exists, reusing", self.name, self.appId)
    return self.sensor
  end

  local sensor = model_createSensor({type = SENSOR_TYPE_DIY})
  sensor:name(self.name)
  sensor:appId(self.appId)
  sensor:physId(0)
  sensor:module(self.moduleIndex)
  if self.unit then
    sensor:unit(self.unit)
    sensor:protocolUnit(self.unit)
  end
  if self.decimals then
    sensor:decimals(self.decimals)
    sensor:protocolDecimals(self.decimals)
  end
  sensor:minimum(self.minimum)
  sensor:maximum(self.maximum)
  debugLog.format("[diy_sensor] created %s (appId=0x%04X)", self.name, self.appId)

  self.sensor = sensor
  self.resolved = true
  return self.sensor
end

-- value == nil clears the sensor (e.g. inputs went missing mid-session
-- without a full disconnect); the sensor stays resolved so it doesn't need
-- re-creating once a value returns.
function DiySensor:set(value, connected)
  local sensor = self:_resolve(connected)
  if not sensor then return end

  if value == nil then
    if self.lastValue ~= nil then
      sensor:reset()
      self.lastValue = nil
    end
    return
  end

  local now = os_clock()
  if self.lastValue == value and (now - self.lastPushAt) < STALE_REFRESH_SECONDS then
    return
  end

  pushValue(sensor, value)
  self.lastValue = value
  self.lastPushAt = now
end

-- Re-pushes the last known value once the stale-refresh window has
-- elapsed, without the caller needing to already know what that value
-- was. For a caller that calls set() with a fresh value every wakeup
-- regardless of whether it changed (e.g. tasks/session.lua's smartfuel
-- sensor), set() alone already guarantees this -- refresh() exists for
-- callers that only call set() when new data actually arrives (e.g.
-- tasks/elrs_sensors.lua, one appId per CRSF SID): without a periodic
-- sweep independent of new data, a SID the FC stops sending (a slot
-- round-robin gap, a value that only transmits on change, a brief link
-- hiccup) would leave that one sensor looking stale/no-signal even though
-- the link and every other sensor are still fine. Matches the original's
-- own elrs.lua `refreshStaleSensors()`, called unconditionally every
-- wakeup there too.
function DiySensor:refresh()
  if not self.resolved or self.lastValue == nil then return end
  self:set(self.lastValue, true)
end

-- Called on disconnect: forget the resolved sensor so a fresh connection
-- re-resolves from scratch -- a stale sensor object from a previous
-- aircraft/session must not carry over, same reasoning as
-- tasks/session.lua's own field resets in setConnected(false).
function DiySensor:reset()
  if self.resolved and self.sensor and self.lastValue ~= nil then
    self.sensor:reset()
  end
  self.sensor = nil
  self.resolved = false
  self.lastValue = nil
  self.lastPushAt = 0
end

return DiySensor

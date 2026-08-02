-- ELRS/CRSF custom-telemetry (frame type 0x88) decode + auto-create.
-- Loaded once by tasks/background.lua (single instance, module-level state --
-- same convention as tasks/session.lua) and driven from taskWakeup() only
-- when the CRSF transport is active; nothing here runs for S.Port (see
-- lib/frsky_sensors.lua for that protocol's own, differently-shaped
-- mechanism).
--
-- Mirrors rotorflight-lua-ethos-suite's tasks/scheduler/sensors/elrs.lua,
-- trimmed hard:
--   - No frame-skip/publish-overflow/parse-break diagnostic counters or
--     cooldown-limited diag logging -- see AGENTS.md's debug-print
--     convention instead (a plain [elrs] print, not per-frame).
--   - No live-reconfiguration support for the relevant-SID set: this
--     rebuild's tasks/session.lua only reads telemetry slots once per
--     connection (never re-reads mid-session), so the set is built once,
--     the first time slots become available, and reset only alongside a
--     full disconnect (see reset() below) -- no slot-signature/rebuild
--     tracking needed.
--   - Each relevant SID gets its own lib/diy_sensor.lua instance instead
--     of a bespoke sensorCache/negativeCache/lastValue/lastPush table --
--     that primitive already does resolve-once + skip-unchanged +
--     stale-refresh; no need to reimplement it here.
--
-- CRSF's custom telemetry packs many SIDs into one binary frame; unlike
-- S.Port's frsky_sensors.lua (which only needs to *label* frames the FC
-- already broadcasts), there is no way to know a SID's value without
-- decoding frames as they arrive -- so, unlike that config-driven
-- approach, this one is inherently reactive.
--
-- Aggregate SIDs (Ctrl/Attitude/Accel/GPS coord/Cell voltages/Adjustment)
-- are a wire-level "envelope": their own dec() function never itself
-- returns a value (always `nil`) -- instead it publishes several *child*
-- SIDs directly, each with its own hardcoded name/unit/decimals/range.
-- Transcribed as literals straight from the original's own decControl/
-- decAttitude/decAccel/decLatLong/decAdjFunc/decCells (not looked up from
-- lib/elrs_sensor_table.lua) because that original's own table entries
-- for several of these child SIDs actually disagree with what those
-- decoders themselves publish (different decimals/range on more than one
-- entry) -- the inline values are what's authoritative for what a
-- standalone (non-aggregate) wire SID would use instead, not what the
-- aggregate path itself does.

local elrsDecode = assert(loadfile("lib/elrs_decode_primitives.lua"))()
local sidLookup = assert(loadfile("lib/elrs_sid_lookup.lua"))()
local DiySensor = assert(loadfile("lib/diy_sensor.lua"))()
local debugLog = assert(loadfile("lib/debug_log.lua"))()

-- ELRS/CRSF DIY sensors use module 1 (external RF module bay), matching
-- the original's own hardcoded choice for this protocol -- see
-- lib/diy_sensor.lua's header for why this differs from S.Port's module 0.
local MODULE_INDEX = 1

-- Safety cap on time spent draining queued custom-telemetry frames in a
-- single wakeup -- deliberately tighter than the original's own 0.2s,
-- since this now runs alongside the background task's MSP queue/session
-- polling in the same wakeup tick. Only matters if frames have backed up;
-- steady-state draining finishes in well under this.
local POP_BUDGET_SECONDS = 0.05

local os_clock = os.clock
local math_floor = math.floor

-- appId -> {name, unit, prec, min, max, dec} once built (see
-- buildSensorTable below); appId -> DiySensor instance once first seen.
local sensorTable = nil
local sensors = {}

-- nil until telemetrySlots is available (permissive: process every known
-- SID until then, matching the original's own default-allow-until-config
-- behaviour), then a fixed set for the rest of the connection.
local relevantSids = nil

-- Shared publish choke point -- every value, whether from the outer
-- dispatch (standalone SIDs) or an aggregate decoder's own child SIDs,
-- goes through here, so relevance filtering applies uniformly to both
-- (matches the original's own single setTelemetryValue() doing the same).
local function resolveAndPush(appId, value, name, unit, decimals, minimum, maximum)
  if relevantSids and not relevantSids[appId] then return end
  if value == nil or not name then return end

  local sensor = sensors[appId]
  if not sensor then
    sensor = DiySensor.new(appId, name, unit, minimum, maximum, MODULE_INDEX, decimals)
    sensors[appId] = sensor
  end
  sensor:set(value, true) -- a frame arrived at all => the link is up
end

-- Aggregate decoders -- see file header for why these use hardcoded
-- metadata rather than lib/elrs_sensor_table.lua lookups. Ported verbatim
-- from the original's own elrs.lua local functions of the same names.
local function decCells(data, pos)
  local cnt, val, vol
  cnt, pos = elrsDecode.decU8(data, pos)
  resolveAndPush(0x1020, cnt, "Cell Count", UNIT_RAW, 0, 0, 15)
  for i = 1, cnt do
    val, pos = elrsDecode.decU8(data, pos)
    val = val > 0 and val + 200 or 0
    vol = (cnt << 24) | ((i - 1) << 16) | val
    resolveAndPush(0x102F, vol, "Cell Voltages", UNIT_CELLS, 2, 0, 455)
  end
  return nil, pos
end

local function decControl(data, pos)
  local p, r, y, c
  p, r, pos = elrsDecode.decS12S12(data, pos)
  y, c, pos = elrsDecode.decS12S12(data, pos)
  resolveAndPush(0x1031, p, "Pitch Control", UNIT_DEGREE, 2, -4500, 4500)
  resolveAndPush(0x1032, r, "Roll Control", UNIT_DEGREE, 2, -4500, 4500)
  resolveAndPush(0x1033, 3 * y, "Yaw Control", UNIT_DEGREE, 2, -9000, 9000)
  resolveAndPush(0x1034, c, "Coll Control", UNIT_DEGREE, 2, -4500, 4500)
  return nil, pos
end

local function decAttitude(data, pos)
  local p, r, y
  p, pos = elrsDecode.decS16(data, pos)
  r, pos = elrsDecode.decS16(data, pos)
  y, pos = elrsDecode.decS16(data, pos)
  resolveAndPush(0x1101, p, "Pitch Attitude", UNIT_DEGREE, 1, -1800, 3600)
  resolveAndPush(0x1102, r, "Roll Attitude", UNIT_DEGREE, 1, -1800, 3600)
  resolveAndPush(0x1103, y, "Yaw Attitude", UNIT_DEGREE, 1, -1800, 3600)
  return nil, pos
end

local function decAccel(data, pos)
  local x, y, z
  x, pos = elrsDecode.decS16(data, pos)
  y, pos = elrsDecode.decS16(data, pos)
  z, pos = elrsDecode.decS16(data, pos)
  resolveAndPush(0x1111, x, "Accel X", UNIT_G, 2, -4000, 4000)
  resolveAndPush(0x1112, y, "Accel Y", UNIT_G, 2, -4000, 4000)
  resolveAndPush(0x1113, z, "Accel Z", UNIT_G, 2, -4000, 4000)
  return nil, pos
end

local function decLatLong(data, pos)
  local lat, lon
  lat, pos = elrsDecode.decS32(data, pos)
  lon, pos = elrsDecode.decS32(data, pos)
  lat = math_floor(lat * 0.001)
  lon = math_floor(lon * 0.001)
  resolveAndPush(0x1125, lat, "GPS Latitude", UNIT_DEGREE, 4, -10000000000, 10000000000)
  resolveAndPush(0x112B, lon, "GPS Longitude", UNIT_DEGREE, 4, -10000000000, 10000000000)
  return nil, pos
end

local function decAdjFunc(data, pos)
  local fun, val
  fun, pos = elrsDecode.decU16(data, pos)
  val, pos = elrsDecode.decS32(data, pos)
  resolveAndPush(0x1221, fun, "Adj. Source", UNIT_RAW, 0, 0, 255)
  resolveAndPush(0x1222, val, "Adj. Value", UNIT_RAW, 0, nil, nil)
  return nil, pos
end

local function buildSensorTable()
  if sensorTable then return end
  local factory = assert(loadfile("lib/elrs_sensor_table.lua"))()
  sensorTable = factory({
    decNil = elrsDecode.decNil,
    decU8 = elrsDecode.decU8,
    decS8 = elrsDecode.decS8,
    decU16 = elrsDecode.decU16,
    decS16 = elrsDecode.decS16,
    decU24 = elrsDecode.decU24,
    decS24 = elrsDecode.decS24,
    decU32 = elrsDecode.decU32,
    decS32 = elrsDecode.decS32,
    decCellV = elrsDecode.decCellV,
    decCells = decCells,
    decControl = decControl,
    decAttitude = decAttitude,
    decAccel = decAccel,
    decLatLong = decLatLong,
    decAdjFunc = decAdjFunc,
  })
end

-- Built once, the first time telemetrySlots is available -- this
-- rebuild's tasks/session.lua only reads TELEMETRY_CONFIG once per
-- connection, so there is nothing to rebuild against later.
local function buildRelevantSids(telemetrySlots)
  if relevantSids then return end
  relevantSids = {}
  for i = 1, #telemetrySlots do
    local sid = telemetrySlots[i]
    if sid and sid ~= 0 then
      local sids = sidLookup[sid]
      if sids then
        for j = 1, #sids do relevantSids[sids[j]] = true end
      end
    end
  end
  local count = 0
  for _ in pairs(relevantSids) do count = count + 1 end
  debugLog.print("[elrs] relevant SID set built: " .. count .. " SIDs")
end

-- Parses one popped custom-telemetry frame: 2 address bytes + 1 frame-id
-- byte (all skipped -- this rebuild doesn't track frame-skip diagnostics),
-- then repeating (U16 sid, decoded value) pairs until the frame is
-- exhausted. An unrecognized sid can't be decoded without knowing its
-- byte width, so parsing stops there (matches the original's own
-- "parse break" behaviour) -- the rest of that frame's data is lost, not
-- the connection.
local function parseFrame(data)
  local len = #data
  local ptr = 4 -- skip 2 address bytes + 1 frame-id byte
  -- Strictly-less-than: decU16 below needs 2 full bytes (data[ptr] and
  -- data[ptr+1]), and it isn't pcall-wrapped, so ptr must never reach the
  -- last byte with nothing left to pair it with -- matches the original's
  -- own `while ptr < #data` guard exactly.
  while ptr < len do
    local sid
    sid, ptr = elrsDecode.decU16(data, ptr)
    local meta = sensorTable[sid]
    if not meta then return end

    local prevPtr = ptr
    local ok, value, nextPtr = pcall(meta.dec, data, ptr)
    if not ok or not nextPtr or nextPtr <= prevPtr then return end
    ptr = nextPtr

    if value ~= nil then
      resolveAndPush(sid, value, meta.name, meta.unit, meta.prec, meta.min, meta.max)
    end
  end
end

local function wakeup(transport, telemetrySlots)
  if not transport or not transport.popCustomTelemetryFrame then return end
  if not sensorTable then buildSensorTable() end
  if telemetrySlots and not relevantSids then buildRelevantSids(telemetrySlots) end

  local deadline = os_clock() + POP_BUDGET_SECONDS
  while os_clock() < deadline do
    local command, data = transport.popCustomTelemetryFrame()
    if not command then break end
    parseFrame(data)
  end

  -- Unconditional, every wakeup, regardless of whether any frame arrived
  -- this tick -- see lib/diy_sensor.lua's refresh() for why this sweep is
  -- needed at all here. Cheap: each entry is a no-op unless its own
  -- STALE_REFRESH_SECONDS window has actually elapsed.
  for _, sensor in pairs(sensors) do sensor:refresh() end
end

-- Called on disconnect (mirrors tasks/session.lua's own field resets):
-- forget the relevant-SID set (rebuilt fresh from the next connection's
-- own TELEMETRY_CONFIG read) and every resolved sensor's cached value, in
-- case a different aircraft is now connected. The Ethos sensor objects
-- themselves are left alone -- see lib/diy_sensor.lua's own reasoning for
-- why lib/frsky_sensors.lua doesn't tear those down either.
local function reset()
  relevantSids = nil
  for _, sensor in pairs(sensors) do sensor:reset() end
end

return {wakeup = wakeup, reset = reset}

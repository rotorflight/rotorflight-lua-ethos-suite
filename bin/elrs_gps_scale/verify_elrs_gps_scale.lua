-- Behaviour check for the GPS sensors of the CRSF custom telemetry (issue #2665).
--
-- Run it:
--     lua5.4 bin/elrs_gps_scale/verify_elrs_gps_scale.lua
--     lua5.4 bin/elrs_gps_scale/verify_elrs_gps_scale.lua --self-test
--
-- The claim: a frame's GPS values reach the radio at the scale the firmware
-- sends them.
--   * Home distance is whole metres (firmware: GPS_distanceToHome = dist / 100).
--   * Home direction is whole degrees (firmware: GPS_directionToHome = dir / 100).
--   * GPS altitude is decimetres from MSP API 12.10 (firmware #549) and
--     centimetres before. The sensor stays at centimetre precision, so the value
--     is scaled to it, and nothing is published while the API version is unknown.
--
-- How it is measured: tasks/elrs_sensors.lua is loaded from its own file, with
-- the real decoder table (lib/elrs_sensor_table.lua), the real decode primitives
-- and the real lib/diy_sensor.lua. Only Ethos's objects are stubbed:
-- system.getSource and model.createSensor, which record what the suite asks of a
-- sensor. A frame is pushed through the transport, the way the radio delivers it.
--
-- --self-test loads a copy of elrs_sensors.lua with the altitude scale removed and
-- requires the altitude check to go red on it.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local TASKS = SRC .. "/tasks"
local ELRS_SENSORS_PATH = TASKS .. "/elrs_sensors.lua"

local failures = 0
local checks = 0

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

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

-- ---------------------------------------------------------------------------
-- Ethos globals the real files read. Units are readable strings so a check
-- can say what the suite asked for.
-- ---------------------------------------------------------------------------
UNIT_METER, UNIT_DEGREE, UNIT_G, UNIT_RAW = "m", "deg", "g", "raw"
UNIT_PERCENT, UNIT_CELLS, UNIT_METER_PER_SECOND = "%", "cells", "m/s"
UNIT_VOLT, UNIT_AMPERE, UNIT_CELSIUS, UNIT_RPM = "V", "A", "C", "rpm"
UNIT_MILLIAMPERE_HOUR = "mAh"
CATEGORY_TELEMETRY_SENSOR, SENSOR_TYPE_DIY = 5, 1

-- ---------------------------------------------------------------------------
-- Sensor objects. Every setter call is recorded; value() and rawValue() also
-- set `last`, so a check can read what was published.
-- ---------------------------------------------------------------------------
local function newSensor(id)
  -- `id` is the appId the sensor carries. Named apart from the appId() setter.
  local sensor = { id = id, calls = {}, last = nil }
  return setmetatable(sensor, {__index = function(self, name)
    -- Plain fields are read as fields: an unset one is nil, not a method.
    if name == "last" or name == "calls" or name == "id" then return nil end
    return function(_, arg)
      self.calls[#self.calls + 1] = {name = name, arg = arg}
      if name == "appId" then self.id = arg end
      if name == "value" or name == "rawValue" then self.last = arg end
    end
  end})
end

local function hasCall(sensor, name, arg)
  if not sensor then return false end
  for _, call in ipairs(sensor.calls) do
    if call.name == name and call.arg == arg then return true end
  end
  return false
end

-- Per scenario: the sensors the suite creates, and the ones the radio already has.
local created, existing = {}, {}

system = {
  getSource = function(spec)
    if spec.category ~= CATEGORY_TELEMETRY_SENSOR then return nil end
    return existing[spec.appId]
  end,
  getVersion = function() return {simulation = false} end,
}
model = {
  createSensor = function()
    local sensor = newSensor(nil)
    created[#created + 1] = sensor
    return sensor
  end,
}

local function createdFor(appId)
  for _, sensor in ipairs(created) do
    if sensor.id == appId then return sensor end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- The loader: real modules by path, cached per scenario so each one starts clean.
-- ---------------------------------------------------------------------------
local cache = {}
local function realModule(name)
  if cache[name] == nil then
    cache[name] = assert(loadfile(SRC .. "/" .. name))()
  end
  return cache[name]
end

local debugLogStub = {print = function() end, format = function() end, msp = function() end}
-- Stands in for lib/elrs_sid_lookup.lua: it is used only when telemetry slots are
-- given, and these scenarios pass none, so every SID is relevant.
local sidLookupStub = {}

local function installRequire()
  cache = {}
  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/debug_log.lua" then return debugLogStub end
    if name == "lib/elrs_sid_lookup.lua" then return sidLookupStub end
    if name == "lib/elrs_decode_primitives.lua" then return realModule(name) end
    if name == "lib/diy_sensor.lua" then return realModule(name) end
    if name == "lib/ethos_version.lua" then return realModule(name) end
    if name == "lib/elrs_sensor_table.lua" then return realModule(name) end
    error("unexpected dependency: " .. tostring(name))
  end
end

-- ---------------------------------------------------------------------------
-- Frames. A frame is 2 address bytes, a frame id, then (U16 sid, value) pairs.
-- Values are big-endian, as the decode primitives read them.
-- ---------------------------------------------------------------------------
local function be16(value)
  value = value & 0xFFFF
  return {(value >> 8) & 0xFF, value & 0xFF}
end

local function frame(pairs_)
  local bytes = {0x00, 0x00, 0x11}
  for _, pair in ipairs(pairs_) do
    for _, b in ipairs(be16(pair.sid)) do bytes[#bytes + 1] = b end
    for _, b in ipairs(pair.bytes) do bytes[#bytes + 1] = b end
  end
  return bytes
end

local function s16(sid, value) return {sid = sid, bytes = be16(value)} end

-- Runs the real elrs_sensors.lua over `frames`. `source` replaces the file's
-- text (the self-test's sabotaged copy). The first wakeup is the cold start that
-- loads the decoder table; the second decodes the backlog.
local function run(frames, apiMajor, apiMinor, source, alreadyThere)
  created, existing = {}, alreadyThere or {}
  installRequire()
  local chunk
  if source then
    chunk = assert(load(source, "=elrs_sensors", "t"))
  else
    chunk = assert(loadfile(ELRS_SENSORS_PATH))
  end
  local module = chunk()
  local queue = frames
  local transport = {
    popCustomTelemetryFrame = function()
      if #queue == 0 then return nil end
      return 0x88, table.remove(queue, 1)
    end,
  }
  module.wakeup(transport, nil, apiMajor, apiMinor)
  module.wakeup(transport, nil, apiMajor, apiMinor)
  return module
end

local ALT, HOME_DIST, HOME_DIR = 0x1126, 0x1129, 0x112A

-- ---------------------------------------------------------------------------
-- 1. GPS altitude.
-- ---------------------------------------------------------------------------
print("GPS altitude")
do
  -- 1234 decimetres = 123.4 m, sent by API 12.10 firmware.
  run({frame({s16(ALT, 1234)})}, 12, 10)
  local alt = createdFor(ALT)
  check("API 12.10: the altitude is published in centimetres (1234 dm -> 12340 cm)",
    alt ~= nil and alt.last == 12340, "published " .. tostring(alt and alt.last))
  check("API 12.10: the altitude sensor keeps two decimals, in metres",
    hasCall(alt, "decimals", 2) and hasCall(alt, "unit", UNIT_METER),
    "decimals/unit calls: " .. tostring(alt and #alt.calls))
end
do
  -- 1234 centimetres, sent by API 12.9 firmware (the released 4.6.0).
  run({frame({s16(ALT, 1234)})}, 12, 9)
  local alt = createdFor(ALT)
  check("API 12.9: the altitude is published as sent (1234 cm)",
    alt ~= nil and alt.last == 1234, "published " .. tostring(alt and alt.last))
end
do
  -- Before the API version is read, a guessed scale would show ten times off.
  run({frame({s16(ALT, 1234)})}, nil, nil)
  check("no API version yet: the altitude is not published",
    createdFor(ALT) == nil, "a sensor was created for the altitude")
end

-- ---------------------------------------------------------------------------
-- 2. Home distance and home direction: whole units, no decimals.
-- ---------------------------------------------------------------------------
print("Home distance and direction")
do
  run({frame({s16(HOME_DIST, 500), s16(HOME_DIR, 270)})}, 12, 10)
  local dist, dir = createdFor(HOME_DIST), createdFor(HOME_DIR)
  check("home distance is whole metres (500 m, two decimals not applied)",
    dist ~= nil and dist.last == 500 and hasCall(dist, "decimals", 0) and hasCall(dist, "unit", UNIT_METER),
    "published " .. tostring(dist and dist.last))
  check("home direction is whole degrees (270 deg, metres not applied, max 360)",
    dir ~= nil and dir.last == 270 and hasCall(dir, "decimals", 0) and hasCall(dir, "unit", UNIT_DEGREE)
      and hasCall(dir, "maximum", 360),
    "published " .. tostring(dir and dir.last))
end

-- ---------------------------------------------------------------------------
-- 3. A held-back altitude does not stop the frame walk: the sensors packed after
--    it in the same frame still arrive.
-- ---------------------------------------------------------------------------
print("Frame walk")
do
  run({frame({s16(ALT, 1234), s16(HOME_DIST, 500)})}, nil, nil)
  local dist = createdFor(HOME_DIST)
  check("with no API version the altitude is held, and the home distance behind it still arrives",
    dist ~= nil and dist.last == 500, "published " .. tostring(dist and dist.last))
end

-- ---------------------------------------------------------------------------
-- 4. A sensor the radio already has keeps its old unit and decimals (an older
--    suite created it with the wrong ones). They are brought to this table's.
-- ---------------------------------------------------------------------------
print("Existing sensors")
do
  -- The radio already has this sensor, created by an older suite (metres, as the
  -- old table said). Its calls start empty: only what this run asks of it counts.
  local oldDir = newSensor(HOME_DIR)
  run({frame({s16(HOME_DIR, 270)})}, 12, 10, nil, {[HOME_DIR] = oldDir})
  check("an existing home direction sensor is set to degrees, whole numbers",
    hasCall(oldDir, "unit", UNIT_DEGREE) and hasCall(oldDir, "decimals", 0),
    "calls on the existing sensor: " .. tostring(#oldDir.calls))
  check("an existing home direction sensor is reused, not created again",
    createdFor(HOME_DIR) == nil, "a second sensor was created")
  check("the value reaches the existing sensor", oldDir.last == 270, "published " .. tostring(oldDir.last))
end

-- ---------------------------------------------------------------------------
-- 5. Disconnect reset: clears firmwareDecimetres so a subsequent connection
--    does not publish altitude before its own API version is known.
-- ---------------------------------------------------------------------------
print("Reset on disconnect")
do
  local module = run({frame({s16(ALT, 1234)})}, 12, 10)
  check("altitude was published while connected to API 12.10",
    createdFor(ALT) ~= nil and createdFor(ALT).last == 12340)

  module.reset()

  -- A subsequent connection delivers an altitude frame before its API version is known.
  created = {}
  local queue = {frame({s16(ALT, 1234)})}
  local transport = {
    popCustomTelemetryFrame = function()
      if #queue == 0 then return nil end
      return 0x88, table.remove(queue, 1)
    end,
  }
  module.wakeup(transport, nil, nil, nil)
  check("reset cleared the API version: altitude is held again until known",
    createdFor(ALT) == nil, "altitude sensor was published after reset without API version")
end

-- ---------------------------------------------------------------------------
-- self-test: the altitude check must be able to go red.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the altitude check must go red without the scale")

  local source = readFile(ELRS_SENSORS_PATH)
  local mutated, replacements = source:gsub("if firmwareDecimetres then val = val %* 10 end",
    "if false then val = val * 10 end", 1)
  check("self-test: the altitude scale was found in elrs_sensors.lua exactly once",
    replacements == 1, "replacements=" .. replacements .. " (the harness no longer tracks the code it checks)")

  if replacements == 1 then
    run({frame({s16(ALT, 1234)})}, 12, 10, mutated)
    local alt = createdFor(ALT)
    check("self-test: without the scale the altitude is published as sent (1234, not 12340)",
      alt ~= nil and alt.last == 1234, "published " .. tostring(alt and alt.last))
  end
end

-- ---------------------------------------------------------------------------

print()
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.exit(1)

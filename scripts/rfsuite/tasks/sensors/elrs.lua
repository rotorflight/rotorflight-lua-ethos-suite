-- tasks/sensors/elrs.lua  (lazy sid load, compact map, free sid; polls only whitelisted sensors)

local arg = {...}
local config = arg[1]

local elrs = {}
elrs.name = "elrs"

-- Crossfire access shims (unchanged)
if crsf.getSensor ~= nil then
  local sensor = crsf.getSensor()
  elrs.popFrame = function() return sensor:popFrame() end
  elrs.pushFrame = function(x, y) return sensor:pushFrame(x, y) end
else
  elrs.popFrame = function() return crsf.popFrame() end
if not elrs.crossfirePush then elrs.crossfirePush = elrs.pushFrame end
  elrs.pushFrame = function(x, y) return crsf.pushFrame(x, y) end
end

-- Track changes to the MSP-provided whitelist
local function slotsFingerprint()
  local slots = rfsuite and rfsuite.session and rfsuite.session.telemetryConfig 
  if not slots then return "" end
  local acc = {}
  for i = 1, #slots do acc[#acc+1] = tostring(slots[i] or "") end
  return table.concat(acc, ",")
end

local _lastSlotsFp = nil

-- ==== Lazy sid accessor (avoids circular load; allows freeing & reload) ====
local function getSidList()
  local mod = rfsuite and rfsuite.tasks and rfsuite.tasks.sensors
  if not mod then return nil end
  return mod.sid or (mod.getSid and mod.getSid()) or nil
end

---------------------------------------------------------------------
-- Decoders (locals). All writes go through setTelemetryValue().
---------------------------------------------------------------------
local function decInt(data, pos, bytes, signed)
  local val = 0
  for i = 0, bytes - 1 do val = (val << 8) | data[pos + i] end
  if signed then
    local bits = bytes * 8
    if (val & (1 << (bits - 1))) ~= 0 then val = val - (1 << bits) end
  end
  return val, pos + bytes
end

local function decNil(_, pos)  return nil, pos end
local function decU8(d, p)     return decInt(d, p, 1, false) end
local function decS8(d, p)     return decInt(d, p, 1, true)  end
local function decU16(d, p)    return decInt(d, p, 2, false) end
local function decS16(d, p)    return decInt(d, p, 2, true)  end
local function decU24(d, p)    return decInt(d, p, 3, false) end
local function decS24(d, p)    return decInt(d, p, 3, true)  end
local function decU32(d, p)    return decInt(d, p, 4, false) end
local function decS32(d, p)    return decInt(d, p, 4, true)  end

local function decU12U12(d, p)
  local a = ((d[p] & 0x0F) << 8) | d[p + 1]
  local b = ((d[p] & 0xF0) << 4) | d[p + 2]
  return a, b, p + 3
end
local function decS12S12(d, p)
  local a, b, np = decU12U12(d, p)
  if a >= 0x800 then a = a - 0x1000 end
  if b >= 0x800 then b = b - 0x1000 end
  return a, b, np
end

-- composite decoders call setTelemetryValue (whitelist gate inside)
local setTelemetryValue -- forward-declare

local function decCellV(d, p)
  local v; v, p = decU8(d, p)
  return (v > 0 and v + 200 or 0), p
end

local function decCells(d, p)
  local cnt; cnt, p = decU8(d, p)
  setTelemetryValue(0x1020, 0, 0, cnt, UNIT_RAW, 0, "Cell Count", 0, 15)
  for i = 1, cnt do
    local v; v, p = decU8(d, p)
    v = (v > 0 and v + 200 or 0)
    local packed = (cnt << 24) | ((i - 1) << 16) | v
    setTelemetryValue(0x102F, 0, 0, packed, UNIT_CELLS, 2, "Cell Voltages", 0, 455)
  end
  return nil, p
end

local function decControl(d, p)
  local ptc, rol, yaw, col
  ptc, rol, p = decS12S12(d, p)
  yaw, col, p = decS12S12(d, p)
  setTelemetryValue(0x1031, 0, 0, ptc,     UNIT_DEGREE, 2, "Pitch Control", -4500, 4500)
  setTelemetryValue(0x1032, 0, 0, rol,     UNIT_DEGREE, 2, "Roll Control",  -4500, 4500)
  setTelemetryValue(0x1033, 0, 0, 3 * yaw, UNIT_DEGREE, 2, "Yaw Control",   -9000, 9000)
  setTelemetryValue(0x1034, 0, 0, col,     UNIT_DEGREE, 2, "Coll Control",  -4500, 4500)
  return nil, p
end

local function decAttitude(d, p)
  local ptc, rol, yaw
  ptc, p = decS16(d, p)
  rol, p = decS16(d, p)
  yaw, p = decS16(d, p)
  setTelemetryValue(0x1101, 0, 0, ptc, UNIT_DEGREE, 1, "Pitch Attitude", -1800, 3600)
  setTelemetryValue(0x1102, 0, 0, rol, UNIT_DEGREE, 1, "Roll Attitude",  -1800, 3600)
  setTelemetryValue(0x1103, 0, 0, yaw, UNIT_DEGREE, 1, "Yaw Attitude",   -1800, 3600)
  return nil, p
end

local function decAccel(d, p)
  local x, y, z
  x, p = decS16(d, p)
  y, p = decS16(d, p)
  z, p = decS16(d, p)
  setTelemetryValue(0x1111, 0, 0, x, UNIT_G, 2, "Accel X", -4000, 4000)
  setTelemetryValue(0x1112, 0, 0, y, UNIT_G, 2, "Accel Y", -4000, 4000)
  setTelemetryValue(0x1113, 0, 0, z, UNIT_G, 2, "Accel Z", -4000, 4000)
  return nil, p
end

local function decLatLong(d, p)
  local lat, lon
  lat, p = decS32(d, p)
  lon, p = decS32(d, p)
  lat = math.floor(lat * 0.001)
  lon = math.floor(lon * 0.001)
  setTelemetryValue(0x1125, 0, 0, lat, UNIT_DEGREE, 4, "GPS Latitude",  -10000000000, 10000000000)
  setTelemetryValue(0x112B, 0, 0, lon, UNIT_DEGREE, 4, "GPS Longitude", -10000000000, 10000000000)
  return nil, p
end

local function decAdjFunc(d, p)
  local fun, val
  fun, p = decU16(d, p)
  val, p = decS32(d, p)
  setTelemetryValue(0x1221, 0, 0, fun, UNIT_RAW, 0, "Adj. Source", 0, 255)
  setTelemetryValue(0x1222, 0, 0, val, UNIT_RAW, 0, "Adj. Value")
  return nil, p
end

-- Map of decoder names -> functions (for sid.lua string lookups)
local DECODERS = {
  decNil      = decNil,
  decU8       = decU8,
  decS8       = decS8,
  decU16      = decU16,
  decS16      = decS16,
  decU24      = decU24,
  decS24      = decS24,
  decU32      = decU32,
  decS32      = decS32,
  decCellV    = decCellV,
  decCells    = decCells,
  decControl  = decControl,
  decAttitude = decAttitude,
  decAccel    = decAccel,
  decLatLong  = decLatLong,
  decAdjFunc  = decAdjFunc,
}

---------------------------------------------------------------------
-- Build ELRS lookup keyed by sidElrs ONCE, then free sid.lua to save RAM
---------------------------------------------------------------------
local _elrsMapBuilt = false

local function ensureElrsMap()
  if _elrsMapBuilt then return end
  elrs.RFSensors = {}

  local sidList = getSidList()
  if not sidList then return end

  -- Build ELRS lookup keyed by *every* sidElrs value
  for _, s in pairs(sidList) do
    local sid = s.sidElrs
    if sid then
      local decFn = DECODERS[s.dec] or decNil
      if type(sid) == "table" then
        for i = 1, #sid do
          elrs.RFSensors[sid[i]] = {
            name = s.name,
            unit = s.unit,
            prec = s.prec,
            min  = s.min,
            max  = s.max,
            dec  = decFn,
            -- idx = i,        -- uncomment if any decoder wants to know which sub-SID it is
          }
        end
      else
        elrs.RFSensors[sid] = {
          name = s.name,
          unit = s.unit,
          prec = s.prec,
          min  = s.min,
          max  = s.max,
          dec  = decFn,
        }
      end
    end
  end

  -- Free the big table now; keep only the compact elrs.RFSensors
  if rfsuite and rfsuite.tasks and rfsuite.tasks.sensors then
    rfsuite.tasks.sensors.sid = nil
  end
  collectgarbage("collect")

  _elrsMapBuilt = true
end

---------------------------------------------------------------------
-- Whitelist of enabled sensors: setFblSensors([...id...]) public API
---------------------------------------------------------------------
local enabledSidElrs = {}

function elrs.setFblSensors(list)
  enabledSidElrs = {}

  -- We need sid to map rotorflight id -> sidElrs (load, then free)
  local sidList = getSidList()
  if sidList then
    for _, id in ipairs(list or {}) do
      local s = sidList[id]
      if s and s.sidElrs then
      if type(s.sidElrs) == "table" then
        for i=1,#s.sidElrs do enabledSidElrs[s.sidElrs[i]] = true end
      else
        enabledSidElrs[s.sidElrs] = true
      end
      end
    end
    -- free again after use
    if rfsuite and rfsuite.tasks and rfsuite.tasks.sensors then
      rfsuite.tasks.sensors.sid = nil
    end
    collectgarbage("collect")
  end
end


elrs.setFblSensors(rfsuite.session.telemetryConfig)

local function isEnabled(sidElrs)
  return enabledSidElrs[sidElrs] == true
end

---------------------------------------------------------------------
-- State & constants
---------------------------------------------------------------------
local sensors = { uid = {}, lastvalue = {}, lasttime = {} }

local constants = {
  CRSF_FRAME_CUSTOM_TELEM = 0x88,
  FRAME_COUNT_ID = 0xEE01,
  FRAME_SKIP_ID  = 0xEE02,
}

local META_UID = {}
META_UID[constants.FRAME_COUNT_ID] = true
META_UID[constants.FRAME_SKIP_ID]  = true

elrs.telemetryFrameId    = 0
elrs.telemetryFrameSkip  = 0
elrs.telemetryFrameCount = 0

local REFRESH_INTERVAL_MS = 2500 -- 2.5s

---------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------
local function telemetryActive()
  return rfsuite and rfsuite.session and rfsuite.session.telemetryState == true
end

local function nowMs()
  return math.floor(os.clock() * 1000)
end

local function resetSensors()
  sensors.uid, sensors.lastvalue, sensors.lasttime = {}, {}, {}
end

---------------------------------------------------------------------
-- Create/update helpers (writes gated by whitelist)
---------------------------------------------------------------------
local function createTelemetrySensor(uid, name, unit, dec, value, min, max)
  if not telemetryActive() then return nil end
  sensors.uid[uid] = model.createSensor({ type = SENSOR_TYPE_DIY })
  local s = sensors.uid[uid]
  s:name(name)
  s:appId(uid)
  s:module(1)
  s:minimum(min or -1000000000)
  s:maximum(max or 2147483647)
  if dec  then s:decimals(dec); s:protocolDecimals(dec) end
  if unit then s:unit(unit);    s:protocolUnit(unit)    end
  if value then s:value(value) end
  return s
end

local function getOrCreateSensor(uid, name, unit, dec, value, min, max)
  if not sensors.uid[uid] then
    sensors.uid[uid] = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = uid })
    if not sensors.uid[uid] then
      createTelemetrySensor(uid, name, unit, dec, value, min, max)
    end
  end
  return sensors.uid[uid]
end

-- SINGLE GATE: if not enabled, drop the write
setTelemetryValue = function(uid, subid, instance, value, unit, dec, name, min, max)
  if not telemetryActive() then return end
  -- allow meta sensors regardless of whitelist
  if not (META_UID[uid] or isEnabled(uid)) then return end

  local s = getOrCreateSensor(uid, name, unit, dec, value, min, max)
  if s then
    local last = sensors.lastvalue[uid]
    if last == nil or last ~= value then
      s:value(value)
      sensors.lastvalue[uid] = value
      sensors.lasttime[uid]  = nowMs()
    end
  end
end

local function refreshStaleSensors()
  local t = nowMs()
  for uid, s in pairs(sensors.uid) do
    local last, lt = sensors.lastvalue[uid], sensors.lasttime[uid]
    if last and lt and (t - lt) > REFRESH_INTERVAL_MS then
      s:value(last)
      sensors.lasttime[uid] = t
    end
  end
end

---------------------------------------------------------------------
-- Telemetry pump (uses elrs.RFSensors; ensure map exists first)
---------------------------------------------------------------------
function elrs.crossfirePop()
  ensureElrsMap()

  if (CRSF_PAUSE_TELEMETRY == true or rfsuite.session.mspBusy == true or not telemetryActive()) then
    if not telemetryActive() then resetSensors() end
    return false
  end

  local command, data = elrs.popFrame()
  if not (command and data) then return false end

  if command == constants.CRSF_FRAME_CUSTOM_TELEM then
    local ptr = 3
    local fid; fid, ptr = decU8(data, ptr)
    local delta = (fid - elrs.telemetryFrameId) & 0xFF
    if delta > 1 then elrs.telemetryFrameSkip = elrs.telemetryFrameSkip + 1 end
    elrs.telemetryFrameId = fid
    elrs.telemetryFrameCount = elrs.telemetryFrameCount + 1

    local len, tlvCount = #data, 0
    local MAX_TLVS_PER_FRAME = 40

    while ptr < len do
      if (len - ptr) < 2 then break end
      local sidElrs; sidElrs, ptr = decU16(data, ptr)
      local sensor = elrs.RFSensors[sidElrs]
      if not sensor then break end

      local prev = ptr
      local ok, val, np = pcall(sensor.dec, data, ptr)
      if not ok then break end
      ptr = np or prev
      if ptr <= prev then break end

      if val ~= nil then
        setTelemetryValue(sidElrs, 0, 0, val, sensor.unit, sensor.prec, sensor.name, sensor.min, sensor.max)
      end

      tlvCount = tlvCount + 1
      if tlvCount >= MAX_TLVS_PER_FRAME then break end
    end

    setTelemetryValue(constants.FRAME_COUNT_ID, 0, 0, elrs.telemetryFrameCount, UNIT_RAW, 0, "Frame Count", 0, 2147483647)
    setTelemetryValue(constants.FRAME_SKIP_ID,  0, 0, elrs.telemetryFrameSkip,  UNIT_RAW, 0, "Frame Skip",  0, 2147483647)
  end

  return true
end

function elrs.wakeup()

  -- we cannot do anything until connected
  if not rfsuite.session.isConnected then return end
    if rfsuite.tasks and rfsuite.tasks.onconnect and rfsuite.tasks.onconnect.active and rfsuite.tasks.onconnect.active() then
        return
    end 

  -- Rebuild whitelist if MSP changed the selection
  local fp = slotsFingerprint()
  if fp ~= _lastSlotsFp then
    _lastSlotsFp = fp
    elrs.setFblSensors(rfsuite.session.telemetryConfig or {})
    resetSensors() -- clears local caches so new ones get created on demand
  end

  if telemetryActive() and rfsuite.session.telemetrySensor then
    if not rfsuite.session.mspBusy then 
      local n = 0
      while elrs.crossfirePop() do
        n = n + 1
        if n >= 50 then break end
        if CRSF_PAUSE_TELEMETRY == true or rfsuite.session.mspBusy == true then break end
      end
    end  
    refreshStaleSensors()
  else
    resetSensors()
  end
end

function elrs.reset()
  resetSensors()
  -- if you want to rebuild map later:
  -- _elrsMapBuilt = false
end

return elrs

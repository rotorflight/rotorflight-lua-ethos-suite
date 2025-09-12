-- tasks/sensors/frsky.lua  (lazy sid load, compact maps, free sid; acts only on whitelisted S.Port sensors)

local arg = {...}
local config = arg[1]

local frsky = {}
frsky.name = "frsky"

local function telemetryActive()
  return rfsuite and rfsuite.session and rfsuite.session.telemetryState == true
end

-- Detect changes to MSP-provided whitelist
local function slotsFingerprint()
  local slots = rfsuite and rfsuite.session and rfsuite.session.telemetryConfig 
  if not slots then return "" end
  local acc = {}
  for i = 1, #slots do acc[#acc+1] = tostring(slots[i] or "") end
  return table.concat(acc, ",")
end

local _lastSlotsFp = nil

-- ================= Lazy sid accessor =================
local function getSidList()
  local mod = rfsuite and rfsuite.tasks and rfsuite.tasks.sensors
  if not mod then return nil end
  return mod.sid or (mod.getSid and mod.getSid()) or nil
end

-- Bounded drain controls
local MAX_FRAMES_PER_WAKEUP = 200
local MAX_TIME_BUDGET       = 0.1

-- runtime caches
frsky.createSensorCache = {}
frsky.renameSensorCache = {}
frsky.dropSensorCache   = {}
frsky.renamed = {}
frsky.dropped = {}

-- dynamic lists built from sid.lua + whitelist
local createSensorList = {}  -- [appId] = {name=..., unit=..., decimals=..., minimum=..., maximum=...}
local renameSensorList = {}  -- [appId] = { {name="New", onlyifname="Old"}, ... }
local dropSensorList   = {}  -- [appId] = true
local enabledAppIds    = {}  -- whitelist of expected appIds

----------------------------------------------------------------------
-- Public API: set Rotorflight IDs we expect (e.g., {0,1,5,10})
-- We map each to its sidSport appId, build tiny lists, then free sid.
----------------------------------------------------------------------
function frsky.setFblSensors(fblIds)
  enabledAppIds, createSensorList, renameSensorList, dropSensorList = {}, {}, {}, {}

  local sidList = getSidList()
  if not sidList then return end

  -- 1) Mark enabled S.Port appIds from Rotorflight ids
  for _, id in ipairs(fblIds or {}) do
    local s = sidList[id]
    if s and s.sidSport then
      enabledAppIds[s.sidSport] = true
    end
  end

  -- 2) Build tiny maps only for enabled appIds
  for _, s in pairs(sidList) do
    local appId = s.sidSport
    if appId and enabledAppIds[appId] then
      createSensorList[appId] = {
        name     = s.sportName or s.name,
        unit     = s.unit,
        decimals = (s.sportDecimals ~= nil) and s.sportDecimals or s.prec,
        minimum  = s.min,
        maximum  = s.max,
      }
      if s.sportDrop == true then
        dropSensorList[appId] = true
      end
      if s.sportRename then
        renameSensorList[appId] = (s.sportRename[1] and s.sportRename) or { s.sportRename }
      end
    end
  end

  -- 3) Free sid to reclaim memory
  if rfsuite and rfsuite.tasks and rfsuite.tasks.sensors then
    rfsuite.tasks.sensors.sid = nil
  end
  collectgarbage("collect")
end

-- Default stub (until caller provides the real profile list)
frsky.setFblSensors(rfsuite.session.telemetryConfig)

----------------------------------------------------------------------
-- Helpers: create, drop, rename (same flow; gated by tiny maps)
----------------------------------------------------------------------
local function createSensor(physId, primId, appId, frameValue)
  if rfsuite.session.apiVersion == nil then return "skip" end
  local v = createSensorList[appId]
  if not v then return "skip" end

  if frsky.createSensorCache[appId] == nil then
    frsky.createSensorCache[appId] = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = appId })
    if frsky.createSensorCache[appId] == nil then
      local s = model.createSensor()
      s:name(v.name)
      s:appId(appId)
      s:physId(physId)
      s:module(rfsuite.session.telemetrySensor:module())
      if v.minimum  ~= nil then s:minimum(v.minimum) else s:minimum(-1000000000) end
      if v.maximum  ~= nil then s:maximum(v.maximum) else s:maximum(2147483647) end
      if v.unit     ~= nil then s:unit(v.unit); s:protocolUnit(v.unit) end
      if v.decimals ~= nil then s:decimals(v.decimals); s:protocolDecimals(v.decimals) end
      frsky.createSensorCache[appId] = s
      return "created"
    end
  end
  return "noop"
end

local function dropSensor(physId, primId, appId, frameValue)
  if rfsuite.session.apiVersion == nil then return "skip" end
  if not dropSensorList[appId] then return "skip" end

  if frsky.dropSensorCache[appId] == nil then
    local src = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = appId })
    frsky.dropSensorCache[appId] = src or false
  end
  local src = frsky.dropSensorCache[appId]
  if src and src ~= false then
    if not frsky.dropped[appId] then
      src:drop()
      frsky.dropped[appId] = true
      return "dropped"
    end
    return "noop"
  end
  return "skip"
end

local function renameSensor(physId, primId, appId, frameValue)
  if rfsuite.session.apiVersion == nil then return "skip" end
  local rules = renameSensorList[appId]
  if not rules then return "skip" end
  if frsky.renamed[appId] then return "noop" end

  if frsky.renameSensorCache[appId] == nil then
    local src = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = appId })
    frsky.renameSensorCache[appId] = src or false
  end
  local src = frsky.renameSensorCache[appId]
  if src and src ~= false then
    local cur = src:name()
    for _, rule in ipairs(rules) do
      if cur == rule.onlyifname then
        src:name(rule.name)
        frsky.renamed[appId] = true
        return "renamed"
      end
    end
    return "noop"
  end
  return "skip"
end

----------------------------------------------------------------------
-- Frame drain (bounded, discovery-aware). Only acts on known appIds.
----------------------------------------------------------------------
local function telemetryPop()
  if not rfsuite.tasks.msp.sensorTlm then return false end

  local frame = rfsuite.tasks.msp.sensorTlm:popFrame()
  if frame == nil then return false end
  if not frame.physId or not frame.primId then return false end

  local physId, primId, appId, value = frame:physId(), frame:primId(), frame:appId(), frame:value()

  -- Skip entirely if this appId is not in any of our lists (saves work)
  if not (createSensorList[appId] or renameSensorList[appId] or dropSensorList[appId]) then
    return true
  end

  local cs = createSensor(physId, primId, appId, value)
  if cs ~= "skip" then return true end

  local ds = dropSensor(physId, primId, appId, value)
  if ds ~= "skip" then return true end

  renameSensor(physId, primId, appId, value)
  return true
end

function frsky.wakeup()

  if not rfsuite.session.telemetryState or not rfsuite.session.telemetrySensor then
    frsky.reset()
    return
  end
  if not (rfsuite.tasks and rfsuite.tasks.telemetry and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue) then
    return
  end

  -- If MSP changed the selected sensors, rebuild tiny maps and reset caches
  local fp = slotsFingerprint()
  if fp ~= _lastSlotsFp then
    _lastSlotsFp = fp
    frsky.setFblSensors(rfsuite.session.telemetryConfig or {})
    frsky.reset() -- clears create/rename/drop caches so next frames re-apply rules
  end  

  if rfsuite.app and rfsuite.app.guiIsRunning == false and rfsuite.tasks.msp.mspQueue:isProcessed() then


  if telemetryActive() and rfsuite.session.telemetrySensor then
    local n = 0
    while telemetryPop() do
      n = n + 1
      if n >= 50 then break end
      if rfsuite.app.triggers.mspBusy == true then break end
    end
  end

  end
end

function frsky.reset()
  frsky.createSensorCache = {}
  frsky.renameSensorCache = {}
  frsky.dropSensorCache   = {}
  frsky.renamed = {}
  frsky.dropped = {}
end

return frsky

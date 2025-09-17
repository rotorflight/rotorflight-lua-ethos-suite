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
frsky.renamed = {}

-- dynamic lists built from sid.lua + whitelist
local createSensorList = {}  -- [appId] = {name=..., unit=..., decimals=..., minimum=..., maximum=...}
local renameSensorList = {}  -- [appId] = { {name="New", onlyifname="Old"}, ... }
local enabledAppIds    = {}  -- whitelist of expected appIds

-- Are there any actions left to perform?
local function hasPendingActions()
  return next(createSensorList) or next(renameSensorList)
end

----------------------------------------------------------------------
-- Public API: set Rotorflight IDs we expect (e.g., {0,1,5,10})
-- We map each to its sidSport appId, build tiny lists, then free sid.
----------------------------------------------------------------------
function frsky.setFblSensors(fblIds)
  enabledAppIds, createSensorList, renameSensorList = {}, {}, {}

  local sidList = getSidList()
  if not sidList then return end

  -- 1) Mark enabled S.Port appIds from Rotorflight ids
  for _, id in ipairs(fblIds or {}) do
    local s = sidList[id]
    if s and s.sidSport then
      local sport = s.sidSport
      if type(sport) == "table" then
        enabledAppIds[sport[1]] = true     -- trigger appId when array
      else
        enabledAppIds[sport] = true        -- scalar case
      end
    end
  end

  -- 2) Build tiny maps only for enabled appIds
  for _, s in pairs(sidList) do
    local sport = s.sidSport
    if sport then
      if type(sport) ~= "table" then sport = { sport } end
      local names = s.sportName or s.name
      if type(names) ~= "table" then names = { names } end

      -- first element is the trigger appId we expect frames for
      local triggerAppId = sport[1]
      if enabledAppIds[triggerAppId] then
        -- record the primary (trigger) create rule, plus any “extras” to create
        createSensorList[triggerAppId] = {
          name     = names[1] or s.name,
          unit     = s.unit,
          decimals = (s.sportDecimals ~= nil) and s.sportDecimals or s.prec,
          minimum  = s.min,
          maximum  = s.max,
          extras   = (function()
            local acc = {}
            for i = 2, #sport do
              acc[#acc+1] = {
                appId    = sport[i],                 -- DIY appId to create
                name     = names[i] or (s.name .. " #" .. i),
                unit     = s.unit,                   -- inherit unless you later add per-item arrays
                decimals = (s.sportDecimals ~= nil) and s.sportDecimals or s.prec,
                minimum  = s.min,
                maximum  = s.max,
              }
            end
            return (#acc > 0) and acc or nil
          end)(),
        }

        if s.sportRename then
          renameSensorList[triggerAppId] = (s.sportRename[1] and s.sportRename) or { s.sportRename }
        end
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
-- Helpers: create, rename (same flow; gated by tiny maps)
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

      if v.extras then
        for _, e in ipairs(v.extras) do
          -- only create if it doesn't exist yet
          local existing = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = e.appId })
          if not existing then
            local sExtra = model.createSensor({ type = SENSOR_TYPE_DIY })
            sExtra:name(e.name)
            sExtra:appId(e.appId)
            sExtra:physId(physId)  
            sExtra:module(rfsuite.session.telemetrySensor:module())
            if e.minimum  ~= nil then sExtra:minimum(e.minimum) else sExtra:minimum(-1000000000) end
            if e.maximum  ~= nil then sExtra:maximum(e.maximum) else sExtra:maximum(2147483647) end
            if e.unit     ~= nil then sExtra:unit(e.unit);           sExtra:protocolUnit(e.unit) end
            if e.decimals ~= nil then sExtra:decimals(e.decimals);   sExtra:protocolDecimals(e.decimals) end
          end
        end
      end

      createSensorList[appId] = nil   -- rule done: stop watching this appId
      return "created"
    end
  end
  return "noop"
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
        renameSensorList[appId] = nil -- rule done: stop watching this appId
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
  if not (createSensorList[appId] or renameSensorList[appId]) then
    return true
  end

  -- Try to create; only bail out early if we actually created something.
  local cs = createSensor(physId, primId, appId, value)
  if cs == "created" then
    return true
  end

  -- Allow rename even if createSensor() returned "noop" or "skip"
  if renameSensorList[appId] then
    renameSensor(physId, primId, appId, value)
  end

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
    frsky.reset() -- clears create/rename caches so next frames re-apply rules
  end  

  if rfsuite.app and rfsuite.app.guiIsRunning == false and rfsuite.tasks.msp.mspQueue:isProcessed() then


    -- Only drain frames while there is work to do (create/rename).
    if telemetryActive() and rfsuite.session.telemetrySensor and hasPendingActions() then
      local n = 0
      while telemetryPop() do
        n = n + 1
        if n >= 50 then break end
        if rfsuite.session.mspBusy == true then break end
        -- If we ran out of actions mid-loop, we can stop early.
        if not hasPendingActions() then break end
      end
    end

  end
end

function frsky.reset()
  frsky.createSensorCache = {}
  frsky.renameSensorCache = {}
  frsky.renamed = {}
end

return frsky

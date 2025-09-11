-- tasks/sensors/frsky.lua  (refactored: uses sid.lua passed in, polls only whitelisted, supports optional sid.lua sport* hints)

local arg = {...}
local config   = arg[1]
local sidList = rfsuite.tasks.sensors.sid  

local frsky = {}
frsky.name = "frsky"

-- Bounded drain controls
local MAX_FRAMES_PER_WAKEUP = 32
local MAX_TIME_BUDGET       = 0.004

-- runtime caches
frsky.createSensorCache = {}
frsky.renameSensorCache = {}
frsky.dropSensorCache   = {}
frsky.renamed = {}
frsky.dropped = {}

-- dynamic lists built from sidList + whitelist
local createSensorList = {}  -- [appId] = {name=..., unit=..., decimals=..., minimum=..., maximum=...}
local renameSensorList = {}  -- [appId] = {name="New", onlyifname="Old"}  or array of rules
local dropSensorList   = {}  -- [appId] = true

-- whitelist: enabled S.Port appIds
local enabledAppIds = {}

----------------------------------------------------------------------
-- Public API: set the Rotorflight ID list we expect (e.g. {0,1,5,10})
-- We map each to its sidSport appId and rebuild our lists.
----------------------------------------------------------------------
function frsky.setFblSensors(fblIds)
  enabledAppIds = {}

  -- collect enabled appIds from sidList
  for _, id in ipairs(fblIds or {}) do
    local s = sidList[id]
    if s and s.sidSport then
      enabledAppIds[s.sidSport] = true
    end
  end

  -- (Re)build lists from sidList + enabledAppIds
  createSensorList, renameSensorList, dropSensorList = {}, {}, {}

  for _, s in pairs(sidList) do
    local appId = s.sidSport
    if appId and enabledAppIds[appId] then
      -- CREATE entry
      local name = s.sportName or s.name
      local decimals = s.sportDecimals
      if decimals == nil then decimals = s.prec end

      createSensorList[appId] = {
        name     = name,
        unit     = s.unit,
        decimals = decimals,
        minimum  = s.min,
        maximum  = s.max,
      }

      -- optional DROP entry
      if s.sportDrop == true then
        dropSensorList[appId] = true
      end

      -- optional RENAME rule(s)
      if s.sportRename then
        if s.sportRename[1] ~= nil then
          -- array of rules
          renameSensorList[appId] = s.sportRename
        else
          -- single rule table
          renameSensorList[appId] = { s.sportRename }
        end
      end
    end
  end

  -- Fallback: if you still want a few hard-coded renames when no hints exist in sid.lua,
  -- you can keep a tiny compatibility block here. Example:
  local function addFallbackRename(appId, newName, onlyIf)
    if not enabledAppIds[appId] then return end
    if renameSensorList[appId] == nil then renameSensorList[appId] = {} end
    table.insert(renameSensorList[appId], { name = newName, onlyifname = onlyIf })
  end

end

-- default (stub) until caller sets the real list
local defaultFblSensors = {
  3,   -- Voltage
  4,   -- Current
  5,   -- Consumption
  6,   -- Fuel / Charge Level
  15,  -- Throttle %
  23,  -- ESC Temp
  43,  -- BEC Voltage
  52,  -- MCU Temp
  60,  -- Headspeed
  90,  -- Arm Flags
  91,  -- Arm Disable Flags
  93,  -- Governor
  95,  -- PID Profile
  96,  -- Rate Profile
  99,  -- Adjustment Function
}

elrs.setFblSensors(defaultFblSensors)

----------------------------------------------------------------------
-- Helpers: create, drop, rename (same flow as before; gated by lists)
----------------------------------------------------------------------

-- createSensor: return a status ("created"|"noop"|"skip")
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
      -- bounds (if provided; else use broad defaults)
      if v.minimum  ~= nil then s:minimum(v.minimum) else s:minimum(-1000000000) end
      if v.maximum  ~= nil then s:maximum(v.maximum) else s:maximum(2147483647) end
      if v.unit     ~= nil then s:unit(v.unit); s:protocolUnit(v.unit) end
      if v.decimals ~= nil then s:decimals(v.decimals); s:protocolDecimals(v.decimals) end
      frsky.createSensorCache[appId] = s
      return "created"
    end
  end

  return "noop"  -- already present
end

-- dropSensor: return status ("dropped"|"noop"|"skip")
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

-- renameSensor: return status ("renamed"|"noop"|"skip")
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
    return true  -- frame consumed, nothing to do
  end

  -- 1) If this appId belongs to create list and we created/found it, we can skip rename/drop
  local cs = createSensor(physId, primId, appId, value)
  if cs ~= "skip" then return true end

  -- 2) If you’re actively dropping legacy sensors, try that next
  local ds = dropSensor(physId, primId, appId, value)
  if ds ~= "skip" then return true end

  -- 3) Finally, try a conditional rename
  renameSensor(physId, primId, appId, value)
  return true
end

function frsky.wakeup()
  -- Bail early if telemetry is unavailable
  if not rfsuite.session.telemetryState or not rfsuite.session.telemetrySensor then
    frsky.reset()
    return
  end

  -- Safety: required task objects present?
  if not (rfsuite.tasks and rfsuite.tasks.telemetry and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue) then
    return
  end

  if rfsuite.app and rfsuite.app.guiIsRunning == false and rfsuite.tasks.msp.mspQueue:isProcessed() then
    local discoverActive = (system and system.isSensorDiscoverActive and system.isSensorDiscoverActive() == true)

    if discoverActive then
      -- ETHOS discovery: unbounded drain for faster sensor discovery
      rfsuite.utils.log("FRSKY: Discovery active, draining all frames", "info")
      while telemetryPop() do end
    else
      -- Legacy: bounded, low CPU
      local start = os.clock()
      local count = 0
      while count < MAX_FRAMES_PER_WAKEUP and (os.clock() - start) <= MAX_TIME_BUDGET do
        if not telemetryPop() then break end
        count = count + 1
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

-- tasks/sensors/frsky.lua  (lazy sid load, compact maps, free sid; acts only on whitelisted S.Port sensors)

local arg = {...}
local config = arg[1]

local frsky = {}
frsky.name = "frsky"

-- init caches
frsky.createSensorCache = frsky.createSensorCache or {}
frsky.renameSensorCache = frsky.renameSensorCache or {}
frsky.renamed = frsky.renamed or {}


-- rename table
local renameSensorList = {
    -- RPM sensors
    [0x0500] = { name = "Headspeed", onlyifname = "RPM" },
    [0x0501] = { name = "Tailspeed", onlyifname = "RPM" },
    [0x0508] = { name = "ESC1 RPM", onlyifname = "RPM" },
    [0x050A] = { name = "ESC2 RPM", onlyifname = "RPM" },

    -- Voltage sensors
    [0x0210] = { name = "Voltage", onlyifname = "VFAS" },
    [0x0211] = { name = "ESC Voltage", onlyifname = "VFAS" },
    [0x0218] = { name = "ESC1 Voltage", onlyifname = "VFAS" },
    [0x0219] = { name = "BEC1 Voltage", onlyifname = "VFAS" },
    [0x021A] = { name = "ESC2 Voltage", onlyifname = "VFAS" },
    [0x0900] = { name = "MCU Voltage", onlyifname = "ADC3" },
    [0x0901] = { name = "BEC Voltage", onlyifname = "ADC3" },
    [0x0902] = { name = "BUS Voltage", onlyifname = "ADC3" },
    [0x0910] = { name = "Cell Voltage", onlyifname = "ADC4" },

    -- Current sensors
    [0x0208] = { name = "ESC1 Current", onlyifname = "Current" },
    [0x020A] = { name = "ESC2 Current", onlyifname = "Current" },
    [0x0201] = { name = "ESC Current", onlyifname = "Current" },
    [0x0222] = { name = "BEC Current", onlyifname = "Current" },
    [0x0229] = { name = "BEC1 Current", onlyifname = "Current" },

    -- Temperature sensors
    [0x0B70] = { name = "ESC Temp", onlyifname = "ESC temp" },
    [0x0418] = { name = "ESC1 Temp", onlyifname = "Temp2" },
    [0x0419] = { name = "BEC1 Temp", onlyifname = "Temp2" },
    [0x041A] = { name = "ESC2 Temp", onlyifname = "Temp2" },
    [0x0400] = { name = "MCU Temp", onlyifname = "Temp1" },
    [0x0401] = { name = "ESC Temp", onlyifname = "Temp1" },
    [0x0402] = { name = "BEC Temp", onlyifname = "Temp1" },

    -- Misc sensors
    [0x0600] = { name = "Charge Level", onlyifname = "Fuel" },
    [0x0840] = { name = "GPS Heading", onlyifname = "GPS course" },
    [0x5210] = { name = "Y.angle", onlyifname = "Heading" },
}


--[[
    renameSensor - Renames a sensor based on provided parameters if certain conditions are met.

    Parameters:
    physId (number) - The physical ID of the sensor.
    primId (number) - The primary ID of the sensor.
    appId (number) - The application ID of the sensor.
    frameValue (number) - The frame value of the sensor.

    Description:
    This function checks if the API version is available and if the sensor with the given appId exists in the renameSensorList.
    If the sensor exists and is not already cached, it retrieves the sensor source and renames it if its current name matches the specified condition.
]]
-- Renames a sensor to its desired name when found. If already correct, mark done.
local function renameSensor(physId, primId, appId, frameValue)
    if rfsuite.session.apiVersion == nil then return "skip" end
    local v = renameSensorList[appId]
    if not v then return "skip" end
    if frsky.renamed[appId] then return "noop" end

    if frsky.renameSensorCache[appId] == nil then
        local src = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = appId })
        frsky.renameSensorCache[appId] = src or false
    end
    local src = frsky.renameSensorCache[appId]
    if not src or src == false then
        return "skip" -- doesn’t exist yet; try again next cycle
    end

    local current = src:name()
    if current == v.name then
        frsky.renamed[appId] = true
        return "done"
    end

    -- If onlyifname is set, prefer renaming when it matches vendor default;
    -- otherwise, still rename if it's simply not the desired name.
    if (v.onlyifname and current == v.onlyifname) or (current ~= v.name) then
        src:name(v.name)
        frsky.renamed[appId] = true
        return "renamed"
    end

    return "noop"
end

-- Rename maintenance scheduling (every 30 seconds), runs at end of wakeup()
local RENAME_INTERVAL_MS = 30000
frsky._nextRenameAt = frsky._nextRenameAt or 0

local function nowMs()
    if system and system.getTimeCounter then return system.getTimeCounter() end
    return math.floor((os.clock() or 0) * 1000)
end

-- Run through all known rename rules on a short budget.
local function runRenameMaintenance()
    if not renameSensorList then return end
    local t = nowMs()
    if t < (frsky._nextRenameAt or 0) then return end
    frsky._nextRenameAt = t + RENAME_INTERVAL_MS

    local start = t
    for appId, _ in pairs(renameSensorList) do
        if not (frsky.renamed and frsky.renamed[appId]) then
            pcall(function() renameSensor(nil, nil, appId, nil) end)
            -- small time budget; stop if we’ve spent ~5ms
            if nowMs() - start > 5 then break end
        end
    end
end

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
local enabledAppIds    = {}  -- whitelist of expected appIds

-- Are there any actions left to perform?
local function hasPendingActions()
  return next(createSensorList) 
end

----------------------------------------------------------------------
-- Public API: set Rotorflight IDs we expect (e.g., {0,1,5,10})
-- We map each to its sidSport appId, build tiny lists, then free sid.
----------------------------------------------------------------------
function frsky.setFblSensors(fblIds)
  enabledAppIds, createSensorList = {}, {}

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
-- Helpers: create (same flow; gated by tiny maps)
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
  if not (createSensorList[appId]) then
    return true
  end

  local cs = createSensor(physId, primId, appId, value)
  if cs ~= "skip" then return true end

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
    frsky.reset() -- clears create caches so next frames re-apply rules
  end  

  if rfsuite.app and rfsuite.app.guiIsRunning == false and rfsuite.tasks.msp.mspQueue:isProcessed() then


    -- Only drain frames while there is work to do (create).
    if telemetryActive() and rfsuite.session.telemetrySensor and hasPendingActions() then
      local n = 0
      while telemetryPop() do
        n = n + 1
        if n >= 50 then break end
        if rfsuite.app.triggers.mspBusy == true then break end
        -- If we ran out of actions mid-loop, we can stop early.
        if not hasPendingActions() then break end
      end
    end

  end


  -- Rename sensors (if needed)
  -- we run this every 30 seconds 
  runRenameMaintenance()

end

function frsky.reset()
  frsky.createSensorCache = {}
  frsky.renameSensorCache = {}
  frsky.renamed = {}
  frsky._nextRenameAt = 0
end

return frsky

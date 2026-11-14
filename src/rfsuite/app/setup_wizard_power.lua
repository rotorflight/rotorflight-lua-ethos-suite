-- Setup Wizard helper for the power screens of the ESC telemetry step: the voltage and the
-- current source, the battery (the cell count of the active profile and the six capacities),
-- and SmartFuel. These are the settings the EdgeTX suite's helicopter wizard shows on its power
-- cards, and the Ethos Setup > Power pages save.
--
-- Battery and SmartFuel settings apply live, without a restart. They are written as they are
-- set, and every change is kept for Discard under one key, so Discard restores what was there.
-- The active battery profile is read and shown, never changed here.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local batteryConfig = requireModule("lib/msp_battery_config.lua")
local batteryProfile = requireModule("lib/msp_battery_profile.lua")
local smartfuelConfig = requireModule("lib/msp_smartfuel_config.lua")

local P = {}

P.SOURCE_NONE = 0
P.SOURCE_ADC = 1
P.SOURCE_ESC = 2
P.SOURCE_FBUS = 3
P.CAPACITY_MAX = 40000
P.CAPACITY_SLOTS = 6
P.CELL_MAX = 24
-- SmartFuel modes that need a voltage: VOLTAGE (1) and COMBINED (3).
local VOLTAGE_MODES = {[1] = true, [3] = true}
local CHANGE_KEY = "power_settings"

local function copy(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

local function clamp(value, min, max)
  value = math.floor((tonumber(value) or 0) + 0.5)
  if value < min then return min end
  if value > max then return max end
  return value
end

local function toChoices(list)
  local out = {}
  for i, c in ipairs(list) do out[i] = {text = c[1], value = c[2]} end
  return out
end

-- Drop-down values as {text, value} for the wizard's choice rows.
P.SOURCE_CHOICES = toChoices(batteryConfig.SOURCE_CHOICES)
P.MODE_CHOICES = toChoices(smartfuelConfig.MODE_CHOICES)

function P.needsVoltage(mode)
  return VOLTAGE_MODES[mode] == true
end

function P.new(wiz)
  local self = {loaded = false, battery = nil, profile = nil, smartfuel = nil}

  -- Reads the battery, the active profile and SmartFuel. SmartFuel may be missing on older
  -- firmware; the battery is needed for the screens and a missing one is shown as such.
  function self.load(onDone)
    wiz.fetch({
      battery = function(ok, err) return batteryConfig.buildReadMessage(ok, err) end,
      profile = function(ok, err) return batteryProfile.buildReadMessage(ok, err) end,
      smartfuel = function(ok, err) return smartfuelConfig.buildReadMessage(ok, err) end,
    }, function(results)
      self.battery = results.battery
      local p = results.profile and tonumber(results.profile.batteryProfile)
      if p and p >= 0 and p <= 5 and p % 1 == 0 then self.profile = p else self.profile = nil end
      self.smartfuel = results.smartfuel
      self.loaded = true
      if onDone then onDone() end
    end)
  end

  local function publishSaved()
    bus.publish("battery.config.saved")
  end

  local function writeBattery()
    wiz.send(batteryConfig.buildWriteMessage(copy(self.battery), publishSaved))
  end

  local function writeSmartFuel()
    wiz.send(smartfuelConfig.buildWriteMessage(copy(self.smartfuel)))
  end

  local function snapshot()
    return {
      battery = self.battery and copy(self.battery) or nil,
      smartfuel = self.smartfuel and copy(self.smartfuel) or nil,
    }
  end

  local function restore(o)
    if o.battery then
      self.battery = copy(o.battery)
      writeBattery()
    end
    if o.smartfuel then
      self.smartfuel = copy(o.smartfuel)
      writeSmartFuel()
    end
    wiz.rebuild()
  end

  -- Sources ----------------------------------------------------------------------------

  function self.source(key)
    return self.battery and self.battery[key] or P.SOURCE_NONE
  end

  function self.setSource(key, value)
    if not self.battery or self.battery[key] == value then return end
    wiz.change(CHANGE_KEY, snapshot(), restore)
    self.battery[key] = value
    writeBattery()
  end

  -- Battery ----------------------------------------------------------------------------

  -- The active profile (0 to 5), or nil when the flight controller does not say.
  function self.activeProfile()
    return self.profile
  end

  -- The cell count the active profile uses: its own field on firmware that has one per profile.
  function self.cellKey()
    if self.battery and self.battery.hasProfileCells and self.profile ~= nil then
      return "batteryCellCount_" .. self.profile
    end
    return "batteryCellCount"
  end

  function self.cellCount()
    return self.battery and self.battery[self.cellKey()] or 0
  end

  function self.setCellCount(value)
    if not self.battery then return end
    value = clamp(value, 0, P.CELL_MAX)
    local key = self.cellKey()
    if self.battery[key] == value then return end
    wiz.change(CHANGE_KEY, snapshot(), restore)
    self.battery[key] = value
    -- The legacy field mirrors the active profile, as the Setup > Power > Battery page saves it.
    if key ~= "batteryCellCount" then self.battery.batteryCellCount = value end
    writeBattery()
  end

  function self.capacity(index)
    return self.battery and self.battery["batteryCapacity_" .. index] or 0
  end

  function self.setCapacity(index, value)
    if not self.battery then return end
    value = clamp(value, 0, P.CAPACITY_MAX)
    local key = "batteryCapacity_" .. index
    if self.battery[key] == value then return end
    wiz.change(CHANGE_KEY, snapshot(), restore)
    self.battery[key] = value
    if index == self.profile then self.battery.batteryCapacity = value end
    writeBattery()
  end

  -- SmartFuel --------------------------------------------------------------------------

  function self.hasSmartFuel()
    return self.smartfuel ~= nil
  end

  function self.mode()
    return self.smartfuel and self.smartfuel.smartfuel_mode or 0
  end

  function self.setMode(value)
    if not self.smartfuel or self.smartfuel.smartfuel_mode == value then return end
    wiz.change(CHANGE_KEY, snapshot(), restore)
    self.smartfuel.smartfuel_mode = value
    writeSmartFuel()
  end

  -- A voltage source is needed by the SmartFuel mode, and none is set.
  function self.voltageMissing()
    return P.needsVoltage(self.mode()) and self.source("voltageMeterSource") == P.SOURCE_NONE
  end

  return self
end

return P

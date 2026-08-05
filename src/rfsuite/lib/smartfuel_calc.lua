-- Stateful local battery-fuel estimator: sigmoid discharge curve + slew-rate
-- limiting + monotonic clamp, matching the shape of
-- rotorflight-lua-ethos-suite's tasks/scheduler/sensors/lib/smartfuellocal.lua.
--
-- Used only as a fallback when the FC's own SMARTFUEL_CONFIG mode is 0 (the
-- FC isn't computing/broadcasting fuel itself) -- see tasks/session.lua,
-- which mirrors the FC's own value directly whenever mode > 0.
--
-- Deliberately simplified relative to the original:
--   - No sag compensation (needs live RC stick input; this rebuild doesn't
--     read RC channels yet). Voltage sag under load will show as a
--     slightly lower estimate rather than being compensated out.
--   - No flight-mode-based mid-session battery-swap detection (this rebuild
--     doesn't track flight mode here). It does still wait for a stable
--     voltage window before seeding the initial estimate, gates the charge
--     slew while disarmed, and resets on a disarmed voltage jump, matching
--     the original local-mode behaviours that protect usable-capacity math.
--   - Always blends in a consumption sensor when present (matching the
--     original's COMBINED mode); pure voltage-only otherwise. No separate
--     user-selectable VOLTAGE/CURRENT/COMBINED preference.
--
-- Each instance owns its own state (create with SmartFuel.new()); nothing
-- here is a module-level global.

local math_min = math.min
local math_max = math.max
local math_exp = math.exp
local os_clock = os.clock

local smartfuel_reserve = assert(loadfile("lib/smartfuel_reserve.lua"))()

local SmartFuel = {}
SmartFuel.__index = SmartFuel

local DEFAULT_VOLTAGE_FALL_PER_SECOND = 0.01 -- V/s
local DEFAULT_CHARGE_DROP_PER_SECOND = 0.005 -- fraction/s
local STABILIZE_DELAY_SECONDS = 1.5
local STABLE_WINDOW_VOLTS = 0.15
local MAX_VOLTAGE_SAMPLES = 5

function SmartFuel.new()
  return setmetatable({
    chargeLevel = 0.0,
    initialChargeLevel = 0.0,
    lastCellVoltage = 0.0,
    initialConsumption = nil,
    lastTimestamp = nil,
    wasEverArmed = false,
    lastPackVoltage = nil,
    voltageStabilised = false,
    stabilizeNotBefore = nil,
    voltageSamples = {},
    voltageSampleCount = 0,
    voltageSampleIndex = 0,
    configCellCount = nil,
    configPackCapacity = nil,
    configMinV = nil,
    configFullV = nil,
    configWarningPercent = nil,
  }, SmartFuel)
end

function SmartFuel:reset()
  self.chargeLevel = 0.0
  self.initialChargeLevel = 0.0
  self.lastCellVoltage = 0.0
  self.initialConsumption = nil
  self.lastTimestamp = nil
  self.wasEverArmed = false
  self.lastPackVoltage = nil
  self.voltageStabilised = false
  self.stabilizeNotBefore = nil
  for i = 1, MAX_VOLTAGE_SAMPLES do
    self.voltageSamples[i] = nil
  end
  self.voltageSampleCount = 0
  self.voltageSampleIndex = 0
  self.configCellCount = nil
  self.configPackCapacity = nil
  self.configMinV = nil
  self.configFullV = nil
  self.configWarningPercent = nil
end

-- Only permits the value to fall at maxDrop per call; rises are instant.
local function slewDownLimit(current, target, maxDrop)
  if target < current then
    return math_max(target, current - maxDrop)
  end
  return target
end

-- Sigmoid mapping cellVoltage -> 0.0-1.0 charge fraction, scaled into a
-- fixed 3.0-4.2V reference range regardless of the pack's actual min/full
-- voltages (matches the firmware's own curve shape).
local function chargeLevelFromVoltage(cellVoltage, minV, fullV)
  if cellVoltage >= fullV then return 1.0 end
  if cellVoltage <= minV then return 0.0 end
  local scaledV = 3.0 + (cellVoltage - minV) / (fullV - minV) * 1.2
  scaledV = math_max(3.0, math_min(4.2, scaledV))
  return math_max(0.0, math_min(1.0, 1.0 / (1.0 + math_exp(-12.0 * (scaledV - 3.7)))))
end

local function resetVoltageTracking(self)
  for i = 1, MAX_VOLTAGE_SAMPLES do
    self.voltageSamples[i] = nil
  end
  self.voltageSampleCount = 0
  self.voltageSampleIndex = 0
  self.voltageStabilised = false
end

local function resetFuelState(self, now)
  self.chargeLevel = 0.0
  self.initialChargeLevel = 0.0
  self.lastCellVoltage = 0.0
  self.initialConsumption = nil
  self.lastTimestamp = nil
  self.wasEverArmed = false
  self.lastPackVoltage = nil
  self.stabilizeNotBefore = now and (now + STABILIZE_DELAY_SECONDS) or nil
  resetVoltageTracking(self)
end

local function isVoltageStable(self)
  if self.voltageSampleCount < MAX_VOLTAGE_SAMPLES then return false end
  local samples = self.voltageSamples
  local vmin = samples[1]
  local vmax = vmin
  for i = 2, MAX_VOLTAGE_SAMPLES do
    local v = samples[i]
    if v < vmin then vmin = v end
    if v > vmax then vmax = v end
  end
  return (vmax - vmin) <= STABLE_WINDOW_VOLTS
end

local function addVoltageSample(self, voltage)
  local nextIndex = self.voltageSampleIndex + 1
  if nextIndex > MAX_VOLTAGE_SAMPLES then nextIndex = 1 end
  self.voltageSampleIndex = nextIndex
  self.voltageSamples[nextIndex] = voltage
  if self.voltageSampleCount < MAX_VOLTAGE_SAMPLES then
    self.voltageSampleCount = self.voltageSampleCount + 1
  end
end

local function configChanged(self, cellCount, packCapacity, minV, fullV, warningPercent)
  return self.configCellCount ~= cellCount
    or self.configPackCapacity ~= packCapacity
    or self.configMinV ~= minV
    or self.configFullV ~= fullV
    or self.configWarningPercent ~= warningPercent
end

local function rememberConfig(self, cellCount, packCapacity, minV, fullV, warningPercent)
  self.configCellCount = cellCount
  self.configPackCapacity = packCapacity
  self.configMinV = minV
  self.configFullV = fullV
  self.configWarningPercent = warningPercent
end

-- inputs: {
--   voltage, consumption,          -- live telemetry (consumption optional)
--   cellCount, minV, fullV, packCapacity, warningPercent, -- from BATTERY_CONFIG
--   voltageFallPerSecond, chargeDropPerSecond,            -- from SMARTFUEL_CONFIG
-- }
-- Returns a 0-100 percent, or nil if there isn't enough information yet.
function SmartFuel:update(inputs)
  local voltage = inputs.voltage
  local cellCount = inputs.cellCount
  local packCapacity = inputs.packCapacity
  local minV = inputs.minV
  local fullV = inputs.fullV
  local warningPercent = inputs.warningPercent

  if not voltage or voltage < 2 or not cellCount or cellCount == 0
    or not packCapacity or packCapacity < 10
    or not minV or not fullV or fullV <= minV then
    resetVoltageTracking(self)
    self.stabilizeNotBefore = nil
    return nil
  end

  local now = os_clock()
  if configChanged(self, cellCount, packCapacity, minV, fullV, warningPercent) then
    rememberConfig(self, cellCount, packCapacity, minV, fullV, warningPercent)
    resetFuelState(self, now)
  end

  if self.voltageStabilised and inputs.isArmed == false and self.lastPackVoltage
    and voltage > self.lastPackVoltage + STABLE_WINDOW_VOLTS then
    resetFuelState(self, now)
    return nil
  end

  if self.stabilizeNotBefore and now < self.stabilizeNotBefore then
    self.lastPackVoltage = voltage
    return nil
  end

  addVoltageSample(self, voltage)
  if not self.voltageStabilised then
    if not isVoltageStable(self) then
      self.lastPackVoltage = voltage
      return nil
    end
    self.voltageStabilised = true
  end

  local dt = (self.lastTimestamp and now > self.lastTimestamp) and (now - self.lastTimestamp) or 0

  local cellVoltage = voltage / cellCount
  if self.lastCellVoltage > 0 then
    cellVoltage = slewDownLimit(
      self.lastCellVoltage, cellVoltage,
      (inputs.voltageFallPerSecond or DEFAULT_VOLTAGE_FALL_PER_SECOND) * dt
    )
  end
  self.lastCellVoltage = cellVoltage

  local estimation = chargeLevelFromVoltage(cellVoltage, minV, fullV)

  if self.initialChargeLevel == 0 then
    self.chargeLevel = estimation
    self.initialChargeLevel = estimation
  end
  if self.initialConsumption == nil and inputs.consumption ~= nil then
    self.initialConsumption = inputs.consumption
  end
  estimation = math_min(self.initialChargeLevel, estimation)

  if inputs.isArmed == true then self.wasEverArmed = true end

  local nextChargeLevel
  if inputs.isArmed == true or self.wasEverArmed then
    nextChargeLevel = slewDownLimit(
      self.chargeLevel, estimation,
      (inputs.chargeDropPerSecond or DEFAULT_CHARGE_DROP_PER_SECOND) * dt
    )
  else
    nextChargeLevel = estimation
  end

  if inputs.consumption ~= nil and self.initialConsumption ~= nil then
    local used = inputs.consumption - self.initialConsumption
    local currentEstimate = self.initialChargeLevel - used / packCapacity
    nextChargeLevel = math_min(nextChargeLevel, currentEstimate)
  end

  -- Monotonic: fuel is never allowed to rise except via reset().
  nextChargeLevel = math_min(nextChargeLevel, self.chargeLevel)
  self.chargeLevel = math_max(0.0, math_min(nextChargeLevel, self.initialChargeLevel))
  self.lastTimestamp = now
  self.lastPackVoltage = voltage

  return smartfuel_reserve.applyPercent(math_min(1.0, self.chargeLevel) * 100, warningPercent)
end

return SmartFuel

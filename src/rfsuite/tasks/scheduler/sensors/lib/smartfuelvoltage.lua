--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local smartfuelprefs = assert(loadfile("tasks/scheduler/sensors/lib/smartfuelprefs.lua"))()

local os_clock = os.clock
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_exp = math.exp
local table_insert = table.insert
local table_remove = table.remove

-- ── State ────────────────────────────────────────────────────────────────────

local chargeLevel        = 0.0
local initialChargeLevel = 0.0
local lastCellVoltage    = 0.0
local initialCellVoltage = 0.0
local lastTimestamp      = nil
local virtualConsumption = nil
local initialConsumption = nil
local wasEverArmed       = false
local wasEverInFlight    = false
local batteryConfigCache = nil

-- Stabilise tracking (values fixed as constants; see smartfuelprefs)
local lastVoltages      = {}
local maxVoltageSamples = 5
local voltageStabilised = false
local stabilizeNotBefore = nil
local lastMode          = nil
local telemetry         = nil

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function normalizeBatteryProfileIndex(value)
    local n = tonumber(value)
    if not n then return nil end
    n = math_floor(n)
    if n >= 1 and n <= 6 then return n - 1 end
    if n >= 0 and n <= 5 then return n end
    return nil
end

-- Only permits the value to fall at maxDrop per call; rises are instant.
local function slewDownLimit(current, target, maxDrop)
    if target < current then
        return math_max(target, current - maxDrop)
    end
    return target
end

-- Sigmoid mapping identical to firmware smartFuelChargeLevelFromVoltage().
-- Maps cellVoltage onto a 0.0–1.0 fraction using minV..fullV as the span,
-- scaled into the 3.0–4.2 V reference range before applying the curve.
local function chargeLevelFromVoltage(cellVoltage, minV, fullV)
    if cellVoltage >= fullV then return 1.0 end
    if cellVoltage <= minV  then return 0.0 end

    local scaledV = 3.0 + (cellVoltage - minV) / (fullV - minV) * 1.2
    scaledV = math_max(3.0, math_min(4.2, scaledV))
    return math_max(0.0, math_min(1.0, 1.0 / (1.0 + math_exp(-12.0 * (scaledV - 3.7)))))
end

-- Stick-load approximation matching firmware formula:
--   stickLoad = collective² + cyclic × 0.2
-- RX values assumed ±500 normalised range.
local function getStickLoadFactor()
    local rx = rfsuite.session.rx and rfsuite.session.rx.values
    if not rx then return 0 end
    local collective = math_min(1.0, math.abs(rx.collective or 0) / 500.0)
    local cyclic     = math_min(1.0, math_max(math.abs(rx.aileron or 0), math.abs(rx.elevator or 0)) / 500.0)
    return math_min(1.0, collective * collective + cyclic * 0.2)
end

-- Sag compensation: add sagGain × stickLoad to per-cell voltage, inflight only.
-- Matches firmware smartFuelApplySagCompensation() / isAirborne() guard.
local function applySagCompensation(cellVoltage)
    if rfsuite.flightmode.current ~= "inflight" then return cellVoltage end
    return cellVoltage + smartfuelprefs.getSagGain() * getStickLoadFactor()
end

local function getPackCapacity(bc)
    local batType = telemetry and telemetry.getSensor and telemetry.getSensor("battery_profile")
    local idx = normalizeBatteryProfileIndex(batType)
    if idx ~= nil then rfsuite.session.activeBatteryType = idx end

    local capacity = bc.batteryCapacity
    local active   = rfsuite.session.activeBatteryType
    if active and bc.profiles and bc.profiles[active] and bc.profiles[active] > 0 then
        capacity = bc.profiles[active]
    end
    return capacity
end

-- ── Reset helpers ─────────────────────────────────────────────────────────────

local function resetVoltageTracking()
    lastVoltages     = {}
    voltageStabilised = false
end

local function resetFuelState(now)
    chargeLevel        = 0.0
    initialChargeLevel = 0.0
    lastCellVoltage    = 0.0
    initialCellVoltage = 0.0
    lastTimestamp      = nil
    virtualConsumption = nil
    initialConsumption = nil
    wasEverArmed       = false
    wasEverInFlight    = false
    stabilizeNotBefore = now and (now + smartfuelprefs.getStabilizeDelaySeconds()) or nil
    resetVoltageTracking()
end

local function resetState()
    batteryConfigCache = nil
    telemetry          = nil
    lastMode           = nil
    resetFuelState(nil)
end

local function isVoltageStable()
    if #lastVoltages < maxVoltageSamples then return false end
    local vmin, vmax = lastVoltages[1], lastVoltages[1]
    for _, v in ipairs(lastVoltages) do
        if v < vmin then vmin = v end
        if v > vmax then vmax = v end
    end
    return (vmax - vmin) <= smartfuelprefs.getStableWindowVolts()
end

-- ── Main calculation ──────────────────────────────────────────────────────────

local function smartFuelCalc()
    if not telemetry then telemetry = rfsuite.tasks.telemetry end

    if not rfsuite.session.isConnected or not rfsuite.session.batteryConfig then
        resetState()
        return nil
    end

    local bc           = rfsuite.session.batteryConfig
    local cellCount    = bc.batteryCellCount
    local minV         = bc.vbatmincellvoltage  or 3.30
    local fullV        = bc.vbatfullcellvoltage or 4.10
    local packCapacity = getPackCapacity(bc)

    if packCapacity < 10 or cellCount == 0 or fullV <= minV then
        resetState()
        return nil
    end

    -- Reset when battery config changes
    local configSig = table.concat({cellCount, packCapacity, bc.vbatmincellvoltage, bc.vbatfullcellvoltage, bc.consumptionWarningPercentage}, ":")
    if configSig ~= batteryConfigCache then
        batteryConfigCache = configSig
        resetFuelState(os_clock())
    end

    local voltage     = telemetry and telemetry.getSensor and telemetry.getSensor("voltage") or nil
    local consumption = telemetry and telemetry.getSensor and telemetry.getSensor("consumption") or nil
    if not voltage or voltage < 2 then
        resetVoltageTracking()
        stabilizeNotBefore = nil
        return nil
    end

    local now         = os_clock()
    local currentMode = rfsuite.flightmode.current or "preflight"
    if lastMode == nil then lastMode = currentMode end

    -- Reset on return to preflight-disarmed (battery swap / re-land)
    if lastMode ~= currentMode and currentMode == "preflight" and rfsuite.session.isArmed == false then
        resetFuelState(now)
        lastMode = currentMode
        return nil
    end
    lastMode = currentMode

    -- Stabilise delay
    if stabilizeNotBefore and now < stabilizeNotBefore then return nil end

    -- Wait for voltage to be stable before seeding
    table_insert(lastVoltages, voltage)
    if #lastVoltages > maxVoltageSamples then table_remove(lastVoltages, 1) end

    if not voltageStabilised then
        if isVoltageStable() then
            voltageStabilised = true
        else
            return nil
        end
    end

    -- If voltage jumps up in preflight (battery swap), reseed
    if #lastVoltages >= 2 and currentMode == "preflight" and rfsuite.session.isArmed == false then
        local prev = lastVoltages[#lastVoltages - 1]
        if voltage > prev + smartfuelprefs.getStableWindowVolts() then
            resetFuelState(now)
            return nil
        end
    end

    -- ── Core algorithm (matches firmware smartFuelUpdate) ─────────────────────

    local isArmed = rfsuite.session.isArmed == true
    if isArmed then wasEverArmed = true end
    if currentMode == "inflight" then wasEverInFlight = true end

    local dt = (lastTimestamp and now > lastTimestamp) and (now - lastTimestamp) or 0

    -- Per-cell voltage with falling slew limit
    local cellVoltage = voltage / cellCount
    if initialCellVoltage == 0 then initialCellVoltage = cellVoltage end

    if lastCellVoltage > 0 then
        cellVoltage = slewDownLimit(lastCellVoltage, cellVoltage, smartfuelprefs.getVoltageFallPerSecond() * dt)
    end
    lastCellVoltage = cellVoltage

    -- Sag compensation then sigmoid → charge estimation
    local compensatedVoltage = applySagCompensation(cellVoltage)
    local estimation         = chargeLevelFromVoltage(compensatedVoltage, minV, fullV)

    -- Seed initial level on first valid sample
    if initialChargeLevel == 0 then
        chargeLevel = estimation
        initialChargeLevel = estimation
    end
    if initialConsumption == nil and consumption ~= nil then
        initialConsumption = consumption
    end
    estimation = math_min(initialChargeLevel, estimation)

    -- Charge-level slew: only restrict rate once armed (or previously armed)
    local nextChargeLevel
    if isArmed or wasEverArmed then
        nextChargeLevel = slewDownLimit(chargeLevel, estimation, smartfuelprefs.getChargeDropRatePerSecond() * dt)
    else
        nextChargeLevel = estimation
    end

    -- Local modes mirror firmware:
    --   CURRENT: consumption-derived, falling back to voltage if consumption is unavailable.
    --   VOLTAGE: voltage-derived only.
    --   COMBINED: whichever of voltage or consumption is more pessimistic.
    local source = smartfuelprefs.getSource()
    if (source == 0 or source == 2) and consumption ~= nil and initialConsumption ~= nil and packCapacity > 0 then
        local used = consumption - initialConsumption
        local curr_estimate = initialChargeLevel - used / packCapacity
        if source == 0 then
            nextChargeLevel = curr_estimate
        else
            nextChargeLevel = math_min(nextChargeLevel, curr_estimate)
        end
    end

    nextChargeLevel = math_min(nextChargeLevel, chargeLevel)
    chargeLevel = math_max(0.0, math_min(nextChargeLevel, initialChargeLevel))

    -- Virtual consumption derived from charge fraction change since start
    virtualConsumption = (initialChargeLevel - chargeLevel) * packCapacity

    lastTimestamp = now
    if not smartfuelprefs.getEndAtZeroEnabled() or not wasEverInFlight then
        return math_floor(math_min(1.0, chargeLevel) * 100 + 0.5)
    end

    local warningFrac = (bc.consumptionWarningPercentage or 0) / 100
    local usableRange = math_max(0.01, 1.0 - warningFrac)
    local adjusted    = math_max(0.0, chargeLevel - warningFrac)
    return math_floor(math_min(1.0, adjusted / usableRange) * 100 + 0.5)
end

local function getConsumption()
    -- Current and Combined modes: actual consumed mAh from current sensor
    local source = smartfuelprefs.getSource()
    if source == 0 or source == 2 then
        if initialConsumption == nil then return nil end
        local rawConsumption = telemetry and telemetry.getSensor and telemetry.getSensor("consumption") or nil
        if rawConsumption == nil then return nil end
        return math_floor(math_max(rawConsumption - initialConsumption, 0) + 0.5)
    end
    -- Voltage mode: virtual consumption derived from charge fraction change
    if virtualConsumption == nil then return nil end
    return math_floor(math_max(virtualConsumption, 0) + 0.5)
end

return {calculate = smartFuelCalc, getConsumption = getConsumption, reset = resetState}

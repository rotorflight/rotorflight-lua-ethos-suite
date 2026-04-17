--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local smartfuelprefs = assert(loadfile("tasks/scheduler/sensors/lib/smartfuelprefs.lua"))()

local os_clock = os.clock
local math_abs = math.abs
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local table_insert = table.insert
local table_remove = table.remove

local batteryConfigCache = nil
local lastVoltages = {}
local maxVoltageSamples = 5
local voltageStableTime = nil
local voltageStabilised = false
local stabilizeNotBefore = nil
local voltageThreshold = 0.15
local telemetry
local currentMode = rfsuite.flightmode.current or "preflight"
local lastMode = currentMode
local lastSensorMode

local lastFuelPercent = nil
local lastFuelTimestamp = nil
local virtualConsumption = nil

local lastFilteredVoltage = nil

local function normalizeBatteryProfileIndex(value)
    local n = tonumber(value)
    if not n then return nil end
    n = math_floor(n)
    if n >= 1 and n <= 6 then return n - 1 end
    if n >= 0 and n <= 5 then return n end
    return nil
end

local function fallingLimitedFilter(current_v, prev_v, dt)
    if not prev_v then return current_v end
    local max_drop = dt * smartfuelprefs.getVoltageFallPerSecond()
    if current_v >= prev_v then
        return current_v
    else
        return math_max(current_v, prev_v - max_drop)
    end
end

local dischargeCurveTable = {}
for i = 0, 120 do
    local v = 3.00 + i * 0.01
    local a, b = 12, 3.7
    local percent = 100 / (1 + math.exp(-a * (v - b)))
    dischargeCurveTable[i + 1] = math_floor(math_min(100, math_max(0, percent)) + 0.5)
end

local function resetVoltageTracking()
    lastVoltages = {}
    voltageStableTime = nil
    voltageStabilised = false
end

local function resetState()
    batteryConfigCache = nil
    stabilizeNotBefore = nil
    lastSensorMode = nil
    lastFuelPercent = nil
    lastFuelTimestamp = nil
    virtualConsumption = nil
    lastFilteredVoltage = nil
    lastRpm = nil
    telemetry = nil
    currentMode = rfsuite.flightmode.current or "preflight"
    lastMode = currentMode
    resetVoltageTracking()
end

local function isVoltageStable()
    if #lastVoltages < maxVoltageSamples then return false end
    local vmin, vmax = lastVoltages[1], lastVoltages[1]
    for _, v in ipairs(lastVoltages) do
        if v < vmin then vmin = v end
        if v > vmax then vmax = v end
    end
    return (vmax - vmin) <= voltageThreshold
end

local function shouldResetForModeChange(previousMode, nextMode)
    if previousMode == nextMode then return false end
    if nextMode ~= "preflight" then return false end
    return rfsuite.session and rfsuite.session.isArmed == false
end

local function getPackCapacity(bc)
    local batType = telemetry and telemetry.getSensor and telemetry.getSensor("battery_profile")
    local normalizedBatType = normalizeBatteryProfileIndex(batType)
    if normalizedBatType ~= nil then
        rfsuite.session.activeBatteryType = normalizedBatType
    end

    local packCapacity = bc.batteryCapacity
    local activeProfile = rfsuite.session.activeBatteryType
    if activeProfile and bc.profiles and bc.profiles[activeProfile] then
        local pCap = bc.profiles[activeProfile]
        if pCap and pCap > 0 then
            packCapacity = pCap
        end
    end

    return packCapacity
end

local function getUsableCapacity(packCapacity, reserve)
    if reserve > 60 or reserve < 15 then
        reserve = 35
    end

    local usableCapacity = packCapacity * (1 - reserve / 100)
    if usableCapacity < 10 then
        usableCapacity = packCapacity
    end

    return usableCapacity, reserve
end

local function getStickLoadFactor()
    local rx = rfsuite.session.rx.values
    if not rx then return 0 end
    local sum = 1.0 * math_abs(rx.aileron or 0) + 1.0 * math_abs(rx.elevator or 0) + 1.2 * math_abs(rx.collective or 0)
    return math_min(1.0, sum / 3000)
end

local lastRpm = nil
local function getRpmDropFactor()
    local rpm = telemetry and telemetry.getSensor and telemetry.getSensor("rpm") or nil
    if not rpm or rpm < 100 then return 0 end
    if not lastRpm then
        lastRpm = rpm;
        return 0
    end
    local drop = (lastRpm - rpm) / lastRpm
    lastRpm = rpm
    return math_max(0, drop)

end

local function applySagCompensation(voltage)
    if rfsuite.flightmode.current ~= "inflight" then return voltage end
    local multiplier = smartfuelprefs.getSagMultiplier()
    local sagFactor = math_max(getStickLoadFactor(), getRpmDropFactor())

    local compensationScale = multiplier ^ 1.5
    return voltage + (compensationScale * sagFactor * 0.5)
end

local function fuelPercentageCalcByVoltage(voltage, cellCount)
    local bc = rfsuite.session.batteryConfig
    local minV = bc.vbatmincellvoltage or 3.30
    local fullV = bc.vbatfullcellvoltage or 4.10
    local reserve = bc.consumptionWarningPercentage or 30
    local voltagePerCell = voltage / cellCount

    if voltagePerCell >= fullV then
        return 100
    elseif voltagePerCell <= minV then
        return 0
    end

    local sigmoidMin, sigmoidMax = 3.00, 4.20
    local scaledV = sigmoidMin + (voltagePerCell - minV) / (fullV - minV) * (sigmoidMax - sigmoidMin)
    scaledV = math_max(sigmoidMin, math_min(sigmoidMax, scaledV))

    local tableIndex = math_floor((scaledV - sigmoidMin) / 0.01) + 1
    tableIndex = math_max(1, math_min(#dischargeCurveTable, tableIndex))

    if reserve > 60 or reserve < 15 then
        reserve = 35
    end

    local rawPercent = dischargeCurveTable[tableIndex]
    local usableSpan = 100 - reserve
    if usableSpan <= 0 then
        return rawPercent
    end

    if rawPercent <= reserve then
        return 0
    end

    return ((rawPercent - reserve) / usableSpan) * 100
end

local function smartFuelCalc()
    if not telemetry then telemetry = rfsuite.tasks.telemetry end

    if not rfsuite.session.isConnected or not rfsuite.session.batteryConfig then
        resetState()
        return nil
    end

    local sensorMode = smartfuelprefs.getSource()
    if lastSensorMode ~= sensorMode then
        lastFuelPercent = nil
        lastFuelTimestamp = nil
        virtualConsumption = nil
        lastFilteredVoltage = nil
        resetVoltageTracking()
        lastSensorMode = sensorMode
        stabilizeNotBefore = os_clock() + smartfuelprefs.getStabilizeDelaySeconds()
        return nil
    end

    local bc = rfsuite.session.batteryConfig
    local packCapacity = getPackCapacity(bc)
    local configSig = table.concat({bc.batteryCellCount, packCapacity, bc.consumptionWarningPercentage, bc.vbatmaxcellvoltage, bc.vbatmincellvoltage, bc.vbatfullcellvoltage}, ":")

    if configSig ~= batteryConfigCache then
        batteryConfigCache = configSig
        lastFuelPercent = nil
        lastFuelTimestamp = nil
        virtualConsumption = nil
        lastFilteredVoltage = nil
        resetVoltageTracking()
        stabilizeNotBefore = os_clock() + smartfuelprefs.getStabilizeDelaySeconds()
    end

    local voltage = telemetry and telemetry.getSensor and telemetry.getSensor("voltage") or nil
    if not voltage or voltage < 2 then
        resetVoltageTracking()
        stabilizeNotBefore = nil
        return nil
    end

    local now = os_clock()
    currentMode = rfsuite.flightmode.current or "preflight"

    if shouldResetForModeChange(lastMode, currentMode) then
        rfsuite.utils.log("Flight mode changed – resetting voltage state", "info")
        lastFuelPercent = nil
        lastFuelTimestamp = nil
        virtualConsumption = nil
        lastFilteredVoltage = nil
        resetVoltageTracking()
        stabilizeNotBefore = now + smartfuelprefs.getStabilizeDelaySeconds()
        lastMode = currentMode
        return nil
    end
    lastMode = currentMode

    voltageThreshold = smartfuelprefs.getStableWindowVolts()

    if stabilizeNotBefore and now < stabilizeNotBefore then return nil end

    table_insert(lastVoltages, voltage)
    if #lastVoltages > maxVoltageSamples then table_remove(lastVoltages, 1) end

    if not voltageStabilised then
        if isVoltageStable() then
            rfsuite.utils.log("Voltage stabilized at: " .. voltage, "info")
            voltageStabilised = true
        else
            rfsuite.utils.log("Waiting for voltage to stabilize...", "info")
            return nil
        end
    end

    if #lastVoltages >= 2 and rfsuite.flightmode.current == "preflight" then
        local prev = lastVoltages[#lastVoltages - 1]
        if voltage > prev + voltageThreshold then
            rfsuite.utils.log("Voltage increased after stabilization – resetting...", "info")
            lastFuelPercent = nil
            lastFuelTimestamp = nil
            virtualConsumption = nil
            lastFilteredVoltage = nil
            resetVoltageTracking()
            stabilizeNotBefore = os_clock() + smartfuelprefs.getStabilizeDelaySeconds()
            return nil
        end
    end

    local filteredVoltage = fallingLimitedFilter(voltage, lastFilteredVoltage, os_clock() - (lastFuelTimestamp or os_clock()))
    local compensatedVoltage = applySagCompensation(filteredVoltage / bc.batteryCellCount) * bc.batteryCellCount
    local targetPercent = fuelPercentageCalcByVoltage(compensatedVoltage, bc.batteryCellCount)
    local usableCapacity = getUsableCapacity(packCapacity, bc.consumptionWarningPercentage or 30)
    if usableCapacity < 10 then return nil end

    local targetConsumption = usableCapacity * (100 - targetPercent) / 100
    local isPreflightDisarmed = currentMode == "preflight" and rfsuite.session.isArmed == false

    -- Seed once from stabilized resting voltage, then hold that estimate until flight begins.
    -- A meaningful voltage rise in preflight still triggers the reset/reseed path above.
    if virtualConsumption == nil then
        virtualConsumption = targetConsumption
    elseif not isPreflightDisarmed and lastFuelTimestamp then
        local dt = now - lastFuelTimestamp
        local maxConsumptionIncrease = dt * smartfuelprefs.getFuelDropPerSecond() * usableCapacity / 100
        if targetConsumption > virtualConsumption then
            virtualConsumption = math_min(targetConsumption, virtualConsumption + maxConsumptionIncrease)
        end
    end

    local percent = 100 - (virtualConsumption / usableCapacity * 100)
    percent = math_max(0, math_min(100, percent))

    lastFuelPercent = percent
    lastFuelTimestamp = now
    lastFilteredVoltage = filteredVoltage

    return math_floor(percent + 0.5)
end

local function getConsumption()
    if virtualConsumption == nil then return nil end
    return math_floor(math_max(virtualConsumption, 0) + 0.5)
end

return {calculate = smartFuelCalc, getConsumption = getConsumption, reset = resetState}

--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

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
local preStabiliseDelay = 1.5

local telemetry
local currentMode = rfsuite.flightmode.current or "preflight"
local lastMode = currentMode
local lastSensorMode

local lastFuelPercent = nil
local lastFuelTimestamp = nil

local maxFuelDropPerSecond = 1

local maxFuelRisePerSecond = 0.2

local MAX_FALL_PER_SEC = 0.05
local lastFilteredVoltage = nil

local function fallingLimitedFilter(current_v, prev_v, dt)
    if not prev_v then return current_v end
    local max_drop = dt * MAX_FALL_PER_SEC
    if current_v >= prev_v then
        return current_v
    else
        return math_max(current_v, prev_v - max_drop)
    end
end

local dischargeCurveTable = {}
for i = 0, 100 do
    local v = 3.30 + i * 0.01
    local percent = (v - 3.30) / (4.20 - 3.30) * 100
    dischargeCurveTable[i + 1] = math_floor(math_min(100, math_max(0, percent)) + 0.5)
end

local function resetVoltageTracking()
    lastVoltages = {}
    voltageStableTime = nil
    voltageStabilised = false
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
    local multiplier = rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.sag_multiplier or 0.7
    local sagFactor = math_max(getStickLoadFactor(), getRpmDropFactor())

    local compensationScale = multiplier ^ 1.5
    return voltage + (compensationScale * sagFactor * 0.5)
end

local function fuelPercentageCalcByVoltage(voltage, cellCount)
    local bc = rfsuite.session.batteryConfig
    local minV = bc.vbatmincellvoltage or 3.30
    local fullV = bc.vbatfullcellvoltage or 4.10
    local reserve = bc.consumptionWarningPercentage or 30

    local usableRange = fullV - minV
    local adjustedMinV = minV + (usableRange * (reserve / 100)) * 1.4

    local voltagePerCell = voltage / cellCount

    voltagePerCell = math_max(3.30, math_min(fullV, voltagePerCell))

    local sigmoidMin, sigmoidMax = 3.30, 4.20
    local scaledV = sigmoidMin + (voltagePerCell - adjustedMinV) / (fullV - adjustedMinV) * (sigmoidMax - sigmoidMin)

    local tableIndex = math_floor((scaledV - sigmoidMin) / 0.01) + 1
    tableIndex = math_max(1, math_min(#dischargeCurveTable, tableIndex))

    return dischargeCurveTable[tableIndex]
end

local function smartFuelCalc()
    if not telemetry then telemetry = rfsuite.tasks.telemetry end

    if not rfsuite.session.isConnected or not rfsuite.session.batteryConfig then
        resetVoltageTracking()
        return nil
    end

    if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.calc_local then
        if lastSensorMode ~= rfsuite.session.modelPreferences.battery.calc_local then
            resetVoltageTracking()
            lastSensorMode = rfsuite.session.modelPreferences.battery.calc_local
        end
    end

    local bc = rfsuite.session.batteryConfig
    local configSig = table.concat({bc.batteryCellCount, bc.batteryCapacity, bc.consumptionWarningPercentage, bc.vbatmaxcellvoltage, bc.vbatmincellvoltage, bc.vbatfullcellvoltage}, ":")

    if configSig ~= batteryConfigCache then
        batteryConfigCache = configSig
        resetVoltageTracking()
        stabilizeNotBefore = os_clock() + preStabiliseDelay
    end

    local voltage = telemetry and telemetry.getSensor and telemetry.getSensor("voltage") or nil
    if not voltage or voltage < 2 then
        resetVoltageTracking()
        stabilizeNotBefore = nil
        return nil
    end

    local now = os_clock()

    if currentMode ~= lastMode then
        rfsuite.utils.log("Flight mode changed – resetting voltage state", "info")
        resetVoltageTracking()
        stabilizeNotBefore = now + preStabiliseDelay
        lastMode = currentMode
        return nil
    end
    lastMode = currentMode

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

    if #lastVoltages >= 1 and rfsuite.flightmode.current == "preflight" then
        local prev = lastVoltages[#lastVoltages - 1]
        if voltage > prev + voltageThreshold then
            rfsuite.utils.log("Voltage increased after stabilization – resetting...", "info")
            resetVoltageTracking()
            stabilizeNotBefore = os_clock() + preStabiliseDelay
            return nil
        end
    end

    local filteredVoltage = fallingLimitedFilter(voltage, lastFilteredVoltage, os_clock() - (lastFuelTimestamp or os_clock()))
    local compensatedVoltage = applySagCompensation(filteredVoltage / bc.batteryCellCount) * bc.batteryCellCount
    local percent = fuelPercentageCalcByVoltage(compensatedVoltage, bc.batteryCellCount)
    local now = os_clock()
    if (rfsuite.flightmode.current == "inflight" or rfsuite.flightmode.current == "postflight") and lastFuelPercent and lastFuelTimestamp then

        local dt = now - lastFuelTimestamp
        local maxDrop = dt * maxFuelDropPerSecond
        local maxRise = dt * maxFuelRisePerSecond

        if percent < lastFuelPercent then
            percent = math_max(percent, lastFuelPercent - maxDrop)
        elseif percent > lastFuelPercent then
            percent = math_min(percent, lastFuelPercent + maxRise)
        end
    end

    lastFuelPercent = percent
    lastFuelTimestamp = now

    return percent
end

return {calculate = smartFuelCalc, reset = resetVoltageTracking}

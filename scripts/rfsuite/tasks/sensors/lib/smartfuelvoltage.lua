--[[ 
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note.  Some icons have been sourced from https://www.flaticon.com/
]] --

local batteryConfigCache      = nil
local lastVoltages            = {}
local maxVoltageSamples       = 5
local voltageStableTime       = nil
local voltageStabilised       = false
local stabilizeNotBefore      = nil
local voltageThreshold        = 0.15
local preStabiliseDelay       = 1.5

local telemetry
local currentMode = rfsuite.flightmode.current
local lastMode = currentMode
local lastSensorMode

-- Discharge curve with 0.01V per cell resolution from 3.00V to 4.20V (121 points)
-- This curve uses a sigmoid approximation to mimic real LiPo discharge behavior
local dischargeCurveTable = {}
for i = 0, 120 do
    local v = 3.00 + i * 0.01
    local a, b, c = 12, 3.7, 100
    local percent = 100 / (1 + math.exp(-a * (v - b)))
    dischargeCurveTable[i + 1] = math.floor(math.min(100, math.max(0, percent)) + 0.5)
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

local function indexOf(t, value)
    for i = 1, #t do
        if t[i] == value then return i end
    end
    return nil
end

local function getStickLoadFactor()
    local rx = rfsuite.session.rx.values
    if not rx then return 0 end
    local sumAbs = math.abs(rx.aileron or 0) + math.abs(rx.elevator or 0) + math.abs(rx.collective or 0) + math.abs(rx.rudder or 0)
    return math.min(1.0, sumAbs / 4000) -- scale from 0.0 to 1.0
end

local function applySagCompensation(voltage)
    if rfsuite.flightmode.current ~= "inflight" then
        return voltage -- no sag compensation unless we're flying
    end
    local multiplier = rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.sag_multiplier or 0.5
    local sagFactor = getStickLoadFactor()
    local compensatedVoltage = voltage + ((1.0 - multiplier) * sagFactor * 0.3)
    return compensatedVoltage
end

local function fuelPercentageCalcByVoltage(voltage, cellCount)
    local bc = rfsuite.session.batteryConfig
    local minV = bc.vbatmincellvoltage or 3.30
    local fullV = bc.vbatfullcellvoltage or 4.10
    local reserve = bc.consumptionWarningPercentage or 0

    local usableRange = fullV - minV
    local adjustedMinV = minV + (usableRange * (reserve / 100))

    local voltagePerCell = voltage / cellCount

    -- Clamp voltage to adjusted usable range
    voltagePerCell = math.max(adjustedMinV, math.min(fullV, voltagePerCell))

    -- Remap [adjustedMinV, fullV] → [3.00, 4.20]
    local sigmoidMin, sigmoidMax = 3.00, 4.20
    local scaledV = sigmoidMin + (voltagePerCell - adjustedMinV) / (fullV - adjustedMinV) * (sigmoidMax - sigmoidMin)

    local tableIndex = math.floor((scaledV - sigmoidMin) / 0.01) + 1
    tableIndex = math.max(1, math.min(#dischargeCurveTable, tableIndex))

    return dischargeCurveTable[tableIndex]
end


local function smartFuelCalc()
    if not telemetry then
        telemetry = rfsuite.tasks.telemetry
    end

    if not rfsuite.session.isConnected or not rfsuite.session.batteryConfig then
        resetVoltageTracking()
        return nil
    end

    -- make sure we reset the method if the sensor mode changes
    if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.calc_local then
        if lastSensorMode ~= rfsuite.session.modelPreferences.battery.calc_local then
            resetVoltageTracking()
            lastSensorMode = rfsuite.session.modelPreferences.battery.calc_local
        end
    end

    local bc = rfsuite.session.batteryConfig
    local configSig = table.concat({
        bc.batteryCellCount,
        bc.batteryCapacity,
        bc.consumptionWarningPercentage,
        bc.vbatmaxcellvoltage,
        bc.vbatmincellvoltage,
        bc.vbatfullcellvoltage
    }, ":")

    if configSig ~= batteryConfigCache then
        batteryConfigCache = configSig
        resetVoltageTracking()
        stabilizeNotBefore = os.clock() + preStabiliseDelay
    end

    local voltage = telemetry and telemetry.getSensor and telemetry.getSensor("voltage") or nil
    if not voltage or voltage < 2 then
        resetVoltageTracking()
        stabilizeNotBefore = nil
        return nil
    end

    local now = os.clock()

    if currentMode ~= lastMode then
        rfsuite.utils.log("Flight mode changed – resetting voltage state", "info")
        resetVoltageTracking()
        stabilizeNotBefore = now + preStabiliseDelay
        lastMode = currentMode
        return nil
    end
    lastMode = currentMode

    if stabilizeNotBefore and now < stabilizeNotBefore then return nil end

    table.insert(lastVoltages, voltage)
    if #lastVoltages > maxVoltageSamples then table.remove(lastVoltages, 1) end

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
            stabilizeNotBefore = os.clock() + preStabiliseDelay
            return nil
        end
    end

    local compensatedVoltage = applySagCompensation(voltage)
    local percent = fuelPercentageCalcByVoltage(compensatedVoltage, bc.batteryCellCount)
    rfsuite.utils.log("Battery fuel percent (compensated): " .. percent)
    return percent
end

return {
    calculate = smartFuelCalc,
    reset = resetVoltageTracking
}
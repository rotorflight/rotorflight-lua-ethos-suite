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

local lastFuelPercent = nil
local lastFuelTimestamp = nil


-- Very stable, slow decline	    1–5
-- Moderate responsiveness	        6–10
-- Fast decay (minimal clamping)	12+
local   maxFuelDropPerSecond  = 0.65   -- percent per second 

-- Very slow rise per second to avoid false positives (fuel technically can only go down )
local maxFuelRisePerSecond = 0.2   -- maximum rise in percent per second

--
local minQ, maxQ   = 0.002, 0.02
local minR, maxR   = 0.5,   0.1
local defaultFactor= 0.5    -- mid‑point
local lastFactor   = nil

local kalmanVoltage = nil
local kalmanP       = 1.0
local kalmanQ       = minQ
local kalmanR       = maxR


local function updateKalmanParams(f)
    -- clamp 0–1
    f = math.max(0, math.min(1, f))

    -- Q: high→low as f goes 0→1  (more smoothing at high f)
    kalmanQ = maxQ - (maxQ - minQ) * f

    -- R: low→high as f goes 0→1  (more trusting of measurement noise at high f)
    kalmanR = minR + (maxR - minR) * f
end

local function kalmanFilterVoltage(measured)
    if not kalmanVoltage then
        kalmanVoltage = measured
        return measured
    end

    -- Prediction update
    kalmanP = kalmanP + kalmanQ

    -- Measurement update
    local K = kalmanP / (kalmanP + kalmanR)
    kalmanVoltage = kalmanVoltage + K * (measured - kalmanVoltage)
    kalmanP = (1 - K) * kalmanP

    return kalmanVoltage
end

-- Discharge curve with 0.01V per cell resolution from 3.00V to 4.20V (121 points)
-- This curve uses a sigmoid approximation to mimic real LiPo discharge behavior
local dischargeCurveTable = {}
for i = 0, 120 do
    local v = 3.00 + i * 0.01
    local a, b, c = 12, 3.7, 100
    local percent = 100 / (1 + math.exp(-a * (v - b)))
    dischargeCurveTable[i + 1] = math.floor(math.min(100, math.max(0, percent)) + 0.5)
end

local function resetKalmanFilter()
    kalmanVoltage = nil
    kalmanP = 1.0
end

local function resetVoltageTracking()
    lastVoltages = {}
    voltageStableTime = nil
    voltageStabilised = false
    resetKalmanFilter()
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
    local sumAbs = math.abs(rx.aileron or 0) + math.abs(rx.elevator or 0) + math.abs(rx.collective or 0) + math.abs(rx.rudder or 0)
    return math.min(1.0, sumAbs / 4000) -- scale from 0.0 to 1.0
end

local lastRpm = nil
local function getRpmDropFactor()
    local rpm = telemetry and telemetry.getSensor and telemetry.getSensor("rpm") or nil
    if not rpm or rpm < 100 then return 0 end
    if not lastRpm then lastRpm = rpm; return 0 end
    local drop = (lastRpm - rpm) / lastRpm
    lastRpm = rpm
    return math.max(0, drop)

end

local function applySagCompensation(voltage)
    if rfsuite.flightmode.current ~= "inflight" then
        return voltage -- no sag compensation unless we're flying
    end
    local multiplier = rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.sag_multiplier or 0.5
    local sagFactor = math.max(getStickLoadFactor(), getRpmDropFactor())
    -- nonlinear curve that *increases* with multiplier:
    local compensationScale = multiplier ^ 1.5
    local compensatedVoltage = voltage + (compensationScale * sagFactor * 0.6)
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
    voltagePerCell = math.max(3.00, math.min(fullV, voltagePerCell))

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

    -- if it changed, recompute Q/R and wipe the old state
    local f = rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.kalman_multiplier or defaultFactor
    if f ~= lastFactor then
        lastFactor = f
        updateKalmanParams(f)
        resetVoltageTracking()
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

    -- Only apply Kalman while actually flying; otherwise reset it and use raw voltage
    local filteredVoltage
    if rfsuite.flightmode.current == "inflight" or rfsuite.flightmode.current == "postflight"  then
        filteredVoltage = kalmanFilterVoltage(voltage)
    else
        -- mode isn’t inflight: wipe out any past filter state
        resetKalmanFilter()
        filteredVoltage = voltage
    end

    local compensatedVoltage = applySagCompensation(filteredVoltage)
    local percent = fuelPercentageCalcByVoltage(compensatedVoltage, bc.batteryCellCount)

    local now = os.clock()
    if (rfsuite.flightmode.current == "inflight" or rfsuite.flightmode.current == "postflight")
    and lastFuelPercent and lastFuelTimestamp then

        local dt = now - lastFuelTimestamp
        local maxDrop = dt * maxFuelDropPerSecond
        local maxRise = dt * maxFuelRisePerSecond

        if percent < lastFuelPercent then
            percent = math.max(percent, lastFuelPercent - maxDrop)
        elseif percent > lastFuelPercent then
            percent = math.min(percent, lastFuelPercent + maxRise)
        end
    end

    -- always update the last‑seen values so that when you enter flight mode
    -- the timer resets correctly
    lastFuelPercent   = percent
    lastFuelTimestamp = now

    return percent
end

return {
    calculate = smartFuelCalc,
    reset = resetVoltageTracking
}
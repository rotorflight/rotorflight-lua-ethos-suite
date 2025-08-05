--[[ 
 * Copyright (C) Rotorflight Project
 *
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
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 
]] --
-- Persistent vars for the smart fuel logic
local batteryConfigCache      = nil   -- Cached battery configuration data.
local fuelStartingPercent     = nil   -- Initial fuel percentage at the start of measurement.
local fuelStartingConsumption = nil   -- Initial fuel consumption value at the start.

-- Voltage stabilisation state
local lastVoltages        = {}        -- Table holding the most recent voltage readings for stability analysis.
local maxVoltageSamples   = 5         -- Number of recent voltage samples to retain for stability checks.
local voltageStableTime   = nil       -- Timestamp when voltage was last considered stable.
local voltageStabilised   = false     -- Boolean indicating if voltage has stabilised.
local stabilizeNotBefore  = nil       -- Earliest time at which stabilisation can be considered.
local voltageThreshold    = 0.15      -- Maximum allowed voltage variation within the sample window to consider as stable.
local preStabiliseDelay   = 1.5       -- Minimum seconds to wait after configuration or telemetry update before checking for stabilisation.

local telemetry                       -- Reference to the telemetry task, used to access sensor data.
local lastMode = rfsuite.flightmode.current
local currentMode = rfsuite.flightmode.current
local lastSensorMode

-- Discharge curve with 0.01V per cell resolution from 3.00V to 4.20V (121 points)
-- This curve uses a sigmoid approximation to mimic real LiPo discharge behavior
-- Same curve as used in smartfuelvoltage.lua for consistency
local dischargeCurveTable = {}
for i = 0, 120 do
    local v = 3.00 + i * 0.01
    local a, b, c = 12, 3.7, 100
    local percent = 100 / (1 + math.exp(-a * (v - b)))
    dischargeCurveTable[i + 1] = math.floor(math.min(100, math.max(0, percent)) + 0.5)
end

-- Calculate fuel percentage using sigmoid discharge curve for accurate LiPo behavior
-- This provides much better accuracy than linear voltage mapping
local function fuelPercentageFromVoltage(voltage, cellCount, bc)
    local minV = bc.vbatmincellvoltage or 3.30
    local fullV = bc.vbatfullcellvoltage or 4.10

    local voltagePerCell = voltage / cellCount

    -- Handle edge cases
    if voltagePerCell >= fullV then
        return 100
    elseif voltagePerCell <= minV then
        return 0
    end

    -- Map voltage range [minV, fullV] to discharge curve range [3.00, 4.20]
    local sigmoidMin, sigmoidMax = 3.00, 4.20
    local scaledV = sigmoidMin + (voltagePerCell - minV) / (fullV - minV) * (sigmoidMax - sigmoidMin)

    -- Clamp to discharge curve range
    scaledV = math.max(sigmoidMin, math.min(sigmoidMax, scaledV))

    -- Look up percentage from discharge curve table
    local index = math.floor((scaledV - sigmoidMin) / 0.01) + 1
    index = math.max(1, math.min(#dischargeCurveTable, index))

    return dischargeCurveTable[index]
end

-- Resets the voltage tracking state by clearing the last recorded voltages,
-- resetting the voltage stable time, and marking the voltage as not stabilised.
-- This function is typically used to reinitialize voltage monitoring logic.
local function resetVoltageTracking()
    lastVoltages = {}
    voltageStableTime = nil
    voltageStabilised = false
end

-- Checks if the voltage readings in `lastVoltages` are stable.
-- Stability is determined by ensuring the number of samples in `lastVoltages`
-- is at least `maxVoltageSamples`, and the difference between the maximum and
-- minimum voltage values does not exceed `voltageThreshold`.
-- @return boolean True if voltage is stable, false otherwise.
local function isVoltageStable()
    if #lastVoltages < maxVoltageSamples then
        return false
    end
    local vmin, vmax = lastVoltages[1], lastVoltages[1]
    for _, v in ipairs(lastVoltages) do
        if v < vmin then vmin = v end
        if v > vmax then vmax = v end
    end
    return (vmax - vmin) <= voltageThreshold
end

-- Calculates the estimated remaining battery "fuel" percentage based on voltage and consumption telemetry.
-- 
-- This function performs a two-step estimation:
-- 1. Determines the initial fuel percentage from the battery voltage, after ensuring voltage readings are stable.
-- 2. Tracks the percentage drop using mAh consumption telemetry after the initial value is set.
--
-- The function handles battery configuration changes, voltage stabilization, and clamps values to ensure safe operation.
-- It uses a ring buffer to stabilize voltage readings and waits for a pre-stabilization delay after configuration changes.
--
-- @return number|nil The estimated remaining fuel percentage (0-100), or nil if unavailable or not stabilized.
local function smartFuelCalc()

    -- Assign this here as it may not be available in the global scope at intialisation
    if not telemetry then
        telemetry = rfsuite.tasks.telemetry
    end

    -- quick exit and cleanup
    if not rfsuite.session.isConnected or not rfsuite.session.batteryConfig then 
        resetVoltageTracking()
        return nil 
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

    -- If config changed, reset voltage stabilization and fuel state
    if configSig ~= batteryConfigCache then
        batteryConfigCache = configSig
        fuelStartingPercent = nil
        fuelStartingConsumption = nil
        resetVoltageTracking()
        stabilizeNotBefore = os.clock() + preStabiliseDelay -- start pre-stabilisation delay on config change
    end

    -- make sure we reset the method if the sensor mode changes
    if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.calc_local then
        if lastSensorMode ~= rfsuite.session.modelPreferences.battery.calc_local then
            resetVoltageTracking()
            lastSensorMode = rfsuite.session.modelPreferences.battery.calc_local
        end
    end

    -- Read current voltage
    local voltage = telemetry and telemetry.getSensor and telemetry.getSensor("voltage") or nil

    -- Only track/accept valid voltages (e.g., battery plugged in)
    if not voltage or voltage < 2 then
        resetVoltageTracking()
        stabilizeNotBefore = nil
        return nil
    end

    local now = os.clock()

    --**Preemptive reset**: bail out _before_ any recalculation
    if currentMode ~= lastMode then
        rfsuite.utils.log("Flight mode changed – resetting voltage & fuel state", "info")
        -- clear starting references
        fuelStartingPercent     = nil
        fuelStartingConsumption = nil
        -- clear any stored voltages
        resetVoltageTracking()
        -- defer next real calc until after your stabilization delay
        stabilizeNotBefore = now + preStabiliseDelay

        -- update for next time and exit
        lastMode = currentMode
        return nil
    end
    -- keep track for next invocation
    lastMode = currentMode


    -- Wait for pre-stabilisation delay after config/telemetry is available
   if stabilizeNotBefore and now < stabilizeNotBefore then
       -- still in pre-stabilization, but don’t toss our samples
       return nil
   end

    -- ring buffer of last N voltage readings
    table.insert(lastVoltages, voltage)
    if #lastVoltages > maxVoltageSamples then
        table.remove(lastVoltages, 1)
    end

    -- wait until we have N consistent readings within threshold
    if not voltageStabilised then
        if isVoltageStable() then
            rfsuite.utils.log("Voltage stabilized at: " .. voltage,"info")
            voltageStabilised = true
        else
            rfsuite.utils.log("Waiting for voltage to stabilize...","info")
            return nil
        end
    end

    -- Detect voltage increase after stabilization if not yet flying
    if #lastVoltages >= 1 and rfsuite.flightmode.current == "preflight" then
        local prev = lastVoltages[#lastVoltages - 1]
        if voltage > prev + voltageThreshold then
            rfsuite.utils.log("Voltage increased after stabilization – resetting...", "info")
            fuelStartingPercent = nil
            fuelStartingConsumption = nil
            resetVoltageTracking()
            stabilizeNotBefore = os.clock() + preStabiliseDelay
            return nil  -- Ensure upstream caller knows we are resetting
        end
    end    

    -- After voltage is stable, proceed as normal
    local cellCount, packCapacity, reserve, maxCellV, minCellV, fullCellV =
        bc.batteryCellCount, bc.batteryCapacity, bc.consumptionWarningPercentage,
        bc.vbatmaxcellvoltage, bc.vbatmincellvoltage, bc.vbatfullcellvoltage

    -- Clamp reserve to allowed range for safety
    if reserve > 60 then
        reserve = 35
    elseif reserve < 15 then
        reserve = 35
    end

    if packCapacity < 10 or cellCount == 0 or maxCellV <= minCellV or fullCellV <= 0 then
        fuelStartingPercent = nil
        fuelStartingConsumption = nil
        return nil
    end

    -- Clamp usableCapacity once for both steps
    local usableCapacity = packCapacity * (1 - reserve / 100)
    if usableCapacity < 10 then usableCapacity = packCapacity end

    local consumption = telemetry and telemetry.getSensor and telemetry.getSensor("consumption") or nil

    -- Step 1: Determine initial fuel % from voltage using accurate discharge curve
    if not fuelStartingPercent then
        if voltage and cellCount > 0 then
            -- Use sigmoid discharge curve for accurate LiPo percentage calculation
            fuelStartingPercent = fuelPercentageFromVoltage(voltage, cellCount, bc)
        else
            fuelStartingPercent = 0
        end
        local estimatedUsed = usableCapacity * (1 - fuelStartingPercent / 100)
        fuelStartingConsumption = (consumption or 0) - estimatedUsed
    end

    -- Step 2: Use mAh consumption to track % drop after initial value
    if consumption and fuelStartingConsumption and packCapacity > 0 then
        local used = consumption - fuelStartingConsumption
        local percentUsed = used / usableCapacity * 100
        local remaining = math.max(0, fuelStartingPercent - percentUsed)
        return math.floor(math.min(100, remaining) + 0.5)
    else
        -- If we're resetting or recalculating, don't return a stale value
        if not voltageStabilised or (stabilizeNotBefore and os.clock() < stabilizeNotBefore) then
            print("Voltage not stabilised or pre-stabilisation delay active, returning nil")
            return nil
        end
        return fuelStartingPercent
    end
end

--- Returns a table containing the `calculate` function for smart fuel calculations.
-- @field calculate Function to perform smart fuel calculations.
return {
        calculate = smartFuelCalc,
        reset = resetVoltageTracking
    }
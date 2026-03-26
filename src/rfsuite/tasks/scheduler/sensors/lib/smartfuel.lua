--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local os_clock = os.clock
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local table_insert = table.insert
local table_remove = table.remove

local batteryConfigCache = nil
local fuelStartingPercent = nil
local fuelStartingConsumption = nil

local lastVoltages = {}
local maxVoltageSamples = 5
local voltageStableTime = nil
local voltageStabilised = false
local stabilizeNotBefore = nil
local voltageThreshold = 0.15
local preStabiliseDelay = 1.5

local telemetry
local lastMode = rfsuite.flightmode.current or "preflight"
local currentMode = rfsuite.flightmode.current or "preflight"
local lastSensorMode

local function normalizeBatteryProfileIndex(value)
    local n = tonumber(value)
    if not n then return nil end
    n = math_floor(n)
    if n >= 1 and n <= 6 then return n - 1 end
    if n >= 0 and n <= 5 then return n end
    return nil
end

local dischargeCurveTable = {}
for i = 0, 120 do
    local v = 3.00 + i * 0.01
    local a, b, c = 12, 3.7, 100
    local percent = 100 / (1 + math.exp(-a * (v - b)))
    dischargeCurveTable[i + 1] = math_floor(math_min(100, math_max(0, percent)) + 0.5)
end

local function fuelPercentageFromVoltage(voltage, cellCount, bc)
    local minV = bc.vbatmincellvoltage or 3.30
    local fullV = bc.vbatfullcellvoltage or 4.10

    local voltagePerCell = voltage / cellCount

    if voltagePerCell >= fullV then
        return 100
    elseif voltagePerCell <= minV then
        return 0
    end

    local sigmoidMin, sigmoidMax = 3.00, 4.20
    local scaledV = sigmoidMin + (voltagePerCell - minV) / (fullV - minV) * (sigmoidMax - sigmoidMin)

    scaledV = math_max(sigmoidMin, math_min(sigmoidMax, scaledV))

    local index = math_floor((scaledV - sigmoidMin) / 0.01) + 1
    index = math_max(1, math_min(#dischargeCurveTable, index))

    return dischargeCurveTable[index]
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

local function smartFuelCalc()

    if not telemetry then telemetry = rfsuite.tasks.telemetry end

    local batType = telemetry and telemetry.getSensor and telemetry.getSensor("battery_profile")
    local normalizedBatType = normalizeBatteryProfileIndex(batType)
    if normalizedBatType ~= nil then
        rfsuite.session.activeBatteryType = normalizedBatType
    end

    if not rfsuite.session.isConnected or not rfsuite.session.batteryConfig then
        resetVoltageTracking()
        return nil
    end

    local bc = rfsuite.session.batteryConfig

    local packCapacity = bc.batteryCapacity
    local activeProfile = rfsuite.session.activeBatteryType
    if activeProfile and bc.profiles and bc.profiles[activeProfile] then
        local pCap = bc.profiles[activeProfile]
        if pCap and pCap > 0 then
            packCapacity = pCap
        end
    end

    local configSig = table.concat({bc.batteryCellCount, packCapacity, bc.consumptionWarningPercentage, bc.vbatmaxcellvoltage, bc.vbatmincellvoltage, bc.vbatfullcellvoltage}, ":")

    if configSig ~= batteryConfigCache then
        batteryConfigCache = configSig
        fuelStartingPercent = nil
        fuelStartingConsumption = nil
        resetVoltageTracking()
        stabilizeNotBefore = os_clock() + preStabiliseDelay
    end

    if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.calc_local then
        if lastSensorMode ~= rfsuite.session.modelPreferences.battery.calc_local then
            resetVoltageTracking()
            lastSensorMode = rfsuite.session.modelPreferences.battery.calc_local
        end
    end

    local voltage = telemetry and telemetry.getSensor and telemetry.getSensor("voltage") or nil

    if not voltage or voltage < 2 then
        resetVoltageTracking()
        stabilizeNotBefore = nil
        return nil
    end

    local now = os_clock()

    if currentMode ~= lastMode then
        rfsuite.utils.log("Flight mode changed – resetting voltage & fuel state", "info")

        fuelStartingPercent = nil
        fuelStartingConsumption = nil

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

    local isDisarmed = (rfsuite and rfsuite.session and rfsuite.session.isArmed == false)
    local isPreflight = (rfsuite and rfsuite.flightmode and rfsuite.flightmode.current == "preflight")

    if lastVoltages and #lastVoltages >= 2 and isPreflight and isDisarmed then
        local prev = lastVoltages[#lastVoltages - 1]
        if voltage > prev + voltageThreshold then
            rfsuite.utils.log("Voltage increased after stabilization – resetting...", "info")
            fuelStartingPercent = nil
            fuelStartingConsumption = nil
            resetVoltageTracking()
            stabilizeNotBefore = os_clock() + preStabiliseDelay
            return nil
        end
    end

    local cellCount, reserve, maxCellV, minCellV, fullCellV = bc.batteryCellCount, bc.consumptionWarningPercentage, bc.vbatmaxcellvoltage, bc.vbatmincellvoltage, bc.vbatfullcellvoltage

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

    local usableCapacity = packCapacity * (1 - reserve / 100)
    if usableCapacity < 10 then usableCapacity = packCapacity end

    local consumption = telemetry and telemetry.getSensor and telemetry.getSensor("consumption") or nil

    if not fuelStartingPercent then
        if voltage and cellCount > 0 then

            fuelStartingPercent = fuelPercentageFromVoltage(voltage, cellCount, bc)
        else
            fuelStartingPercent = 0
        end
        local estimatedUsed = usableCapacity * (1 - fuelStartingPercent / 100)
        fuelStartingConsumption = (consumption or 0) - estimatedUsed
    end

    if consumption and fuelStartingConsumption and packCapacity > 0 then
        local used = consumption - fuelStartingConsumption
        local percentUsed = used / usableCapacity * 100
        local remaining = math_max(0, fuelStartingPercent - percentUsed)
        return math_floor(math_min(100, remaining) + 0.5)
    else

        if not voltageStabilised or (stabilizeNotBefore and os_clock() < stabilizeNotBefore) then
            print("Voltage not stabilised or pre-stabilisation delay active, returning nil")
            return nil
        end
        return fuelStartingPercent
    end
end

return {calculate = smartFuelCalc, reset = resetVoltageTracking}

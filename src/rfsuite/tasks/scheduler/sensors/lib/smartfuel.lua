--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local smartfuelprefs = assert(loadfile("tasks/scheduler/sensors/lib/smartfuelprefs.lua"))()

local os_clock = os.clock
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local table_insert = table.insert
local table_remove = table.remove

local batteryConfigCache = nil
local fuelStartingPercent = nil
local fuelStartingConsumption = nil
local lastFuelPercent = nil

local lastVoltages = {}
local maxVoltageSamples = 5
local voltageStableTime = nil
local voltageStabilised = false
local stabilizeNotBefore = nil
local voltageThreshold = 0.15
local telemetry
local lastMode = rfsuite.flightmode.current or "preflight"
local currentMode = rfsuite.flightmode.current or "preflight"
local lastSensorMode
local lastLocalFuelStatus
local wasEverInFlight = false

local function logSmartFuelStatus(status, detail)
    if lastLocalFuelStatus == status then return end
    lastLocalFuelStatus = status

    local logger = rfsuite and rfsuite.utils and rfsuite.utils.log
    if not logger then return end

    local msg = "Smart Fuel local current: " .. status
    if detail then msg = msg .. " (" .. detail .. ")" end
    logger(msg, "info")
    logger(msg, "connect")
end

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
    local a, b = 12, 3.7
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

local function startStabilizeDelay(now)
    local delay = smartfuelprefs.getStabilizeDelaySeconds()
    stabilizeNotBefore = (now or os_clock()) + delay
    return delay
end

local function resetState()
    batteryConfigCache = nil
    fuelStartingPercent = nil
    fuelStartingConsumption = nil
    lastFuelPercent = nil
    stabilizeNotBefore = nil
    lastSensorMode = nil
    lastLocalFuelStatus = nil
    wasEverInFlight = false
    telemetry = nil
    currentMode = rfsuite.flightmode.current or "preflight"
    lastMode = currentMode
    resetVoltageTracking()
end

local function clampFuelBounceback(fuel)
    if fuel == nil then return nil end
    if lastFuelPercent ~= nil and fuel > lastFuelPercent then
        fuel = lastFuelPercent
    end
    lastFuelPercent = fuel
    return fuel
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

local function smartFuelCalc()

    if not telemetry then telemetry = rfsuite.tasks.telemetry end

    local batType = telemetry and telemetry.getSensor and telemetry.getSensor("battery_profile")
    local normalizedBatType = normalizeBatteryProfileIndex(batType)
    if normalizedBatType ~= nil then
        rfsuite.session.activeBatteryType = normalizedBatType
    end

    if not rfsuite.session.isConnected or not rfsuite.session.batteryConfig then
        resetState()
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
        lastFuelPercent = nil
        resetVoltageTracking()
        local delay = startStabilizeDelay()
        logSmartFuelStatus("battery config changed", "delay=" .. tostring(delay))
    end

    local sensorMode = smartfuelprefs.getSource()
    if lastSensorMode ~= sensorMode then
        fuelStartingPercent = nil
        fuelStartingConsumption = nil
        lastFuelPercent = nil
        resetVoltageTracking()
        lastSensorMode = sensorMode
        local delay = startStabilizeDelay()
        logSmartFuelStatus("local source changed", "source=" .. tostring(sensorMode) .. " delay=" .. tostring(delay))
        return nil
    end

    local voltage = telemetry and telemetry.getSensor and telemetry.getSensor("voltage") or nil

    if not voltage or voltage < 2 then
        resetVoltageTracking()
        stabilizeNotBefore = nil
        logSmartFuelStatus("waiting for voltage")
        return nil
    end

    local now = os_clock()
    currentMode = rfsuite.flightmode.current or "preflight"

    if shouldResetForModeChange(lastMode, currentMode) then
        rfsuite.utils.log("Flight mode changed – resetting voltage & fuel state", "info")

        fuelStartingPercent = nil
        fuelStartingConsumption = nil
        lastFuelPercent = nil
        wasEverInFlight = false

        resetVoltageTracking()

        startStabilizeDelay(now)

        lastMode = currentMode
        logSmartFuelStatus("flight mode reset")
        return nil
    end

    lastMode = currentMode
    if currentMode == "inflight" then wasEverInFlight = true end

    voltageThreshold = smartfuelprefs.getStableWindowVolts()

    if stabilizeNotBefore and now < stabilizeNotBefore then
        logSmartFuelStatus("stabilizing")
        return nil
    end

    table_insert(lastVoltages, voltage)
    if #lastVoltages > maxVoltageSamples then table_remove(lastVoltages, 1) end

    if not voltageStabilised then
        if isVoltageStable() then
            logSmartFuelStatus("voltage stabilized", "voltage=" .. tostring(voltage))
            voltageStabilised = true
        else
            logSmartFuelStatus("waiting for stable voltage", "samples=" .. tostring(#lastVoltages))
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
            lastFuelPercent = nil
            resetVoltageTracking()
            startStabilizeDelay()
            logSmartFuelStatus("voltage increased reset")
            return nil
        end
    end

    local cellCount, maxCellV, minCellV, fullCellV = bc.batteryCellCount, bc.vbatmaxcellvoltage, bc.vbatmincellvoltage, bc.vbatfullcellvoltage

    if packCapacity < 10 or cellCount == 0 or maxCellV <= minCellV or fullCellV <= 0 then
        fuelStartingPercent = nil
        fuelStartingConsumption = nil
        lastFuelPercent = nil
        logSmartFuelStatus("invalid battery config", table.concat({tostring(packCapacity), tostring(cellCount), tostring(maxCellV), tostring(minCellV), tostring(fullCellV)}, "/"))
        return nil
    end

    local consumption = telemetry and telemetry.getSensor and telemetry.getSensor("consumption") or nil

    if not fuelStartingPercent then
        if voltage and cellCount > 0 then

            fuelStartingPercent = fuelPercentageFromVoltage(voltage, cellCount, bc)
        else
            fuelStartingPercent = 0
        end
    end

    if fuelStartingConsumption == nil and consumption ~= nil then
        fuelStartingConsumption = consumption
    end

    if consumption and fuelStartingConsumption and packCapacity > 0 then
        local used = consumption - fuelStartingConsumption
        local percentUsed = used / packCapacity * 100
        local remaining = fuelStartingPercent - percentUsed
        if not smartfuelprefs.getEndAtZeroEnabled() or not wasEverInFlight then
            logSmartFuelStatus("ready", "consumption")
            return clampFuelBounceback(math_floor(math_min(100, math_max(0, remaining)) + 0.5))
        end

        local warningPercent = bc.consumptionWarningPercentage or 0
        local usableRange = math_max(1, 100 - warningPercent)
        local adjusted = math_max(0, remaining - warningPercent)
        logSmartFuelStatus("ready", "consumption")
        return clampFuelBounceback(math_floor(math_min(100, adjusted / usableRange * 100) + 0.5))
    else

        if not voltageStabilised or (stabilizeNotBefore and os_clock() < stabilizeNotBefore) then
            logSmartFuelStatus("waiting for fallback fuel")
            return nil
        end
        logSmartFuelStatus("ready", "voltage estimate")
        return clampFuelBounceback(fuelStartingPercent)
    end
end

return {calculate = smartFuelCalc, reset = resetState}

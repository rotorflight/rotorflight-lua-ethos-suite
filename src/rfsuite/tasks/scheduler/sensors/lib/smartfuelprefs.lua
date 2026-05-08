--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local prefs = {}

local tonumber = tonumber

local function getBatteryPrefs()
    local modelPreferences = rfsuite.session and rfsuite.session.modelPreferences
    return modelPreferences and modelPreferences.battery or nil
end

local function getNumericField(batteryPrefs, key, fallback)
    if not batteryPrefs then return fallback end
    local value = tonumber(batteryPrefs[key])
    if value == nil then return fallback end
    return value
end

local function getScaledField(key, fallback, minValue, maxValue, scale)
    local value = getNumericField(getBatteryPrefs(), key, fallback)
    if value == nil then return fallback end

    if scale and scale > 1 and maxValue and value > maxValue then
        local guard = 0
        while value > maxValue and guard < 4 do
            value = value / scale
            guard = guard + 1
        end
    end

    if minValue and value < minValue then return minValue end
    if maxValue and value > maxValue then return maxValue end
    return value
end

function prefs.getSource()
    local batteryPrefs = getBatteryPrefs()
    local source = getNumericField(batteryPrefs, "smartfuel_source", nil)
    if source ~= nil then
        return source
    end
    return getNumericField(batteryPrefs, "calc_local", 0)
end

function prefs.getStabilizeDelaySeconds()
    return getScaledField("stabilize_delay", 1500, 0, 10000, 1000) / 1000
end

function prefs.getStableWindowVolts()
    return getScaledField("stable_window", 15, 0, 100, 100) / 100
end

function prefs.getVoltageFallPerSecond()
    return getScaledField("voltage_fall_limit", 5, 0, 100, 100) / 100
end

function prefs.getFuelDropPerSecond()
    return getScaledField("fuel_drop_rate", 10, 0, 500, 10) / 10
end

function prefs.getSagMultiplier()
    local batteryPrefs = getBatteryPrefs()
    local sagMultiplierPercent = getScaledField("sag_multiplier_percent", nil, 0, 200, 100)
    if sagMultiplierPercent ~= nil then
        return sagMultiplierPercent / 100
    end
    return getNumericField(batteryPrefs, "sag_multiplier", 0.7)
end

return prefs

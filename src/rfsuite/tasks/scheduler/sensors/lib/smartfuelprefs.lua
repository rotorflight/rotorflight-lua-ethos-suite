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

function prefs.getSource()
    local batteryPrefs = getBatteryPrefs()
    local source = getNumericField(batteryPrefs, "smartfuel_source", nil)
    if source ~= nil then
        return source
    end
    return getNumericField(batteryPrefs, "calc_local", 0)
end

function prefs.getStabilizeDelaySeconds()
    return getNumericField(getBatteryPrefs(), "stabilize_delay", 1500) / 1000
end

function prefs.getStableWindowVolts()
    return getNumericField(getBatteryPrefs(), "stable_window", 15) / 100
end

function prefs.getVoltageFallPerSecond()
    return getNumericField(getBatteryPrefs(), "voltage_fall_limit", 5) / 100
end

function prefs.getFuelDropPerSecond()
    return getNumericField(getBatteryPrefs(), "fuel_drop_rate", 10) / 10
end

function prefs.getFuelRisePerSecond()
    return getNumericField(getBatteryPrefs(), "fuel_rise_rate", 2) / 10
end

function prefs.getSagMultiplier()
    local batteryPrefs = getBatteryPrefs()
    local sagMultiplierPercent = getNumericField(batteryPrefs, "sag_multiplier_percent", nil)
    if sagMultiplierPercent ~= nil then
        return sagMultiplierPercent / 100
    end
    return getNumericField(batteryPrefs, "sag_multiplier", 0.7)
end

return prefs

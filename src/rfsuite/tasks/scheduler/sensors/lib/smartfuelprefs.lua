--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local prefs = {}

local tonumber = tonumber

-- Settle-time parameters are no longer user-editable; values here are the fixed defaults.
local STABILIZE_DELAY_SECONDS = 1.5
local STABLE_WINDOW_VOLTS     = 0.15

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
    if source == nil then
        source = getNumericField(batteryPrefs, "calc_local", 0)
    end
    if source >= 0 and source <= 2 then return source end
    return 0
end

function prefs.getEndAtZeroEnabled()
    return getNumericField(getBatteryPrefs(), "smartfuel_end_at_zero", 1) ~= 0
end

-- Returns the fixed stabilize delay (seconds). No longer INI-backed.
function prefs.getStabilizeDelaySeconds()
    return STABILIZE_DELAY_SECONDS
end

-- Returns the fixed stable-window threshold (volts). No longer INI-backed.
function prefs.getStableWindowVolts()
    return STABLE_WINDOW_VOLTS
end

-- Returns voltage slew-down limit in V/s (firmware: voltage_drop_rate mV/s ÷ 1000).
function prefs.getVoltageFallPerSecond()
    return getScaledField("voltage_drop_rate", 10, 0, 250, nil) / 1000
end

-- Returns charge slew-down limit as a fraction/s (firmware: charge_drop_rate ÷ 10000).
function prefs.getChargeDropRatePerSecond()
    return getScaledField("charge_drop_rate", 50, 0, 250, 100) / 10000
end

-- Returns sag-gain as a 0.0–1.0 multiplier (firmware: sag_gain% ÷ 100).
function prefs.getSagGain()
    return getScaledField("sag_gain", 40, 0, 100, nil) / 100
end

return prefs

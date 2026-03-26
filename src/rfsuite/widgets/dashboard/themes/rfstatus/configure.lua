--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local floor = math.floor
local pairs = pairs
local tonumber = tonumber

local config = {}
local THEME_DEFAULTS = {v_min = 18.0, v_max = 25.2}

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function getPref(key) return rfsuite.widgets.dashboard.getPreference(key) end

local function setPref(key, value) rfsuite.widgets.dashboard.savePreference(key, value) end

local formFields = {}
local prevConnectedState = nil

local function isTelemetryConnected() return rfsuite and rfsuite.session and rfsuite.session.isConnected and rfsuite.session.mcu_id and rfsuite.preferences end

local function configure()
    for k, v in pairs(THEME_DEFAULTS) do
        local val = tonumber(getPref(k))
        config[k] = val or v
    end

    local voltage_panel = form.addExpansionPanel("@i18n(widgets.dashboard.voltage)@")
    voltage_panel:open(true)

    local voltage_min_line = voltage_panel:addLine("@i18n(widgets.dashboard.min)@")
    formFields[#formFields + 1] = form.addNumberField(voltage_min_line, nil, 50, 650, function()
        local v = config.v_min or THEME_DEFAULTS.v_min
        return floor((v * 10) + 0.5)
    end, function(val)
        local min_val = val / 10
        config.v_min = clamp(min_val, 5, config.v_max - 0.1)
    end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

    local voltage_max_line = voltage_panel:addLine("@i18n(widgets.dashboard.max)@")
    formFields[#formFields + 1] = form.addNumberField(voltage_max_line, nil, 50, 650, function()
        local v = config.v_max or THEME_DEFAULTS.v_max
        return floor((v * 10) + 0.5)
    end, function(val)
        local max_val = val / 10
        config.v_max = clamp(max_val, config.v_min + 0.1, 65)
    end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

end

local function write() for k, v in pairs(config) do setPref(k, v) end end

return {configure = configure, write = write}

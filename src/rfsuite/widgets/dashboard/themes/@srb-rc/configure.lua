--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local floor = math.floor
local pairs = pairs
local tonumber = tonumber

local config = {}

local THEME_DEFAULTS = {bec_warn = 6.5, esctemp_warn = 90, esctemp_max = 200}

local function clamp(val, min, max)
    if val < min then
        return min
    end
    if val > max then
        return max
    end
    return val
end

local function getPref(key)
    return rfsuite.widgets.dashboard.getPreference(key)
end

local function setPref(key, value)
    rfsuite.widgets.dashboard.savePreference(key, value)
end

local formFields = {}
local prevConnectedState = nil

local function isTelemetryConnected()
    return rfsuite and rfsuite.session and rfsuite.session.isConnected and rfsuite.session.mcu_id and rfsuite.preferences
end

local function configure()

    for k, v in pairs(THEME_DEFAULTS) do
        local val = tonumber(getPref(k))
        config[k] = val or v
    end

    local bec_panel = form.addExpansionPanel("BEC Voltage")
    bec_panel:open(true)

    local bec_warn_line = bec_panel:addLine("Warning")
    formFields[#formFields + 1] = form.addNumberField(bec_warn_line, nil, 65, 150, function()
        local v = config.bec_warn or THEME_DEFAULTS.bec_warn
        return floor((v * 10) + 0.5)
    end, function(val)
        local warn_val = val / 10
        config.bec_warn = warn_val
    end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

    local esc_panel = form.addExpansionPanel("ESC Temp")
    esc_panel:open(true)
    local esc_warn_line = esc_panel:addLine("Warning")
    formFields[#formFields + 1] = form.addNumberField(esc_warn_line, nil, 0, 200, function() return config.esctemp_warn end, function(val) config.esctemp_warn = clamp(tonumber(val) or THEME_DEFAULTS.esctemp_warn, 0, config.esctemp_max - 1) end, 1)
    formFields[#formFields]:suffix("°")
end

local function write()
    for k, v in pairs(config) do
        setPref(k, v)
    end
end

return {configure = configure, write = write}

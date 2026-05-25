--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local floor = math.floor
local pairs = pairs
local tonumber = tonumber

local config = {}

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 3000, bec_min = 3.0, bec_warn = 6.0, bec_max = 13.0, esctemp_warn = 90, esctemp_max = 140}

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
        if k == "bec_min" or k == "bec_max" then
            if not val or val < 2 or val > 15 then
                config[k] = v
                setPref(k, v)
            else
                config[k] = val
            end
        else
            config[k] = val or v
        end
    end

    local rpm_panel = form.addExpansionPanel("@i18n(widgets.dashboard.headspeed)@")
    rpm_panel:open(false)
    local rpm_min_line = rpm_panel:addLine("@i18n(widgets.dashboard.min)@")
    formFields[#formFields + 1] = form.addNumberField(rpm_min_line, nil, 0, 20000, function() return config.rpm_min end, function(val) config.rpm_min = clamp(tonumber(val) or THEME_DEFAULTS.rpm_min, 0, config.rpm_max - 1) end, 1)
    formFields[#formFields]:suffix("rpm")

    local rpm_max_line = rpm_panel:addLine("@i18n(widgets.dashboard.max)@")
    formFields[#formFields + 1] = form.addNumberField(rpm_max_line, nil, 1, 20000, function() return config.rpm_max end, function(val) config.rpm_max = clamp(tonumber(val) or THEME_DEFAULTS.rpm_max, config.rpm_min + 1, 20000) end, 1)
    formFields[#formFields]:suffix("rpm")

    local bec_panel = form.addExpansionPanel("@i18n(widgets.dashboard.bec_voltage)@")
    bec_panel:open(false)
    local bec_min_line = bec_panel:addLine("@i18n(widgets.dashboard.min)@")
    formFields[#formFields + 1] = form.addNumberField(bec_min_line, nil, 20, 150, function()
        local v = config.bec_min or THEME_DEFAULTS.bec_min
        return floor((v * 10) + 0.5)
    end, function(val)
        local min_val = val / 10
        config.bec_min = clamp(min_val, 2, config.bec_max - 0.1)
    end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

    local bec_warn_line = bec_panel:addLine("@i18n(widgets.dashboard.warning)@")
    formFields[#formFields + 1] = form.addNumberField(bec_warn_line, nil, 20, 150, function()
        local v = config.bec_warn or THEME_DEFAULTS.bec_warn
        return floor((v * 10) + 0.5)
    end, function(val)
        local warn_val = val / 10
        config.bec_warn = clamp(warn_val, config.bec_min + 0.1, config.bec_max - 0.1)
    end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

    local bec_max_line = bec_panel:addLine("@i18n(widgets.dashboard.max)@")
    formFields[#formFields + 1] = form.addNumberField(bec_max_line, nil, 20, 150, function()
        local v = config.bec_max or THEME_DEFAULTS.bec_max
        return floor((v * 10) + 0.5)
    end, function(val)
        local max_val = val / 10
        config.bec_max = clamp(max_val, config.bec_min + 0.1, 15)
    end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

    local esc_panel = form.addExpansionPanel("@i18n(widgets.dashboard.esc_temp)@")
    esc_panel:open(false)
    local esc_warn_line = esc_panel:addLine("@i18n(widgets.dashboard.warning)@")
    formFields[#formFields + 1] = form.addNumberField(esc_warn_line, nil, 0, 200, function() return config.esctemp_warn end, function(val) config.esctemp_warn = clamp(tonumber(val) or THEME_DEFAULTS.esctemp_warn, 0, config.esctemp_max - 1) end, 1)
    formFields[#formFields]:suffix("°")

    local esc_max_line = esc_panel:addLine("@i18n(widgets.dashboard.max)@")
    formFields[#formFields + 1] = form.addNumberField(esc_max_line, nil, 1, 200, function() return config.esctemp_max end, function(val) config.esctemp_max = clamp(tonumber(val) or THEME_DEFAULTS.esctemp_max, config.esctemp_warn + 1, 200) end, 1)
    formFields[#formFields]:suffix("°")
end

local function write() for k, v in pairs(config) do setPref(k, v) end end

return {configure = configure, write = write}

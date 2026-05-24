--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html

  @claude — theme configuration
  Pilots can set their helicopter's max headspeed and override the voltage range.
]] --

local rfsuite = require("rfsuite")

local floor    = math.floor
local pairs    = pairs
local tonumber = tonumber

local config = {}
local THEME_DEFAULTS = {rpm_max = 3000, v_min = 0.0, v_max = 0.0}

local function clamp(val, lo, hi)
    if val < lo then return lo end
    if val > hi then return hi end
    return val
end

local function getPref(key)   return rfsuite.widgets.dashboard.getPreference(key) end
local function setPref(key, v) rfsuite.widgets.dashboard.savePreference(key, v) end

local formFields = {}

local function configure()
    for k, v in pairs(THEME_DEFAULTS) do
        local val = tonumber(getPref(k))
        config[k] = val or v
    end

    -- ── Headspeed ──────────────────────────────────────────────────────
    local hs_panel = form.addExpansionPanel("Headspeed")
    hs_panel:open(true)

    local rpm_max_line = hs_panel:addLine("Max RPM")
    formFields[#formFields + 1] = form.addNumberField(rpm_max_line, nil, 500, 6000, function()
        return floor(config.rpm_max or THEME_DEFAULTS.rpm_max)
    end, function(val)
        config.rpm_max = clamp(val, 500, 6000)
    end)
    formFields[#formFields]:suffix(" rpm")
    formFields[#formFields]:step(50)

    -- ── Voltage range (leave at 0 to auto-detect from battery config) ──
    local v_panel = form.addExpansionPanel("@i18n(widgets.dashboard.voltage)@")
    v_panel:open(false)

    -- Helper note: 0 = auto-detect
    local v_min_line = v_panel:addLine("@i18n(widgets.dashboard.min)@ (0 = auto)")
    formFields[#formFields + 1] = form.addNumberField(v_min_line, nil, 0, 650, function()
        return floor(((config.v_min or 0) * 10) + 0.5)
    end, function(val)
        config.v_min = clamp(val / 10, 0, 65)
    end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")

    local v_max_line = v_panel:addLine("@i18n(widgets.dashboard.max)@ (0 = auto)")
    formFields[#formFields + 1] = form.addNumberField(v_max_line, nil, 0, 650, function()
        return floor(((config.v_max or 0) * 10) + 0.5)
    end, function(val)
        config.v_max = clamp(val / 10, 0, 65)
    end)
    formFields[#formFields]:decimals(1)
    formFields[#formFields]:suffix("V")
end

local function write()
    for k, v in pairs(config) do setPref(k, v) end
end

return {configure = configure, write = write}

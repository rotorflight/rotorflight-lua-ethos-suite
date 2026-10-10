--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html

  kse5 — theme configuration
  Full-scale values for the headspeed, current and ESC temperature rings.
]] --

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")

local floor = math.floor
local pairs = pairs
local tonumber = tonumber

local config = {}
-- Keep in step with common.lua's DEFAULTS.
local THEME_DEFAULTS = {rpm_max = 3000, current_max = 150, temp_max = 100}

local function clamp(val, lo, hi)
    if val < lo then return lo end
    if val > hi then return hi end
    return val
end

local function getPref(key) return rfsuite.widgets.dashboard.getPreference(key) end
local function setPref(key, v) rfsuite.widgets.dashboard.savePreference(key, v) end

local function addMax(title, key, lo, hi, step, suffix)
    local panel = form.addExpansionPanel(title)
    panel:open(true)
    local line = panel:addLine("@i18n(widgets.dashboard.max)@")
    local field = form.addNumberField(line, nil, lo, hi, function()
        return floor(config[key] or THEME_DEFAULTS[key])
    end, function(val)
        config[key] = clamp(val, lo, hi)
    end)
    field:step(step)
    field:suffix(suffix)
end

local function configure()
    for k, v in pairs(THEME_DEFAULTS) do
        local val = tonumber(getPref(k))
        config[k] = (val and val > 0) and val or v
    end

    addMax("@i18n(widgets.dashboard.headspeed)@", "rpm_max", 500, 6000, 50, " rpm")
    addMax("@i18n(widgets.dashboard.current)@", "current_max", 10, 500, 5, " A")
    addMax("@i18n(widgets.dashboard.esc_temp)@", "temp_max", 40, 150, 5, " °C")
end

local function write()
    for k, v in pairs(config) do setPref(k, v) end
end

return {configure = configure, write = write}

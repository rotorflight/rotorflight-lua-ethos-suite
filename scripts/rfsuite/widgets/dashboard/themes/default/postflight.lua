--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local i18n = rfsuite.i18n.get
local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local function maxVoltageToCellVoltage(value)
    local cfg = rfsuite.session.batteryConfig
    local cells = (cfg and cfg.batteryCellCount) or 3

    if cfg and cells and value then
        value = math.max(0, value / cells)
        value = math.floor(value * 100 + 0.5) / 100  -- round to 2 decimal places
    end

    return value
end

-- Theme based configuration settings
local theme_section = "system/default"

local THEME_DEFAULTS = {
    v_min = 18.0,
    v_max = 25.2,
}

-- Theme Options based on screen width
local function getThemeOptionKey(W)
    if     W == 800 then return "ls_full"
    elseif W == 784 then return "ls_std"
    elseif W == 640 then return "ss_full"
    elseif W == 630 then return "ss_std"
    elseif W == 480 then return "ms_full"
    elseif W == 472 then return "ms_std"
    end
end

local function getThemeValue(key)
    -- Use General preferences for TX values
    if key == "tx_min" or key == "tx_warn" or key == "tx_max" then
        if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
            local val = rfsuite.preferences.general[key]
            if val ~= nil then return tonumber(val) end
        end
    end
    -- Theme defaults for other values
    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then return val end
    end
    return THEME_DEFAULTS[key]
end

-- Theme Options based on screen size
local themeOptions = {

    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    ls_full = {
        font = "FONT_XXL", 
    },

    ls_std  = {
        font = "FONT_XL", 
    },

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = {
        font = "FONT_XXL", 
    },

    ms_std  = {
        font = "FONT_XL", 
    },

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = {
        font = "FONT_XL", 
    },

    ss_std  = {
        font = "FONT_XL", 
    },
}

-- Caching for boxes
local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil

-- Theme Layout
local layout = {
    cols    = 2,
    rows    = 2,
    padding = 2,
    --showgrid = lcd.RGB(100, 100, 100)  -- or any color you prefer
}

-- Header Layout
local header_layout = utils.standardHeaderLayout(headeropts)

-- Header Boxes
local last_header_pref = {}

local function header_boxes()
    -- Header Cache: compare relevant general prefs
    local gp = rfsuite and rfsuite.preferences and rfsuite.preferences.general or {}
    local tx_min = tonumber(gp.tx_min)
    local tx_warn = tonumber(gp.tx_warn)
    local tx_max = tonumber(gp.tx_max)
    -- Only re-build if any have changed
    if not header_boxes_cache or last_header_pref.tx_min ~= tx_min or last_header_pref.tx_warn ~= tx_warn or last_header_pref.tx_max ~= tx_max then
        header_boxes_cache = utils.standardHeaderBoxes(i18n, colorMode, headeropts, getThemeValue)
        last_header_pref.tx_min = tx_min
        last_header_pref.tx_warn = tx_warn
        last_header_pref.tx_max = tx_max
    end
    return header_boxes_cache
end

-- Boxes
local function buildBoxes(W)
    
    -- Object based options determined by screensize
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.unknown

    return {
        -- Flight info and RPM info
        {col = 1, row = 1, type = "time", subtype = "flight", font = opts.font, title = i18n("widgets.dashboard.flight_duration"), titlepos = "bottom", bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
        {col = 1, row = 2, type = "time", subtype = "total", font = opts.font, title = i18n("widgets.dashboard.total_flight_duration"), titlepos = "bottom", bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},

        -- Flight max/min stats 2
        {col = 2, row = 1, type = "text", subtype = "stats", font = opts.font, stattype = "min", source = "voltage", title = i18n("widgets.dashboard.min_volts_cell"), titlepos = "bottom", bgcolor = colorMode.bgcolor, unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
        {col = 2, row = 2, type = "text", subtype = "stats", font = opts.font, stattype = "min", source = "link", title = i18n("widgets.dashboard.link_min"), titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    }

end

local function boxes()
    local W = lcd.getWindowSize()
    if boxes_cache == nil or lastScreenW ~= W then
        boxes_cache = buildBoxes(W)
        lastScreenW = W
    end
    return boxes_cache
end

return {
  layout = layout,
  boxes = boxes,
  header_boxes = header_boxes,
  header_layout = header_layout,
  scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
  }    
}

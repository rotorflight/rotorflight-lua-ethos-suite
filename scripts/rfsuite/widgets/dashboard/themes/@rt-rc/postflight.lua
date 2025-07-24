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
local theme_section = "system/@rt-rc"

local THEME_DEFAULTS = {
    v_min      = 18.0,
    v_max      = 25.2,
}

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

-- Theme Options based on screen size
local themeOptions = {

    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    ls_full = {
        font = "FONT_XXL", 
        titlefont = "FONT_S", 
        valuepaddingtop = 15
    },

    ls_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XS", 
        valuepaddingtop = 10
    },

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = {
        font = "FONT_XL", 
        titlefont = "FONT_XXS", 
        valuepaddingtop = 15
    },

    ms_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XXS", 
        valuepaddingtop = 10
    },

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = {
        font = "FONT_XL", 
        titlefont = "FONT_XS", 
        valuepaddingtop = 0
    },

    ss_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XXS", 
        valuepaddingtop = 0
    },
}

-- Caching for boxes
local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local last_txbatt_type = nil

-- Theme Layout
local layout = {
    cols    = 6,
    rows    = 12,
    padding = 2,
    --showgrid = lcd.RGB(100, 100, 100)  -- or any color you prefer
}

-- Header Layout
local header_layout = utils.standardHeaderLayout(headeropts)

-- Header Boxes
local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end

    -- Rebuild cache if type changed
    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        header_boxes_cache = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

-- Boxes
local function buildBoxes(W)
    
    -- Object based options determined by screensize
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.unknown

    return{
-- Flight info and RPM info
        {col = 1, row = 1, colspan = 2, rowspan = 3, type = "time", subtype = "flight", title = i18n("widgets.dashboard.flight_duration"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 1, row = 4, colspan = 2, rowspan = 3, type = "time", subtype = "total", title = i18n("widgets.dashboard.total_flight_duration"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 1, row = 7, colspan = 2, rowspan = 3, type = "text", subtype = "stats", stattype = "min", source = "rpm", title = i18n("widgets.dashboard.rpm_min"), unit = " rpm", titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 1, row = 10, colspan = 2, rowspan = 3, type = "text", subtype = "stats", source = "rpm", title = i18n("widgets.dashboard.rpm_max"), unit = " rpm", titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont},

        -- Flight max/min stats 1
        {col = 3, row = 1, colspan = 2, rowspan = 3, type = "text", subtype = "stats", source = "throttle_percent", title = i18n("widgets.dashboard.throttle_max"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 3, row = 4, colspan = 2, rowspan = 3, type = "text", subtype = "stats", source = "current", title = i18n("widgets.dashboard.current_max"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 3, row = 7, colspan = 2, rowspan = 3, type = "text", subtype = "stats", source = "temp_esc", title = i18n("widgets.dashboard.esc_max_temp"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 3, row = 10, colspan = 2, rowspan = 3, type = "text", subtype = "watts", source = "max", title = i18n("widgets.dashboard.watts_max"), unit = "W", titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont},

        -- Flight max/min stats 2
        {col = 5, row = 1, colspan = 2, rowspan = 3, type = "text", subtype = "stats", stattype = "max", source = "consumption", title = i18n("widgets.dashboard.consumed_mah"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 5, row = 4, colspan = 2, rowspan = 3, type = "text", subtype = "stats", stattype = "min", source = "smartfuel", title = i18n("widgets.dashboard.fuel_remaining"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 5, row = 7, colspan = 2, rowspan = 3, type = "text", subtype = "stats", stattype = "min", source = "voltage", title = i18n("widgets.dashboard.min_volts_cell"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 5, row = 10, colspan = 2, rowspan = 3, type = "text", subtype = "telemetry", source = "voltage", title = i18n("widgets.dashboard.volts_per_cell"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, valuepaddingtop = opts.valuepaddingtop, unit = "V", font = opts.font, titlefont = opts.titlefont, transform = function(v) return maxVoltageToCellVoltage(v) end},       
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

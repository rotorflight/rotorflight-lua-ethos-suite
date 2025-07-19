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
local boxes_cache = nil
local lastScreenW = nil

local function maxVoltageToCellVoltage(value)
    local cfg = rfsuite.session.batteryConfig
    local cells = (cfg and cfg.batteryCellCount) or 3

    if cfg and cells and value then
        value = math.max(0, value / cells)
        value = math.floor(value * 100 + 0.5) / 100  -- round to 2 decimal places
    end

    return value
end

local darkMode = {
    textcolor       = "white",
    titlecolor      = "white",
    bgcolor         = "black",
    fillcolor       = "green",
    fillbgcolor     = "darkgrey",
    accentcolor     = "white",
    rssifillcolor   = "green",
    rssifillbgcolor = "darkgrey",
    txaccentcolor   = "grey",
    txfillcolor     = "green",
    txbgfillcolor   = "darkgrey"
}

local lightMode = {
    textcolor       = "black",
    titlecolor      = "black",
    bgcolor         = "white",
    fillcolor       = "green",
    fillbgcolor     = "lightgrey",
    accentcolor     = "darkgrey",
    rssifillcolor   = "green",
    rssifillbgcolor = "grey",
    txaccentcolor   = "darkgrey",
    txfillcolor     = "green",
    txbgfillcolor   = "grey"
}

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

-- Theme config support
local theme_section = "system/@aerc"

local THEME_DEFAULTS = {
    rpm_min      = 0,
    rpm_max      = 3000,
    bec_min      = 3.0,
    bec_max      = 13.0,
    esctemp_warn = 90,
    esctemp_max  = 140,
    tx_min       = 7.2,
    tx_warn      = 7.4,
    tx_max       = 8.4
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

-- Theme Options based on screen size
local themeOptions = {

    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    ls_full = {
        font = "FONT_XXL", 
        titlefont = "FONT_S", 
        valuepaddingbottom = 20, 
        titlepaddingtop = 15
    },

    ls_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XS", 
        valuepaddingbottom = 25, 
        titlepaddingtop = 0},

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = {
        font = "FONT_XL", 
        titlefont = "FONT_XS", 
        valuepaddingbottom = 15, 
        titlepaddingtop = 5
    },

    ms_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XXS", 
        valuepaddingbottom = 0, 
        titlepaddingtop = 0
    },

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = {
        font = "FONT_XL", 
        titlefont = "FONT_XS", 
        valuepaddingbottom = 15, 
        titlepaddingtop = 5
    },

    ss_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XXS", 
        valuepaddingbottom = 0, 
        titlepaddingtop = 0
    },
}

local function getThemeValue(key)
    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then return val end
    end
    return THEME_DEFAULTS[key]
end

-- Caching for boxes
local lastScreenW = nil
local boxes_cache = nil
local themeconfig = nil
local headeropts = utils.getHeaderOptions()

-- Theme Layout
local layout = {
    cols    = 3,
    rows    = 8,
}

local header_layout = {
    height  = headeropts.height,
    cols    = 7,
    rows    = 1,
}

-- Boxes
local function buildBoxes(W)

    -- Object based options determined by screensize
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.unknown

    return {    
        -- Flight info and RPM info
        {col = 1, row = 1, rowspan = 2, type = "time", subtype = "flight", title = i18n("widgets.dashboard.flight_duration"), titlepos = "top", titlepaddingtop = opts.titlepaddingtop,
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange"},

        {col = 1, row = 3, rowspan = 2, type = "time", subtype = "total", title = i18n("widgets.dashboard.total_flight_duration"), titlepos = "top", titlepaddingtop = opts.titlepaddingtop, 
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange"},

        {col = 1, row = 5, rowspan = 2, type = "time", subtype = "count", title = i18n("widgets.dashboard.flights"), titlepos = "top", titlepaddingtop = opts.titlepaddingtop, 
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

        {col = 1, row = 7, rowspan = 2, type = "text", subtype = "stats", source = "rpm", title = i18n("widgets.dashboard.rpm_max"), unit = " rpm", titlepos = "top", titlepaddingtop = opts.titlepaddingtop, 
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

        -- Flight max/min stats 1
        {col = 2, row = 1, rowspan = 2, type = "text", subtype = "watts", source = "max", title = i18n("widgets.dashboard.watts_max"), unit = "W", titlepos = "top", titlepaddingtop = opts.titlepaddingtop, 
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},

        {col = 2, row = 3, rowspan = 2, type = "text", subtype = "stats", source = "current", title = i18n("widgets.dashboard.current_max"), titlepos = "top", titlepaddingtop = opts.titlepaddingtop, 
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

        {col = 2, row = 5, rowspan = 2, type = "text", subtype = "stats", source = "temp_esc", title = i18n("widgets.dashboard.esc_max_temp"), titlepos = "top", titlepaddingtop = opts.titlepaddingtop, 
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

        {col = 2, row = 7, rowspan = 2, type = "text", subtype = "stats", source = "altitude", title = i18n("widgets.dashboard.altitude_max"), titlepos = "top", titlepaddingtop = opts.titlepaddingtop, 
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

        -- Flight max/min stats 2
        {col = 3, row = 1, rowspan = 2, type = "text", subtype = "stats", stattype = "max", source = "consumption", title = i18n("widgets.dashboard.consumed_mah"), titlepos = "top", titlepaddingtop = opts.titlepaddingtop, 
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

        {col = 3, row = 3, rowspan = 2, type = "text", subtype = "stats", stattype = "min", source = "smartfuel", title = i18n("widgets.dashboard.fuel_remaining"), titlepos = "top", titlepaddingtop = opts.titlepaddingtop,
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

        {col = 3, row = 5, rowspan = 2, type = "text", subtype = "telemetry", source = "voltage", title = i18n("widgets.dashboard.volts_per_cell"), titlepos = "top", titlepaddingtop = opts.titlepaddingtop, 
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end},

        {col = 3, row = 7, rowspan = 2, type = "text", subtype = "stats", stattype = "min", source = "rssi", title = i18n("widgets.dashboard.link_min"), titlepos = "top", titlepaddingtop = opts.titlepaddingtop,
        font = opts.font, titlefont = opts.titlefont, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
    }
end

local header_boxes = {
-- Craftname
    { 
        col = 1, 
        row = 1, 
        colspan = 2, 
        type = "text", 
        subtype = "craftname",
        font = headeropts.font, 
        valuealign = "left", 
        valuepaddingleft = 5,
        bgcolor = colorMode.bgcolor, 
        titlecolor = colorMode.titlecolor, 
        textcolor = colorMode.textcolor 
    },

    -- RF Logo
    { 
        col = 3, 
        row = 1, 
        colspan = 3, 
        type = "image", 
        subtype = "image",
        bgcolor = colorMode.bgcolor 
    },

    -- TX Battery
    { 
        col = 6, 
        row = 1,
        type = "gauge", 
        subtype = "bar", 
        source = "txbatt",
        font = headeropts.font,
        battery = true, 
        batteryframe = true, 
        hidevalue = true,
        valuealign = "left", 
        batterysegments = 4, 
        batteryspacing = 1, 
        batteryframethickness  = 2,
        batterysegmentpaddingtop = headeropts.batterysegmentpaddingtop,
        batterysegmentpaddingbottom = headeropts.batterysegmentpaddingbottom,
        batterysegmentpaddingleft = headeropts.batterysegmentpaddingleft,
        batterysegmentpaddingright = headeropts.batterysegmentpaddingright,
        gaugepaddingright = headeropts.gaugepaddingright,
        gaugepaddingleft = headeropts.gaugepaddingleft,
        gaugepaddingbottom = headeropts.gaugepaddingbottom,
        gaugepaddingtop = headeropts.gaugepaddingtop,
        fillbgcolor = colorMode.txbgfillcolor, 
        bgcolor = colorMode.bgcolor,
        accentcolor = colorMode.txaccentcolor, 
        textcolor = colorMode.textcolor,
        min = getThemeValue("tx_min"), 
        max = getThemeValue("tx_max"), 
        thresholds = {
            { value = getThemeValue("tx_warn"), fillcolor = "orange" },
            { value = getThemeValue("tx_max"), fillcolor = colorMode.txfillcolor }
        }
    },

    -- RSSI
    { 
        col = 7, 
        row = 1,
        type = "gauge", 
        subtype = "step", 
        source = "rssi",
        font = "FONT_XS", 
        stepgap = 2, 
        stepcount = 5, 
        decimals = 0,
        valuealign = "left",
        barpaddingleft = headeropts.barpaddingleft,
        barpaddingright = headeropts.barpaddingright,
        barpaddingbottom = headeropts.barpaddingbottom,
        barpaddingtop = headeropts.barpaddingtop,
        valuepaddingleft = headeropts.valuepaddingleft,
        valuepaddingbottom = headeropts.valuepaddingbottom,
        bgcolor = colorMode.bgcolor, 
        textcolor = colorMode.textcolor, 
        fillcolor = colorMode.rssifillcolor,
        fillbgcolor = colorMode.rssifillbgcolor,
    },
}

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

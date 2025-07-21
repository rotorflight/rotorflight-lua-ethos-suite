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

local darkMode = {
    textcolor       = "white",
    titlecolor      = "white",
    bgcolor         = "black",
    fillcolor       = "green",
    fillwarncolor   = "orange",
    fillcritcolor   = "red",
    fillbgcolor     = "grey",
    accentcolor     = "white",
    rssifillcolor   = "green",
    rssifillbgcolor = "darkgrey",
    txaccentcolor   = "grey",
    txfillcolor     = "green",
    txbgfillcolor   = "darkgrey",
    bgcolortop      = "black",
    cntextcolor     = "white",
    rssitextcolor   = "white"
}

local lightMode = {
    textcolor       = "lmgrey",
    titlecolor      = "lmgrey",
    bgcolor         = "white",
    fillcolor       = "lightgreen",
    fillwarncolor   = "lightorange",
    fillcritcolor   = "lightred",
    fillbgcolor     = "lightgrey",
    accentcolor     = "darkgrey",
    rssifillcolor   = "lightgreen",
    rssifillbgcolor = "grey",
    txaccentcolor   = "white",
    txfillcolor     = "lightgreen",
    txbgfillcolor   = "grey",
    bgcolortop      = "darkgrey",
    cntextcolor     = "white",
    rssitextcolor   = "white"
}

local function maxVoltageToCellVoltage(value)
    local cells = 2

    if cells and value then
        value = math.max(0, value / cells)
        value = math.floor(value * 100 + 0.5) / 100  -- round to 2 decimal places
    end

    return value
end

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

-- Theme config support
local theme_section = "system/@aerc-n"

local THEME_DEFAULTS = {
    v_min   = 7.0,
    v_max   = 8.4,
    rpm_min = 0,
    rpm_max = 3000,
    tx_min  = 7.2,
    tx_warn = 7.4,
    tx_max  = 8.4
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
        titlepaddingtop = 15
    },

    ls_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XS", 
        titlepaddingtop = 0
    },

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = {
        font = "FONT_XL", 
        titlefont = "FONT_XXS", 
        titlepaddingtop = 5
    },

    ms_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XXS", 
        titlepaddingtop = 0
    },

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = {
        font = "FONT_XL", 
        titlefont = "FONT_XS", 
        titlepaddingtop = 5
    },

    ss_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XXS", 
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
local headeropts = utils.getHeaderOptions()

-- Theme Layout
local layout = {
    cols    = 6,
    rows    = 12,
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
        {col = 1, row = 1, colspan = 2, rowspan = 4, type = "time", subtype = "flight", title = i18n("widgets.dashboard.flight_duration"), titlefont = opts.titlefont, titlepos = "top", 
        titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, textcolor = "orange", titlecolor = colorMode.titlecolor},

        {col = 1, row = 5, colspan = 2, rowspan = 4, type = "time", subtype = "total", title = i18n("widgets.dashboard.total_flight_duration"), titlefont = opts.titlefont, titlepos = "top", 
        titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, textcolor = "orange", titlecolor = colorMode.titlecolor},

        {col = 1, row = 9, colspan = 2, rowspan = 4, type = "time", subtype = "count", title = i18n("widgets.dashboard.flights"), titlefont = opts.titlefont, titlepos = "top", 
        titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

        {col = 3, row = 1, colspan = 2, rowspan = 4, type = "text", subtype = "stats", stattype = "min", source = "rpm", title = i18n("widgets.dashboard.rpm_min"), titlefont = opts.titlefont, 
        unit = " rpm", titlepos = "top", titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},

        {col = 3, row = 5, colspan = 2, rowspan = 4, type = "text", subtype = "stats", source = "rpm", title = i18n("widgets.dashboard.rpm_max"), unit = " rpm", titlefont = opts.titlefont, titlepos = "top", 
         titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},

        {col = 3, row = 9, colspan = 2, rowspan = 4, type = "text", subtype = "stats", source = "throttle_percent", title = i18n("widgets.dashboard.throttle_max"), titlefont = opts.titlefont, titlepos = "top", 
        titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},
        
        {col = 5, row = 1, colspan = 2, rowspan = 4, type = "text", subtype = "telemetry", source = "bec_voltage", title = i18n("widgets.dashboard.voltage"), titlefont = opts.titlefont, titlepos = "top", 
        titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, unit = "V", textcolor = "orange", titlecolor = colorMode.titlecolor},

        {col = 5, row = 5, colspan = 2, rowspan = 4, type = "text", subtype = "stats", stattype = "min", source = "bec_voltage", title = i18n("widgets.dashboard.min_voltage"), titlefont = opts.titlefont, titlepos = "top", 
        titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end, textcolor = "orange", titlecolor = colorMode.titlecolor},

        {col = 5, row = 9, colspan = 2, rowspan = 4, type = "text", subtype = "stats", source = "altitude", title = i18n("widgets.dashboard.altitude_max"), titlefont = opts.titlefont, titlepos = "top", 
        titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
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
        bgcolor = colorMode.bgcolortop,
        titlecolor = colorMode.titlecolor, 
        textcolor = colorMode.cntextcolor 
    },

    -- RF Logo
    { 
        col = 3, 
        row = 1, 
        colspan = 3, 
        type = "image", 
        subtype = "image",
        bgcolor = colorMode.bgcolortop,
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
        bgcolor = colorMode.bgcolortop,
        accentcolor = colorMode.txaccentcolor, 
        textcolor = colorMode.textcolor,
        min = getThemeValue("tx_min"), 
        max = getThemeValue("tx_max"), 
        thresholds = {
            { value = getThemeValue("tx_warn"), fillcolor = colorMode.fillwarncolor },
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
        bgcolor = colorMode.bgcolortop,
        textcolor = colorMode.rssitextcolor, 
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


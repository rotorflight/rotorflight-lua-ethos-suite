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
local themeconfig = nil
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

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

-- Theme based configuration settings
local theme_section = "system/@aerc"

local THEME_DEFAULTS = {
    rpm_min      = 0,
    rpm_max      = 3000,
    bec_min      = 3.0,
    bec_warn     = 6.0,
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

-- Theme Options based on screen width
local themeOptions = {
    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    ls_full = { 
        font = "FONT_XXL", 
        advfont = "FONT_M", 
        thickness = 25, 
        batteryframethickness = 4, 
        titlepaddingbottom = 15, 
        valuepaddingleft = 25, 
        valuepaddingtop = 20, 
        valuepaddingbottom = 25, 
        gaugepaddingtop = 20, 
        battadvpaddingtop = 20, 
        brvaluepaddingtop = 25
    },

    ls_std  = { 
        font = "FONT_XL", 
        advfont = "FONT_M", 
        thickness = 15, 
        batteryframethickness = 4, 
        titlepaddingbottom = 0, 
        valuepaddingleft = 75, 
        valuepaddingtop = 5, 
        valuepaddingbottom = 25, 
        gaugepaddingtop = 5, 
        battadvpaddingtop = 5, 
        brvaluepaddingtop = 10
    },

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = { 
        font = "FONT_XXL", 
        advfont = "FONT_M", 
        thickness = 17, 
        batteryframethickness = 4, 
        titlepaddingbottom = 0, 
        valuepaddingleft = 20, 
        valuepaddingtop = 5, 
        valuepaddingbottom = 15, 
        gaugepaddingtop = 5, 
        battadvpaddingtop = 5, 
        brvaluepaddingtop = 20
    },

    ms_std  = { 
        font = "FONT_XL", 
        advfont = "FONT_S", 
        thickness = 10, 
        batteryframethickness = 2, 
        titlepaddingbottom = 0, 
        valuepaddingleft = 20, 
        valuepaddingtop = 10, 
        valuepaddingbottom = 25, 
        gaugepaddingtop = 5, 
        battadvpaddingtop = 0, 
        brvaluepaddingtop = 10
    },

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = { 
        font = "FONT_XL", 
        advfont = "FONT_M", 
        thickness = 20,  
        batteryframethickness = 4, 
        titlepaddingbottom = 0, 
        valuepaddingleft = 20, 
        valuepaddingtop = 5, 
        valuepaddingbottom = 15, 
        gaugepaddingtop = 5, 
        battadvpaddingtop = 5, 
        brvaluepaddingtop = 10
    },

    ss_std  = { 
        font = "FONT_XL", 
        advfont = "FONT_S", 
        thickness = 12,  
        batteryframethickness = 2, 
        titlepaddingbottom = 0, 
        valuepaddingleft = 20, 
        valuepaddingtop = 10, 
        valuepaddingbottom = 25, 
        gaugepaddingtop = 5, 
        battadvpaddingtop = 0, 
        brvaluepaddingtop = 10
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
    cols    = 7,
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
        -- Model Image
        {
            col = 1, 
            row = 1, 
            colspan = 3, 
            rowspan = 9, 
            type = "image", 
            subtype = "model", 
            bgcolor = colorMode.bgcolor
        },
        
        -- Rates
        {
            col = 1, 
            row = 10, 
            rowspan = 3,
            type = "text", 
            subtype = "telemetry", 
            source = "rate_profile",
            title = i18n("widgets.dashboard.rates"):upper(), 
            titlepos = "bottom",
            font = "FONT_XL",
            valuepaddingtop = opts.brvaluepaddingtop,
            bgcolor = colorMode.bgcolor, 
            titlecolor = colorMode.titlecolor,
            transform = "floor",
            thresholds = {
                { value = 1.5, textcolor = "blue" },
                { value = 2.5, textcolor = colorMode.fillwarncolor },
                { value = 6,   textcolor = colorMode.fillcolor }
            }
        },

        -- PID
        {
            col = 2, 
            row = 10, 
            rowspan = 3,
            type = "text", 
            subtype = "telemetry", 
            source = "pid_profile",
            title = i18n("widgets.dashboard.profile"):upper(), 
            titlepos = "bottom",
            font = "FONT_XL",
            valuepaddingtop = opts.brvaluepaddingtop,
            bgcolor = colorMode.bgcolor, 
            titlecolor = colorMode.titlecolor,
            transform = "floor",
            thresholds = {
                { value = 1.5, textcolor = "blue" },
                { value = 2.5, colorMode.fillwarncolor },
                { value = 6,   colorMode.fillcolor }
            }
        },
        
        -- Flights
        {
            col = 3, 
            row = 10, 
            rowspan = 3,
            type = "time", 
            subtype = "count",
            title = i18n("widgets.dashboard.flights"):upper(), 
            titlepos = "bottom",
            font = "FONT_XL",
            valuepaddingtop = opts.brvaluepaddingtop,
            bgcolor = colorMode.bgcolor, 
            titlecolor = colorMode.titlecolor, 
            textcolor = colorMode.textcolor,
        },

        -- Fuel Bar
        {
            col = 4, 
            row = 1, 
            colspan = 4, 
            rowspan = 3,
            type = "gauge", 
            source = "smartfuel", 
            batteryframe = true, 
            battadv = true,
            battadvvaluealign = "right",
            battadvpaddingright = 25,
            gaugepaddingbottom = 3,
            gaugepaddingleft = 5, 
            gaugepaddingright = 5,
            valuealign = "left", 
            batteryframethickness = opts.batteryframethickness,
            font = opts.font,
            valuepaddingleft = opts.valuepaddingleft, 
            valuepaddingtop = opts.valuepaddingtop,
            gaugepaddingtop = opts.gaugepaddingtop, 
            battadvfont = opts.advfont, 
            battadvpaddingtop = opts.battadvpaddingtop, 
            fillcolor = colorMode.fillcolor,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor, 
            textcolor = colorMode.textcolor, 
            accentcolor = colorMode.accentcolor,
            transform = "floor",
            thresholds = {
                { value = 10, fillcolor = colorMode.fillcritcolor },
                { value = 30, fillcolor = colorMode.fillwarncolor }
            }
        },

        -- BEC Voltage
        {
            col = 4, 
            colspan = 2, 
            row = 4, 
            rowspan = 6,
            type = "gauge", 
            subtype = "arc", 
            source = "bec_voltage",
            title = i18n("widgets.dashboard.bec_voltage"):upper(), 
            titlepos = "bottom",
            decimals = 1,         
            titlepaddingbottom = opts.titlepaddingbottom,
            font = opts.font,
            min = getThemeValue("bec_min"), 
            max = getThemeValue("bec_max"),
            thickness = opts.thickness,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor, 
            textcolor = colorMode.textcolor, 
            thresholds = {
                { value = getThemeValue("bec_warn"), fillcolor = colorMode.fillwarncolor },
                { value = getThemeValue("bec_max"), fillcolor = colorMode.fillcolor }
            }
        },

        -- Blackbox
        {
            col = 4, 
            row = 10, 
            colspan = 2, 
            rowspan = 3,
            type = "text", 
            subtype = "blackbox",
            title = i18n("widgets.dashboard.blackbox"):upper(), 
            titlepos = "bottom",
            font = "FONT_XL", 
            decimals = 0,
            bgcolor = colorMode.bgcolor, 
            titlecolor = colorMode.titlecolor,
            valuepaddingtop = opts.brvaluepaddingtop,
            transform = "floor", 
            thresholds = {
                { value = 80, textcolor = colorMode.textcolor },
                { value = 90, textcolor = colorMode.fillwarncolor },
                { value = 100, textcolor = colorMode.fillcritcolor }
            }
        },

        -- ESC Temp
        {
            col = 6, 
            colspan = 2, 
            row = 4, 
            rowspan = 6,
            type = "gauge", 
            subtype = "arc", 
            source = "temp_esc",
            title = i18n("widgets.dashboard.esc_temp"):upper(), 
            titlepos = "bottom",
            font = opts.font,
            min = 0, 
            max = getThemeValue("esctemp_max"), 
            thickness = opts.thickness,
            valuepaddingleft = 10, 
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor, 
            titlecolor = colorMode.titlecolor, 
            textcolor = colorMode.textcolor,
            titlepaddingbottom = opts.titlepaddingbottom,
            transform = "floor",
            thresholds = {
                { value = getThemeValue("esctemp_warn"), fillcolor = colorMode.fillcolor },
                { value = getThemeValue("esctemp_max"), fillcolor = colorMode.fillwarncolor },
                { value = 200, fillcolor = colorMode.fillcritcolor }
            }
        },

        -- Governor
        {
            col = 6, 
            row = 10, 
            colspan = 2, 
            rowspan = 3,
            type = "text", 
            subtype = "governor",
            title = i18n("widgets.dashboard.governor"):upper(), 
            titlepos = "bottom",
            font = "FONT_XL",
            valuepaddingtop = opts.brvaluepaddingtop,
            bgcolor = colorMode.bgcolor, 
            titlecolor = colorMode.titlecolor,
            thresholds = {
                { value = i18n("widgets.governor.DISARMED"), textcolor = colorMode.fillcritcolor },
                { value = i18n("widgets.governor.OFF"), textcolor = colorMode.fillcritcolor },
                { value = i18n("widgets.governor.IDLE"), textcolor = "blue" },
                { value = i18n("widgets.governor.SPOOLUP"), textcolor = "blue" },
                { value = i18n("widgets.governor.RECOVERY"), textcolor = colorMode.fillwarncolor },
                { value = i18n("widgets.governor.ACTIVE"), textcolor = colorMode.fillcolor },
                { value = i18n("widgets.governor.THR-OFF"), textcolor = colorMode.fillcritcolor }
            }
        }
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
    local config = rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section]
    local W = lcd.getWindowSize()
    if boxes_cache == nil or themeconfig ~= config or lastScreenW ~= W then
        boxes_cache = buildBoxes(W)
        themeconfig = config
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

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

-- Theme config section for Nitro
local theme_section = "system/@aerc-n"

local THEME_DEFAULTS = {
    v_min      = 7.0,
    v_max      = 8.4,
    rpm_min    = 0,
    rpm_max    = 3000,
    tx_min     = 7.2,
    tx_warn    = 7.4,
    tx_max     = 8.4
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
        titlepaddingtop = 15,
        vgaugepaddingbottom = 7 
    },

    ls_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XS", 
        valuepaddingbottom = 25, 
        titlepaddingtop = 0,
        vgaugepaddingbottom = 5
    },

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = {
        font = "FONT_XL", 
        titlefont = "FONT_XS", 
        valuepaddingbottom = 15, 
        titlepaddingtop = 5,
        vgaugepaddingbottom = 5
    },

    ms_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XXS", 
        valuepaddingbottom = 0, 
        titlepaddingtop = 0,
        vgaugepaddingbottom = 5
    },

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = {
        font = "FONT_XL", 
        titlefont = "FONT_XS", 
        valuepaddingbottom = 15, 
        titlepaddingtop = 5,
        vgaugepaddingbottom = 7
    },
                
    ss_std  = {
        font = "FONT_XL", 
        titlefont = "FONT_XXS", 
        valuepaddingbottom = 0, 
        titlepaddingtop = 0,
        vgaugepaddingbottom = 5
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
    local vmin = getThemeValue("v_min")
    local vmax = getThemeValue("v_max")

    return {
        -- Throttle
        {
            col = 1, 
            colspan = 2, 
            row = 1, 
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "throttle_percent",
            title = i18n("widgets.dashboard.throttle"):upper(), 
            titlepos = "bottom", 
            font = opts.font,
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            thresholds = {
                { value = 20,  textcolor = colorMode.textcolor },
                { value = 80,  textcolor = colorMode.fillwarncolor },
                { value = 100, textcolor = colorMode.fillcritcolor }
                }
            },

        -- Headspeed
        {
            col = 1, 
            colspan = 2, 
            row = 4, 
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "rpm",
            title = i18n("widgets.dashboard.headspeed"):upper(),  
            titlepos = "bottom",
            font = opts.font,
            unit = " rpm", 
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
        },

        -- Blackbox
        {
            col = 1, 
            colspan = 2, 
            row = 7, 
            rowspan = 3, 
            type = "text", 
            subtype = "blackbox", 
            title = i18n("widgets.dashboard.blackbox"):upper(), 
            titlepos = "bottom",
            font = opts.font,
            decimals = 0, 
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            transform = "floor",
            thresholds = {
                { value = 80, textcolor = colorMode.textcolor },
                { value = 90, textcolor = colorMode.fillwarncolor },
                { value = 100, textcolor = colorMode.fillcritcolor }
            }
            },

        -- Governor
        {
            col = 1, 
            colspan = 2, 
            row = 10, 
            rowspan = 3,
            type = "text", 
            subtype = "governor", 
            title = i18n("widgets.dashboard.governor"):upper(), 
            titlepos = "bottom",
            font = opts.font,
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
        },

        -- Model Image
        {
            col = 3, 
            row = 1, 
            colspan = 3, 
            rowspan = 9, 
            type = "image", 
            subtype = "model", 
            bgcolor = colorMode.bgcolor
        },

        -- Rate Profile
        {
            col = 3, 
            row = 10, 
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "rate_profile",    
            title = i18n("widgets.dashboard.rates"):upper(), 
            titlepos = "bottom",
            font = opts.font,
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                { value = 1.5, textcolor = "blue" },
                { value = 2.5, textcolor = colorMode.fillwarncolor },
                { value = 6,   textcolor = colorMode.fillcolor }
            }
        },

        -- PID Profile
        {
            col = 4, 
            row = 10, 
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "pid_profile",    
            title = i18n("widgets.dashboard.profile"):upper(),
            titlepos = "bottom",
            font = opts.font,
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                { value = 1.5, textcolor = "blue" },
                { value = 2.5, colorMode.fillwarncolor },
                { value = 6,   colorMode.fillcolor }
            }
        },

        -- Flight Count
        {
            col = 5, 
            row = 10, 
            rowspan = 3, 
            type = "time", 
            subtype = "count", 
            title = i18n("widgets.dashboard.flights"):upper(), 
            titlepos = "bottom",
            font = opts.font,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
        },

        -- Voltage
        {
            col = 6, 
            colspan = 1, 
            row = 1, 
            rowspan = 12,
            type = "gauge", 
            source = "bec_voltage", 
            title = i18n("widgets.dashboard.voltage"):upper(), 
            titlepos = "bottom", 
            gaugeorientation = "vertical",
            gaugepaddingright = 10,
            gaugepaddingleft = 10,
            gaugepaddingtop = 5,
            gaugepaddingbottom = opts.vgaugepaddingbottom,
            decimals = 1,
            battery = true,
            batteryspacing = 1,
            valuepaddingbottom = 17,
            valuepaddingleft = 8,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            min = getThemeValue("v_min"),
            max = getThemeValue("v_max"),
            thresholds = {
                { value = vmin + 0.2 * (vmax - vmin), fillcolor = colorMode.fillcritcolor },
                { value = vmin + 0.4 * (vmax - vmin), fillcolor = colorMode.fillwarncolor },
                { value = vmax,                       fillcolor = colorMode.fillcolor     }
                }
        },
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

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

-- Theme config support
local theme_section = "system/@aerc"

local THEME_DEFAULTS = {
    rpm_min      = 0,
    rpm_max      = 3000,
    bec_min      = 3.0,
    bec_warn     = 6.0,
    bec_max      = 13.0,
    esctemp_warn = 90,
    esctemp_max  = 140,
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
        advfont = "FONT_L", 
        thickness = 28, 
        gaugepadding = 10, 
        gaugepaddingbottom = 40, 
        maxpaddingtop = 60, 
        maxpaddingleft = 20, 
        valuepaddingbottom = 25,
        fuelpaddingbottom = 10,
        maxfont = "FONT_L"
    },

    ls_std  = { 
        font = "FONT_XL", 
        advfont = "FONT_M", 
        thickness = 22, 
        gaugepadding = 0, 
        gaugepaddingbottom = 0, 
        maxpaddingtop = 30, 
        maxpaddingleft = 15, 
        valuepaddingbottom = 0,
        fuelpaddingbottom = 10, 
        maxfont = "FONT_M"
    },

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = { 
        font = "FONT_XXL", 
        advfont = "FONT_M", 
        thickness = 13, 
        gaugepadding = 5, 
        gaugepaddingbottom = 20, 
        maxpaddingtop = 30, 
        maxpaddingleft = 10, 
        valuepaddingbottom = 15,
        fuelpaddingbottom = 5, 
        maxfont = "FONT_S"
    },

    ms_std  = {
        font = "FONT_XXL", 
        advfont = "FONT_M", 
        thickness = 13, 
        gaugepadding = 0, 
        gaugepaddingbottom = 0, 
        maxpaddingtop = 30, 
        maxpaddingleft = 10, 
        valuepaddingbottom = 0,
        fuelpaddingbottom = 10,
        maxfont = "FONT_S"
    },

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = { 
        font = "FONT_XXL", 
        advfont = "FONT_M", 
        thickness = 19, 
        gaugepadding = 5, 
        gaugepaddingbottom = 20, 
        maxpaddingtop = 30, 
        maxpaddingleft = 10, 
        valuepaddingbottom = 10,
        fuelpaddingbottom = 5, 
        maxfont = "FONT_S"
    },

    ss_std  = {
        font = "FONT_XL", 
        advfont = "FONT_M", 
        thickness = 17, 
        gaugepadding = 0, 
        gaugepaddingbottom = 0, 
        maxpaddingtop = 25, 
        maxpaddingleft = 10, 
        valuepaddingbottom = 0,
        fuelpaddingbottom = 0, 
        maxfont = "FONT_S"
    },
}

-- Caching for boxes
local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

-- Theme Layout
local layout = {
    cols    = 3,
    rows    = 10,
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

    return {
        -- Timer
        {
            col = 1, 
            row = 1, 
            rowspan = 2, 
            type = "time", 
            subtype = "flight", 
            font = opts.font,
            title = i18n("widgets.dashboard.flight_time"):upper(),
            titlepos = "bottom",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
        },

        -- Battery Bar
        {
            col = 2, 
            row = 1,
            colspan = 2, 
            rowspan = 2,
            type = "gauge", 
            source = "smartfuel", 
            battadv = true,
            valuealign = "left", 
            valuepaddingleft = 85, 
            valuepaddingbottom = opts.fuelpaddingbottom,
            battadvfont = "FONT_M", 
            font = opts.font,
            battadvpaddingright = 5, 
            battadvvaluealign = "right",
            transform = "floor",
            fillcolor = colorMode.fillcolor,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor, 
            textcolor = colorMode.textcolor,
            thresholds = {
                { value = 10, fillcolor = colorMode.fillcritcolor },
                { value = 30, fillcolor = colorMode.fillwarncolor }
            }
        },

        -- Throttle
        {
            col = 1, 
            row = 3, 
            rowspan = 8,
            type = "gauge", 
            subtype = "arc", 
            source = "throttle_percent", 
            arcmax = true,
            title = i18n("widgets.dashboard.throttle"):upper(), 
            titlepos = "bottom", 
            thickness = opts.thickness, 
            font = opts.font, 
            maxfont = opts.maxfont,
            maxprefix = "Max: ", 
            maxpaddingtop = opts.maxpaddingtop,
            gaugepadding = opts.gaugepadding, 
            gaugepaddingbottom = opts.gaugepaddingbottom, 
            valuepaddingbottom = opts.valuepaddingbottom,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor, 
            textcolor = colorMode.textcolor, 
            maxtextcolor = "orange",
            transform = "floor",
            thresholds = {
                { value = 89,  fillcolor = "blue"       },
                { value = 100, fillcolor = "darkblue"   }
            }
        },

        -- Headspeed
        {
            col = 2, 
            row = 3, 
            rowspan = 8,
            type = "gauge", 
            subtype = "arc", 
            source = "rpm", 
            arcmax = true,
            title = i18n("widgets.dashboard.headspeed"):upper(), 
            titlepos = "bottom", 
            min = 0, 
            max = getThemeValue("rpm_max"),
            thickness = opts.thickness,
            unit = "",
            maxprefix = "Max: ", 
            font = opts.font, 
            maxpaddingtop = opts.maxpaddingtop, 
            maxfont = opts.maxfont,
            gaugepadding = opts.gaugepadding, 
            gaugepaddingbottom = opts.gaugepaddingbottom, 
            valuepaddingbottom = opts.valuepaddingbottom,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor, 
            textcolor = colorMode.textcolor, 
            maxtextcolor = "orange",
            transform = "floor",
            thresholds = {
                { value = getThemeValue("rpm_min"),   fillcolor = "lightpurple"   },
                { value = getThemeValue("rpm_max"),   fillcolor = "purple"        },
                { value = 10000,                      fillcolor = "darkpurple"    }
            }
        },

        -- ESC Temp
        {
            col = 3, 
            row = 3, 
            rowspan = 8,
            type = "gauge", 
            subtype = "arc", 
            source = "temp_esc", 
            arcmax = true,
            title = i18n("widgets.dashboard.esc_temp"):upper(), 
            titlepos = "bottom", 
            min = 0, max = getThemeValue("esctemp_max"), 
            thickness = opts.thickness,
            valuepaddingleft = 10, 
            valuepaddingbottom = opts.valuepaddingbottom, 
            maxpaddingleft = opts.maxpaddingleft, 
            maxpaddingtop = opts.maxpaddingtop,
            maxprefix = "Max: ",
            maxfont = opts.maxfont, 
            font = opts.font,
            gaugepadding = opts.gaugepadding, 
            gaugepaddingbottom = opts.gaugepaddingbottom,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor, 
            titlecolor = colorMode.titlecolor, 
            textcolor = colorMode.textcolor, 
            maxtextcolor = "orange",
            transform = "floor", 
            thresholds = {
                { value = getThemeValue("esctemp_warn"), fillcolor = colorMode.fillcolor },
                { value = getThemeValue("esctemp_max"), fillcolor = colorMode.fillwarncolor },
                { value = 200, fillcolor = colorMode.fillcritcolor }
            }
        },
    }
end

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

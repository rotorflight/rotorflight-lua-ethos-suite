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

-- User voltage min/max override support
local function getUserVoltageOverride(which)
  local prefs = rfsuite.session and rfsuite.session.modelPreferences
  if prefs and prefs["system/@rt-rc-n"] then
    local v = tonumber(prefs["system/@rt-rc-n"][which])
    -- Only use override if it is present and different from the default 6S values
    -- (Defaults: min=18.0, max=25.2)
    if which == "v_min" and v and math.abs(v - 18.0) > 0.05 then return v end
    if which == "v_max" and v and math.abs(v - 25.2) > 0.05 then return v end
  end
  return nil
end

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

-- Theme based configuration settings
local theme_section = "system/@rt-rc-n"

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
    cols    = 4,
    rows    = 14,
    padding = 1,
    --showgrid = lcd.RGB(100, 100, 100)  -- or any color you prefer
}

local header_layout = {
    height  = headeropts.height,
    cols    = 7,
    rows    = 1,
    padding = 0,
    --showgrid = lcd.RGB(100, 100, 100)  -- or any color you prefer
}

-- Boxes
local function buildBoxes(W)
    
    -- Object based options determined by screensize
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.unknown
    local vmin = getThemeValue("v_min") or 0
    local vmax = getThemeValue("v_max") or 0
    return {
        {
            type = "gauge",
            subtype = "arc",
            col = 1, row = 1,
            rowspan = 12,
            colspan = 2,
            source = "bec_voltage",
            thickness = gaugeThickness,
            font = "FONT_XXL",
            arcbgcolor = colorMode.arcbgcolor,
            title = i18n("widgets.dashboard.voltage"):upper(),
            titlepos = "bottom",
            bgcolor = colorMode.bgcolor,
            min = vmin,
            max = vmax,
            thresholds = {
                { value = vmin + 0.2 * (vmax - vmin), fillcolor = "red"    },
                { value = vmin + 0.4 * (vmax - vmin), fillcolor = "orange" },
                { value = vmax,                       fillcolor = "green"  }
            },
        },
        {
            type = "gauge",
            subtype = "arc",
            col = 3, row = 1,
            rowspan = 12,
            thickness = gaugeThickness,
            colspan = 2,
            source = "throttle_percent",
            transform = "floor",
            min = 0,
            max = 140,
            font = "FONT_XXL",
            arcbgcolor = colorMode.arcbgcolor,
            title = i18n("widgets.dashboard.throttle"):upper(),
            titlepos = "bottom",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            thresholds = {
                { value = 30,  fillcolor = "red",    textcolor = colorMode.textcolor },
                { value = 50,  fillcolor = "orange", textcolor = colorMode.textcolor },
                { value = 140, fillcolor = colorMode.fillcolor,  textcolor = colorMode.textcolor }
            },
        },
        {
            col = 1,
            row = 13,
            rowspan = 2,
            type = "text",
            subtype = "governor",
            thresholds = {
                { value = i18n("widgets.governor.DISARMED"), textcolor = "red"    },
                { value = i18n("widgets.governor.OFF"),      textcolor = "red"    },
                { value = i18n("widgets.governor.IDLE"),     textcolor = "yellow" },
                { value = i18n("widgets.governor.SPOOLUP"),  textcolor = "blue"   },
                { value = i18n("widgets.governor.RECOVERY"), textcolor = "orange" },
                { value = i18n("widgets.governor.ACTIVE"),   textcolor = "green"  },
                { value = i18n("widgets.governor.THR-OFF"),  textcolor = "red"    },
            },
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
        },
        {
            col = 4,
            row = 13,
            rowspan = 2,
            type = "time",
            subtype = "flight",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
        },
        {
            col = 3,
            row = 13,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "rpm",
            unit = "rpm",
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
        },
        {
            col = 2,
            row = 13,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "rssi",
            unit = "dB",
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
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

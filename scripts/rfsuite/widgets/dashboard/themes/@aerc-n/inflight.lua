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

local layout = {
    cols = 6,
    rows = 12,
}

local darkMode = {
    textcolor   = "white",
    titlecolor  = "white",
    bgcolor     = "black",
    fillcolor   = "green",
    fillbgcolor = "grey",
    accentcolor = "white",
}

local lightMode = {
    textcolor   = "black",
    titlecolor  = "black",
    bgcolor     = "white",
    fillcolor   = "green",
    fillbgcolor = "grey",
    accentcolor = "black",
}

local colorMode = lcd.darkMode() and darkMode or lightMode

-- Theme config support
local theme_section = "system/@aerc-n"

local THEME_DEFAULTS = {
    v_min   = 7.0,
    v_max   = 8.4,
    rpm_min = 0,
    rpm_max = 3000,
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
local boxes_cache = nil
local themeconfig = nil

local function buildBoxes()
    local vmin = getThemeValue("v_min")
    local vmax = getThemeValue("v_max")
    return {

        -- Headspeed
        {col = 1, colspan = 2, row = 1, rowspan = 12,
        type = "gauge",
        subtype = "arc",
        source = "rpm",
        arcmax = true,
        title = i18n("widgets.dashboard.headspeed"):upper(), 
        titlepos = "bottom", 
        min = 0,
        max = getThemeValue("rpm_max"),
        valuepaddingtop = 30,
        thickness = 25,
        unit = "",
        maxprefix = "Max: ",
        maxpaddingtop = 22,
        font = "FONT_XL",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        fillbgcolor = colorMode.fillbgcolor,
        maxtextcolor = "orange",
        transform = "floor",
        thresholds = {
            { value = getThemeValue("rpm_min"),   fillcolor = "lightpurple"   },
            { value = getThemeValue("rpm_max"),   fillcolor = "purple"        },
            { value = 10000,                      fillcolor = "darkpurple"    }
        }
        },

        -- Timer
        {col = 3, colspan = 2, row = 1, rowspan = 2,
        type = "time", 
        subtype = "flight", 
        font = "FONT_XL",
        title = i18n("widgets.dashboard.flight_time"):upper(),
        titlepos = "bottom",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        },

        -- Voltage
        {col = 3, colspan = 2, row = 3, rowspan = 10,
         type = "gauge", 
         source = "bec_voltage", 
         title = i18n("widgets.dashboard.voltage"):upper(), 
         titlepos = "bottom", 
         gaugeorientation = "vertical",
         gaugepaddingright = 40,
         gaugepaddingleft = 40,
         decimals = 1,
         battery = true,
         batteryspacing = 3,
         valuepaddingbottom = 17,
         bgcolor = colorMode.bgcolor,
         titlecolor = colorMode.titlecolor,
         textcolor = colorMode.textcolor,
         min = vmin,
         max = vmax,
         thresholds = {
            { value = vmin + 0.2 * (vmax - vmin), fillcolor = "red"    },
            { value = vmin + 0.4 * (vmax - vmin), fillcolor = "orange" },
            { value = vmax,                       fillcolor = "green"  }
            }
        },

        -- Throttle
        {col = 5, colspan = 2, row = 1, rowspan = 12,
        type = "gauge",
        subtype = "arc",
        source = "throttle_percent",
        arcmax = true,
        title = i18n("widgets.dashboard.throttle"):upper(), 
        titlepos = "bottom", 
        transform = "floor",
        thickness = 25,
        valuepaddingtop = 30,
        font = "FONT_XL",
        maxprefix = "Max: ",
        maxpaddingtop = 22,
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        fillbgcolor = colorMode.fillbgcolor,
        maxtextcolor = "orange",
        thresholds = {
            { value = 89,  fillcolor = "blue"       },
            { value = 100, fillcolor = "darkblue"   }
        }
        },
    }
end

local function boxes()
    local config =
        rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section]
    if boxes_cache == nil or themeconfig ~= config then
        boxes_cache = buildBoxes()
        themeconfig = config
    end
    return boxes_cache
end

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }    
}

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
    rows = 8,
    padding = 1
}

local darkMode = {
    textcolor   = "white",
    titlecolor  = "white",
    bgcolor     = "black",
    fillcolor   = "green",
    fillbgcolor = "grey",
    arcbgcolor  = "lightgrey",
}

local lightMode = {
    textcolor   = "black",
    titlecolor  = "black",
    bgcolor     = "white",
    fillcolor   = "green",
    fillbgcolor = "lightgrey",
    arcbgcolor  = "darkgrey",
}

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
    return {

        -- Timer
        {col = 1, colspan = 2, row = 1, rowspan = 2, 
        type = "time", 
        subtype = "flight", 
        font = "FONT_XL",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        },

        -- Battery Bar
        {col = 3, row = 1, colspan = 4, rowspan = 2,
        type = "gauge",
        source = "smartfuel",
        battadv = true,
        fillcolor = "green",
        valuealign = "left",
        valuepaddingleft = 85,
        battadvfont = "FONT_M",
        font = "FONT_XL",
        battadvpaddingright = 5,
        battadvvaluealign = "right",
        transform = "floor",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        thresholds = {
            { value = 10,  fillcolor = "red"    },
            { value = 30,  fillcolor = "orange" }
        }
        },

        -- Throttle
        {col = 1, colspan = 2, row = 3, rowspan = 6,
        type = "gauge",
        subtype = "arc",
        source = "throttle_percent",
        arcmax = true,
        title = i18n("widgets.dashboard.throttle"):upper(),  
        titlepos = "bottom", 
        transform = "floor",
        thickness = 20,
        font = "FONT_XL",
        maxprefix = "Max: ",
        maxpaddingtop = 22,
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        maxtextcolor = "orange",
        thresholds = {
            { value = 89,  fillcolor = "orange" },
            { value = 100, fillcolor = "red"    }
        }
        },

        -- Headspeed
        {col = 3, colspan = 2, row = 3, rowspan = 6,
        type = "gauge",
        subtype = "arc",
        source = "rpm",
        arcmax = true,
        title = i18n("widgets.dashboard.headspeed"):upper(),  
        titlepos = "bottom", 
        min = getThemeValue("rpm_min"),
        max = getThemeValue("rpm_max"),
        thickness = 20,
        unit = "",
        maxprefix = "Max: ",
        maxpaddingtop = 22,
        font = "FONT_XL",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        maxtextcolor = "orange",
        transform = "floor",
        thresholds = {
            { value = getThemeValue("rpm_max"),   fillcolor = "yellow"        },
            { value = 10000,                      fillcolor = "darkyellow"    }
        }
        },

        -- ESC Temp
        {col = 5, colspan = 2, row = 3, rowspan = 6,
        type = "gauge", 
        subtype = "arc",
        arcmax = true,
        source = "temp_esc", 
        title = i18n("widgets.dashboard.esc_temp"):upper(), 
        titlepos = "bottom", 
        min = 0, 
        max = getThemeValue("esctemp_max"), 
        thickness = 20,
        valuepaddingleft = 10,
        maxpaddingleft = 10,
        maxprefix = "Max: ",
        maxpaddingtop = 22,
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        maxtextcolor = "orange",
        font = "FONT_XL",
        transform = "floor", 
        thresholds = {
            { value = getThemeValue("esctemp_warn"), fillcolor = "green"  },
            { value = getThemeValue("esctemp_max"),  fillcolor = "orange" },
            { value = 200,                           fillcolor = "red"    }
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
    spread_scheduling = true,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
    spread_ratio = 0.8              -- optional: manually override default ratio logic (applies if spread_scheduling is true)   
    }
}

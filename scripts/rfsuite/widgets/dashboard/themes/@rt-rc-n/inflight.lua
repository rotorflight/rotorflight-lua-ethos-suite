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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]] --

local telemetry = rfsuite.tasks.telemetry
local utils = rfsuite.widgets.dashboard.utils

local W, H = lcd.getWindowSize()
local VERSION = system.getVersion() and system.getVersion().board

local gaugeThickness = 30
if VERSION == "X18" or VERSION == "X18S" or VERSION == "X14" or VERSION == "X14S" then gaugeThickness = 15 end

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

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

-- Theme config support
local theme_section = "system/@rt-rc-n"

local THEME_DEFAULTS = {
    v_min   = 7.0,
    v_max   = 8.4,
}

local function getThemeValue(key)
    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then return val end
    end
    return THEME_DEFAULTS[key]
end

local boxes_cache = nil
local themeconfig = nil

local layout = {
    cols = 4,
    rows = 14,
    padding = 1,
    bgcolor = colorMode.bgcolor
}

local function buildBoxes()
    local vmin = getThemeValue("v_min")
    local vmax = getThemeValue("v_max")
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
            title = "VOLTAGE",
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
            title = "THROTTLE",
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
                { value = "DISARMED", textcolor = "red"    },
                { value = "OFF",      textcolor = "red"    },
                { value = "IDLE",     textcolor = "yellow" },
                { value = "SPOOLUP",  textcolor = "blue"   },
                { value = "RECOVERY", textcolor = "orange" },
                { value = "ACTIVE",   textcolor = "green"  },
                { value = "THR-OFF",  textcolor = "red"    },
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

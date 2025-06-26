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

local layout = {
    cols = 6,
    rows = 12,
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

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

local boxes = {

    -- Headspeed
    {col = 1, colspan = 2, row = 1, rowspan = 12,
    type = "gauge",
    subtype = "arc",
    source = "rpm",
    arcmax = true,
    title = "HEADSPEED", 
    titlepos = "bottom", 
    min = 0, 
    max = 3000,
    valuepaddingtop = 30,
    thickness = 25,
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
            { value = 100,  fillcolor = "lightyellow"   },
            { value = 1600, fillcolor = "yellow"        },
            { value = 3000, fillcolor = "darkyellow"    }
        }
    },

    -- Timer
    {col = 3, colspan = 2, row = 1, rowspan = 2,
    type = "time", 
    subtype = "flight", 
    font = "FONT_XL",
    bgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.textcolor,
    },

    -- RX Voltage
    {col = 3, colspan = 2, row = 3, rowspan = 10,
     type = "gauge", 
     source = "bec_voltage", 
     title = "RX VOLTAGE", 
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
     min = 7.0,
     max = 8.4,
     thresholds = {
            {
                value = 7.4,
                fillcolor = "red",
            },
            {
                value = 7.7,
                fillcolor = "orange",
            },
            {
                value = 10,
                fillcolor = "green",
            }
        }
    },

    -- Throttle
    {col = 5, colspan = 2, row = 1, rowspan = 12,
    type = "gauge",
    subtype = "arc",
    source = "throttle_percent",
    arcmax = true,
    title = "THROTTLE %", 
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
    maxtextcolor = "orange",
        thresholds = {
            { value = 89,  fillcolor = "orange" },
            { value = 100, fillcolor = "red"    }
        }
    },
}

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        spread_scheduling = true,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
        spread_ratio = 0.8              -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }    
}
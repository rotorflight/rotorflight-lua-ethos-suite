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

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

local boxes = {

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
    title = "THROTTLE %", 
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
    title = "HEADSPEED", 
    titlepos = "bottom", 
    min = 0, 
    max = 3000,
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
            { value = 100,  fillcolor = "lightyellow"   },
            { value = 1600, fillcolor = "yellow"        },
            { value = 3000, fillcolor = "darkyellow"    }
        }
    },

    -- ESC Temp
    {col = 5, colspan = 2, row = 3, rowspan = 6,
    type = "gauge", 
    subtype = "arc",
    arcmax = true,
    source = "temp_esc", 
    title = "ESC TEMP", 
    titlepos = "bottom", 
    min = 0, 
    max = 140, 
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
            { value = 70,  fillcolor = "green"  },
            { value = 90,  fillcolor = "orange" },
            { value = 140, fillcolor = "red"    }
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

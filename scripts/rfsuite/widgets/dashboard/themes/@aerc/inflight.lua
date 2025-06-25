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
    cols = 4,
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
    {col = 1, row = 1, rowspan = 2, 
    type = "time", 
    subtype = "flight", 
    title = "TIMER", 
    titlepos = "bottom", 
    font = "FONT_XL",
    bgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.textcolor,
    },

    -- Battery Bar
    {col = 2, row = 1, colspan = 3, rowspan = 2,
    type = "gauge",
    source = "smartfuel",
    battadv = true,
    fillcolor = "green",
    valuealign = "left",
    valuepaddingleft = 170,
    battadvfont = "FONT_M",
    font = "FONT_XXL",
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

    -- RPM
    {col = 1, row = 3, rowspan = 4,
    type = "gauge",
    subtype = "arc",
    source = "rpm",
    arcmax = true,
    title = "RPM", 
    titlepos = "bottom", 
    min = 0, 
    max = 3000,
    thickness = 12,
    unit = "",
    maxprefix = "Max: ",
    maxpaddingtop = 22,
    font = "FONT_L",
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

    -- Governor
    {col = 1, row = 7, rowspan = 2, 
    type = "text", 
    subtype = "governor", 
    title = "GOVERNOR", 
    titlepos = "bottom",
    font = "FONT_XL",
    bgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.textcolor,
        thresholds = {
            { value = "DISARMED", textcolor = "red"    },
            { value = "OFF",      textcolor = "red"    },
            { value = "IDLE",     textcolor = "blue"   },
            { value = "SPOOLUP",  textcolor = "blue"   },
            { value = "RECOVERY", textcolor = "orange" },
            { value = "ACTIVE",   textcolor = "green"  },
            { value = "THR-OFF",  textcolor = "red"    },
        }
    },

    -- Throttle
    {col = 2, row = 3, rowspan = 4,
    type = "gauge",
    subtype = "arc",
    source = "throttle_percent",
    arcmax = true,
    title = "THROTTLE %", 
    titlepos = "bottom", 
    transform = "floor",
    thickness = 12,
    font = "FONT_L",
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

    -- BEC Voltage
    {col = 2, row = 7, rowspan = 2,
     type = "text",
     subtype = "telemetry",
     source = "bec_voltage", 
     title = "BEC VOLTAGE", 
     titlepos = "bottom", 
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
     font = "FONT_XL",
     min = 3, 
     max = 13, 
        thresholds = {
            { value = 5.5, textcolor = "red"   },
            { value = 13,  textcolor = "green" }
        }
    },

        -- Current
    {col = 3, row = 3, rowspan = 4,
    type = "gauge",
    subtype = "arc",
    source = "current",
    arcmax = true,
    title = "CURRENT", 
    titlepos = "bottom", 
    transform = "floor",
    thickness = 12,
    font = "FONT_L",
    maxprefix = "Max: ",
    maxpaddingtop = 22,
    min = 0,
    max = 300,
    bgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.textcolor,
    maxtextcolor = "orange",
        thresholds = {
            { value = 200, fillcolor = "lightred"   },
            { value = 300, fillcolor = "red"        }
        }
    },
  
    -- Rate Profile
    {col = 3, row = 7, rowspan = 2,
    type = "text",
    subtype = "telemetry",
    source = "rate_profile",    
    title = "RATES",
    titlepos = "bottom",
    transform = "floor",
    font = "FONT_XL",
    bgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.textcolor,
        thresholds = {
            { value = 1.5, textcolor = "blue" },
            { value = 2.5, textcolor = "orange" },
            { value = 6,   textcolor = "green"  }
        }
    },

    -- ESC Temp
    {col = 4, row = 3, rowspan = 4,
    type = "gauge", 
    subtype = "arc",
    arcmax = true,
    source = "temp_esc", 
    title = "ESC TEMP", 
    titlepos = "bottom", 
    min = 0, 
    max = 140, 
    thickness = 12,
    valuepaddingleft = 10,
    maxpaddingleft = 10,
    maxprefix = "Max: ",
    maxpaddingtop = 22,
    bgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.textcolor,
    maxtextcolor = "orange",
    font = "FONT_L",
    transform = "floor", 
        thresholds = {
            { value = 70,  fillcolor = "green"  },
            { value = 90,  fillcolor = "orange" },
            { value = 140, fillcolor = "red"    }
        }
    },

    -- PID Profile
    {col = 4, row = 7, rowspan = 2,
    type = "text",
    subtype = "telemetry",
    source = "pid_profile",    
    title = "PROFILE",
    titlepos = "bottom",
    transform = "floor",
    font = "FONT_XL",
    bgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.textcolor,
        thresholds = {
            { value = 1.5, textcolor = "blue" },
            { value = 2.5, textcolor = "orange" },
            { value = 6,   textcolor = "green"  }
        }
    },
}

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        wakeup_interval = 0.1,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 0.1,            -- Interval (seconds) to run paint script when display is visible 
        spread_scheduling = true,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
        spread_ratio = 0.8              -- optional: manually override default ratio logic (applies if spread_scheduling is true)        
    }  
}

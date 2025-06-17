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
    cols = 7,
    rows = 11,
    padding = 1,
}

local darkMode = {
    textcolor   = "white",
    titlecolor  = "white",
    bgcolor     = "black",
    fillcolor   = "green",
    fillbgcolor = "grey",
    accentcolor  = "white",
    arcbgcolor  = "lightgrey",
}

local lightMode = {
    textcolor   = "black",
    titlecolor  = "black",
    bgcolor     = "white",
    fillcolor   = "green",
    fillbgcolor = "lightgrey",
    accentcolor  = "lightgrey",
    arcbgcolor  = "darkgrey",
}

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

local boxes = {
    -- Model Image
    {col = 1, row = 1, colspan = 3, rowspan = 8, 
     type = "image", 
     subtype = "model", 
     bgcolor = colorMode.bgcolor,
    },

    -- Rate Profile
    {col = 1, row = 9, rowspan = 3,
     type = "text",
     subtype = "telemetry",
     source = "rate_profile",    
     title = "RATES",
     titlepos = "bottom",
     transform = "floor",
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
        thresholds = {
            { value = 1.5, textcolor = "blue" },
            { value = 2.5, textcolor = "orange" },
            { value = 6,   textcolor = "green"  }
        }
    },

    -- PID Profile
    {col = 2, row = 9, rowspan = 3,
     type = "text",
     subtype = "telemetry",
     source = "pid_profile",    
     title = "PROFILE",
     titlepos = "bottom",
     transform = "floor",
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
        thresholds = {
            { value = 1.5, textcolor = "blue" },
            { value = 2.5, textcolor = "orange" },
            { value = 6,   textcolor = "green"  }
        }
    },

    -- Flight Count
    {col = 3, row = 9, rowspan = 3, 
     type = "time", 
     subtype = "count", 
     title = "FLIGHTS", 
     titlepos = "bottom", 
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
     textcolor = colorMode.textcolor,
    },

    -- Battery Gauge
    {col = 4, row = 1, colspan = 4, rowspan = 3,
     type = "gauge",
     source = "fuel",
     batteryframe = true, 
     battadv = true,
     fillcolor = "green",
     valuealign = "left",
     valuepaddingleft = 75,
     battadvfont = "FONT_STD",
     battadvpaddingright = 18,
     battadvvaluealign = "right",
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
     textcolor = colorMode.textcolor,
     accentcolor = colorMode.accentcolor,
     transform = "floor",
        thresholds = {
            { value = 10,  fillcolor = "red"    },
            { value = 30,  fillcolor = "orange" }
        }
    },

    -- BEC Voltage
    {col = 4, colspan = 2, row = 4, rowspan = 5,
     type = "gauge", 
     subtype = "arc",
     source = "bec_voltage", 
     title = "BEC VOLTAGE", 
     titlepos = "bottom", 
     min = 3, 
     max = 13, 
     decimals = 1, 
     thickness = 13,
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
     textcolor = colorMode.textcolor,
     font = "FONT_XL", 
        thresholds = {
            { value = 5.5, fillcolor = "red"   },
            { value = 13,  fillcolor = "green" }
        }
    },

    -- Blackbox
    {col = 4, row = 9, colspan = 2, rowspan = 3, 
     type = "text", 
     subtype = "blackbox", 
     title = "BLACKBOX", 
     titlepos = "bottom", 
     decimals = 0, 
     textcolor = "blue",
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
     transform = "floor"
    },

    -- ESC Temp
    {col = 6, colspan = 2, row = 4, rowspan = 5,
     type = "gauge", 
     subtype = "arc",
     source = "temp_esc", 
     title = "ESC TEMP", 
     titlepos = "bottom", 
     min = 0, 
     max = 140, 
     thickness = 12,
     valuepaddingleft = 10,
     font = "FONT_XL", 
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
     textcolor = colorMode.textcolor,
     transform = "floor", 
        thresholds = {
            { value = 70,  fillcolor = "green"  },
            { value = 90,  fillcolor = "orange" },
            { value = 140, fillcolor = "red"    }
        }
    },

    -- Governor
    {col = 6, row = 9, colspan = 2, rowspan = 3, 
     type = "text", 
     subtype = "governor", 
     title = "GOVERNOR", 
     titlepos = "bottom", 
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
          thresholds = {
            { value = "DISARMED", textcolor = "red"    },
            { value = "OFF",      textcolor = "red"    },
            { value = "IDLE",     textcolor = "blue" },
            { value = "SPOOLUP",  textcolor = "blue"   },
            { value = "RECOVERY", textcolor = "orange" },
            { value = "ACTIVE",   textcolor = "green"  },
            { value = "THR-OFF",  textcolor = "red"    },
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

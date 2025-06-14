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

local boxes = {
    -- Model Image
    {col = 1, row = 1, colspan = 3, rowspan = 8, 
     type = "image", 
     subtype = "model", 
     bgcolor = "black"
    },

    -- Rate Profile
    {col = 1, row = 9, rowspan = 3,
     type = "text",
     subtype = "telemetry",
     source = "rate_profile",    
     title = "RATES",
     titlepos = "bottom",
     transform = "floor",
     bgcolor = "black",
        thresholds = {
            { value = 1.5, textcolor = "yellow" },
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
     bgcolor = "black",
        thresholds = {
            { value = 1.5, textcolor = "yellow" },
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
     bgcolor = "black"
    },

    -- Battery Gauge
    {col = 4, row = 1, colspan = 4, rowspan = 3,
     type = "gauge",
     source = "fuel",
     batteryframe = true, 
     battadv = true,
     fillcolor = "green",
     bgcolor = "black",
     valuealign = "left",
     valuepaddingleft = 75,
     battadvfont = "FONT_STD",
     battadvpaddingright = 18,
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
     bgcolor = "black",
     min = 3, 
     max = 13, 
     decimals = 1, 
     thickness = 15,
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
     bgcolor = "black", 
     decimals = 0, 
     textcolor = "blue", 
     transform = "floor"
    },

    -- ESC Temp
    {col = 6, colspan = 2, row = 4, rowspan = 5,
     type = "gauge", 
     subtype = "arc",
     source = "temp_esc", 
     title = "ESC TEMP", 
     titlepos = "bottom", 
     bgcolor = "black",
     min = 0, 
     max = 140, 
     thickness = 15,
     valuepaddingleft = 10,
     font = "FONT_XL", 
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
     bgcolor = "black",
        thresholds = {
            { value = "DISARMED", textcolor = "red"    },
            { value = "OFF",      textcolor = "red"    },
            { value = "IDLE",     textcolor = "yellow" },
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
    }    
}

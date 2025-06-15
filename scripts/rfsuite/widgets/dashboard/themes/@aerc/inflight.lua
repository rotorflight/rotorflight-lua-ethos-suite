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
    cols = 5,
    rows = 11,
    padding = 1
}

local boxes = {

    -- Battery Bar
    {col = 1, row = 1, colspan = 5, rowspan = 3,
     type = "gauge",
     source = "fuel",
     battadv = true,
     fillcolor = "green",
     bgcolor = "black",
     valuealign = "center",
     battadvfont = "FONT_STD",
     font = "FONT_XXL",
     battadvpaddingright = 18,
     transform = "floor",
        thresholds = {
            { value = 10,  fillcolor = "red"    },
            { value = 30,  fillcolor = "orange" }
        }
    },

    -- RPM
    {col = 1, row = 4, colspan = 2, rowspan = 6,
    type = "gauge",
    subtype = "arc",
    source = "rpm",
    arcmax = true,
    title = "RPM", 
    titlepos = "bottom", 
    bgcolor = "black",
    min = 0, 
    max = 3000,
    thickness = 15,
    unit = "",
    maxprefix = "Max: ",
    maxpaddingtop = 27,
    maxtextcolor = "orange",
    font = "FONT_L",
    transform = "floor",
        thresholds = {
            { value = 100,  fillcolor = "red"    },
            { value = 1600, fillcolor = "yellow" },
            { value = 3000, fillcolor = "green"  }
        }
    },

    -- Governor
    {col = 1, row = 10, colspan = 2, rowspan = 2, 
     type = "text", 
     subtype = "governor", 
     title = "GOVERNOR", 
     titlepos = "bottom",
     font = "FONT_XL",
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

    -- Timer
    {col = 3, row = 4, rowspan = 2, type = "time", subtype = "flight", title = "TIMER", titlepos = "bottom", font = "FONT_XL", bgcolor = "black"},

    -- Throttle
    {col = 3, row = 6, rowspan = 2,
     type = "text",
     subtype = "telemetry",
     source = "throttle_percent",
     title = "THROTTLE %", 
     titlepos = "bottom", 
     bgcolor = "black",
     transform = "floor",
     font = "FONT_XL",
        thresholds = {
            { value = 89,  textcolor = "white" },
            { value = 90,  textcolor = "yellow" },
            { value = 100, textcolor = "red"    }
        }
    },

    -- Current
    {col = 3, row = 8, rowspan = 2,
     type = "text",
     subtype = "telemetry",
     source = "current",
     title = "CURRENT", 
     titlepos = "bottom", 
     bgcolor = "black",
     transform = "floor",
     font = "FONT_XL",
        thresholds = {
            { value = 199, textcolor = "white" },
            { value = 200, textcolor = "yellow" },
            { value = 300, textcolor = "red"    }
        }
    },

    -- BEC Voltage
    {col = 3, row = 10, rowspan = 2,
     type = "text",
     subtype = "telemetry",
     source = "bec_voltage", 
     title = "BEC VOLTAGE", 
     titlepos = "bottom", 
     bgcolor = "black",
     font = "FONT_XL",
     min = 3, 
     max = 13, 
        thresholds = {
            { value = 5.5, textcolor = "red"   },
            { value = 13,  textcolor = "white" }
        }
    },

    -- ESC Temp
    {col = 4, colspan = 2, row = 4, rowspan = 6,
     type = "gauge", 
     subtype = "arc",
     arcmax = true,
     source = "temp_esc", 
     title = "ESC TEMP", 
     titlepos = "bottom", 
     bgcolor = "black",
     min = 0, 
     max = 140, 
     thickness = 15,
     valuepaddingleft = 10,
     maxpaddingleft = 10,
     maxprefix = "Max: ",
     maxpaddingtop = 27,
     maxtextcolor = "orange",
     font = "FONT_L",
     transform = "floor", 
        thresholds = {
            { value = 70,  fillcolor = "green"  },
            { value = 90,  fillcolor = "orange" },
            { value = 140, fillcolor = "red"    }
        }
    },
    
    -- Rate Profile
    {col = 4, row = 10, rowspan = 2,
     type = "text",
     subtype = "telemetry",
     source = "rate_profile",    
     title = "RATES",
     titlepos = "bottom",
     transform = "floor",
     font = "FONT_XL",
     bgcolor = "black",
        thresholds = {
            { value = 1.5, textcolor = "yellow" },
            { value = 2.5, textcolor = "orange" },
            { value = 6,   textcolor = "green"  }
        }
    },

    -- PID Profile
    {col = 5, row = 10, rowspan = 2,
     type = "text",
     subtype = "telemetry",
     source = "pid_profile",    
     title = "PROFILE",
     titlepos = "bottom",
     transform = "floor",
     font = "FONT_XL",
     bgcolor = "black",
        thresholds = {
            { value = 1.5, textcolor = "yellow" },
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
    }  
}

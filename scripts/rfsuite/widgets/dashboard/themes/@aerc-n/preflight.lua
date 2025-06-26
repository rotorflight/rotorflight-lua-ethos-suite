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
    rows = 12,
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

   -- Throttle
    {col = 1, colspan = 2, row = 1, rowspan = 3,
    type = "text",
    subtype = "telemetry",
    source = "throttle_percent",
    title = "THROTTLE %", 
    titlepos = "bottom", 
    transform = "floor",
    bgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.textcolor,
    },

    -- Headspeed
    {col = 1, colspan = 2, row = 4, rowspan = 3,
    type = "text",
    subtype = "telemetry",
    source = "rpm",
    title = "HEADSPEED", 
    titlepos = "bottom",
    unit = " rpm", 
    transform = "floor",
    bgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.textcolor,
    },

    -- Blackbox
    {col = 1, colspan = 2, row = 7, rowspan = 3, 
     type = "text", 
     subtype = "blackbox", 
     title = "BLACKBOX", 
     titlepos = "bottom", 
     decimals = 0, 
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
     textcolor = colorMode.textcolor,
     transform = "floor",
        thresholds = {
            { value = 80, textcolor = colorMode.textcolor },
            { value = 90, textcolor = "orange" },
            { value = 100, textcolor = "red" }
        }
    },

    -- Governor
    {col = 1, colspan = 2, row = 10, rowspan = 3,
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

    -- Model Image
    {col = 3, row = 1, colspan = 3, rowspan = 9, 
     type = "image", 
     subtype = "model", 
     bgcolor = colorMode.bgcolor,
    },

    -- Rate Profile
    {col = 3, row = 10, rowspan = 3,
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
    {col = 4, row = 10, rowspan = 3,
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
    {col = 5, row = 10, rowspan = 3, 
     type = "time", 
     subtype = "count", 
     title = "FLIGHTS", 
     titlepos = "bottom", 
     bgcolor = colorMode.bgcolor,
     titlecolor = colorMode.titlecolor,
     textcolor = colorMode.textcolor,
    },

     -- RX Voltage
    {col = 6, colspan = 2, row = 1, rowspan = 12,
     type = "gauge", 
     source = "bec_voltage", 
     title = "RX VOLTAGE", 
     titlepos = "bottom", 
     gaugeorientation = "vertical",
     gaugepaddingright = 40,
     gaugepaddingleft = 40,
     decimals = 1,
     battery = true,
     batteryspacing = 1,
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

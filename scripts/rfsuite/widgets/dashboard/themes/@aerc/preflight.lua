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
    accentcolor = "lightgrey",
    arcbgcolor  = "darkgrey",
}

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

-- Theme based configuration settings
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

-- Caching pattern
local boxes_cache = nil
local themeconfig = nil

local function buildBoxes()
    return {
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
         source = "smartfuel",
         batteryframe = true, 
         battadv = true,
         fillcolor = "green",
         valuealign = "left",
         valuepaddingleft = 75,
         battadvfont = "FONT_M",
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
         min = getThemeValue("bec_min"),
         max = getThemeValue("bec_max"), 
         decimals = 1, 
         thickness = 13,
         bgcolor = colorMode.bgcolor,
         titlecolor = colorMode.titlecolor,
         textcolor = colorMode.textcolor,
         font = "FONT_XL", 
         thresholds = {
             { value = getThemeValue("bec_min"), fillcolor = "red"   },
             { value = getThemeValue("bec_max"), fillcolor = "green" }
         }
        },

        -- Blackbox
        {col = 4, row = 9, colspan = 2, rowspan = 3, 
         type = "text", 
         subtype = "blackbox", 
         title = "BLACKBOX", 
         titlepos = "bottom", 
         decimals = 0, 
         bgcolor = colorMode.bgcolor,
         titlecolor = colorMode.titlecolor,
         transform = "floor",
         thresholds = {
            { value = 80, textcolor = colorMode.textcolor },
            { value = 90, textcolor = "orange" },
            { value = 100, textcolor = "red" }
         }
        },

        -- ESC Temp
        {col = 6, colspan = 2, row = 4, rowspan = 5,
         type = "gauge", 
         subtype = "arc",
         source = "temp_esc", 
         title = "ESC TEMP", 
         titlepos = "bottom", 
         min = 0,
         max = getThemeValue("esctemp_max"),
         thickness = 12,
         valuepaddingleft = 10,
         font = "FONT_XL", 
         bgcolor = colorMode.bgcolor,
         titlecolor = colorMode.titlecolor,
         textcolor = colorMode.textcolor,
         transform = "floor", 
         thresholds = {
             { value = getThemeValue("esctemp_warn"), fillcolor = "green"  },
             { value = getThemeValue("esctemp_max"),  fillcolor = "orange" },
             { value = 200,                           fillcolor = "red"    }
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
end

local function boxes()
    local config =
        rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section]
    -- Only rebuild if values change
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

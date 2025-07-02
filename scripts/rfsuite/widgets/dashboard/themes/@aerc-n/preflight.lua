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
    accentcolor = "lightgrey",
    arcbgcolor  = "darkgrey",
}

local colorMode = lcd.darkMode() and darkMode or lightMode

-- Theme config section for Nitro
local theme_section = "system/@aerc-n"

local THEME_DEFAULTS = {
    v_min      = 7.0,
    v_max      = 8.4,
    rpm_min    = 0,
    rpm_max    = 3000,
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

local function buildBoxes()
    local vmin = getThemeValue("v_min")
    local vmax = getThemeValue("v_max")
    return {
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
        thresholds = {
            { value = 20,  textcolor = colorMode.textcolor },
            { value = 80,  textcolor = "yellow" },
            { value = 100, textcolor = "red" }
            }
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

        -- Voltage
        {col = 6, colspan = 2, row = 1, rowspan = 12,
         type = "gauge", 
         source = "bec_voltage", 
         title = "VOLTAGE", 
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
         min = getThemeValue("v_min"),
         max = getThemeValue("v_max"),
         thresholds = {
            { value = vmin + 0.2 * (vmax - vmin), fillcolor = "red"    },
            { value = vmin + 0.4 * (vmax - vmin), fillcolor = "orange" },
            { value = vmax,                       fillcolor = "green"  }
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

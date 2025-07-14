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

local i18n = rfsuite.i18n.get

local layout = {
    cols = 12,
    rows = 12,
}

local function liveVoltageToCellVoltage(value)
    local cfg = rfsuite.session.batteryConfig
    local cells = (cfg and cfg.batteryCellCount) or 3
    if not cells or not value then return nil end

    local vpc = math.max(0, value / cells)
    return math.floor(vpc * 100 + 0.5) / 100
end

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
    -- Battery Bar
    {col = 1, row = 1, rowspan = 12,
    type = "gauge",
    source = "smartfuel",
    gaugeorientation = "vertical",
    battery = true,
    hidevalue = true,
    novalue = "",
    gaugepaddingtop = 2,
    transform = "floor",
    fillcolor = "green",
    bgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.textcolor,
        thresholds = {
            { value = 25,  fillcolor = "red"    },
            { value = 50,  fillcolor = "orange" }
        }
    }, 
    
    -- Voltage
    {col = 2, row = 1, colspan = 3, rowspan = 3, 
     type = "text", subtype = "telemetry", source = "voltage",
     i18n("widgets.dashboard.voltage"), titlepos = "top", titlealign = "left", titlefont = "FONT_S", titlepaddingleft = 4,
     font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuealign = "left", decimals = 1, transform = "floor",
    },

    -- BEC Voltage
    {col = 2, row = 4, colspan = 3, rowspan = 3,
     type = "text", subtype = "telemetry", source = "bec_voltage",
     title = i18n("widgets.dashboard.bec_voltage"), titlepos = "top", titlealign = "left", titlefont = "FONT_S", titlepaddingleft = 4,
     font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuealign = "left", decimals = 1, transform = "floor",
    },

    -- ESC Temperature
    {col = 2, row = 7, colspan = 3, rowspan = 3,
     type = "text", subtype = "telemetry", source = "temp_esc",
     title = i18n("widgets.dashboard.esc_temp"), titlepos = "top", titlealign = "left", titlefont = "FONT_S", titlepaddingleft = 4,
     font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuealign = "left", transform = "floor",
    },

    -- Cell Voltage
    {col = 2, row = 10, colspan = 3, rowspan = 3,
     type = "text", subtype = "telemetry", source = "voltage",
     title = i18n("widgets.dashboard.cell_voltage"), titlepos = "top", titlealign = "left", titlefont = "FONT_S", titlepaddingleft = 4,
     font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuealign = "left",
     transform = liveVoltageToCellVoltage,
    },

    -- Power
    {col = 9, row = 1, colspan = 3, rowspan = 3, 
     type = "text", subtype = "telemetry", source = "power", unit = "W",
     title = i18n("widgets.dashboard.power"), titlepos = "top", titlealign = "right", titlefont = "FONT_S", titlepaddingright = 4, 
     font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuealign = "right",
    },

    -- Current
    {col = 9, row = 4, colspan = 3, rowspan = 3,
     type = "text", "watts", source = "current",
     title = i18n("widgets.dashboard.current"), titlepos = "top", titlealign = "right", titlefont = "FONT_S", titlepaddingright = 4, 
     font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuealign = "right",
    },

    -- Altitude
    {col = 9, row = 7, colspan = 3, rowspan = 3, 
     type = "text", subtype = "telemetry", source = "altitude",
     title = i18n("widgets.dashboard.altitude"), titlepos = "top", titlealign = "right", titlefont = "FONT_S", titlepaddingright = 4, 
     font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     decimals = 1, valuealign = "right", transform = "floor",
    },

    -- Throttle
    {col = 9, row = 10, colspan = 3, rowspan = 3,
     type = "text", subtype = "telemetry", source = "throttle_percent",
     title = i18n("widgets.dashboard.throttle"), titlepos = "top", titlealign = "right", titlefont = "FONT_S", titlepaddingright = 4, 
     font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuealign = "right", transform = "floor",
    },

    -- Rates
    {col = 5, row = 1, colspan = 4, rowspan = 3,
     type = "text", subtype = "pidrates", object = "rates",
     title = "", font = "FONT_XL", fillcolor = "cyan", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     rowspacing = 20, rowfont ="FONT_L", rowalign = "center", rowpaddingbottom = 10,
     highlightlarger = true, transform = "floor",
    },

    -- RPM
    {col = 5, row = 4, colspan = 4, rowspan = 2,
     type = "text", subtype = "telemetry", source = "rpm", unit = "  RPM",
     title = "", titlepos = "top", font = "FONT_L", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuealign = "bottom", valuepaddingtop = 10, transform = "floor",
    },

    -- Timer
    {col = 5, row = 6, colspan = 4, rowspan = 3,
     type = "time", subtype = "flight",
     title = "", font = "FONT_XXL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuepaddingbottom = 30,
    },

    -- mAh Consumed
    {col = 5, row = 9, colspan = 4,
     type = "text", subtype = "telemetry", source = "consumption", unit = "  mAh",
     title = "", titlepos = "bottom", font = "FONT_L", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuealign = "top", valuepaddingbottom = 5, transform = "floor",
    },

    -- Governor
    {col = 5, row = 10, colspan = 4, rowspan = 3,
     type = "text", subtype = "governor",
     title = "", font = "FONT_XL",
     bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
     valuealign = "top", valuepaddingbottom = 20,
        thresholds = {
            { value = i18n("widgets.governor.DISARMED"), textcolor = "red"    },
            { value = i18n("widgets.governor.OFF"),      textcolor = "red"    },
            { value = i18n("widgets.governor.IDLE"),     textcolor = "blue"   },
            { value = i18n("widgets.governor.SPOOLUP"),  textcolor = "blue"   },
            { value = i18n("widgets.governor.RECOVERY"), textcolor = "orange" },
            { value = i18n("widgets.governor.ACTIVE"),   textcolor = "green"  },
            { value = i18n("widgets.governor.THR-OFF"),  textcolor = "red"    },
        }
    },

    -- Battery Bar
    {col = 12, row = 1, rowspan = 12,
    type = "gauge",
    source = "smartfuel",
    gaugeorientation = "vertical",
    battery = true,
    hidevalue = true,
    novalue = "",
    gaugepaddingtop = 2,
    transform = "floor",
    fillcolor = "green",
    bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
        thresholds = {
            { value = 25,  fillcolor = "red"    },
            { value = 50,  fillcolor = "orange" }
        }
    }, 
}

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }    
}

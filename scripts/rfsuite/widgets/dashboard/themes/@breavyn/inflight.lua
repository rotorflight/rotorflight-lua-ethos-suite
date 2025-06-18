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

local colorMode = lcd.darkMode() and darkMode or lightMode

local boxes = {
    -- Voltage
    {col = 1, row = 1, rowspan = 3,
     type = "text", subtype = "telemetry", source = "voltage",
     title = "Voltage", titlepos = "top", titlealign = "left", titlefont = "FONT_S",
     font = "FONT_XL", textcolor = "white", bgcolor = colorMode.bgcolor,
     valuealign = "left", decimals = 1, transform = "floor",
    },

    -- BEC Voltage
    {col = 1, row = 4, rowspan = 3,
     type = "text", subtype = "telemetry", source = "bec_voltage",
     title = "BEC Voltage", titlepos = "top", titlealign = "left", titlefont = "FONT_S",
     font = "FONT_XL", textcolor = "white", bgcolor = colorMode.bgcolor,
     valuealign = "left", decimals = 1, transform = "floor",
    },

    -- ESC Temperature
    {col = 1, row = 7, rowspan = 3,
     type = "text", subtype = "telemetry", source = "temp_esc",
     title = "ESC Temperature", titlepos = "top", titlealign = "left", titlefont = "FONT_S",
     font = "FONT_XL", textcolor = "white", bgcolor = colorMode.bgcolor,
     valuealign = "left", transform = "floor",
    },

    -- Cell Voltage
    {col = 1, row = 10, rowspan = 3,
     type = "text", subtype = "telemetry", source = "voltage",
     title = "Cell Voltage", titlepos = "top", titlealign = "left", titlefont = "FONT_S",
     font = "FONT_XL", textcolor = "white", bgcolor = colorMode.bgcolor,
     valuealign = "left",
     transform = liveVoltageToCellVoltage
    },

    -- Power
    {col = 4, row = 1, rowspan = 3,
     type = "text", subtype = "telemetry", source = "power", unit = "W",
     title = "Power", titlepos = "top", titlepos = "top", titlealign = "right", titlefont = "FONT_S",
     font = "FONT_XL", textcolor = "white", bgcolor = colorMode.bgcolor,
     valuealign = "right",
    },

    -- Current
    {col = 4, row = 4, rowspan = 3,
     type = "text", "watts", source = "current",
     title = "Current", titlepos = "top", titlepos = "top", titlealign = "right", titlefont = "FONT_S",
     font = "FONT_XL", textcolor = "white", bgcolor = colorMode.bgcolor,
     valuealign = "right",
    },

    -- Altitude
    {col = 4, row = 7, rowspan = 3,
     type = "text", subtype = "telemetry", source = "altitude",
     title = "Altitude", titlepos = "top", titlepos = "top", titlealign = "right", titlefont = "FONT_S",
     font = "FONT_XL", textcolor = "white", bgcolor = colorMode.bgcolor,
     decimals = 1, valuealign = "right", transform = "floor",
    },

    -- Throttle
    {col = 4, row = 10,  rowspan = 3,
     type = "text", subtype = "telemetry", source = "throttle_percent",
     title = "Throttle", titlepos = "top", titlepos = "top", titlealign = "right", titlefont = "FONT_S",
     font = "FONT_XL", textcolor = "white", bgcolor = colorMode.bgcolor,
     valuealign = "right", transform = "floor",
    },

    -- Rates
    {col = 2, row = 1, colspan = 2, rowspan = 3,
     type = "text", subtype = "pidrates", object = "rates",
     title = "", font = "FONT_XL", textcolor = "cyan", bgcolor = colorMode.bgcolor,
     rowspacing = 20, rowfont ="FONT_STD", rowalign = "center", rowpaddingbottom = 10,
     highlightlarger = true, transform = "floor",
    },

    -- RPM
    {col = 2, row = 4, colspan = 2, rowspan = 2,
     type = "text", subtype = "telemetry", source = "rpm", unit = "  RPM",
     title = "", titlepos = "top", font = "FONT_L", textcolor = "white", bgcolor = colorMode.bgcolor,
     valuealign = "bottom", valuepaddingtop = 10, transform = "floor",
    },

    -- Timer
    {col = 2, row = 6, colspan = 2, rowspan = 3,
     type = "time", subtype = "flight",
     title = "", font = "FONT_XXL", textcolor = "white", bgcolor = colorMode.bgcolor,
     valuepaddingbottom = 30,
    },

    -- mAh Consumed
    {col = 2, row = 9, colspan = 2,
     type = "text", subtype = "telemetry", source = "consumption", unit = "  mAh",
     title = "", titlepos = "bottom", font = "FONT_L", textcolor = "white", bgcolor = colorMode.bgcolor,
     valuealign = "top", valuepaddingbottom = 5, transform = "floor",
    },

    -- Governor
    {col = 2, row = 10, colspan = 2, rowspan = 3,
     type = "text", subtype = "governor",
     title = "", font = "FONT_XL",
     textcolor = "orange", bgcolor = colorMode.bgcolor,
     valuealign = "top", valuepaddingbottom = 20,
        thresholds = {
            { value = "DISARMED", textcolor = "red"    },
            { value = "OFF",      textcolor = "red"    },
            { value = "IDLE",     textcolor = "blue"   },
            { value = "SPOOLUP",  textcolor = "blue"   },
            { value = "RECOVERY", textcolor = "orange" },
            { value = "ACTIVE",   textcolor = "orange"  },
            { value = "THR-OFF",  textcolor = "red"    },
        }
    },
}

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        wakeup_interval = 0.1,
        wakeup_interval_bg = 5,
        paint_interval = 0.1,
    }
}

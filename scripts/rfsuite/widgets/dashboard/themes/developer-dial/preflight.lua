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

================================================================================
                         CONFIGURATION INSTRUCTIONS
================================================================================

For a complete list of all available widget parameters and usage options,
SEE THE TOP OF EACH WIDGET OBJECT FILE.

(Scroll to the top of files like battery.lua, telemetry.lua etc, for the full reference.)

--------------------------------------------------------------------------------
-- ACTUAL DASHBOARD CONFIG BELOW (edit/add your widgets here!)
--------------------------------------------------------------------------------
]]

local layout = {
    cols = 3,
    rows = 3,
    padding = 4,
}

local boxes = {

    -- DIAL
    {
        type = "dial",
        col = 1, row = 1,
        title = "Voltage",
        unit = "v",
        titlepos = "bottom",
        source = "voltage",
        aspect = "fit",
        align = "center",
        dial = 1,
        needlecolor = "red",
        needlehubcolor = "red",
        needlehubsize = 5,
        needlethickness = 4,
        font = "FONT_S",
        min = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        max = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
    },

    -- HEATRING
    {
        type = "gauge",
        subtype = "ring",
        col = 2, row = 1,
        title = "RPM",
        min = 0,
        max = 12000,
        thresholds = {
            { value = 3000,  fillcolor = "green" },
            { value = 6000,  fillcolor = "orange" },
            { value = 9000,  fillcolor = "orange" },
            { value = 12000, fillcolor = "red" },
        },
        ringsize = 0.8,
        textoffset = 0,
        titleoffset = 0,
        textalign = "center",
        titlealign = "center",
        titlepos = "below",
        unit = "",
        transform = "floor",
        textcolor = "white",
        source = "rpm",
    },

    -- ARCGUAGE
    {
        type = "gauge",
        subtype = "arc",
        col = 1, row = 2,
        source = "temp_esc",
        title = "ESC TEMP",
        titlepos = "bottom",
        min = 0, 
        max = 140,
        transform = "floor", 
        fillbgcolor = "lightgrey",
        thresholds = {
            { value = 70,  fillcolor = "green"  },
            { value = 90,  fillcolor = "orange" },
            { value = 140, fillcolor = "red"    }
        }
    },

    -- ARCDIAL
    {
        type = "dial",
        subtype = "rainbow",
        col = 2, row = 2,
        title = "Fuel",
        titlepos = "bottom",
        titlecolor = "white",
        unit = "%",
        source = "fuel",
        min = function() return 0 end,
        max = function() return 100 end,
        bandLabels = {"Low", "OK", "High"},
        bandColors = {"red", "orange", "green"},
        startangle = 180,
        sweep = 180,
        needlecolor = "black",
        needlehubcolor = "red",
        needlehubsize = 12,
        needlethickness = 6,
        aspect = "fit",
        align = "center",
    },

    -- FUEL GAUGE
    {
        col = 1, row = 3,
        type = "gauge",
        source = "fuel",
        batteryframe = true,
        title = "FUEL",
        titlepos = "bottom",
        textcolor = "white",
        valuepaddingbottom = 20,
        transform = "floor",
        thresholds = {
            { value = 20,  fillcolor = "red"},
            { value = 50,  fillcolor = "orange"},
            { value = 100,  fillcolor = "green"},
        },
    },

    -- VOLTAGE GAUGE
    {
        col = 2, row = 3,
        type = "gauge",
        source = "voltage",
        min = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        max = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
        title = "VOLTAGE",
        textcolor = "white",
        titlepos = "bottom",
        fillcolor = "green",
        roundradius = 8,
        valuepaddingbottom = 20,
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2
                end,
                fillbgcolor = "red",
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2
                end,
                fillbgcolor = "orange",
            }
        }
    },

    -- BATTERY
    {
        col = 3, row = 1,
        type = "gauge",
        battery = true,
        batteryframe = true,
        source = "voltage",
        min = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        max = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
        title = "VOLTAGE",
        titlepos = "bottom",
        fillcolor = "green",
        textcolor = "white",
        valuepaddingbottom = 20,
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2
                end,
                fillcolor = "red"
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2
                end,
                fillcolor = "orange"
            }
        },        
    },

    -- ARC MAX GAUGE
    {
        type = "gauge",
        subtype = "arc",
        arcmax = true,
        col = 3, row = 2, rowspan = 2,
        source = "temp_esc", 
        title = "ESC TEMP", 
        titlepos = "bottom",
        min = 0, 
        max = 140, 
        textcolor = "white", 
        font = "FONT_STD", 
        transform = "floor", 
        fillbgcolor = "lightgrey",
        valuepaddingleft = 10,
        maxprefix = "Max: ",
        maxpaddingleft = 10,
        thickness = 16,
        thresholds = {
            { value = 70,  fillcolor = "green", maxtextcolor = "green"},
            { value = 90,  fillcolor = "orange", maxtextcolor = "orange"},
            { value = 140, fillcolor = "red", maxtextcolor = "red"}
        }
    },
}

return {
    layout = layout,
    boxes = boxes,
    wakeup = wakeup,
    event = event,
    paint = paint,
    overlayMessage = nil,
    customRenderFunction = customRenderFunction,
    scheduler = {
        wakeup_interval = 0.25,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 0.5,            -- Interval (seconds) to run paint script when display is visible 
    }    
}

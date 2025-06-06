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
        type = "heatring",
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
        type = "arcgauge",
        col = 1, row = 2,
        source = "temp_esc",
        title = "ESC TEMP",
        titlepos = "bottom",
        min = 0, 
        max = 140,
        transform = "floor", 
        fillbgcolor = "lightgrey",
        valuepaddingright = 18,
        thresholds = {
            { value = 70,  fillcolor = "green"  },
            { value = 90,  fillcolor = "orange" },
            { value = 140, fillcolor = "red"    }
        }
    },

    -- ARCDIAL
    {
        type = "arcdial",
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
        gaugemin = 0,
        gaugemax = 100,
        roundradius = 9,
        fillbgcolor = "grey",
        gaugeorientation = "horizontal",
        gaugepadding = 8,
        gaugebelowtitle = true,
        title = "FUEL",
        unit = "%",
        textcolor = "white",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        thresholds = {
            { value = 20,  fillcolor = "red",    textcolor = "white" },
            { value = 50,  fillcolor = "orange", textcolor = "black" },
        },
        fillcolor = "green",
    },

    -- VOLTAGE GAUGE
    {
        col = 2, row = 3,
        type = "gauge",
        source = "voltage",
        gaugemin = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        gaugemax = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
        gaugeorientation = "horizontal",
        fillbgcolor = "grey",
        gaugepadding = 4,
        gaugebelowtitle = true,
        title = "VOLTAGE",
        unit = "V",
        textcolor = "white",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        fillcolor = "green",
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2
                end,
                fillbgcolor = "red",
                textcolor = "white"
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2
                end,
                fillbgcolor = "orange",
                textcolor = "white"
            }
        }
    },

    -- BATTERY
    {
        col = 3, row = 1,
        type = "battery",
        source = "voltage",
        gaugemin = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        gaugemax = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
        fillbgcolor = "gray",
        gaugeorientation = "horizontal",
        gaugebelowtitle = true,
        showvalue = true,
        title = "VOLTAGE",
        unit = "V",
        textcolor = "black",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        titlecolor = "white",
        fillcolor = "green",
        batteryframe = true,
        batteryframethickness = 4,
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2
                end,
                fillcolor = "red", textcolor = "white"
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2
                end,
                fillcolor = "orange", textcolor = "black"
            }
        },        
    },

    -- ARC MAX GAUGE
    {
        type = "arcmaxgauge",
        col = 3, row = 2, rowspan = 2,
                source = "temp_esc", 
        title = "ESC Temp", 
        titlepos = "bottom",
        gaugemin = 0, 
        gaugemax = 140, 
        unit = "°", 
        textcolor = "white", 
        font = "FONT_STD", 
        transform = "floor", 
        textoffsetx = 12,
        fillbgcolor = "lightgrey", 
        arcOffsetY = 4, 
        arcThickness = 1, 
        startAngle = 225, 
        sweep = 270,
        thresholds = {
            { value = 70,  fillcolor = "green"  },
            { value = 90,  fillcolor = "orange" },
            { value = 140, fillcolor = "red"    }
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

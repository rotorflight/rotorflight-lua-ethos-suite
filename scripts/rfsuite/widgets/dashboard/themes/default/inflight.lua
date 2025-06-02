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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]] --

local telemetry = rfsuite.tasks.telemetry

local layout = {
    cols = 2,
    rows = 1,
    padding = 4
}

local boxes = {
    {
        type = "arcgauge",
        col = 1, row = 1,
        source = "voltage",
        unit = "V",
        font = "FONT_XXL",
        textoffsetx = 12,
        arcOffsetY = 4,
        arcThickness = 1,
        startAngle = 225,
        sweep = 270,
        arcbgcolor = "lightgrey",
        title = "VOLTAGE",
        titlepos = "bottom",
        thresholds = {
            { value = 30,  fillcolor = "red", textcolor = "white" },
            { value = 50,  fillcolor = "orange", textcolor = "white" },
            { value = 140, fillcolor = "green", textcolor = "white" }
        },
        min = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            local value = math.max(0, cells * minV)
            return value
        end,
        max = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            local value = math.max(0, cells * maxV)
            return value
        end,   
        gaugemin = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            local value = math.max(0, cells * minV)
            return value
        end,
        gaugemax = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            local value = math.max(0, cells * maxV)
            return value
        end,
        thresholds = {
            {
                value = function(box)
                local gm = box._cache.gaugemin
                local gM = box._cache.gaugemax
                return gm + 0.30 * (gM - gm)
                end,
                color = "red"
            },
            {
                value = function(box)
                local gm = box._cache.gaugemin
                local gM = box._cache.gaugemax
                return gm + 0.50 * (gM - gm)
                end,
                color = "orange"
            },
            {
                value = function(box)
                local gM = box._cache.gaugemax
                return gM
                end,
                color = "green"
            }     
        }    
    },
    {
        type = "arcgauge",
        col = 2, row = 1,
        source = "fuel",
        transform = "floor",
        gaugemin = 0,
        gaugemax = 140,
        unit = "%",
        font = "FONT_XXL",
        textoffsetx = 12,
        arcOffsetY = 4,
        arcThickness = 1,
        startAngle = 225,
        sweep = 270,
        arcbgcolor = "lightgrey",
        title = "FUEL",
        titlepos = "bottom",
        thresholds = {
            { value = 30,  fillcolor = "red", textcolor = "white" },
            { value = 50,  fillcolor = "orange", textcolor = "white" },
            { value = 140, fillcolor = "green", textcolor = "white" }
        },
        gaugemin = 0,
        gaugemax = 100,     
    }
}

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        wakeup_interval = 0.25,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 0.5,            -- Interval (seconds) to run paint script when display is visible 
    }    
}

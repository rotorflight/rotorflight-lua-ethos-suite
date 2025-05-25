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
There are two ways to add gauges:
1. Full manual: Use type="gauge" and specify all properties and thresholds for full control.
2. Simple/auto: Use type="fuelgauge" or "voltagegauge" for quick setup with good defaults.
   You can still override any property if needed.
The simple types are easiest for most users—just set the title, unit, etc.
Manual type is best for advanced customization.
]]

--[[

Arc Gauge Box (`type = "arcgauge"`) — Parameters

Displays a circular or semi-circular arc gauge with a value, min/max, optional thresholds, and flexible styling.

Params (all can be a constant or a function):
-------------------------------------------------
* type         : "arcgauge"
* source       : Telemetry field name or function for value
* gaugemin     : Minimum value (number or function)
* gaugemax     : Maximum value (number or function)
* unit         : Value unit, e.g., "V" or "A"
* arcColor     : Arc color (string name, lcd.RGB, or function)
* arcBgColor   : Background arc color (string name, lcd.RGB, or function)
* arcThickness : Thickness of the arc in pixels (default: auto)
* startAngle   : Starting angle in degrees (0=right, 90=up, 180=left, 270=down; default: 135)
* sweep        : Degrees covered by the arc (default: 270)
* thresholds   : Table of { value = ..., color = ..., textcolor = ... } for dynamic arc coloring
* title        : Title string (shown top or bottom, as set)
* titlepos     : "top" or "bottom"
* titlealign   : "left", "center", "right"
* titlecolor   : Color of the title text
* textColor    : Color of the value in the center
* subText      : Optional subtitle shown below or inside gauge
* valueFormat  : Function for custom value display
* ...and all standard box layout/position params (col, row, w, h, etc.)

Example:
{
    type = "arcgauge",
    source = "voltage",
    gaugemin = 9,
    gaugemax = 13,
    unit = "V",
    arcColor = "green",
    arcBgColor = "gray",
    arcThickness = 10,
    startAngle = 225,
    sweep = 270,
    thresholds = {
        { value = 10.5, color = "red" },
        { value = 11.3, color = "orange" },
    },
    title = "BATTERY",
    titlepos = "bottom",
    titlealign = "center"
}

]]


local layout = {
    cols = 2,
    rows = 3,
    padding = 4,
    selectcolor = lcd.RGB(255, 255, 255),
    selectborder = 2
}

local boxes = {

   {
        col =1,
        row = 1,
        type = "gauge",
        source = "fuel",
        gaugemin = 0,
        gaugemax = 100,
        --gaugebgcolor = "black",
        gaugeorientation = "vertical",  -- or "horizontal"
        gaugepadding = 8,
        gaugebelowtitle = true,  -- <<--- do not draw under title area!
        title = "FUEL",
        unit = "%",
        color = "white",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        titlecolor = "white",
        thresholds = {
            { value = 20,  color = "red",    textcolor = "white" },   -- value < 20: red
            { value = 50,  color = "orange", textcolor = "black" },   -- 20 <= value < 40: orange
        },
        gaugecolor = "green",
    },
    {
        col = 2,
        row = 1,
        type = "gauge",
        source = "voltage",
        gaugemin = function()
            local cfg = rfsuite.session.batteryConfig

            --print(rfsuite.session.batteryConfig.vbatmincellvoltage)

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
        gaugebgcolor = "gray",
        gaugeorientation = "horizontal",
        gaugepadding = 8,
        gaugebelowtitle = true,
        title = "VOLTAGE",
        unit = "V",
        color = "black",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        titlecolor = "white",
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2 -- 20% above minimum voltage
                end,
                color = "red", textcolor = "white"
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2 -- 20% above minimum voltage
                end,
                color = "orange", textcolor = "black"
            }
        },
        gaugecolor = "green",
    },
    -- super simple way
    { col = 1, row = 2, type = "fuelgauge", title = "Fuel", unit = "%", titlepos = "bottom", gaugeorientation = "vertical" },
    -- arc gauges
    {
        col = 2,
        row = 2,
        rowspan = 2,
        type = "arcgauge",
        source = "voltage",
        startAngle = 225,
        arcColor = "red",
        arcThickness = 2,
        gaugemin = function()
            local cfg = rfsuite.session.batteryConfig

            --print(rfsuite.session.batteryConfig.vbatmincellvoltage)

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
        gaugebgcolor = "gray",
        gaugeorientation = "horizontal",
        gaugepadding = 8,
        gaugebelowtitle = true,
        title = "VOLTAGE",
        unit = "V",
        color = "black",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        titlecolor = "white",
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2 -- 20% above minimum voltage
                end,
                color = "red", textcolor = "white"
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2 -- 20% above minimum voltage
                end,
                color = "orange", textcolor = "black"
            }
        },
        gaugecolor = "green",
    },       


}


return {
    layout = layout,
    boxes = boxes,
    wakeup = wakeup,
    event = event,
    paint = paint,
    overlayMessage = nil,
    customRenderFunction = customRenderFunction
}

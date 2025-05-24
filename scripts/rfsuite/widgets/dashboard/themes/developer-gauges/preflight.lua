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

local layout = {
    cols = 4,
    rows = 4,
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
        gaugepadding = 4,
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
        gaugepadding = 4,
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
    { col = 2, row = 2, type = "voltagegauge", title = "Voltage", unit = "v", titlepos = "bottom", gaugeorientation = "horizontal" }

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

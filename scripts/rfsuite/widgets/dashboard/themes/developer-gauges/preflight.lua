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
        gaugecolor = "yellow",
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
            { value = 20,  color = "red",    textcolor = "white" },     -- value < 20: red gauge & red value text
            { value = 50,  color = "orange", textcolor = "black" },  -- 20 <= value < 50: orange
            { value = 80,  color = "green", textcolor = "black" }   -- 50 <= value < 80: yellow
        }
    },
    {
        col =2,
        row = 1,
        type = "gauge",
        source = "voltage",
        gaugemin = function() return 0 end,
        gaugemax = function() return 50 end,
        gaugecolor = "yellow",
        --gaugebgcolor = "black",
        gaugeorientation = "horizontal",  -- or "vertical"
        gaugepadding = 4,
        gaugebelowtitle = true,  -- <<--- do not draw under title area!
        title = "VOLTAGE",
        unit = "%",
        color = "white",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        titlecolor = "white",
        thresholds = {
            { value = 20,  color = "red",    textcolor = "white" },     -- value < 20: red gauge & red value text
            { value = 50,  color = "orange", textcolor = "black" },  -- 20 <= value < 50: orange
            { value = 80,  color = "green", textcolor = "black" }   -- 50 <= value < 80: yellow
        }
    }

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

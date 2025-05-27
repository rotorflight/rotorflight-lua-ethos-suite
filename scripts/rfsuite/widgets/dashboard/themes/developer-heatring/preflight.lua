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
HEATRING WIDGET PARAMETERS

type = "heatring"

REQUIRED:
    type          : Must be "heatring"
    source        : Telemetry field name (e.g. "rpm", "voltage")

OPTIONAL:
    title         : Label shown above the ring (string)
    unit          : Unit shown after the value (e.g. "V", "%", "RPM")
    thresholds    : List of thresholds with value and color fields. Each is:
                    { value = <number|function>, color = <lcd.RGB or string|function> }
                    -- Color used for value < threshold.value (first match wins)
    ringColor     : Fallback/default color if no thresholds matched (color)
    textColor     : Color of the central value text (default white)
    bgcolor       : Widget background color (default: dark/light mode)
    transform     : "floor", "ceil", "round", or function(v): Adjusts value display
    novalue       : Text/value to display if no sensor data (default: "-")
    font          : Name of font for the value (default: "FONT_XXL")
    titlepos      : Position for title ("top" or "bottom", default: top)
]]

local layout = {
    cols = 1,
    rows = 1,
    padding = 4,
    selectcolor = lcd.RGB(255, 255, 255),
    selectborder = 2
}

local boxes = {
    --[[ Example config for a heatring gauge:
    {
        type = "heatring",
        title = "RPM",
        source = "rpm",
        unit = "",
        transform = "floor",   -- (or "ceil", "round", or function)
        thresholds = {
            {value = 4000, color = lcd.RGB(0,200,0)},      -- Green if < 4000
            {value = 8000, color = lcd.RGB(220,180,40)},   -- Yellow if < 8000
            {value = 100000, color = lcd.RGB(200,0,0)},    -- Red for higher
        },
        ringColor = lcd.RGB(0,200,0),    -- fallback if no thresholds
        textColor = lcd.RGB(255,255,255),
        bgcolor = lcd.RGB(20,20,20),
        novalue = "--",
        font = "FONT_XXL",
        ringsize = 0.8 == 80%
    },
    ]]

{
    type = "heatring",
    title = "RPM",
    min = 0,
    max = 12000,
    thresholds = {
        {value = 3000, color = lcd.RGB(0,200,0)},
        {value = 6000, color = lcd.RGB(220,180,40)},
        {value = 9000, color = lcd.RGB(255,100,0)},
        {value = 12000, color = lcd.RGB(200,0,0)},
    },
    ringsize = 0.8,
    textoffset = 12,
    titleoffset = 0,
    textalign = "center",
    titlealign = "center",
    titlepos = "bottom",
    titleoffset = -50,
    unit = "",
    transform = "floor",
    ringColor = lcd.RGB(0,200,0),
    textColor = lcd.RGB(255,255,255),
    bgcolor = lcd.RGB(30,30,30),
    source = "rpm",
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

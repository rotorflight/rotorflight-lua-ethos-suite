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
    cols = 2,
    rows = 1,
    padding = 4,
    selectcolor = lcd.RGB(255, 255, 255),
    selectborder = 2
}

local boxes = {
    --[[

    ARCDIAL WIDGET PARAMETER REFERENCE
    ----------------------------------

    These are the options you can use in a box of type "arcdial".
    Most options are optional, with reasonable defaults.

    Required:
    - type             : Must be "arcdial"

    Common / General:
    - col, row         : Grid position (required)
    - colspan, rowspan : Optional cell spanning
    - title            : Title label, shown above or below (optional)
    - titlepos         : "top" (default) or "bottom" (optional)
    - titlecolor       : Color for title text (optional)
    - titlealign       : "center" (default), "left", or "right" (optional)
    - subText          : Smaller label below value (optional)
    - style            : Custom style variant (optional)
    - aspect           : "fit" (default), "fill", or "stretch" (optional, image scaling)
    - align            : "center" (default), or e.g. "top-left" (optional)
    - offsetx/y        : Extra position tweaks for dial (optional)
    - bgcolor          : Widget background color (optional)
    - selectcolor      : Color when selected (optional)
    - selectborder     : Border width when selected (optional)

    Data / Value:
    - source           : Telemetry field name, e.g., "voltage" or "fuel"
    - min              : Minimum gauge value (number or function)
    - max              : Maximum gauge value (number or function)
    - unit             : String to append after value (e.g., "V", "%")
    - transform        : "floor", "ceil", "round", function, or number (optional value adjustment)
    - decimals         : Number of decimal places to display (optional)
    - novalue          : Value shown if data is missing (optional)

    Arc/Needle Display:
    - dial             : Panel/dial image (usually unused in arcdial)
    - startAngle       : Angle in degrees where arc starts (default 180; right=0, up=90)
    - sweep            : Degrees to sweep (default 180 for half-circle)
    - bandLabels       : Table of section labels, e.g., {"Bad", "OK", "Good", "Excellent"} (optional)
    - bandColors       : Table of section colors (same length as bandLabels)
    - arcBgColor       : Color of arc background/track (optional)
    - thresholds       : Table of {value=..., color=...} for dynamic color (advanced/optional)
    - needlecolor      : Needle color (default black, can use color name or lcd.RGB)
    - needlehubcolor   : Needle hub/cap color (default black)
    - needlehubsize    : Needle hub/cap radius (default 7)
    - needlethickness  : Needle width (default 5)
    - needlestartangle : Starting angle for the needle (default matches arc's startAngle)
    - needlesweepangle : Arc sweep for needle movement (default matches arc's sweep)
    - valueFormat      : Custom formatting function for value (optional)

    Label Display:
    - font             : Font name for value (default: FONT_STD)
    - textColor        : Color for value text (default: white)
    - textoffsetx      : X offset for value text (optional)
    - titlepadding*    : Padding for title placement (optional; see arcgauge.lua for all options)

    Other:
    - arcOffsetY       : Vertical offset for arc center (optional)
    - gaugemin         : Use instead of min (compatibility)
    - gaugemax         : Use instead of max (compatibility)
    - customRenderFunction: For custom draw logic (advanced)
    - style            : Custom style variant (optional)

    --]]



    {
        col = 1, row = 1,
        type = "arcdial",
        title = "Voltage",
        unit = "v",
        titlepos = "bottom",
        source = "voltage",
        aspect = "fit",
        align = "center",
        dial = 1,  
        needlecolor = "red",
        needlehubcolor = "red",
        needlehubsize = 15,
        needlethickness = 5,        
        min = function()
            local cfg = rfsuite.session.batteryConfig

            --print(rfsuite.session.batteryConfig.vbatmincellvoltage)

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
    },
    {
        col = 2, row = 1,
        type = "arcdial",
        title = "Fuel",
        titlepos = "bottom",
        titlecolor = lcd.RGB(255,255,255),
        unit = "%",
        source = "fuel",
        min = function() return 0 end,
        max = function() return 100 end,
        bandLabels = {"Low", "OK", "High"},
        bandColors = {lcd.RGB(200,40,40), lcd.RGB(252,186,3), lcd.RGB(80,220,80)},
        startAngle = 180,
        sweep = 180,
        needlecolor = lcd.RGB(30,30,30),
        needlehubcolor = lcd.RGB(220,30,30),
        needlehubsize = 12,
        needlethickness = 6,
        aspect = "fit",
        align = "center",
        bgcolor = lcd.RGB(30,30,30),
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

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
        DIAL BOX OPTIONS:
        - col, row         : Grid position
        - rowspan, colspan : Optional row/column spans
        - type             : Must be "dial"
        - title            : Label shown above/below the dial
        - unit             : Unit shown after the value (e.g. "v", "%")
        - titlepos         : "top" or "bottom"
        - source           : Telemetry field name
        - bgcolor         : Background color (optional)
        - min, max         : Value range for angle mapping (optional)
        - aspect           : "fit" (default), "fill", or "stretch"
        - align            : "center" (default), "top-left", "bottom-right", etc.
        - transform        : "floor", "ceil", or "round" to adjust value display or  function
        - offsetx          : Horizontal offset for custom pointer (default 0)
        - offsety          : Vertical offset for custom pointer (default 0)
        - dial = 2,  -- or "custom/path.png", or function() return "..." end
        - needlecolor      : red"
        - needlehubcolor   : "black"
        - needlehubsize    :  10
        - needlethickness  : 5
        - needlestartangle = 135,   -- Degrees (where 0% starts)
        - needlesweepangle = 279,   -- Degrees (arc of full sweep)
    ]]

    {
        col = 1, row = 1,
        type = "dial",
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
        type = "dial",
        title = "Fuel",
        dial = 1,       
        unit = "%",
        titlepos = "bottom",
        style = 2,
        source = "fuel",
        aspect = "fit",
        align = "bottom",
        min = 0,
        max = 100,
        transform = "floor",
        needlecolor = "red",
        needlehubcolor = "black",
        needlehubsize = 10,
        needlethickness = 5,
        needlestartangle = 135, 
        needlesweepangle = 270,  
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

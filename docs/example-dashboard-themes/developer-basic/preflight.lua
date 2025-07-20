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

-- Custom render function for a box
local function customPaintFunction(x, y, w, h)
    local msg = "Render Function"
    local isDarkMode = lcd.darkMode()
    lcd.color(isDarkMode and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.drawFilledRectangle(x, y, w, h)

    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)

    local tsizeW, tsizeH = lcd.getTextSize(msg)
    local tx = x + (w - tsizeW) / 2
    local ty = y + (h - tsizeH) / 2
    lcd.drawText(tx, ty, msg)
end

local function customWakeupFunction()
   -- rfsuite.utils.log("Custom wakeup function called", "info")
end

-- Example on-press function to save and read a preference
local function onpressFunctionSave()
    local key = "test"
    local value = "testValue"
    rfsuite.widgets.dashboard.savePreference(key, value)
    rfsuite.utils.log("Saving value to model preferences: " .. value, "info")

    rfsuite.utils.log("Reading value from model preferences", "info")
    local readValue = rfsuite.widgets.dashboard.getPreference(key)
    rfsuite.utils.log("Value read from model preferences: " .. tostring(readValue), "info")
end

local layout = {
    cols = 4,
    rows = 4,
    padding = 4,
    showgrid = lcd.RGB(100, 100, 100)  -- or any color you prefer
}

local boxes = {
    -- Column 1
    { col = 1, row = 1, type = "image", subtype = "model" },
    { col = 1, row = 2, type = "text", subtype = "telemetry", source = "temp_esc", title = "ESC TEMP", transform = "floor", titlepos = "bottom",
        thresholds = {
            { value = 70,  textcolor = "green"  },
            { value = 90,  textcolor = "orange" },
            { value = 140, textcolor = "red"    }
        }
    },
    { col = 1, row = 3, type = "text", subtype = "governor", title = "GOVERNOR", titlepos = "bottom", 
        thresholds = {
            { value = "DISARMED", textcolor = "red"    },
            { value = "OFF",      textcolor = "red"    },
            { value = "IDLE",     textcolor = "yellow" },
            { value = "SPOOLUP",  textcolor = "blue"   },
            { value = "RECOVERY", textcolor = "orange" },
            { value = "ACTIVE",   textcolor = "green"  },
            { value = "THR-OFF",  textcolor = "red"    },
        }
    },
    { col = 1, row = 4, type="text", subtype = "apiversion", title = "API VERSION", titlepos = "bottom" },

    -- Column 2
    { col = 2, row = 1, type="text", subtype = "telemetry", source = "voltage", title = "VOLTAGE", titlepos = "bottom",
        thresholds = {
            { value = 20, textcolor = "red" },
            { value = 50, textcolor = "yellow" }
        }
    },
    { col = 2, row = 2, type="text", subtype = "telemetry", source = "attroll", title = "ROLL", textcolor = "blue", transform = "floor", titlepos = "bottom" },
    { col = 2, row = 3, type="text", subtype = "craftname", title = "CRAFT NAME", titlepos = "bottom" },
    { col = 2, row = 4, type="text", subtype = "session", source = "isArmed", title = "IS ARMED", titlepos = "bottom" },

    -- Column 3
    { col = 3, row = 1, type="text", subtype = "telemetry", source = "smartfuel", title = "FUEL", titlepos = "bottom", transform = "floor" },
    { col = 3, row = 2, type = "func", paint = customPaintFunction, wakeup = customWakeupFunction, title = "FUNCTION", titlepos = "bottom" },
    { col = 3, row = 3, type="text", subtype = "blackbox", title = "BLACKBOX", titlepos = "bottom", transform = "ceil", decimals = 0,
        thresholds = { 
            { value = 90, textcolor = "white"}, 
            { value = 200, textcolor = "red" },
        }
    },
    { col = 3, row = 4, type="text", subtype = "armflags", title = "ARM FLAGS", titlepos = "bottom",
            thresholds = {
            { value = "DISARMED", textcolor = "red" },
            { value = "ARMED", textcolor = "green" },
        }
    },
    -- Column 4
    { col = 4, row = 1, type = "text", subtype = "text", value = "PRESS ME", title = "ON PRESS", titlepos = "bottom", textcolor = "orange", onpress = onpressFunctionSave },
    { col = 4, row = 2, type = "time", subtype = "count", title = "FLIGHT COUNT", titlepos = "bottom" },
    { col = 4, row = 3, type = "time", subtype = "flight", title = "FLIGHT TIME", titlepos = "bottom"},
    { col = 4, row = 4, type = "time", subtype = "total", title = "TOTAL FLIGHT TIME", titlepos = "bottom"}
}

local function wakeup()
   --print("Preflight wakeup function called")
end

return {
    layout = layout,
    boxes = boxes,
    wakeup = wakeup,
    event = event,
    paint = paint,
    overlayMessage = nil,
    customRenderFunction = customRenderFunction,
    scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }      
}

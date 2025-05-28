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

================================================================================
                                WIDGET OPTION REFERENCE
================================================================================

---------------------------  MODELIMAGE BOX OPTIONS  ---------------------------
{
    type = "modelimage",         -- Required: "modelimage"
    col, row,                    -- Required: grid position
    -- colspan, rowspan,         -- Optional: grid span
    -- align,                    -- "center", "top-left", etc.
    -- aspect,                   -- "fit", "fill", "stretch", "original"
    -- bgcolor,                  -- Background color
    -- selectcolor,              -- Selection color
    -- selectborder,             -- Border thickness on selection
    -- title,                    -- Label (optional)
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- "center", "left", "right"
    -- font,                     -- Label font
    -- textColor,                -- Label text color
}

---------------------------  TELEMETRY BOX OPTIONS  ----------------------------
{
    type = "telemetry",          -- Required: "telemetry"
    col, row,                    -- Required: grid position
    -- colspan, rowspan,         -- Optional: grid span
    source,                      -- Required: Telemetry field name
    -- min, max,                 -- Value range (number/function)
    -- unit,                     -- Value unit ("V", "%", "dB", etc.)
    -- transform,                -- "floor", "ceil", "round", function
    -- nosource,                 -- Placeholder if telemetry source missing
    -- decimals,                 -- Number of decimal places
    -- thresholds,               -- { {value, color, textcolor}, ... }
    -- bgcolor,                  -- Widget background color
    -- selectcolor,              -- Highlight color
    -- selectborder,             -- Border width for selection
    -- title,                    -- Label text
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- "center", "left", "right"
    -- font,                     -- Value font
    -- textColor,                -- Value color
    -- textoffsetx,              -- X offset for value
}

---------------------------  GOVERNOR BOX OPTIONS  -----------------------------
{
    type = "governor",           -- Required: "governor"
    col, row,                    -- Required: grid position
    -- title,                    -- Label
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- Label alignment
    -- font,                     -- Font for label
    -- nosource,                 -- Placeholder if missing
}

--------------------------  APIVERSION BOX OPTIONS  ----------------------------
{
    type = "apiversion",         -- Required: "apiversion"
    col, row,                    -- Required: grid position
    -- title,                    -- Label
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- Label alignment
    -- font,                     -- Font for label
    -- nosource,                 -- Placeholder if missing
}

--------------------------  CRAFTNAME BOX OPTIONS  -----------------------------
{
    type = "craftname",          -- Required: "craftname"
    col, row,                    -- Required: grid position
    -- title,                    -- Label
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- Label alignment
    -- font,                     -- Font for label
    -- nosource,                 -- Placeholder if missing
}

--------------------------  SESSION BOX OPTIONS  -------------------------------
{
    type = "session",            -- Required: "session"
    col, row,                    -- Required: grid position
    -- source,                   -- Session property, e.g., "isArmed"
    -- title,                    -- Label
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- Label alignment
    -- font,                     -- Font for label
    -- nosource,                 -- Placeholder if missing
}

---------------------------  FUNC BOX OPTIONS  ---------------------------------
{
    type = "func",               -- Required: "func"
    col, row,                    -- Required: grid position
    value,                       -- Required: custom render function
    -- title,                    -- Label
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- Label alignment
    -- font,                     -- Font for label
}

--------------------------  BLACKBOX BOX OPTIONS  ------------------------------
{
    type = "blackbox",           -- Required: "blackbox"
    col, row,                    -- Required: grid position
    -- title,                    -- Label
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- Label alignment
    -- font,                     -- Font for label
    -- nosource,                 -- Placeholder if missing
}

---------------------------  TEXT BOX OPTIONS  ---------------------------------
{
    type = "text",               -- Required: "text"
    col, row,                    -- Required: grid position
    value,                       -- Required: text string
    -- onpress,                  -- Function to call when pressed
    -- title,                    -- Label
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- Label alignment
    -- font,                     -- Font for label
    -- nosource,                 -- Placeholder if missing
}

------------------------  FLIGHTCOUNT BOX OPTIONS  -----------------------------
{
    type = "flightcount",        -- Required: "flightcount"
    col, row,                    -- Required: grid position
    -- title,                    -- Label
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- Label alignment
    -- font,                     -- Font for label
    -- nosource,                 -- Placeholder if missing
}

------------------------  FLIGHTTIME BOX OPTIONS  ------------------------------
{
    type = "flighttime",         -- Required: "flighttime"
    col, row,                    -- Required: grid position
    -- title,                    -- Label/title for the widget
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Title text color
    -- titlealign,               -- "center", "left", "right"
    -- unit,                     -- Unit to display (e.g., "min")
    -- color,                    -- Value text color
    -- bgcolor,                  -- Background color
    -- valuealign,               -- "center", "left", "right"
    -- novalue,                  -- Placeholder if timer value missing
    -- titlepadding,             -- Padding (all)
    -- titlepaddingleft,         -- Padding left
    -- titlepaddingright,        -- Padding right
    -- titlepaddingtop,          -- Padding top
    -- titlepaddingbottom,       -- Padding bottom
    -- valuepadding,             -- Padding (all)
    -- valuepaddingleft,         -- Value text left padding
    -- valuepaddingright,        -- Value text right padding
    -- valuepaddingtop,          -- Value text top padding
    -- valuepaddingbottom,       -- Value text bottom padding
}

---------------------  TOTALFLIGHTTIME BOX OPTIONS  ----------------------------
{
    type = "totalflighttime",    -- Required: "totalflighttime"
    col, row,                    -- Required: grid position
    -- title,                    -- Label/title for the widget
    -- titlepos,                 -- "top" or "bottom"
    -- titlecolor,               -- Title text color
    -- titlealign,               -- "center", "left", "right"
    -- unit,                     -- Unit to display (e.g., "h")
    -- color,                    -- Value text color
    -- bgcolor,                  -- Background color
    -- valuealign,               -- "center", "left", "right"
    -- novalue,                  -- Placeholder if value missing
    -- titlepadding,             -- Padding (all)
    -- titlepaddingleft,         -- Padding left
    -- titlepaddingright,        -- Padding right
    -- titlepaddingtop,          -- Padding top
    -- titlepaddingbottom,       -- Padding bottom
    -- valuepadding,             -- Padding (all)
    -- valuepaddingleft,         -- Value text left padding
    -- valuepaddingright,        -- Value text right padding
    -- valuepaddingtop,          -- Value text top padding
    -- valuepaddingbottom,       -- Value text bottom padding
}


================================================================================
                    END OF WIDGET OPTION REFERENCE
================================================================================

]]--


-- Custom render function for a box
local function customRenderFunction(x, y, w, h)
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
    selectcolor = lcd.RGB(255, 255, 255),
    selectborder = 2
}

local boxes = {
    { col = 1, row = 1, type = "modelimage" },
    { col = 1, row = 2, type = "telemetry", source = "rssi", nosource = "-", title = "LQ", unit = "dB", titlepos = "bottom", transform = "floor" },
    { col = 1, row = 3, type = "governor", title = "GOVERNOR", nosource = "-", titlepos = "bottom" },
    { col = 1, row = 4, type = "apiversion", title = "API VERSION", nosource = "-", titlepos = "bottom" },

    { col = 2, row = 1, type = "telemetry", source = "voltage", nosource = "-", title = "VOLTAGE", unit = "v", titlepos = "bottom",
        thresholds = {
            { value = 20, color = "red", textcolor = "white" },
            { value = 50, color = "orange", textcolor = "black" }
        }
    },
    { col = 2, row = 2, type = "telemetry", source = "current", nosource = "-", title = "CURRENT", unit = "A", titlepos = "bottom" },
    { col = 2, row = 3, type = "craftname", title = "CRAFT NAME", nosource = "-", titlepos = "bottom" },
    { col = 2, row = 4, type = "session", source = "isArmed", title = "IS ARMED", nosource = "-", titlepos = "bottom" },

    { col = 3, row = 1, type = "telemetry", source = "fuel", nosource = "-", title = "FUEL", unit = "%", titlepos = "bottom", transform = "floor" },
    { col = 3, row = 2, type = "func", value = customRenderFunction, title = "FUNCTION", titlepos = "bottom" },
    { col = 3, row = 3, type = "blackbox", title = "BLACKBOX", nosource = "-", titlepos = "bottom" },

    { col = 4, row = 1, type = "text", value = "PRESS ME", title = "ON PRESS", nosource = "-", titlepos = "bottom", onpress = onpressFunctionSave },
    { col = 4, row = 2, type = "flightcount", title = "FLIGHT COUNT", nosource = "-", titlepos = "bottom" },

    {col = 2, row = 5, type = "telemetry", source = "rpm", title = "RPM", unit = "rpm", titlepos = "bottom", transform = "floor"},

    {col = 3, row = 4, type = "armflags", title = "ARM FLAGS", titlepos = "bottom"},

    {col = 4, row = 3, type = "flighttime", title = "FLIGHT TIME", titlepos = "bottom"},
    {col = 4, row = 4, type = "totalflighttime", title = "TOTAL FLIGHT TIME", titlepos = "bottom"}

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

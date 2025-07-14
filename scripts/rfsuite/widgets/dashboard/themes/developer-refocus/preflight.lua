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

local activeLayoutIndex = 1  -- 1 or 2

-- must be delared before the layout and boxes so its available to the layout
local function customRenderFunction(x, y, w, h)
    -- Custom rendering logic goes here
    -- This function will be called to render the custom box
    -- You can use the widget parameter to access the widget properties
    -- and perform any custom rendering you need

    local msg = "Render Function"

    -- Example: Draw a rectangle with a custom color
    local isDarkMode = lcd.darkMode()
    lcd.color(isDarkMode and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.drawFilledRectangle(x, y, w, h)

    -- Example: Draw some text
    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)

    -- display in the center of the box
    -- note.  x, y are the top-left coordinates of the box
    -- w, h are the width and height of the box
    -- you need to offset the coordinates by the box's position:
    local tsizeW, tsizeH = lcd.getTextSize(msg)
    local tx = x + (w - tsizeW) / 2
    local ty = y + (h - tsizeH) / 2
    lcd.drawText(tx, ty, msg)

end

local function onpressFunction1()
    activeLayoutIndex = 2  -- Show first layout
    --lcd.invalidate()       -- Make sure to force a redraw
end

local function onpressFunction2()
    activeLayoutIndex = 1  -- Show second layout
    --lcd.invalidate()
end

local layout1 = {
    cols = 4,
    rows = 4,
    padding = 4,
    selectcolor = lcd.RGB(255, 255, 255),
    selectborder = 2
}

local boxes1 = {
    {col=1, row=1, type="image", subtype="model"},
    {col=1, row=2, type="text", subtype="telemetry", source="rssi", nosource="-", title="LQ", unit="dB", titlepos="bottom", transform="floor"},
    {col=1, row=3, type="text", subtype="governor", title="GOVERNOR", nosource="-", titlepos="bottom"},
    {col=1, row=4, type="text", subtype="apiversion", title="API VERSION", nosource="-", titlepos="bottom"},

    {col=2, row=1, type="text", subtype="telemetry", source="voltage", nosource="-", title="VOLTAGE", unit="v", titlepos="bottom"},
    {col=2, row=2, type="text", subtype="telemetry", source="current", nosource="-", title="CURRENT", unit="A", titlepos="bottom"},
    {col=2, row=3, type="text", subtype="craftname", title="CRAFT NAME", nosource="-", titlepos="bottom"},  
    {col=2, row=4, type="text", subtype="session", source="isArmed", title="IS ARMED", nosource="-", titlepos="bottom"}, 

    {col=3, row=1, type="text", subtype="telemetry", source="fuel", nosource="-", title="FUEL", unit="%", titlepos="bottom", transform="floor"},
    {col=3, row=2, type = "func", value=customRenderFunction, title = "FUNCTION", titlepos = "bottom"},
    {col=4, row=1, type="text", subtype="text", value = "PRESS ME", title="SWITCHER", nosource="-", titlepos="bottom", onpress=onpressFunction1}, 
    { col = 3, row = 2, colspan = 2, rowspan = 3, type = "navigation", subtype = "ah" } 
}

local layout2 = {
    cols = 4,
    rows = 4,
    padding = 4,
    selectcolor = lcd.RGB(255, 255, 255),
    selectborder = 2
}

local boxes2 = {

    {col=1, row=1, type="text", subtype="telemetry", source="voltage", nosource="-", title="VOLTAGE", unit="v", titlepos="bottom"},
    {col=1, row=2, type="text", subtype="telemetry", source="current", nosource="-", title="CURRENT", unit="A", titlepos="bottom"},
    {col=1, row=3, type="text", subtype="craftname", title="CRAFT NAME", nosource="-", titlepos="bottom"},  
    {col=1, row=4, type="text", subtype="session", source="isArmed", title="IS ARMED", nosource="-", titlepos="bottom"}, 

    {col=2, row=1, type="image", subtype="model"},
    {col=2, row=2, type="text", subtype="telemetry", source="rssi", nosource="-", title="LQ", unit="dB", titlepos="bottom", transform="floor"},
    {col=2, row=3, type="text", subtype="governor", title="GOVERNOR", nosource="-", titlepos="bottom"},
    {col=2, row=4, type="text", subtype="apiversion", title="API VERSION", nosource="-", titlepos="bottom"},

    {col=3, row=1, type="text", subtype="telemetry", source="fuel", nosource="-", title="FUEL", unit="%", titlepos="bottom", transform="floor"},
    {col=3, row=2, type = "func", value=customRenderFunction, title = "FUNCTION", titlepos = "bottom"},
    {col=3, row=3, type="text", subtype="text", value = "PRESS ME", title="SWITCHER", nosource="-", titlepos="bottom", onpress=onpressFunction2},  
}



local function wakeup()
    --rfsuite.utils.log("wakeup preflight", "info")
end

local function event(widget, category, value, x, y)

end    

local function paint()
    --rfsuite.utils.log("paint preflight", "info")
end

local function screenErrorOverlay(message)
    -- if you want a custom overlay message, you can handle the full screen overlay here
    -- this is for messages like "BG TASK NOT RUNNING"
    -- the framework will display a centered message if this function is not defined
    -- the option is here to allow a them to create a custom overlay
    rfsuuite.utils.screenErrorOverlay(overlayMessage)
end

local function chooseLayout()
    return (activeLayoutIndex == 1) and layout1 or layout2
end

local function chooseBoxes()
    return (activeLayoutIndex == 1) and boxes1 or boxes2
end

return {
    layout = chooseLayout,
    boxes = chooseBoxes,
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

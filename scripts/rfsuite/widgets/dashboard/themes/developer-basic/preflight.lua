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

local function onpressFunctionSave()




    local key = "test"
    local value = "testValue"
    rfsuite.widgets.dashboard.savePreference(key, value)

        rfsuite.utils.log("Saving value to model preferences: ".. value,"info")

    rfsuite.utils.log("Reading value from model preferences","info")
    local value = rfsuite.widgets.dashboard.getPreference(key)

    rfsuite.utils.log("Value read from model preferences: " .. tostring(value), "info")


end


local layout = {
    cols = 4,
    rows = 4,
    padding = 4,
    selectcolor = lcd.RGB(255, 255, 255),
    selectborder = 2
}

local boxes = {
    {col=1, row=1, type="modelimage"},
    {col=1, row=2, type="telemetry", source="rssi", nosource="-", title="LQ", unit="dB", titlepos="bottom", transform="floor"},
    {col=1, row=3, type="governor", title="GOVERNOR", nosource="-", titlepos="bottom"},
    {col=1, row=4, type="apiversion", title="API VERSION", nosource="-", titlepos="bottom"},

    {col=2, row=1, type="telemetry", source="voltage", nosource="-", title="VOLTAGE", unit="v", titlepos="bottom", thresholds = {{ value = 20,  color = "red",    textcolor = "white" }, { value = 50,  color = "orange", textcolor = "black" }}},
    {col=2, row=2, type="telemetry", source="current", nosource="-", title="CURRENT", unit="A", titlepos="bottom"},
    {col=2, row=3, type="craftname", title="CRAFT NAME", nosource="-", titlepos="bottom"},  
    {col=2, row=4, type="session", source="isArmed", title="IS ARMED", nosource="-", titlepos="bottom"}, 

    {col=3, row=1, type="telemetry", source="fuel", nosource="-", title="FUEL", unit="%", titlepos="bottom", transform="floor"},
    {col=3, row=2, type = "function", value=customRenderFunction, title = "FUNCTION", titlepos = "bottom"},
    {col=3, row=3, type="blackbox", title="BLACKBOX", nosource="-", titlepos="bottom"},  

    {col=4, row=2, type="flightcount", title="FLIGHT COUNT", nosource="-", titlepos="bottom"}, 
    {col=4, row=1, type="text", value="PRESS ME", title="ON PRESS", nosource="-", titlepos="bottom", onpress=onpressFunctionSave}

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

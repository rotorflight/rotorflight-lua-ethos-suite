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


local telemetry = rfsuite.tasks.telemetry

local layout = {
    cols = 2,
    rows = 3,
    padding = 4
}

local boxes = {
    {col=1, row=1, type="text", value=telemetry.getSensorStats('voltage').min, title="MIN VOLTAGE", unit="v", titlepos="bottom"},
    {col=2, row=1, type="text", value=telemetry.getSensorStats('voltage').max, title="MAX VOLTAGE", unit="v", titlepos="bottom"},
    {col=1, row=2, type="text", value=telemetry.getSensorStats('current').min, title="MIN CURRENT", unit="A", titlepos="bottom", transform="floor"},
    {col=2, row=2, type="text", value=telemetry.getSensorStats('current').max, title="MAX CURRENT", unit="A", titlepos="bottom", transform="floor"},
    {col=1, row=3, type="text", value=telemetry.getSensorStats('temp_mcu').max, title="MAX T.MCU", unit="°", titlepos="bottom", transform="floor"},
    {col=2, row=3, type="text", value=telemetry.getSensorStats('temp_esc').max, title="MAX E.MCU", unit="°", titlepos="bottom", transform="floor"}
}

local function wakeup()
    --rfsuite.utils.log("wakeup postflight", "info")
end

local function event(widget, category, value, x, y)
    --rfsuite.utils.log("Event triggered: " .. category .. " - " .. code, "info")
end    

local function paint()
    --rfsuite.utils.log("paint postflight", "info")
end

local function screenErrorOverlay(message)
    -- if you want a custom overlay message, you can handle the full screen overlay here
    -- this is for messages like "BG TASK NOT RUNNING"
    -- the framework will display a centered message if this function is not defined
    -- the option is here to allow a them to create a custom overlay
    rfsuuite.utils.screenErrorOverlay(overlayMessage)
end

return {
    layout = layout,
    boxes = boxes,
    wakeup = wakeup,
    event = event,
    paint = paint,
    overlayMessage = nil,
}
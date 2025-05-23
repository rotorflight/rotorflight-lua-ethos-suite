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
    cols = 3,
    rows = 4,
    padding = 4
}

local boxes = {
    {col=1, row=1, rowspan=2, type="modelimage"},
    {col=1, row=3, type="telemetry", source="rssi", nosource="-", title="LQ", unit="dB", titlepos="bottom", transform="floor"},
    {col=1, row=4, type="telemetry", source="governor", nosource="-", title="GOVERNOR", titlepos="bottom", transform=function(v) return rfsuite.utils.getGovernorState(v) end},
    {col=2, row=1, rowspan=2, type="telemetry", source="voltage", nosource="-", title="VOLTAGE", unit="v", titlepos="bottom"},
    {col=2, row=3, rowspan=2, type="telemetry", source="current", nosource="-", title="CURRENT", unit="A", titlepos="bottom"},
    {col=3, row=1, rowspan=2, type="telemetry", source="fuel", nosource="-", title="FUEL", unit="%", titlepos="bottom", transform="floor"},
    {col=3, row=3, rowspan=2, type="telemetry", source="rpm", nosource="-", title="RPM", unit="rpm", titlepos="bottom", transform="floor"},
}

local function wakeup()
    --rfsuite.utils.log("wakeup preflight", "info")
end

local function event(widget, category, value, x, y)
    --rfsuite.utils.log("Event triggered: " .. category .. " - " .. code, "info")
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

return {
    layout = layout,
    boxes = boxes,
    wakeup = wakeup,
    event = event,
    paint = paint,
    overlayMessage = nil,
}

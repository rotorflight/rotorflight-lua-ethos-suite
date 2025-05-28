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
    rows = 5,
    padding = 4
}

local boxes = {
    {col = 1, row = 1, rowspan = 4, type = "telemetry", source = "voltage", title = "VOLTAGE", unit = "v", titlepos = "bottom"},
    {col = 2, row = 1, rowspan = 4, type = "telemetry", source = "fuel", title = "FUEL", unit = "%", titlepos = "bottom", transform = "floor"},
    {col = 1, row = 5, type = "telemetry", source = "governor", title = "GOVERNOR", titlepos = "bottom", transform = function(v) return rfsuite.utils.getGovernorState(v) end},
    {col = 2, row = 5, type = "telemetry", source = "rpm", title = "RPM", unit = "rpm", titlepos = "bottom", transform = "floor"}
}

local function wakeup()
    --rfsuite.utils.log("wakeup inflight", "info")
end

local function event(widget, category, value, x, y)
    --rfsuite.utils.log("Event triggered: " .. category .. " - " .. code, "info")
end     

local function paint()
    --rfsuite.utils.log("paint inflight", "info")
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
    scheduler = {
        wakeup_interval = 0.25,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 0.5,            -- Interval (seconds) to run paint script when display is visible 
    }    
}

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

local postFlightDelay = 10
local themeStartTime = rfsuite.clock
local cachedVpc = nil

local function maxVoltageToCellVoltage(value)
    if cachedVpc then return cachedVpc end

    local now = rfsuite.clock
    local elapsed = now - themeStartTime
    if elapsed < postFlightDelay then return nil end

    local cfg = rfsuite.session.batteryConfig
    local cells = (cfg and cfg.batteryCellCount) or 3
    if not cells or not value then return nil end

    local vpc = math.max(0, value / cells)
    vpc = math.floor(vpc * 100 + 0.5) / 100
    cachedVpc = vpc
    return vpc
end

local darkMode = {
    textcolor   = "white",
    titlecolor  = "white",
    bgcolor = "black",
    fillcolor   = "green",
    fillbgcolor = "grey",
    arcbgcolor  = "lightgrey",
}

local lightMode = {
    textcolor   = "black",
    titlecolor  = "black",
    bgcolor     = "white",
    fillcolor   = "green",
    fillbgcolor = "lightgrey",
    arcbgcolor  = "darkgrey",
}

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode



local layout = {
    cols = 3,
    rows = 4,
    padding = 1
}

local boxes = {
    -- Flight info and RPM info
    {col = 1, row = 1, type = "time", subtype = "flight", title = "Flight Duration", titlepos = "bottom", bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 1, row = 2, type = "time", subtype = "total", title = "Total Model Flight Duration", titlepos = "bottom", bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 1, row = 3, type = "text", subtype = "stats", stattype = "min", source = "rpm", title = "RPM Min", unit = " rpm", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 1, row = 4, type = "text", subtype = "stats", source = "rpm", title = "RPM Max", unit = " rpm", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},

    -- Flight max/min stats 1
    {col = 2, row = 1, type = "text", subtype = "stats", source = "throttle_percent", title = "Throttle Max", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 2, row = 2, type = "text", subtype = "stats", source = "current", title = "Current Max", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 2, row = 3, type = "text", subtype = "stats", source = "temp_esc", title = "ESC Temp Max", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 2, row = 4, type = "text", subtype = "watts", source = "max", title = "Max Watts", unit = "W", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},

    -- Flight max/min stats 2
    {col = 3, row = 1, type = "text", subtype = "stats", stattype = "max", source = "consumption", title = "Consumed mAh", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 3, row = 2, type = "text", subtype = "stats", stattype = "min", source = "fuel", title = "Fuel Remaining", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 3, row = 3, type = "text", subtype = "stats", stattype = "min", source = "voltage", title = "Min Volts per cell", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = function(v) return maxVoltageToCellVoltage(v) end, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 3, row = 4, type = "text", subtype = "stats", stattype = "min", source = "rssi", title = "Link Min", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
}





return {
    layout = layout,
    boxes = boxes,
    wakeup = wakeup,
    scheduler = {
        wakeup_interval = 0.1,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 1,            -- Interval (seconds) to run paint script when display is visible 
        spread_scheduling = true,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
        spread_ratio = 1.0              -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    } 
}

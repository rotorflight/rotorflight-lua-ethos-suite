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

local function maxVoltageToCellVoltage(value)
    local cfg = rfsuite.session.batteryConfig
    local cells = (cfg and cfg.batteryCellCount) or 3

    if cfg and cells and value then
        value = math.max(0, value / cells)
        value = math.floor(value * 100 + 0.5) / 100  -- round to 2 decimal places
    end

    return value
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
    {col = 3, row = 2, type = "text", subtype = "stats", stattype = "min", source = "smartfuel", title = "Fuel Remaining", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 3, row = 3, type = "text", subtype = "stats", stattype = "min", source = "voltage", title = "Min Volts per cell", titlepos = "bottom", bgcolor = colorMode.bgcolor, unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 3, row = 4, type = "text", subtype = "stats", stattype = "min", source = "rssi", title = "Link Min", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
}





return {
    layout = layout,
    boxes = boxes,
    wakeup = wakeup,
    scheduler = {
        spread_scheduling = true,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
        spread_ratio = 0.8              -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }    
}

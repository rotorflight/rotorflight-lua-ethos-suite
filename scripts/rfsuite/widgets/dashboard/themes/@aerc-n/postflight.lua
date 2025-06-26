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

    local cells = 2

    if cells and value then
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
    rows = 3,
    padding = 1
}

local boxes = {
    -- Flight info and RPM info
    {col = 1, row = 1, type = "time", subtype = "flight", title = "Flight Duration", titlepos = "top", bgcolor = colorMode.bgcolor, textcolor = "orange", titlecolor = colorMode.titlecolor},
    {col = 1, row = 2, type = "time", subtype = "total", title = "Total Model Flight Duration", titlepos = "top", bgcolor = colorMode.bgcolor, textcolor = "orange", titlecolor = colorMode.titlecolor},
    {col = 1, row = 3, type = "text", subtype = "stats", stattype = "min", source = "rssi", title = "Link Min", titlepos = "top", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},

    {col = 2, row = 2, type = "text", subtype = "stats", stattype = "min", source = "rpm", title = "Headspeed Min", unit = " rpm", titlepos = "top", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},
    {col = 2, row = 1, type = "text", subtype = "stats", source = "rpm", title = "Headspeed Max", unit = " rpm", titlepos = "top", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},
    {col = 2, row = 3, type = "text", subtype = "stats", source = "throttle_percent", title = "Throttle Max", titlepos = "top", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},
    
    {col = 3, row = 1, type = "text", subtype = "telemetry", source = "bec_voltage", title = "RX Voltage", titlepos = "top", bgcolor = colorMode.bgcolor, unit = "V", textcolor = "orange", titlecolor = colorMode.titlecolor},
    {col = 3, row = 2, type = "text", subtype = "stats", stattype = "min", source = "bec_voltage", title = "RX Min Volts", titlepos = "top", bgcolor = colorMode.bgcolor, unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end, textcolor = "orange", titlecolor = colorMode.titlecolor},
    {col = 3, row = 3, type = "text", subtype = "stats", source = "altitude", title = "Altitude Max", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

}

return {
    layout = layout,
    boxes = boxes,
    wakeup = wakeup,
    scheduler = {
        wakeup_interval = 0.1,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 1,            -- Interval (seconds) to run paint script when display is visible 
    } 
}

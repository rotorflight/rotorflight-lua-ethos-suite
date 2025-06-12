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

local layout = {
    cols = 3,
    rows = 4,
    padding = 1
}

local boxes = {
    -- Flight info and RPM info
    {col = 1, row = 1, type = "time", subtype = "flight", title = "Flight Duration", titlepos = "top", bgcolor = "black", textcolor = "orange"},
    {col = 1, row = 2, type = "time", subtype = "total", title = "Total Model Flight Duration", titlepos = "top", bgcolor = "black", textcolor = "orange"},
    {col = 1, row = 3, type = "text", subtype = "stats", stattype = "min", source = "rpm", title = "RPM Min", unit = " rpm", titlepos = "top", bgcolor = "black", textcolor = "orange", transform = "floor"},
    {col = 1, row = 4, type = "text", subtype = "stats", source = "rpm", title = "RPM Max", unit = " rpm", titlepos = "top", bgcolor = "black", textcolor = "orange", transform = "floor"},

    -- Flight max/min stats 1
    {col = 2, row = 1, type = "text", subtype = "stats", source = "throttle_percent", title = "Throttle Max", titlepos = "top", bgcolor = "black", textcolor = "orange", transform = "floor"},
    {col = 2, row = 2, type = "text", subtype = "stats", source = "current", title = "Current Max", titlepos = "top", bgcolor = "black", textcolor = "orange", transform = "floor"},
    {col = 2, row = 3, type = "text", subtype = "stats", source = "temp_esc", title = "ESC Temp Max", titlepos = "top", bgcolor = "black", textcolor = "orange", transform = "floor"},
    {col = 2, row = 4, type = "text", subtype = "stats", source = "altitude", title = "Altitude Max", titlepos = "top", bgcolor = "black", textcolor = "orange", transform = "floor"},

    -- Flight max/min stats 2
    {col = 3, row = 1, type = "text", subtype = "stats", stattype = "max", source = "consumption", title = "Consumed mAh", titlepos = "top", bgcolor = "black", textcolor = "orange", transform = "floor"},
    {col = 3, row = 2, type = "text", subtype = "stats", stattype = "min", source = "fuel", title = "Fuel Remaining", titlepos = "top", bgcolor = "black", textcolor = "orange", transform = "floor"},
    {col = 3, row = 3, type = "text", subtype = "stats", stattype = "min", source = "voltage", title = "Min Volts per cell", titlepos = "top", bgcolor = "black", textcolor = "orange", unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end},
    {col = 3, row = 4, type = "text", subtype = "stats", stattype = "min", source = "rssi", title = "Link Min", titlepos = "top", bgcolor = "black", textcolor = "orange", transform = "floor"},
}

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        wakeup_interval = 0.25,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 0.5,            -- Interval (seconds) to run paint script when display is visible 
    } 
}

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
local i18n = rfsuite.i18n.get


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
    cols = 2,
    rows = 2,
    padding = 1
}

local boxes = {
    -- Flight info and RPM info
    {col = 1, row = 1, type = "time", subtype = "flight", title = i18n("widgets.dashboard.flight_duration"), titlepos = "bottom", bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 1, row = 2, type = "time", subtype = "total", title = i18n("widgets.dashboard.total_flight_duration"), titlepos = "bottom", bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},

    -- Flight max/min stats 2
    {col = 2, row = 1, type = "text", subtype = "stats", stattype = "min", source = "voltage", title = i18n("widgets.dashboard.min_volts_cell"), titlepos = "bottom", bgcolor = colorMode.bgcolor, unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
    {col = 2, row = 2, type = "text", subtype = "stats", stattype = "min", source = "rssi", title = i18n("widgets.dashboard.rssi_min"), titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
}





return {
    layout = layout,
    boxes = boxes,
    wakeup = wakeup,
    scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }    
}

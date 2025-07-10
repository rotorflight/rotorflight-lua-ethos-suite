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
    bgcolor     = "black",
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
    {col = 1, row = 1, type = "time", subtype = "flight", title = i18n("widgets.dashboard.flight_duration"), titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange"},
    {col = 1, row = 2, type = "time", subtype = "total", title = i18n("widgets.dashboard.total_flight_duration"), titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange"},
    {col = 1, row = 3, type = "text", subtype = "stats", stattype = "min", source = "rpm", title = i18n("widgets.dashboard.rpm_min"), unit = " rpm", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
    {col = 1, row = 4, type = "text", subtype = "stats", source = "rpm", title = i18n("widgets.dashboard.rpm_max"), unit = " rpm", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

    -- Flight max/min stats 1
    {col = 2, row = 1, type = "text", subtype = "watts", source = "max", title = i18n("widgets.dashboard.watts_max"), unit = "W", titlepos = "top", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},
    {col = 2, row = 2, type = "text", subtype = "stats", source = "current", title = i18n("widgets.dashboard.current_max"), titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
    {col = 2, row = 3, type = "text", subtype = "stats", source = "temp_esc", title = i18n("widgets.dashboard.esc_max_temp"), titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
    {col = 2, row = 4, type = "text", subtype = "stats", source = "altitude", title = i18n("widgets.dashboard.altitude_max"), titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

    -- Flight max/min stats 2
    {col = 3, row = 1, type = "text", subtype = "stats", stattype = "max", source = "consumption", title = i18n("widgets.dashboard.consumed_mah"), titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
    {col = 3, row = 2, type = "text", subtype = "stats", stattype = "min", source = "smartfuel", title = i18n("widgets.dashboard.fuel_remaining"), titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
    {col = 3, row = 3, type = "text", subtype = "telemetry", source = "voltage", title = i18n("widgets.dashboard.volts_per_cell"), titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end},
    {col = 3, row = 4, type = "text", subtype = "stats", stattype = "min", source = "rssi", title = i18n("widgets.dashboard.link_min"), titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
}

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        spread_scheduling = false,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
        spread_ratio = 0.8              -- optional: manually override default ratio logic (applies if spread_scheduling is true)        
    } 
}

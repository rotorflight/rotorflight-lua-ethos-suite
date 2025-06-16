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
    -- Batt Bar Summary
    {col = 1, row = 1, colspan = 3,
    type = "gauge",
    source = "fuel",
    battadv = true,
    battstats = true,
    title = "BATTERY INFORMATION",
    titlealign = "center",
    valuealign = "center",
    unit = "%  Remaining",
    valuepaddingtop = 20,
    battadvfont = "FONT_STD",
    font = "FONT_L",
    battadvpaddingtop = 15,
    battadvpaddingright = 30,
    battadvvaluealign = "center",
    transform = "floor",
    bgcolor = colorMode.bgcolor,
    fillbgcolor = colorMode.bgcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = "orange",
    },

    -- Flight info and RPM info
    {col = 1, row = 2, type = "time", subtype = "flight", title = "FLIGHT DURATION", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange"},
    {col = 1, row = 3, type = "time", subtype = "total", title = "TOTAL MODEL FLIGHT DURATION", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange"},
    {col = 1, row = 4, type = "text", subtype = "stats", stattype = "min", source = "rssi", title = "LINK MIN", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

    -- Flight max/min stats 1
    {col = 2, row = 2, type = "text", subtype = "stats", stattype = "min", source = "rpm", title = "RPM MIN", unit = " rpm", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
    {col = 2, row = 3, type = "text", subtype = "stats", source = "rpm", title = "RPM MAX", unit = " rpm", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
    {col = 2, row = 4, type = "text", subtype = "stats", source = "throttle_percent", title = "THROTTLE MAX", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},

    -- Flight max/min stats 2
    {col = 3, row = 2, type = "text", subtype = "stats", source = "current", title = "CURRENT MAX", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
    {col = 3, row = 3, type = "text", subtype = "stats", source = "temp_esc", title = "ESC TEMP MAX", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
    {col = 3, row = 4, type = "text", subtype = "stats", source = "altitude", title = "ALTITUDE MAX", titlepos = "top", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"}, 
}

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        wakeup_interval = 0.1,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 0.1,            -- Interval (seconds) to run paint script when display is visible 
    } 
}

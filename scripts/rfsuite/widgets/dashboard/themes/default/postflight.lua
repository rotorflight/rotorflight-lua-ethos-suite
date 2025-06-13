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
    {col=1, row=1, type="text", subtype="stats", source="voltage", stattype="min", title="MIN VOLTAGE", titlepos="bottom"},
    {col=2, row=1, type="text", subtype="stats", source="voltage", stattype="max", title="MAX VOLTAGE", titlepos="bottom"},
    {col=1, row=2, type="text", subtype="stats", source="current", stattype="min", title="MIN CURRENT", titlepos="bottom", transform="floor"},
    {col=2, row=2, type="text", subtype="stats", source="current", stattype="max", title="MAX CURRENT", titlepos="bottom", transform="floor"},
    {col=1, row=3, type="text", subtype="stats", source="temp_mcu", stattype="max", title="MAX T.MCU", titlepos="bottom", transform="floor"},
    {col=2, row=3, type="text", subtype="stats", source="temp_esc", stattype="max", title="MAX E.MCU", titlepos="bottom", transform="floor"}
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
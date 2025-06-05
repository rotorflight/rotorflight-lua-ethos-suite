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
    {col=1, row=1, type="text", value=telemetry.getSensorStats('voltage').min, nosource="-", title="MIN VOLTAGE", unit="v", titlepos="bottom"},
    {col=2, row=1, type="text", value=telemetry.getSensorStats('voltage').max, nosource="-", title="MAX VOLTAGE", unit="v", titlepos="bottom"},
    {col=1, row=2, type="text", value=telemetry.getSensorStats('current').min, nosource="-", title="MIN CURRENT", unit="A", titlepos="bottom", transform="floor"},
    {col=2, row=2, type="text", value=telemetry.getSensorStats('current').max, nosource="-", title="MAX CURRENT", unit="A", titlepos="bottom", transform="floor"},
    {col=1, row=3, type="text", value=telemetry.getSensorStats('temp_mcu').max, nosource="-", title="MAX T.MCU", unit="°", titlepos="bottom", transform="floor"},
    {col=2, row=3, type="text", value=telemetry.getSensorStats('temp_esc').max, nosource="-", title="MAX E.MCU", unit="°", titlepos="bottom", transform="floor"}
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
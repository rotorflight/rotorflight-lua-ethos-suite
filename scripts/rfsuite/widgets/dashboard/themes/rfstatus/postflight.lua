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

local telemetry = rfsuite.tasks.telemetry

local darkMode = {
    textcolor   = "white",
}

local lightMode = {
    textcolor   = "black",
}

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode



local layout = {
    cols = 2,
    rows = 3,
    padding = 4
}

local boxes = {
    {col=1, row=1, type="text", subtype="stats", source="voltage", stattype="min", title=i18n("widgets.dashboard.min_voltage"):upper(), titlepos="bottom", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor},
    {col=2, row=1, type="text", subtype="stats", source="voltage", stattype="max", title=i18n("widgets.dashboard.max_voltage"):upper(), titlepos="bottom", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor},
    {col=1, row=2, type="text", subtype="stats", source="current", stattype="min", title=i18n("widgets.dashboard.min_current"):upper(), titlepos="bottom", transform="floor", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor},
    {col=2, row=2, type="text", subtype="stats", source="current", stattype="max", title=i18n("widgets.dashboard.max_current"):upper(), titlepos="bottom", transform="floor", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor},
    {col=1, row=3, type="text", subtype="stats", source="temp_mcu", stattype="max", title=i18n("widgets.dashboard.max_tmcu"):upper(), titlepos="bottom", transform="floor", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor},
    {col=2, row=3, type="text", subtype="stats", source="temp_esc", stattype="max", title=i18n("widgets.dashboard.max_emcu"):upper(), titlepos="bottom", transform="floor", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor}
}



return {
    layout = layout,
    wakeup = wakeup,
    boxes = boxes,
    scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }       
}
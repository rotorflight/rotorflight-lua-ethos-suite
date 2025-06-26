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
    {col=1, row=1, type="text", subtype="stats", source="voltage", stattype="min", title="MIN VOLTAGE", titlepos="bottom", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor},
    {col=2, row=1, type="text", subtype="stats", source="voltage", stattype="max", title="MAX VOLTAGE", titlepos="bottom", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor},
    {col=1, row=2, type="text", subtype="stats", source="current", stattype="min", title="MIN CURRENT", titlepos="bottom", transform="floor", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor},
    {col=2, row=2, type="text", subtype="stats", source="current", stattype="max", title="MAX CURRENT", titlepos="bottom", transform="floor", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor},
    {col=1, row=3, type="text", subtype="stats", source="temp_mcu", stattype="max", title="MAX T.MCU", titlepos="bottom", transform="floor", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor},
    {col=2, row=3, type="text", subtype="stats", source="temp_esc", stattype="max", title="MAX E.MCU", titlepos="bottom", transform="floor", textcolor=colorMode.textcolor, titlecolor=colorMode.textcolor}
}



return {
    layout = layout,
    wakeup = wakeup,
    boxes = boxes,
    scheduler = {
        spread_scheduling = true,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
        spread_ratio = 0.8              -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }       
}
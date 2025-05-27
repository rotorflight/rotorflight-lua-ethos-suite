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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]] --

local telemetry = rfsuite.tasks.telemetry

local layout = {
    cols = 2,
    rows = 1,
    padding = 4
}

local boxes = {
    {col = 1, row = 1, rowspan = 4, type = "telemetry", source = "voltage", title = "VOLTAGE", unit = "v", titlepos = "bottom"},
    {col = 2, row = 1, rowspan = 4, type = "telemetry", source = "fuel", title = "FUEL", unit = "%", titlepos = "bottom", transform = "floor"},
}

return {
    layout = layout,
    boxes = boxes,
}

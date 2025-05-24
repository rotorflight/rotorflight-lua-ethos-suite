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
    {col=1, row=1, type="text", value=telemetry.getSensorStats('voltage').min, novalue="-", title="MIN VOLTAGE", unit="v", titlepos="bottom"},
    {col=2, row=1, type="text", value=telemetry.getSensorStats('voltage').max, novalue="-", title="MAX VOLTAGE", unit="v", titlepos="bottom"},
    {col=1, row=2, type="text", value=telemetry.getSensorStats('current').min, novalue="-", title="MIN CURRENT", unit="A", titlepos="bottom", transform="floor"},
    {col=2, row=2, type="text", value=telemetry.getSensorStats('current').max, novalue="-", title="MAX CURRENT", unit="A", titlepos="bottom", transform="floor"},
    {col=1, row=3, type="text", value=telemetry.getSensorStats('temp_mcu').max, novalue="-", title="MAX T.MCU", unit="°", titlepos="bottom", transform="floor"},
    {col=2, row=3, type="text", value=telemetry.getSensorStats('temp_esc').max, novalue="-", title="MAX E.MCU", unit="°", titlepos="bottom", transform="floor"}
}

return {
    layout = layout,
    boxes = boxes,
}
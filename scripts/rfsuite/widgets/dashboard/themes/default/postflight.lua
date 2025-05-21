--[[
 * Copyright (C) Rotorflight Project
 *
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
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --

--[[

this is an example of the options that can be used in the dashboard

return {
    layout = {
        cols =3,
        rows = 4,
        padding = 4
    },
    boxes = {
        {col=1, row=1, type="telemetry", source="governor", title="GOVERNOR", unit="", color=nil, titlealign="left", titlecolor = "red", valuealign="right", titlepaddingleft = 10, transform=function(v) return rfsuite.utils.getGovernorState(v) end},
        {col=2, row=1, type="telemetry", source="current", title="CURRENT", unit="A", color="orange", transform = function(v) return v and math.floor(v / 100) * 100 end, titlealign="center", valuealign="center"},
        {col=3, row=1, type="telemetry", source="rpm", title="RPM", unit="RPM", color="red", transform="floor", titlealign="right", valuealign="left"},
        {col=1, row=2, colspan=2, type="text", value="PRE-FLIGHT", title="", unit="", color={0, 188, 4}, bgcolor="blue", titlealign="center", valuealign="center"},
        {col=3, row=2, type="image", value="widgets/dashboard/default_image.png", title="My Craft", titlecolor="black", bgcolor="white", imagepadding = 10, imagewidth=60, imageheight=60, imagealign="left", titlepos="bottom"}

    }
}
]]

local telemetry = rfsuite.tasks.telemetry

return {
    layout = {
        cols = 2,
        rows = 3,
        padding = 4
    },
    boxes = {
        {col = 1, row = 1,    type = "text", value = telemetry.getSensorStats('voltage').min, title = "MIN VOLTAGE", unit = "v", titlepos = "bottom"},
        {col = 2, row = 1,    type = "text", value = telemetry.getSensorStats('voltage').max, title = "MAX VOLTAGE", unit = "v", titlepos = "bottom"},

        {col = 1, row = 2,    type = "text", value = telemetry.getSensorStats('current').min, title = "MIN CURRENT", unit = "A", titlepos = "bottom", transform="floor"},
        {col = 2, row = 2,    type = "text", value = telemetry.getSensorStats('current').max, title = "MAX CURRENT", unit = "A", titlepos = "bottom", transform="floor"},
        
        {col = 1, row = 3,    type = "text", value = telemetry.getSensorStats('temp_mcu').max, title = "MAX T.MCU", unit = "°", titlepos = "bottom", transform="floor"},
        {col = 2, row = 3,    type = "text", value = telemetry.getSensorStats('temp_esc').max, title = "MAX E.MCU", unit = "°", titlepos = "bottom", transform="floor"},
    }
}


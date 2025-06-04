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

local function default_box()
    return {
    type       = "craftname",
    title      = "Craft Name",
    titlepos   = "top",
    titlepaddingtop = 5,
    titlecolor = "grey",
    textcolor  = "white",
    valuepaddingtop = 20,
    bgcolor          = "transparent",
        -- …add any other defaults here…
    }
end

local box       = default_box()


local object = {}

-- Load the craftname module once and cache it locally
local craftname = rfsuite.widgets.toolbox.load_object(box.type)

--------------------------------------------------------------------------------
-- Wakeup: copy widget params into box for craftname.wakeup
--------------------------------------------------------------------------------
function object.wakeup(widget)

    box = default_box()

    if not widget.title then box.title = nil end

    craftname.wakeup(box, rfsuite.tasks.telemetry)
end

--------------------------------------------------------------------------------
-- Paint: copy widget params into box for craftname.paint
--------------------------------------------------------------------------------
function object.paint(widget)
    local W, H = lcd.getWindowSize()
    craftname.paint(1, 1, W-2, H-2, box)
end

return object

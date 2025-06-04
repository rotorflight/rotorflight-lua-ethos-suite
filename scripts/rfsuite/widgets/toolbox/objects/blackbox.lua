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
    type       = "blackbox",
    title      = "Blackbox",
    titlepos   = "top",
    titlepaddingtop = 5,
    titlecolor = "grey",
    textcolor  = "white",
    bgcolor          = "transparent",
    valuepaddingtop = 20,
        -- …add any other defaults here…
    }
end

local box       = default_box()

local object = {}

-- Load the blackbox module once and cache it locally
local blackbox = rfsuite.widgets.toolbox.load_object(box.type)

--------------------------------------------------------------------------------
-- Wakeup: copy widget params into box for blackbox.wakeup
--------------------------------------------------------------------------------
function object.wakeup(widget)

    box = default_box()

    if not widget.title then box.title = nil end

    blackbox.wakeup(box, rfsuite.tasks.telemetry)
end

--------------------------------------------------------------------------------
-- Paint: copy widget params into box for blackbox.paint
--------------------------------------------------------------------------------
function object.paint(widget)
    local W, H = lcd.getWindowSize()
    blackbox.paint(1, 1, W-2, H-2, box)
end

return object

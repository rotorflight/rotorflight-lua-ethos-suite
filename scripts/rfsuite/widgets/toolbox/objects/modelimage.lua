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
    type       = "modelimage",
    title      = "Model Image",
    titlepos   = "top",
    titlepaddingtop = 5,
    titlecolor = "grey",
    textcolor  = "white",
    valuepaddingtop = 20,
        -- …add any other defaults here…
    }
end

local box       = default_box()


local object = {}

-- Load the modelimage module once and cache it locally
local modelimage = rfsuite.widgets.toolbox.load_object(box.type)

--------------------------------------------------------------------------------
-- Wakeup: copy widget params into box for modelimage.wakeup
--------------------------------------------------------------------------------
function object.wakeup(widget)

    box = default_box()

    if not widget.title then box.title = nil end

    modelimage.wakeup(box, rfsuite.tasks.telemetry)
end

--------------------------------------------------------------------------------
-- Paint: copy widget params into box for modelimage.paint
--------------------------------------------------------------------------------
function object.paint(widget)
    local W, H = lcd.getWindowSize()
    modelimage.paint(0, 0, W, H, box)
end

return object

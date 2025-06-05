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
        type             = "armflags",
        title            = "Arming Flags",
        titlepos         = "top",
        titlefont        = "FONT_S",
        titlepaddingtop  = 3,
        titlecolor       = "grey",
        textcolor        = "white",
        bgcolor          = "transparent",
        valuepaddingtop  = 26,
        -- …add any other defaults here…
    }
end

local box       = default_box()

local object = {}

-- Load the armflags module once and cache it locally
local armflags = rfsuite.widgets.toolbox.load_object(box.type)

--------------------------------------------------------------------------------
-- Wakeup: copy widget params into box for armflags.wakeup
--------------------------------------------------------------------------------
function object.wakeup(widget)

    box = default_box()

    if not widget.title then box.title = nil end

    armflags.wakeup(box, rfsuite.tasks.telemetry)
end

--------------------------------------------------------------------------------
-- Paint: copy widget params into box for armflags.paint
--------------------------------------------------------------------------------
function object.paint(widget)
    local W, H = lcd.getWindowSize()
    return armflags.paint(1, 1, W-2, H-2, box)
end

return object

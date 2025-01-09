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
local rf2craftname = {wakeupSchedulerUI = os.clock()}

local sensors
local lastName

function rf2craftname.create(widget)
    -- Placeholder for widget creation logic
end

function rf2craftname.paint(widget)
    local w, h = lcd.getWindowSize()
    lcd.font(FONT_XXL)

    local str = rfsuite.bg.active() and rfsuite.config.craftName or "UNKNOWN"
    local tsizeW, tsizeH = lcd.getTextSize(str)

    local posX = (w - tsizeW) / 2
    local posY = (h - tsizeH) / 2 + 5

    lcd.drawText(posX, posY, str)
end

-- Configure function
function rf2craftname.configure(widget)
    -- Placeholder for widget configuration logic
end

-- Read function
function rf2craftname.read(widget)
    -- Placeholder for widget read logic
end

-- Write function
function rf2craftname.write(widget)
    -- Placeholder for widget write logic
end

-- Event function
function rf2craftname.event(widget, event)
    -- Placeholder for widget event logic
end

-- Main wakeup function
function rf2craftname.wakeup(widget)
    local schedulerUI = lcd.isVisible() and 0.25 or 1
    local now = os.clock()

    if (now - rf2craftname.wakeupSchedulerUI) >= schedulerUI then
        rf2craftname.wakeupSchedulerUI = now
        rf2craftname.wakeupUI()
    end
end

function rf2craftname.wakeupUI()

    if lastName ~= rfsuite.config.rf2craftnameName then lcd.invalidate() end

    lastName = rfsuite.config.rf2craftnameName

end

return rf2craftname

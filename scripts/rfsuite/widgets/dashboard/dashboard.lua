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
local dashboard = {}
local wakeupSchedulerUI = os.clock()

-- wakeup ui function
local function wakeupUI()
    -- check display size
    local LCD_W, LCD_H = lcd.getWindowSize()


end

-- Create function
function dashboard.create(widget)
    LCD_W, LCD_H = lcd.getWindowSize()
    bitmapPtr = rfsuite.utils.loadImage(default_image)
end

-- Paint function
function dashboard.paint(widget)
 
end

-- Configure function
function dashboard.configure(widget)
    return widget
end

-- Read function
function dashboard.read(widget)

end

-- Write function
function dashboard.write(widget)

end

-- Main wakeup function
function dashboard.wakeup(widget)

    -- run at lower priority if not visible to conserve CPU
    local schedulerUI = lcd.isVisible() and 0.5 or 5
    local now = os.clock()

    if (now - wakeupSchedulerUI) >= schedulerUI then
        wakeupSchedulerUI = now
        wakeupUI()
    end

end


return dashboard

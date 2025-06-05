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
local rf2craftimage = {}

local sensors
local lastName
local lastID
local bitmapPtr
local image
local default_image = "widgets/toolbox/objects/craftimage/default_image.png"
local config = {}
local LCD_W, LCD_H = lcd.getWindowSize()
local LCD_MINH4IMAGE = 130
local wakeupSchedulerUI = os.clock()



-- Paint function
function rf2craftimage.paint(widget)
    local w = LCD_W or 0
    local h = LCD_H or 0

    if not rfsuite.utils.ethosVersionAtLeast() then
        rfsuite.widgets.toolbox.utils.screenError(string.format(rfsuite.i18n.get('ethos') .. " < V%d.%d.%d", 
            rfsuite.config.ethosVersion[1], 
            rfsuite.config.ethosVersion[2], 
            rfsuite.config.ethosVersion[3])
        )
        return
    end

    if bitmapPtr ~= nil then
        local padding = 5
        local bitmapX = 0 + padding
        local bitmapY = 0 + padding
        local bitmapW = w - (padding * 2)
        local bitmapH = h - (padding * 2)
        lcd.drawBitmap(bitmapX, bitmapY, bitmapPtr, bitmapW, bitmapH)
    end

end

-- Configure function
function rf2craftimage.configure(widget)
    -- reset this to force a lcd refresh
    lastName = nil
    lastID = nil

    return widget
end


-- Main wakeup function
function rf2craftimage.wakeup(widget)
    LCD_W, LCD_H = lcd.getWindowSize()

    if lastName ~= rfsuite.session.craftName or lastID ~= rfsuite.session.modelID then
        if rfsuite.session.craftName ~= nil then image1 = "/bitmaps/models/" .. rfsuite.session.craftName .. ".png" end
        if rfsuite.session.modelID ~= nil then image2 = "/bitmaps/models/" .. rfsuite.session.modelID .. ".png" end

        bitmapPtr = rfsuite.utils.loadImage(image1, image2, default_image)

        lcd.invalidate()
    end

    lastName = rfsuite.session.craftName
    lastID = rfsuite.session.modelID
end

return rf2craftimage

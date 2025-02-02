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
local rf2craftimage = { wakeupSchedulerUI = os.clock() }

local sensors
local lastName
local lastID
local bitmapPtr
local image
local default_image = "widgets/craftimage/default_image.png"
local config = {}
local LCD_W
local LCD_H

local LCD_MINH4IMAGE = 130

-- error function
local function screenError(msg)
    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    lcd.font(FONT_STD)
    local tsizeW, tsizeH = lcd.getTextSize(msg)

    -- Set color based on theme
    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)

    -- Center the text on the screen
    local x = (w - tsizeW) / 2
    local y = (h - tsizeH) / 2
    lcd.drawText(x, y, msg)
end

-- Create function
function rf2craftimage.create(widget)
    bitmapPtr = rfsuite.utils.loadImage(default_image)
end

-- Paint function
function rf2craftimage.paint(widget)
    local w = LCD_W
    local h = LCD_H


    if rfsuite.utils.ethosVersion() < rfsuite.config.ethosVersion  then
        screenError(rfsuite.config.ethosVersionString )
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

-- Read function
function rf2craftimage.read(widget)

end

-- Write function
function rf2craftimage.write(widget)

end

-- Event function
function rf2craftimage.event(widget, event)
    -- Placeholder for widget event logic
end

-- Main wakeup function
function rf2craftimage.wakeup(widget)
    local schedulerUI = lcd.isVisible() and 0.1 or 1
    local now = os.clock()

    if (now - rf2craftimage.wakeupSchedulerUI) >= schedulerUI then
        rf2craftimage.wakeupSchedulerUI = now
        rf2craftimage.wakeupUI()
    end
end

function rf2craftimage.wakeupUI()

    LCD_W, LCD_H = lcd.getWindowSize()

    if lastName ~= rfsuite.config.craftName or lastID ~= rfsuite.config.modelID then
        if rfsuite.config.craftName ~= nil then
            image1 = "/bitmaps/models/" .. rfsuite.config.craftName .. ".png"          
        end
        if rfsuite.config.modelID ~= nil then
            image2 = "/bitmaps/models/" .. rfsuite.config.modelID .. ".png"          
        end

        bitmapPtr = rfsuite.utils.loadImage(image1,image2,default_image)  

        lcd.invalidate()
    end

    lastName = rfsuite.config.craftName
    lastID = rfsuite.config.modelID
end

return rf2craftimage

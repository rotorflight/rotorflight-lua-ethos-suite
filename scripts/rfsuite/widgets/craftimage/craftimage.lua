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
local default_image = "widgets/craftimage/default_image.png"
local config = {}
local LCD_W, LCD_H = lcd.getWindowSize()
local LCD_MINH4IMAGE = 130
local wakeupSchedulerUI = os.clock()

-- error function
local function screenError(msg)
    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    -- Available font sizes in order from smallest to largest
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}

    -- Determine the maximum width and height with 10% padding
    local maxW, maxH = w * 0.9, h * 0.9
    local bestFont = FONT_XXS
    local bestW, bestH = 0, 0

    -- Loop through font sizes and find the largest one that fits
    for _, font in ipairs(fonts) do
        lcd.font(font)
        local tsizeW, tsizeH = lcd.getTextSize(msg)
        
        if tsizeW <= maxW and tsizeH <= maxH then
            bestFont = font
            bestW, bestH = tsizeW, tsizeH
        else
            break  -- Stop checking larger fonts once one exceeds limits
        end
    end

    -- Set the optimal font
    lcd.font(bestFont)

    -- Set text color based on dark mode
    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)

    -- Center the text on the screen
    local x = (w - bestW) / 2
    local y = (h - bestH) / 2
    lcd.drawText(x, y, msg)
end

-- Wakeup UI function
local function wakeupUI()

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

-- Create function
function rf2craftimage.create(widget)
    bitmapPtr = rfsuite.utils.loadImage(default_image)
end

-- Paint function
function rf2craftimage.paint(widget)
    local w = LCD_W or 0
    local h = LCD_H or 0

    if not rfsuite.utils.ethosVersionAtLeast() then
        screenError(string.format(rfsuite.i18n.get('ethos') .. " < V%d.%d.%d", 
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
    local schedulerUI = lcd.isVisible() and 0.5 or 5
    local now = os.clock()

    if (now - wakeupSchedulerUI) >= schedulerUI then
        wakeupSchedulerUI = now
        wakeupUI()
    end


end

return rf2craftimage

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
local rf2craftname = { wakeupSchedulerUI = os.clock() }

local sensors
local lastName
local lastID
local bitmapPtr
local image
local default_image = "widgets/craftname/default_image.png"
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
function rf2craftname.create(widget)
    LCD_W, LCD_H = lcd.getWindowSize()    
    bitmapPtr = rfsuite.utils.loadImage(default_image)
end

-- Paint function
function rf2craftname.paint(widget)

    if rfsuite.utils.ethosVersion() < rfsuite.config.ethosVersion  then
        screenError(rfsuite.config.ethosVersionString )
        return
    end

    local w = LCD_W
    local h = LCD_H

    if config.fontSize == 0 then
        lcd.font(FONT_S)
    elseif config.fontSize == 1 then
        lcd.font(FONT_M)
    elseif config.fontSize == 2 then
        lcd.font(FONT_L)    
    elseif config.fontSize == 3 then  
        lcd.font(FONT_XL)
    else
        lcd.font(FONT_M)
    end

    local str = rfsuite.bg.active() and rfsuite.config.craftName or "[NO LINK]"
    local tsizeW, tsizeH = lcd.getTextSize(str)
    local posX = (w - tsizeW) / 2
    local posY = 5

    if config.image == false then
        posY = (h - tsizeH) / 2 + 5
    else
        if bitmapPtr ~= nil then
            local padding = 5
            local bitmapX = 0 + padding
            local bitmapY = 0 + padding + tsizeH
            local bitmapW = w - (padding * 2)
            local bitmapH = h - (padding * 2) - tsizeH
            lcd.drawBitmap(bitmapX, bitmapY, bitmapPtr, bitmapW, bitmapH)
        end
    end
    lcd.drawText(posX, posY, str)
end

-- Configure function
function rf2craftname.configure(widget)
    -- reset this to force a lcd refresh
    lastName = nil
    lastID = nil


    if LCD_H > LCD_MINH4IMAGE then
        local line = form.addLine("Image")
        form.addBooleanField(line,
            nil,
            function() return config.image end,
            function(newValue) config.image = newValue end)
    end

    local sizeTable = {{"Small", 0}, {"Medium", 1}, {"Large", 2}, {"X Large", 3},}
    local line = form.addLine("Font Size")
    form.addChoiceField(line, nil, sizeTable, function()
        return config.fontSize
    end, function(newValue)
        config.fontSize = newValue
    end)

    return widget
end

-- Read function
function rf2craftname.read(widget)
    -- display or not display an image on the page
    config.image = storage.read("mem1")
    if config.image == nil then config.image = false end

    -- font size
    config.fontSize = storage.read("mem2")
    if config.fontSize == nil then config.fontSize = 2 end

end

-- Write function
function rf2craftname.write(widget)
    storage.write("mem1", config.image)
    storage.read("mem2", config.fontSize)
end

-- Event function
function rf2craftname.event(widget, event)
    -- Placeholder for widget event logic
end

-- Main wakeup function
function rf2craftname.wakeup(widget)
    local schedulerUI = lcd.isVisible() and 0.1 or 1
    local now = os.clock()

    if (now - rf2craftname.wakeupSchedulerUI) >= schedulerUI then
        rf2craftname.wakeupSchedulerUI = now
        rf2craftname.wakeupUI()
    end
end

function rf2craftname.wakeupUI()

    LCD_W, LCD_H = lcd.getWindowSize()

    if LCD_H < LCD_MINH4IMAGE then
        config.image = false
    end

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

return rf2craftname

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
local bitmapPtr
local image
local default_image = "widgets/craftimage/default_image.png"
local config = {}
local LCD_W
local LCD_H

local LCD_MINH4IMAGE = 130

-- Helper function to check if file exists
local function file_exists(name)
    local f = io.open(name, "r")
    if f then
        io.close(f)
        return true
    end
    return false
end

-- Helper function to load image
local function loadImage(image)
    if image == nil then
        image = default_image
    end

    -- Helper function to check file in different locations
    local function find_image_in_directories(img)

        if file_exists(img) then
            return img
        elseif file_exists("BITMAPS:" .. img) then
            return "BITMAPS:" .. img
        elseif file_exists("SYSTEM:" .. img) then
            return "SYSTEM:" .. img
        else
            return nil
        end
    end

    -- 1. Check the provided image path
    local image_path = find_image_in_directories(image)

    -- 2. If not found, try switching between .png and .bmp
    if not image_path then
        if image:match("%.png$") then
            image_path = find_image_in_directories(image:gsub("%.png$", ".bmp"))
        elseif image:match("%.bmp$") then
            image_path = find_image_in_directories(image:gsub("%.bmp$", ".png"))
        end
    end

    -- 3. If still not found, use the default image
    if not image_path then
        image_path = default_image
    end

    bitmapPtr = lcd.loadBitmap(image_path)
    return bitmapPtr
end

-- Create function
function rf2craftimage.create(widget)
    bitmapPtr = loadImage(default_image)
end

-- Paint function
function rf2craftimage.paint(widget)
    local w = LCD_W
    local h = LCD_H


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

    if lastName ~= rfsuite.config.craftName then
        if rfsuite.config.craftName ~= nil then
            image = "/bitmaps/models/" .. rfsuite.config.craftName .. ".png"
            bitmapPtr = loadImage(image)
        else
            bitmapPtr = loadImage(default_image)
        end

        lcd.invalidate()
    end

    lastName = rfsuite.config.craftName
end

return rf2craftimage

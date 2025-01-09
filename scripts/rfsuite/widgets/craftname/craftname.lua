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

local lastName
local bitmapPtr
local default_image = "/bitmaps/system/default_helicopter.png"
local config = {}

-- Helper function to load a bitmap from various paths
local function load_bitmap(image)
    local paths = { "", "BITMAPS:", "SYSTEM:" }
    for _, path in ipairs(paths) do
        local full_path = path .. image
        if io.open(full_path, "r") then
            return lcd.loadBitmap(full_path)
        end
    end
    return nil
end

-- Create widget
function rf2craftname.create()
    bitmapPtr = load_bitmap(default_image)
end

-- Paint widget
function rf2craftname.paint()
    local w, h = lcd.getWindowSize()
    local craftName = rfsuite.bg.active() and rfsuite.config.craftName or "UNKNOWN"
    local tsizeW, tsizeH = lcd.getTextSize(craftName)
    local posX = (w - tsizeW) / 2
    local posY = config.image and 5 or (h - tsizeH) / 2 + 5

    if config.image and bitmapPtr then
        local padding = 5
        lcd.drawBitmap(padding, padding + tsizeH, bitmapPtr, w - padding * 2, h - padding * 2 - tsizeH)
    end

    lcd.drawText(posX, posY, craftName)
end

-- Configure widget
function rf2craftname.configure()
    lastName = nil
    local line = form.addLine("Image")
    form.addBooleanField(line, nil, function() return config.image end, function(val) config.image = val end)
end

-- Read widget state
function rf2craftname.read()
    config.image = storage.read("mem1") or false
end

-- Write widget state
function rf2craftname.write()
    storage.write("mem1", config.image)
end

-- Event handler (placeholder)
function rf2craftname.event(_, _)
    -- Placeholder for event handling
end

-- Wakeup function
function rf2craftname.wakeup()
    if (os.clock() - rf2craftname.wakeupSchedulerUI) >= (lcd.isVisible() and 0.1 or 1) then
        rf2craftname.wakeupSchedulerUI = os.clock()
        rf2craftname.wakeupUI()
    end
end

-- Wakeup UI function
function rf2craftname.wakeupUI()
    local craftName = rfsuite.config.craftName
    if lastName ~= craftName then
        bitmapPtr = config.image and load_bitmap("/bitmaps/models/" .. (craftName or "default_helicopter") .. ".png") or nil
        if not bitmapPtr then
            bitmapPtr = load_bitmap(default_image)
        end
        lcd.invalidate()
        lastName = craftName
    end
end

return rf2craftname
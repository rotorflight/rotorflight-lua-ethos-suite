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
local bitmapPtr 

local config = {}


-- Helper function to check if file exists
local function file_exists(name)
    local f = io.open(name, "r")
    if f then
        io.close(f)
        return true
    end
    return false
end

function rf2craftname.create(widget)
    -- Placeholder for widget creation logic
end

function rf2craftname.paint(widget)
    local w, h = lcd.getWindowSize()

    if config.image == false then

        lcd.font(FONT_XXL)
        local str = rfsuite.bg.active() and rfsuite.config.craftName or "UNKNOWN"
        local tsizeW, tsizeH = lcd.getTextSize(str)
    
        local posX = (w - tsizeW) / 2
        local posY = (h - tsizeH) / 2 + 5

        lcd.drawText(posX, posY, str)
    else
        lcd.font(FONT_XL)

        local str = rfsuite.bg.active() and rfsuite.config.craftName or "UNKNOWN"
        local tsizeW, tsizeH = lcd.getTextSize(str)
    
        local posX = (w - tsizeW) / 2
        if bitmapPtr ~= nil then
            local padding = 5
            local bitmapX = 0 + padding
            local bitmapY = 0 + padding + tsizeH 
            local bitmapW = w - (padding * 2)
            local bitmapH = h - (padding * 2) - tsizeH
            lcd.drawBitmap(bitmapX, bitmapY, bitmapPtr, bitmapW, bitmapH)
        end
        lcd.drawText(posX, 5, str)
    end
end

-- Configure function
function rf2craftname.configure(widget)

    local line = form.addLine("Image")
    form.addBooleanField(line, 
                        nil, 
                        function() return config.image end, 
                        function(newValue) config.image = newValue end)

    return widget
end

-- Read function
function rf2craftname.read(widget)

    -- display or not display an image on the page
    config.image = storage.read("mem1") 
    if config.image == nil then config.image = false end

end

-- Write function
function rf2craftname.write(widget)

    storage.write("mem1", config.image)

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
    local image

    if lastName ~= rfsuite.config.craftName then
        -- load image if it is enabled
        if config.image == true then
            if rfsuite.config.craftName ~= nil then
                image = "/bitmaps/models/" .. rfsuite.config.craftName .. ".png"

                if file_exists(image) then
                    bitmapPtr = lcd.loadBitmap(image)
                elseif file_exists("BITMAPS:" .. image) then    
                    bitmapPtr = lcd.loadBitmap("BITMAPS:" .. image)
                elseif file_exists("SYSTEM:" .. image) then    
                    bitmapPtr = lcd.loadBitmap("SYSTEM:" .. image)
                else
                    bitmapPtr = nil
                end
            else
                bitmapPtr = nil
            end
        end    
        lcd.invalidate()
    end
    lastName = rfsuite.config.craftName

end

return rf2craftname

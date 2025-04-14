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
local rf2bbl = {}

local config = {}
local LCD_W, LCD_H = lcd.getWindowSize()
local wakeupSchedulerUI = os.clock()

local isErase = false
local init = true

local summary = {}

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

local function getDataflashSummary()
    local message = {
        command = 70, -- MSP_DATAFLASH_SUMMARY
        processReply = function(self, buf)

            local flags = rfsuite.tasks.msp.mspHelper.readU8(buf)
            summary.ready = (flags & 1) ~= 0
            summary.supported = (flags & 2) ~= 0
            summary.sectors = rfsuite.tasks.msp.mspHelper.readU32(buf)
            summary.totalSize = rfsuite.tasks.msp.mspHelper.readU32(buf)
            summary.usedSize = rfsuite.tasks.msp.mspHelper.readU32(buf)

        end,
        simulatorResponse = {3, 1, 0, 0, 0, 0, 4, 0, 0, 0, 3, 0, 0}
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function eraseDataflash()

    isErase = true

    local message = {
        command = 72, -- MSP_DATAFLASH_ERASE
        processReply = function(self, buf)
            summary = {}
            isErase = false
            getDataflashSummary()
        end,
        simulatorResponse = {}
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

-- Wakeup UI function
local function wakeupUI()

    LCD_W, LCD_H = lcd.getWindowSize()

    if rfsuite and rfsuite.tasks.active() then
        getDataflashSummary()
    else
        summary = {}
    end


end

local function getFreeDataflashSpace()
    if not summary.supported then return rfsuite.i18n.get("app.modules.status.unsupported") end
    local freeSpace = summary.totalSize - summary.usedSize
    return string.format("%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"), freeSpace / (1024 * 1024))
end

-- Create function
function rf2bbl.create(widget)

end

-- Paint function
function rf2bbl.paint(widget)
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


    if isErase then
        msg = rfsuite.i18n.get("widgets.bbl.erasing")
    elseif summary.totalSize and summary.usedSize then
        msg = getFreeDataflashSpace()
    else
        msg = rfsuite.i18n.get('app.msg_loading')
    end

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

-- Configure function
function rf2bbl.configure(widget)
    return widget
end

function rf2bbl.menu(widget)
	return {
		{ rfsuite.i18n.get("widgets.bbl.erase_dataflash"), function() eraseDataflash() end},
	}
end

-- Main wakeup function
function rf2bbl.wakeup(widget)
    local schedulerUI = 2
    local now = os.clock()

    if lcd.isVisible() then
        if ((now - wakeupSchedulerUI) >= schedulerUI) or init == true then
            wakeupSchedulerUI = now
                wakeupUI()
                lcd.invalidate()
                init = false
        end
    end


end

return rf2bbl

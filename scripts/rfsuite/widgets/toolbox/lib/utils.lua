--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local utils = {}

function utils.box(title, msg)

    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    local offsetY = 0

    local TITLE_COLOR = lcd.darkMode() and lcd.RGB(154, 154, 154) or lcd.RGB(77, 73, 77)
    local TEXT_COLOR = lcd.darkMode() and lcd.RGB(255, 255, 255) or lcd.RGB(77, 73, 77)

    if title then
        local fonts = {FONT_XXS, FONT_XS, FONT_S}

        local maxW, maxH = w, h
        local bestFont = FONT_XXS
        local bestW, bestH = 0, 0

        for _, font in ipairs(fonts) do
            lcd.font(font)
            local tsizeW, tsizeH = lcd.getTextSize(title)

            if tsizeW <= maxW and tsizeH <= maxH then
                bestFont = font
                bestW, bestH = tsizeW, tsizeH
            else
                break
            end
        end

        lcd.font(bestFont)

        local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
        lcd.color(textColor)

        local x = (w - bestW) / 2
        local y = bestH / 4
        lcd.color(TITLE_COLOR)
        lcd.drawText(x, y, title)

        offsetY = bestH - 3

    end

    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}

    local maxW, maxH = w, h
    local bestFont = FONT_XXS
    local bestW, bestH = 0, 0

    for _, font in ipairs(fonts) do
        lcd.font(font)
        local tsizeW, tsizeH = lcd.getTextSize(msg)

        if tsizeW <= maxW and tsizeH <= maxH then
            bestFont = font
            bestW, bestH = tsizeW, tsizeH
        else
            break
        end
    end

    lcd.font(bestFont)

    local x = (w - bestW) / 2
    local y = (h - bestH) / 2 + offsetY
    lcd.color(TEXT_COLOR)
    lcd.drawText(x, y, msg)
end

return utils

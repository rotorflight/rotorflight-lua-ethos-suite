local utils = {}

function utils.screenError(msg)
    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}
    local maxW, maxH = w * 0.9, h * 0.9
    local bestFont, bestW, bestH = FONT_XXS, 0, 0
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
    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)
    local x = (w - bestW) / 2
    local y = (h - bestH) / 2
    lcd.drawText(x, y, msg)
end

function utils.telemetryBox(x, y, w, h, color, title, value, unit, titletop)
    local isDARKMODE = lcd.darkMode()

    -- Set background color based on mode
    lcd.color(isDARKMODE and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.drawFilledRectangle(x, y, w, h)

    -- Set text color
    lcd.color(isDARKMODE and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90))

    if value ~= nil then
        local str = value .. unit

        local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}

        local maxW, maxH = w * 0.9, h * 0.9
        local bestFont, bestW, bestH = FONT_XXS, 0, 0

        for _, font in ipairs(fonts) do
            lcd.font(font)
            local tW, tH = lcd.getTextSize(unit == "°" and value .. "." or str)
            if tW <= (maxW) and tH <= (maxH) then
                bestFont, bestW, bestH = font, tW, tH
            else
                break
            end
        end

        -- Adjust vertical placement if title is at the top or bottom
        local offsetY = 0
        if title and titletop then
            -- Give a small padding below the title at the top
            offsetY = 10
        end

        local sx = (x + w / 2) - (bestW / 2)
        local sy = (y + h / 2) - (bestH / 2) + (offsetY / 2)

        lcd.font(bestFont)

        -- Set text color based on alarm flag
        if type(color) == "number" then
            if color == 1 then
                lcd.color(lcd.RGB(255, 0, 0, 1)) -- red
            elseif color == 2 then
                lcd.color(lcd.RGB(255, 204, 0, 1)) -- orange
            elseif color == 3 then
                lcd.color(lcd.RGB(0, 188, 4, 1)) -- green
            end
        elseif type(color) == "table" then
            lcd.color(color[1], color[2], color[3], 1)
        end

        lcd.drawText(sx, sy, str)
    end

    if title then
        lcd.color(isDARKMODE and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90))
        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(title)
        local sx = (x + w / 2) - (tsizeW / 2)
        local sy
        if titletop then
            -- Draw at the top with a little padding
            sy = y + tsizeH/4
        else
            -- Draw at the bottom (original behavior)
            sy = (y + h) - (tsizeH + tsizeH / 4)
        end
        lcd.drawText(sx, sy, title)
    end
end

function utils.setBackgroundColourBasedOnTheme()
    local w, h = lcd.getWindowSize()
    if lcd.darkMode() then
        -- dark theme
        lcd.color(lcd.RGB(16, 16, 16))
    else
        -- light theme
        lcd.color(lcd.RGB(209, 208, 208))
    end
    lcd.drawFilledRectangle(0, 0, w, h)
end


return utils
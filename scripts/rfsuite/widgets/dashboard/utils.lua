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

function utils.resolveColor(value)
    local namedColors = {
        red   = {255, 0, 0},
        green = {0, 188, 4},
        blue  = {0, 122, 255},
        white = {255, 255, 255},
        black = {0, 0, 0},
        gray  = {90, 90, 90},
        orange = {255, 204, 0},
        yellow = {255, 255, 0},
        cyan = {0, 255, 255},
        magenta = {255, 0, 255},
    }

    if type(value) == "string" and namedColors[value] then
        return lcd.RGB(namedColors[value][1], namedColors[value][2], namedColors[value][3], 1)
    elseif type(value) == "table" and #value >= 3 then
        return lcd.RGB(value[1], value[2], value[3], 1)
    end

    return nil -- fallback handling will occur elsewhere
end


function utils.telemetryBox(x, y, w, h, color, title, value, unit, titletop, bgcolor)
    local isDARKMODE = lcd.darkMode()

    -- Set background color (custom or default)
    local resolvedBg = utils.resolveColor(bgcolor)
    lcd.color(resolvedBg or (isDARKMODE and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)))
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
            if tW <= maxW and tH <= maxH then
                bestFont, bestW, bestH = font, tW, tH
            else
                break
            end
        end

        local offsetY = 0
        if title and titletop then
            offsetY = 10
        end

        local sx = (x + w / 2) - (bestW / 2)
        local sy = (y + h / 2) - (bestH / 2) + (offsetY / 2)

        lcd.font(bestFont)

        local resolvedColor = utils.resolveColor(color)
        if resolvedColor then
            lcd.color(resolvedColor)
        end

        lcd.drawText(sx, sy, str)
    end

    if title then
        lcd.color(isDARKMODE and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90))
        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(title)
        local sx = (x + w / 2) - (tsizeW / 2)
        local sy = titletop and (y + tsizeH / 4) or ((y + h) - (tsizeH + tsizeH / 4))
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
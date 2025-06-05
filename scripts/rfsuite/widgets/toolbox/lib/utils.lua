
local utils = {}

-- error function
function utils.box(title, msg)

    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    local offsetY = 0

    local TITLE_COLOR = lcd.darkMode() and lcd.RGB(154,154,154) or lcd.RGB(77, 73, 77)
    local TEXT_COLOR = lcd.darkMode() and lcd.RGB(255, 255, 255) or lcd.RGB(77, 73, 77)

    ---------------------------------------------------------------------------
    -- Step 1.  Display the title at top of the screen
    ---------------------------------------------------------------------------
    if title then
        local fonts = {FONT_XXS, FONT_XS, FONT_S}

    -- Determine the maximum width and height with 10% padding
        local maxW, maxH = w , h 
        local bestFont = FONT_XXS
        local bestW, bestH = 0, 0

        -- Loop through font sizes and find the largest one that fits
        for _, font in ipairs(fonts) do
            lcd.font(font)
            local tsizeW, tsizeH = lcd.getTextSize(title)
            
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

        -- Center the text at top of the screen
        local x = (w - bestW) / 2
        local y = bestH/4
        lcd.color(TITLE_COLOR)  -- Set title color
        lcd.drawText(x, y, title)    

        -- if we have a title, we need to bump the y position down for the display of the value message
        offsetY = bestH - 3  -- Add some padding below the title

    end

    ---------------------------------------------------------------------------
    -- Step 2.  Display the value message in the center of the screen
    ---------------------------------------------------------------------------
    -- Available font sizes in order from smallest to largest
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}

    -- Determine the maximum width and height with 10% padding
    local maxW, maxH = w , h 
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

    -- Center the text on the screen
    local x = (w - bestW) / 2
    local y = (h - bestH) / 2 + offsetY  -- Adjust y position based on title height
    lcd.color(TEXT_COLOR)  -- Reset text color for values
    lcd.drawText(x, y, msg)
end

return utils
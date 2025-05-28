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
 
local utils = {}

local imageCache = {}
local fontCache 


--[[
    Returns a table of available font lists (default and reduced) based on the current LCD resolution.
    The function detects the screen size and selects appropriate font sizes for supported radio models.
    If the resolution is not recognized, a default set of fonts is returned.
]]
function utils.getFontListsForResolution()
    local version = system.getVersion()
    local LCD_W = version.lcdWidth
    local LCD_H = version.lcdHeight
    local resolution = LCD_W .. "x" .. LCD_H


    local radios = {
        -- TANDEM X20, TANDEM XE (800x480)
        ["800x480"] = {
            value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL, FONT_XXXXL},
            value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L},
            value_title = FONT_XS
        },
        -- TANDEM X18, TWIN X Lite (480x320)
        ["480x320"] = {
            value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL},
            value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L},
            value_title = FONT_XXS
        },
        -- Horus X10, Horus X12 (480x272)
        ["480x272"] = {
            value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD},
            value_reduced = {FONT_XXS, FONT_XS, FONT_S},
            value_title = FONT_XXS
        },
        -- Twin X14 (632x314)
        ["640x360"] = {
            value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL},
            value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L},
            value_title = FONT_XXS
        }
    }
    if not radios[resolution] then
        rfsuite.utils.log("Unsupported resolution: " .. resolution .. ". Using default fonts.","info")
        return radios["800x480"]
    end
    return radios[resolution] 

end


--[[
    Clears all cached images from the image cache.
    Call this to free memory or when themes/images change.
]]
function utils.resetImageCache()
    for k in pairs(imageCache) do
        imageCache[k] = nil
    end
end

--[[
    Displays a centered error message on the screen,
    choosing the largest font that fits.
    Args: msg (string) - message to display
]]
function utils.screenError(msg)
    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL, FONT_XXXXL}
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

--[[
    Displays a translucent error overlay box with centered message.
    Args: msg (string) - error message
]]
function utils.screenErrorOverlay(msg)
    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()
    local boxW = w * 0.8

    -- Dynamically scale font for text
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}
    local bestFont, bestW, bestH = FONT_XXS, 0, 0
    local maxW = boxW * 0.9

    for _, font in ipairs(fonts) do
        lcd.font(font)
        local tW, tH = lcd.getTextSize(msg)
        if tW <= maxW then
            bestFont, bestW, bestH = font, tW, tH
        else
            break
        end
    end

    local boxH = bestH * 2
    local boxX = (w - boxW) / 2
    local boxY = (h - boxH) / 2

    -- Draw background box
    lcd.color(isDarkMode and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.drawFilledRectangle(boxX, boxY, boxW, boxH)

    -- Draw border
    lcd.color(isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90))
    lcd.drawRectangle(boxX, boxY, boxW, boxH)

    -- Draw text
    lcd.font(bestFont)
    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)
    local textX = (w - bestW) / 2
    local textY = (h - bestH) / 2
    lcd.drawText(textX, textY, msg)
end

--[[
    Calculates the starting X coordinate for a string based on alignment.
    Args: text (string)   - text to align
          align (string)  - "left", "center", or "right"
          x (number)      - left of region
          w (number)      - width of region
    Returns: number (aligned X)
]]
function utils.getAlignedX(text, align, x, w)
    local tsize = lcd.getTextSize(text)
    if align == "right" then
        return x + w - tsize
    elseif align == "left" then
        return x
    else -- center
        return x + (w - tsize) / 2
    end
end

--[[
    Resolves a color name (string) or RGB table to a display color value.
    Args: value (string or table) - color name or {r,g,b}
    Returns: lcd.RGB color value or nil if not recognized
]]
function utils.resolveColor(value)
    local namedColors = {
        red       = {255, 0, 0},
        green     = {0, 188, 4},
        blue      = {0, 122, 255},
        white     = {255, 255, 255},
        black     = {0, 0, 0},
        gray      = {90, 90, 90},
        grey      = {90, 90, 90},
        orange    = {255, 165, 0},
        yellow    = {255, 255, 0},
        cyan      = {0, 255, 255},
        magenta   = {255, 0, 255},
        pink      = {255, 105, 180},
        purple    = {128, 0, 128},
        violet    = {143, 0, 255},
        brown     = {139, 69, 19},
        lime      = {0, 255, 0},
        olive     = {128, 128, 0},
        gold      = {255, 215, 0},
        silver    = {192, 192, 192},
        teal      = {0, 128, 128},
        navy      = {0, 0, 128},
        maroon    = {128, 0, 0},
        beige     = {245, 245, 220},
        turquoise = {64, 224, 208},
        indigo    = {75, 0, 130},
        coral     = {255, 127, 80},
        salmon    = {250, 128, 114},
        mint      = {62, 180, 137},
    }

    if type(value) == "string" and namedColors[value] then
        return lcd.RGB(namedColors[value][1], namedColors[value][2], namedColors[value][3], 1)
    elseif type(value) == "table" and #value >= 3 then
        return lcd.RGB(value[1], value[2], value[3], 1)
    end

    return nil -- fallback handling will occur elsewhere
end

--[[
    Draws a telemetry value box with colored background, value, title, unit, and flexible padding.
    Handles alignment and font sizing for both title and value.
    Args: x, y, w, h         - Box geometry
          color, title, value, unit, bgcolor
          titlealign, valuealign, titlecolor, titlepos
          (plus many optional paddings)
]]
function utils.box(
    x, y, w, h, color, title, value, unit, bgcolor,
    titlealign, valuealign, titlecolor, titlepos,
    titlepadding, titlepaddingleft, titlepaddingright, titlepaddingtop, titlepaddingbottom,
    valuepadding, valuepaddingleft, valuepaddingright, valuepaddingtop, valuepaddingbottom
)
    local isDARKMODE = lcd.darkMode()
    local resolvedBg = utils.resolveColor(bgcolor)
    lcd.color(resolvedBg or (isDARKMODE and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)))
    lcd.drawFilledRectangle(x, y, w, h)

    -- Padding resolution (default 0)
    titlepaddingleft = titlepaddingleft or titlepadding or 0
    titlepaddingright = titlepaddingright or titlepadding or 0
    titlepaddingtop = titlepaddingtop or titlepadding or 0
    titlepaddingbottom = titlepaddingbottom or titlepadding or 0

    valuepaddingleft = valuepaddingleft or valuepadding or 0
    valuepaddingright = valuepaddingright or valuepadding or 0
    valuepaddingtop = valuepaddingtop or valuepadding or 0
    valuepaddingbottom = valuepaddingbottom or valuepadding or 0

    if not fontCache then
        fontCache = utils.getFontListsForResolution()
    end

    -- Draw value
    if value ~= nil then
        local str = tostring(value) .. (unit or "")
        local unitIsDegree = (unit == "°" or (unit and unit:find("°")))
        local strForWidth = unitIsDegree and (tostring(value) .. "0") or str

        local availH = h - valuepaddingtop - valuepaddingbottom
        local fonts = fontCache.value_default

        lcd.font(FONT_XL)
        local _, xlFontHeight = lcd.getTextSize("8")
        if xlFontHeight > availH * 0.5 then
            fonts = fontCache.value_reduced
        end

        local maxW, maxH = w - valuepaddingleft - valuepaddingright, availH
        local bestFont, bestW, bestH = FONT_XXS, 0, 0
        for _, font in ipairs(fonts) do
            lcd.font(font)
            local tW, tH = lcd.getTextSize(strForWidth)
            if tW <= maxW and tH <= maxH then
                bestFont, bestW, bestH = font, tW, tH
            else
                break
            end
        end
        lcd.font(bestFont)
        local region_x = x + valuepaddingleft
        local region_y = y + valuepaddingtop
        local region_w = w - valuepaddingleft - valuepaddingright
        local region_h = h - valuepaddingtop - valuepaddingbottom

        local sy = region_y + (region_h - bestH) / 2
        local align = (valuealign or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - bestW
        else
            sx = region_x + (region_w - bestW) / 2
        end

        local resolvedColor = utils.resolveColor(color)
        if resolvedColor then
            lcd.color(resolvedColor)
        else
            lcd.color(isDARKMODE and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
        end
        lcd.drawText(sx, sy, str)
    end

    -- Draw title (top or bottom)
    if title then
        lcd.font(fontCache.value_title)
        local tsizeW, tsizeH = lcd.getTextSize(title)
        local region_x = x + titlepaddingleft
        local region_w = w - titlepaddingleft - titlepaddingright
        local sy = (titlepos == "bottom")
            and (y + h - titlepaddingbottom - tsizeH)
            or (y + titlepaddingtop)
        local align = (titlealign or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - tsizeW
        else
            sx = region_x + (region_w - tsizeW) / 2
        end
        lcd.color(utils.resolveColor(titlecolor) or (isDARKMODE and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90)))
        lcd.drawText(sx, sy, title)
    end
end

--[[
    Draws an image box, using imageCache and flexible alignment/padding.
    Optionally overlays a title.
    Args: x, y, w, h, ...   - see code above for full param list.
]]
function utils.imageBox(
    x, y, w, h, color, title, imagePath, imagewidth, imageheight, imagealign, bgcolor,
    titlealign, titlecolor, titlepos,
    imagepadding, imagepaddingleft, imagepaddingright, imagepaddingtop, imagepaddingbottom
)
    local isDARKMODE = lcd.darkMode()
    local resolvedBg = utils.resolveColor(bgcolor)
    lcd.color(resolvedBg or (isDARKMODE and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)))
    lcd.drawFilledRectangle(x, y, w, h)

    imagepaddingleft = imagepaddingleft or imagepadding or 0
    imagepaddingright = imagepaddingright or imagepadding or 0
    imagepaddingtop = imagepaddingtop or imagepadding or 0
    imagepaddingbottom = imagepaddingbottom or imagepadding or 0

    local region_x = x + imagepaddingleft
    local region_y = y + imagepaddingtop
    local region_w = w - imagepaddingleft - imagepaddingright
    local region_h = h - imagepaddingtop - imagepaddingbottom

    if rfsuite and rfsuite.utils and rfsuite.utils.loadImage and lcd and lcd.drawBitmap then
        local cacheKey = imagePath
        local bitmapPtr = imageCache[cacheKey]
        if not bitmapPtr then
            bitmapPtr = rfsuite.utils.loadImage(imagePath, nil, "widgets/dashboard/default_image.png")
            imageCache[cacheKey] = bitmapPtr
        end
        if bitmapPtr then
            local img_w = imagewidth or region_w
            local img_h = imageheight or region_h
            local align = imagealign or "center"
            local img_x, img_y = region_x, region_y

            -- Horizontal alignment
            if align == "center" then
                img_x = region_x + (region_w - img_w) / 2
            elseif align == "right" then
                img_x = region_x + region_w - img_w
            else -- left
                img_x = region_x
            end
            -- Vertical alignment
            if align == "center" then
                img_y = region_y + (region_h - img_h) / 2
            elseif align == "bottom" then
                img_y = region_y + region_h - img_h
            else -- top
                img_y = region_y
            end

            if title and title ~= "" then
                lcd.font(FONT_S)
                local tsize_w, tsize_h = lcd.getTextSize(title)
                local sx
                if titlealign == "left" then
                    sx = x
                elseif titlealign == "right" then
                    sx = x + w - tsize_w
                else
                    sx = x + (w - tsize_w) / 2
                end
                local useColor = utils.resolveColor(titlecolor) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
                lcd.color(useColor)
                if titlepos == "bottom" then
                    lcd.drawText(sx, y + h - tsize_h, title)
                else
                    lcd.drawText(sx, y, title)
                    img_y = img_y + tsize_h + 2
                end
            end

            lcd.drawBitmap(img_x, img_y, bitmapPtr, img_w, img_h)
        end
    end
end

--[[
    Sets the background color of the LCD based on the current theme.
    Covers the entire widget area.
]]
function utils.setBackgroundColourBasedOnTheme()
    local w, h = lcd.getWindowSize()
    if lcd.darkMode() then
        lcd.color(lcd.RGB(16, 16, 16))
    else
        lcd.color(lcd.RGB(209, 208, 208))
    end
    lcd.drawFilledRectangle(0, 0, w, h)
end

--[[
    Draws the model image (icon) box, trying craftName, modelID, or model.bitmap().
    Uses padding and alignment. Shows error if no image found.
    Args: x, y, w, h, ...   - see code above for full param list.
]]
function utils.modelImageBox(
    x, y, w, h,
    color, title, imagewidth, imageheight, imagealign, bgcolor,
    titlealign, titlecolor, titlepos,
    imagepadding, imagepaddingleft, imagepaddingright, imagepaddingtop, imagepaddingbottom
)
    local isDARKMODE = lcd.darkMode()
    local resolvedBg = utils.resolveColor(bgcolor)
    lcd.color(resolvedBg or (isDARKMODE and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)))
    lcd.drawFilledRectangle(x, y, w, h)

    imagepaddingleft = imagepaddingleft or imagepadding or 0
    imagepaddingright = imagepaddingright or imagepadding or 0
    imagepaddingtop = imagepaddingtop or imagepadding or 0
    imagepaddingbottom = imagepaddingbottom or imagepadding or 0

    local region_x = x + imagepaddingleft
    local region_y = y + imagepaddingtop
    local region_w = w - imagepaddingleft - imagepaddingright
    local region_h = h - imagepaddingtop - imagepaddingbottom

    local craftName = rfsuite and rfsuite.session and rfsuite.session.craftName
    local modelID = rfsuite and rfsuite.session and rfsuite.session.modelID
    local image1 = craftName and ("/bitmaps/models/" .. craftName .. ".png") or nil
    local image2 = modelID and ("/bitmaps/models/" .. modelID .. ".png") or nil
    local default_image = model.bitmap() or "widgets/dashboard/default_image.png"

    local cacheKey = image1 or image2 or default_image
    local bitmapPtr = imageCache[cacheKey]
    if not bitmapPtr and rfsuite and rfsuite.utils and rfsuite.utils.loadImage then
        bitmapPtr = rfsuite.utils.loadImage(image1, image2, default_image)
        imageCache[cacheKey] = bitmapPtr
    end
    if bitmapPtr then
        local img_w = imagewidth or region_w
        local img_h = imageheight or region_h
        local align = imagealign or "center"
        local img_x, img_y = region_x, region_y

        if align == "center" then
            img_x = region_x + (region_w - img_w) / 2
        elseif align == "right" then
            img_x = region_x + region_w - img_w
        else
            img_x = region_x
        end
        if align == "center" then
            img_y = region_y + (region_h - img_h) / 2
        elseif align == "bottom" then
            img_y = region_y + region_h - img_h
        else
            img_y = region_y
        end

        if title and title ~= "" then
            lcd.font(FONT_S)
            local tsize_w, tsize_h = lcd.getTextSize(title)
            local sx
            if titlealign == "left" then
                sx = x
            elseif titlealign == "right" then
                sx = x + w - tsize_w
            else
                sx = x + (w - tsize_w) / 2
            end
            local useColor = utils.resolveColor(titlecolor) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
            lcd.color(useColor)
            if titlepos == "bottom" then
                lcd.drawText(sx, y + h - tsize_h, title)
            else
                lcd.drawText(sx, y, title)
                img_y = img_y + tsize_h + 2
            end
        end

        lcd.drawBitmap(img_x, img_y, bitmapPtr, img_w, img_h)
    else
        lcd.font(FONT_S)
        lcd.color(lcd.RGB(200,50,50))
        lcd.drawText(x + 10, y + 10, "No Model Image")
    end
end

-- === Function-param support ===
function utils.getParam(box, key, ...)
    local v = box[key]
    if type(v) == "function" then
        return v(box, key, ...)
    else
        return v
    end
end

function utils.applyOffset(x, y, box)
    local ox = utils.getParam(box, "offsetx") or 0
    local oy = utils.getParam(box, "offsety") or 0
    return x + ox, y + oy
end

return utils

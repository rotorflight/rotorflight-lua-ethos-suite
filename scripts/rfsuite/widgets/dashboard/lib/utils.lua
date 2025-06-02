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

--- Draws a bar-style needle (such as for a gauge or meter) at a specified position, angle, and size.
-- The needle is rendered as a thick, filled bar with a specified thickness and length, centered at (cx, cy),
-- and rotated by angleDeg degrees. The needle is drawn with a slight overlap at both ends for visual effect.
--
-- @param cx number: X-coordinate of the needle's base (center point).
-- @param cy number: Y-coordinate of the needle's base (center point).
-- @param length number: Length of the needle from base to tip.
-- @param thickness number: Thickness of the needle bar.
-- @param angleDeg number: Angle of the needle in degrees (0 is to the right, increases counterclockwise).
-- @param color number: Color value to use for drawing the needle.
function utils.drawBarNeedle(cx, cy, length, thickness, angleDeg, color)
    local angleRad = math.rad(angleDeg)
    local cosA = math.cos(angleRad)
    local sinA = math.sin(angleRad)
    local perpA = angleRad + math.pi / 2

    local tipFudge = 2   -- px: overlap past tip for both ends

    local dx = math.cos(perpA) * (thickness / 2)
    local dy = math.sin(perpA) * (thickness / 2)

    -- First set: needle from base to tip (with tip overdrawn)
    local base1X = cx + dx
    local base1Y = cy + dy
    local base2X = cx - dx
    local base2Y = cy - dy
    local tipX = cx + cosA * (length + tipFudge)
    local tipY = cy + sinA * (length + tipFudge)
    local tip1X = tipX + dx
    local tip1Y = tipY + dy
    local tip2X = tipX - dx
    local tip2Y = tipY - dy

    -- Second set: from tip *back* to base, mirrored
    local base3X = tipX + dx
    local base3Y = tipY + dy
    local base4X = tipX - dx
    local base4Y = tipY - dy
    local backX = cx - cosA * tipFudge
    local backY = cy - sinA * tipFudge
    local back1X = backX + dx
    local back1Y = backY + dy
    local back2X = backX - dx
    local back2Y = backY - dy

    lcd.color(color)
    -- First rectangle/needle: base to tip
    lcd.drawFilledTriangle(base1X, base1Y, tip1X, tip1Y, tip2X, tip2Y)
    lcd.drawFilledTriangle(base1X, base1Y, tip2X, tip2Y, base2X, base2Y)
    -- Second rectangle/needle: tip (thick end) overlaps back toward base
    lcd.drawFilledTriangle(base3X, base3Y, back1X, back1Y, back2X, back2Y)
    lcd.drawFilledTriangle(base3X, base3Y, back2X, back2Y, base4X, base4Y)
    -- (You can draw a centerline if you like)
    lcd.drawLine(cx, cy, tipX, tipY)
end

--- Returns a table of font lists appropriate for the current radio's screen resolution.
-- The function detects the radio's LCD width and height, then selects a set of font sizes
-- for default, reduced, and title text usage based on known device resolutions.
-- If the resolution is not recognized, it logs a warning and falls back to the default (800x480) font set.
-- @return table A table containing font lists for 'value_default', 'value_reduced', and 'value_title' keys.
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


--- Resets the image cache by removing all entries from the `imageCache` table.
-- This function iterates over all keys in the `imageCache` table and sets their values to nil,
-- effectively clearing the cache and freeing up memory used by cached images.
function utils.resetImageCache()
    for k in pairs(imageCache) do
        imageCache[k] = nil
    end
end

--- Displays an error message centered on the screen, automatically selecting the largest font size
--- that fits within 90% of the screen's width and height. The text color adapts to the current
--- dark mode setting.
-- @param msg string: The error message to display.
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

--- Calculates the X coordinate for text alignment within a given width.
-- @param text string: The text to be aligned.
-- @param align string: The alignment type ("left", "center", or "right").
-- @param x number: The starting X coordinate of the area.
-- @param w number: The width of the area to align within.
-- @return number: The calculated X coordinate for the aligned text.
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

--- Resolve a named, bright/light, dark, or raw-RGB color.
-- @param value     string (e.g. "red", "brightBlue", "darkGreen") or {r,g,b,...}
-- @param variantFactor number? how strongly to lighten/darken (0–1). Defaults to 0.3.
-- @return lcd.RGB(...) or nil
function utils.resolveColor(value, variantFactor)
    -- base named colors
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

    -- fallback to default 30% if not provided or out of range
    local VARIANT_FACTOR = type(variantFactor) == "number"
                           and math.max(0, math.min(1, variantFactor))
                           or 0.3

    local function clamp(v)
        return math.max(0, math.min(255, math.floor(v + 0.5)))
    end

    local function lighten(rgb)
        return {
            clamp(rgb[1] + (255 - rgb[1]) * VARIANT_FACTOR),
            clamp(rgb[2] + (255 - rgb[2]) * VARIANT_FACTOR),
            clamp(rgb[3] + (255 - rgb[3]) * VARIANT_FACTOR),
        }
    end

    local function darken(rgb)
        return {
            clamp(rgb[1] * (1 - VARIANT_FACTOR)),
            clamp(rgb[2] * (1 - VARIANT_FACTOR)),
            clamp(rgb[3] * (1 - VARIANT_FACTOR)),
        }
    end

    if type(value) == "string" then
        local lower = value:lower()

        -- detect prefix and strip
        local prefix, baseName = lower:match("^(bright)(.+)"),
                                lower:match("^bright(.+)")
        if not prefix then
            prefix, baseName = lower:match("^(light)(.+)"),
                               lower:match("^light(.+)")
        end
        if not prefix then
            prefix, baseName = lower:match("^(dark)(.+)"),
                               lower:match("^dark(.+)")
        end

        if prefix and baseName then
            local baseColor = namedColors[baseName]
            if baseColor then
                local rgb = (prefix == "dark") and darken(baseColor) or lighten(baseColor)
                return lcd.RGB(rgb[1], rgb[2], rgb[3], 1)
            end

        elseif namedColors[lower] then
            -- exact named color
            local c = namedColors[lower]
            return lcd.RGB(c[1], c[2], c[3], 1)
        end

    elseif type(value) == "table" and #value >= 3 then
        -- raw RGB table
        return lcd.RGB(value[1], value[2], value[3], 1)
    end

    -- unrecognized
    return nil
end

-- Single color resolve by context key (returns RGB number)
function utils.resolveThemeColor(colorkey, value)
    -- If already a number (e.g. lcd.RGB), just return
    if type(value) == "number" then return value end
    -- If string (like "red"), use resolveColor
    if type(value) == "string" then
        local resolved = utils.resolveColor(value)
        if resolved then return resolved end
    end
    -- Provide context defaults
    if colorkey == "fillcolor" then
        return lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)
    elseif colorkey == "fillbgcolor" then
        return lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)
    elseif colorkey == "framecolor" then
        return lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)
    elseif colorkey == "textcolor" then
        return lcd.RGB(255,255,255)
    elseif colorkey == "titlecolor" then
        return lcd.RGB(255,255,255)
    elseif colorkey == "accentcolor" then
        return lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)
    end
    -- fallback
    return lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)
end

-- For arrays like bandColors (returns a resolved RGB array)
function utils.resolveThemeColorArray(colorkey, arr)
    local resolved = {}
    if type(arr) == "table" then
        for i = 1, #arr do
            resolved[i] = utils.resolveThemeColor(colorkey, arr[i])
        end
    end
    return resolved
end

--- Draws a telemetry value box with colored background, value, title, unit, and flexible padding/alignment.
--
-- All color arguments (bgcolor, textcolor, titlecolor) must be resolved numbers (not strings).
-- Text sizing can be static (via 'font') or dynamic if omitted.
--
-- @param x                number          X-coordinate of the box.
-- @param y                number          Y-coordinate of the box.
-- @param w                number          Width of the box.
-- @param h                number          Height of the box.
-- @param title            string          Title string (shown above or below the value).
-- @param value            string|number   Main value to display (usually pre-formatted for display).
-- @param unit             string          (Optional) Unit string appended to value, if provided.
-- @param bgcolor          number          Box background color (must be a resolved LCD color number).
-- @param titlealign       string          (Optional) Title alignment: "center", "left", or "right".
-- @param valuealign       string          (Optional) Value alignment: "center", "left", or "right".
-- @param titlecolor       number          (Optional) Title text color (resolved LCD color number).
-- @param titlepos         string          (Optional) Title position: "top" or "bottom". Defaults to "top".
-- @param titlepadding     number          (Optional) Padding for all sides of the title (overridden by the next four if set).
-- @param titlepaddingleft number          (Optional) Left padding for the title.
-- @param titlepaddingright number         (Optional) Right padding for the title.
-- @param titlepaddingtop  number          (Optional) Top padding for the title.
-- @param titlepaddingbottom number        (Optional) Bottom padding for the title.
-- @param valuepadding     number          (Optional) Padding for all sides of the value (overridden by the next four if set).
-- @param valuepaddingleft number          (Optional) Left padding for the value.
-- @param valuepaddingright number         (Optional) Right padding for the value.
-- @param valuepaddingtop  number          (Optional) Top padding for the value.
-- @param valuepaddingbottom number        (Optional) Bottom padding for the value.
-- @param font             string|number   (Optional) Font to use for the value (e.g., "FONT_XL"). If nil, will use dynamic sizing.
-- @param textcolor        number          (Optional) Value/main label text color (resolved LCD color number).

function utils.box(
    x, y, w, h,
    title, value, unit, bgcolor,
    titlealign, valuealign, titlecolor, titlepos,
    titlepadding, titlepaddingleft, titlepaddingright, titlepaddingtop, titlepaddingbottom,
    valuepadding, valuepaddingleft, valuepaddingright, valuepaddingtop, valuepaddingbottom,
    font, textcolor
)
    
    -- Coerce unit to string if not nil and not string
    if unit ~= nil and type(unit) ~= "string" then
        unit = tostring(unit)
    end

    -- Draw background
    lcd.color(bgcolor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Padding resolution (default 0)
    titlepaddingleft   = titlepaddingleft   or titlepadding   or 0
    titlepaddingright  = titlepaddingright  or titlepadding   or 0
    titlepaddingtop    = titlepaddingtop    or titlepadding   or 0
    titlepaddingbottom = titlepaddingbottom or titlepadding   or 0

    valuepaddingleft   = valuepaddingleft   or valuepadding   or 0
    valuepaddingright  = valuepaddingright  or valuepadding   or 0
    valuepaddingtop    = valuepaddingtop    or valuepadding   or 0
    valuepaddingbottom = valuepaddingbottom or valuepadding   or 0

    if not fontCache then
        fontCache = utils.getFontListsForResolution()
    end

    -- Draw value text (centered, uses textcolor)
    if value ~= nil then
        local str = tostring(value) .. (unit or "")
        local unitIsDegree = (unit == "°" or (unit and unit:find("°")))
        local strForWidth = unitIsDegree and (tostring(value) .. "0") or str

        local availH = h - valuepaddingtop - valuepaddingbottom
        local fonts = fontCache.value_default

        local region_x = x + valuepaddingleft
        local region_y = y + valuepaddingtop
        local region_w = w - valuepaddingleft - valuepaddingright
        local region_h = h - valuepaddingtop - valuepaddingbottom

        local bestFont, bestW, bestH

        if font and _G[font] then
            bestFont = _G[font]
            lcd.font(bestFont)
            bestW, bestH = lcd.getTextSize(strForWidth)
        else
            bestFont, bestW, bestH = FONT_XXS, 0, 0
            lcd.font(FONT_XL)
            local _, xlFontHeight = lcd.getTextSize("8")
            if xlFontHeight > availH * 0.5 then
                fonts = fontCache.value_reduced
            end
            for _, tryFont in ipairs(fonts) do
                lcd.font(tryFont)
                local tW, tH = lcd.getTextSize(strForWidth)
                if tW <= region_w and tH <= region_h then
                    bestFont, bestW, bestH = tryFont, tW, tH
                else
                    break
                end
            end
            lcd.font(bestFont)
        end

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

        lcd.color(textcolor)
        lcd.drawText(sx, sy, str)
    end

    -- Draw title (top or bottom, uses titlecolor)
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
        lcd.color(titlecolor)
        lcd.drawText(sx, sy, title)
    end
end


--- Transforms and formats a numeric value for display, applying any configured transform and decimals.
--
-- This function checks the given `box` for a `transform` property (either a string or a function).
-- If provided, it applies the transformation to the input value:
--   - "floor":   Rounds down to nearest integer.
--   - "ceil":    Rounds up to nearest integer.
--   - "round":   Rounds to nearest integer.
--   - function:  Calls the function with the value and uses the result.
-- Next, if a `decimals` property is present in the box, it formats the value to the specified number
-- of decimal places as a string. If neither is set, the raw value is returned as a string.
--
-- @param value number         The raw numeric value to be transformed and formatted.
-- @param box   table          The box configuration table, containing optional `transform` and `decimals`.
-- @return      string         The transformed and formatted value, ready for display.

function utils.transformValue(value, box)
    local transform = utils.getParam(box, "transform")
    -- Apply transformation if configured
    if transform then
        if type(transform) == "function" then
            value = transform(value)
        elseif transform == "floor" then
            value = math.floor(value)
        elseif transform == "ceil" then
            value = math.ceil(value)
        elseif transform == "round" then
            value = math.floor(value + 0.5)
        end
    end
    local decimals = utils.getParam(box, "decimals")
    -- Apply decimal formatting if configured
        if decimals and value ~= nil then
        value = string.format("%."..decimals.."f", value)
    elseif value ~= nil then
        value = tostring(value)
    end
    return value
end

--    Draws an image box, using imageCache and flexible alignment/padding.
--    Optionally overlays a title.
--    Args: x, y, w, h, ...   - see code above for full param list.
--- Draws an image box widget with optional title, background color, image alignment, and padding.
-- 
-- @param x number: The x-coordinate of the box.
-- @param y number: The y-coordinate of the box.
-- @param w number: The width of the box.
-- @param h number: The height of the box.
-- @param color number: (Unused) Color parameter, reserved for future use.
-- @param title string: (Optional) Title text to display above or below the image.
-- @param imagePath string: Path to the image file to display.
-- @param imagewidth number: (Optional) Width of the image. Defaults to available region width.
-- @param imageheight number: (Optional) Height of the image. Defaults to available region height.
-- @param imagealign string: (Optional) Alignment of the image ("left", "center", "right", "top", "bottom"). Defaults to "center".
-- @param bgcolor number|string: (Optional) Background color of the box.
-- @param titlealign string: (Optional) Alignment of the title ("left", "center", "right"). Defaults to "center".
-- @param titlecolor number|string: (Optional) Color of the title text.
-- @param titlepos string: (Optional) Position of the title ("top", "bottom"). Defaults to "top".
-- @param imagepadding number: (Optional) Padding applied to all sides of the image.
-- @param imagepaddingleft number: (Optional) Padding on the left side of the image.
-- @param imagepaddingright number: (Optional) Padding on the right side of the image.
-- @param imagepaddingtop number: (Optional) Padding on the top side of the image.
-- @param imagepaddingbottom number: (Optional) Padding on the bottom side of the image.
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

--- Sets the background color of the LCD based on the current theme (dark or light mode).
-- Determines the window size, selects an appropriate background color depending on whether
-- dark mode is enabled, and fills the entire window with the selected color.
function utils.setBackgroundColourBasedOnTheme()
    local w, h = lcd.getWindowSize()
    if lcd.darkMode() then
        lcd.color(lcd.RGB(16, 16, 16))
    else
        lcd.color(lcd.RGB(209, 208, 208))
    end
    lcd.drawFilledRectangle(0, 0, w, h)
end

--  Draws the model image (icon) box, trying craftName, modelID, or model.bitmap().
--  Uses padding and alignment. Shows error if no image found.
--  Args: x, y, w, h, ...   - see code above for full param list.
--- Draws a model image box widget with optional title and customizable layout.
-- 
-- This function renders a rectangular area containing a model image (with fallback options)
-- and an optional title, supporting various alignment, padding, and color options.
--
-- @param x number: X coordinate of the box.
-- @param y number: Y coordinate of the box.
-- @param w number: Width of the box.
-- @param h number: Height of the box.
-- @param color number: (Unused) Color parameter for future use or compatibility.
-- @param title string: Optional title text to display.
-- @param imagewidth number: Optional width of the image inside the box.
-- @param imageheight number: Optional height of the image inside the box.
-- @param imagealign string: Alignment of the image ("left", "center", "right"). Default is "center".
-- @param bgcolor number|string: Background color (resolved via utils.resolveColor).
-- @param titlealign string: Alignment of the title ("left", "center", "right"). Default is "center".
-- @param titlecolor number|string: Color of the title text.
-- @param titlepos string: Position of the title ("top" or "bottom"). Default is "top".
-- @param imagepadding number: General padding around the image (overridden by specific paddings if set).
-- @param imagepaddingleft number: Padding to the left of the image.
-- @param imagepaddingright number: Padding to the right of the image.
-- @param imagepaddingtop number: Padding above the image.
-- @param imagepaddingbottom number: Padding below the image.
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

--- Retrieves a parameter from the given `box` table by `key`.
-- If the value associated with `key` is a function, it calls the function with `box`, `key`, and any additional arguments, and returns the result.
-- Otherwise, it returns the value directly.
-- @param box table: The table from which to retrieve the parameter.
-- @param key any: The key to look up in the table.
-- @param ... any: Additional arguments to pass if the value is a function.
-- @return any: The value associated with `key`, or the result of calling the function if the value is a function.
function utils.getParam(box, key, ...)
    local v = box[key]
    if type(v) == "function" then
        return v(box, key, ...)
    else
        return v
    end
end

--- Applies offset values from a given box table to the provided x and y coordinates.
-- The function retrieves "offsetx" and "offsety" parameters from the box using utils.getParam.
-- If the parameters are not present, it defaults to 0.
-- @param x number: The original x coordinate.
-- @param y number: The original y coordinate.
-- @param box table: A table potentially containing "offsetx" and "offsety" values.
-- @return number, number: The x and y coordinates after applying the offsets.
function utils.applyOffset(x, y, box)
    local ox = utils.getParam(box, "offsetx") or 0
    local oy = utils.getParam(box, "offsety") or 0
    return x + ox, y + oy
end




return utils

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


-- Determine layout and screensize in use
function utils.isFullScreen(w, h)

    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    if (w == 800 and (h == 458 or h == 480)) then return true end
    if (w == 784 and (h == 294 or h == 316)) then return false end

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    if (w == 480 and (h == 301 or h == 320)) then return true end
    if (w == 472 and (h == 191 or h == 210)) then return false end

    -- Small screens - (X14 / X14S) Full/Standard
    if (w == 640 and (h == 338 or h == 360)) then return true end
    if (w == 630 and (h == 236 or h == 258)) then return false end

    return nil -- Unknown resolution, assume not fullscreen
end

--- Checks if the model preferences are ready.
-- This function returns true if the `rfsuite` table, its `session` field,
-- and the `modelPreferences` field within `session` are all non-nil.
-- @return boolean True if model preferences are ready, false otherwise.
function utils.isModelPrefsReady()
    return rfsuite and rfsuite.session and rfsuite.session.modelPreferences
end

--- Resets the cache of a given box object by clearing all entries in its `_cache` table.
-- If the box has a `_cache` table, all its keys are set to nil, effectively emptying the cache.
-- @param box table The box object whose cache should be reset.
function utils.resetBoxCache(box)
    if box._cache then
        for k in pairs(box._cache) do
            box._cache[k] = nil
        end
    end
end

-- Returns true if (W, H) exactly matches one of the entries in supportedResolutions.
--   W, H:               current window width and height (numbers)
--   supportedResolutions: an array of {width, height} pairs, e.g.
--         {
--           { 784, 294 },
--           { 784, 316 },
--           { 472, 191 },
--           { 472, 210 },
--           { 630, 236 },
--           { 630, 258 },
--         }
function utils.supportedResolution(W,H, supportedResolutions)

    for _, res in ipairs(supportedResolutions) do
        if W == res[1] and H == res[2] then
            return true
        end
    end
    return false
end

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
    local step = 1
    local rad_thick = thickness / 2
    lcd.color(color)
    for i = 0, length, step do
        local px = cx + i * math.cos(angleRad)
        local py = cy + i * math.sin(angleRad)
        lcd.drawFilledCircle(px, py, rad_thick)
    end
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
            value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_M, FONT_L, FONT_XL, FONT_XXL, FONT_XXXXL},
            value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_M, FONT_L},
            value_title   = {FONT_XXS, FONT_XS, FONT_S, FONT_M}
        },
        -- TANDEM X18, TWIN X Lite (480x320)
        ["480x320"] = {
            value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_M, FONT_L, FONT_XL},
            value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_M, FONT_L},
            value_title   = {FONT_XXS, FONT_XS, FONT_S}
        },
        -- Horus X10, Horus X12 (480x272)
        ["480x272"] = {
            value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_M},
            value_reduced = {FONT_XXS, FONT_XS, FONT_S},
            value_title   = {FONT_XXS, FONT_XS, FONT_S}
        },
        -- Twin X14 (632x314)
        ["640x360"] = {
            value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_M, FONT_L, FONT_XL},
            value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_M, FONT_L},
            value_title   = {FONT_XXS, FONT_XS, FONT_S}
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
-- @param msg string:  The error message to display.
-- @param bool      :  The draw border around the text (default true).
-- @param pct number:  The percentage of the screen size to use for text fitting (default 0.5).
-- @param padX number: Horizontal padding around the text (default 8).
-- @param padY number: Vertical padding around the text (default 4).
function utils.screenError(msg, border, pct, padX, padY)
    -- Default values
    if not pct then pct = 0.5 end
    if border == nil then border = true end
    if not padX then padX = 8 end      -- default horizontal padding
    if not padY then padY = 4 end      -- default vertical padding

    -- Get display size and mode
    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    -- Available fonts to try
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_M, FONT_L, FONT_XL, FONT_XXL, FONT_XXXXL}
    
    -- Compute maximum allowed dimensions for text
    local maxW, maxH = w * pct, h * pct
    local bestFont, bestW, bestH = FONT_XXS, 0, 0

    -- Choose the largest font that fits within maxW x maxH
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

    -- Set chosen font
    lcd.font(bestFont)

    -- Determine text and border color
    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)

    -- Calculate centered text position
    local x = (w - bestW) / 2
    local y = (h - bestH) / 2

    -- Draw border rectangle if requested
    if border then
        lcd.drawRectangle(x - padX, y - padY, bestW + padX * 2, bestH + padY * 2)
    end

    -- Draw the text centered
    lcd.drawText(x, y, msg)
end

--- Resolve a named, bright/light, dark, or raw-RGB color.
-- @param value     string (e.g. "red", "brightBlue", "darkGreen") or {r,g,b,...}
-- @param variantFactor number? how strongly to lighten/darken (0–1). Defaults to 0.3.
-- @return lcd.RGB(...) or nil
function utils.resolveColor(value, variantFactor)
    -- base named colors
    local namedColors = {
        red             = {255, 0, 0},
        green           = {0, 188, 4},
        blue            = {0, 122, 255},
        white           = {255, 255, 255},
        black           = {0, 0, 0},
        gray            = {185, 185, 185},
        grey            = {185, 185, 185},
        orange          = {255, 165, 0},
        yellow          = {255, 255, 0},
        cyan            = {0, 255, 255},
        magenta         = {255, 0, 255},
        pink            = {255, 105, 180},
        purple          = {128, 0, 128},
        violet          = {143, 0, 255},
        brown           = {139, 69, 19},
        lime            = {0, 255, 0},
        olive           = {128, 128, 0},
        gold            = {255, 215, 0},
        silver          = {192, 192, 192},
        teal            = {0, 128, 128},
        navy            = {0, 0, 128},
        maroon          = {128, 0, 0},
        beige           = {245, 245, 220},
        turquoise       = {64, 224, 208},
        indigo          = {75, 0, 130},
        coral           = {255, 127, 80},
        salmon          = {250, 128, 114},
        mint            = {62, 180, 137},
        lightgreen      = {144, 238, 144},
        darkgreen       = {0, 100, 0},
        lightred        = {255, 102, 102},
        darkred         = {139, 0, 0},
        lightblue       = {173, 216, 230},
        darkblue        = {0, 0, 139},
        lightpurple     = {216, 191, 216},
        darkpurple      = {48, 25, 52},
        lightyellow     = {255, 255, 224},
        darkyellow      = {204, 204, 0},
        lightgrey       = {211, 211, 211},
        lightgray       = {211, 211, 211},
        darkgrey        = {90, 90, 90},
        darkgray        = {90, 90, 90},
        darkwhite       = {245, 245, 245},
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
    -- an oddbal of a string "transparent" should return nil
    if type(value) == "string" and value == "transparent" then
        return nil
    end    
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
        return lcd.RGB(255, 255, 255)
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

-- Draws a telemetry value box with colored background, value, title, unit, and flexible padding/alignment.
--
-- All color arguments (bgcolor, textcolor, titlecolor) must be resolved numbers (not strings).
-- Text sizing can be static (via 'font'/'titlefont') or dynamic if omitted.
--
-- @param x                number          X-coordinate of the box.
-- @param y                number          Y-coordinate of the box.
-- @param w                number          Width of the box.
-- @param h                number          Height of the box.
-- @param title            string          (Optional) Title string (shown above or below the value).
-- @param titlepos         string          (Optional) Title position: "top" or "bottom". Defaults to "top".
-- @param titlealign       string          (Optional) Title alignment: "center", "left", or "right".
-- @param titlefont        string|number   (Optional) Font to use for title (e.g., "FONT_XL"). If nil, uses dynamic sizing.
-- @param titlespacing     number          (Optional) Controls the vertical gap between title and value text.
-- @param titlecolor       number          (Optional) Title text color (resolved LCD color number).
-- @param titlepadding     number          (Optional) Padding for all sides of the title (overridden by the next four if set).
-- @param titlepaddingleft number          (Optional) Left padding for the title.
-- @param titlepaddingright number         (Optional) Right padding for the title.
-- @param titlepaddingtop  number          (Optional) Top padding for the title.
-- @param titlepaddingbottom number        (Optional) Bottom padding for the title.
-- @param displayValue     string|number   Main value to display (pre-formatted for display).
-- @param unit             string          (Optional) Unit string appended to value, if provided.
-- @param font             string|number   (Optional) Font to use for the value (e.g., "FONT_XL"). If nil, uses dynamic sizing.
-- @param valuealign       string          (Optional) Value alignment: "center", "left", or "right".
-- @param textcolor        number          (Optional) Value/main label text color (resolved LCD color number).
-- @param valuepadding     number          (Optional) Padding for all sides of the value (overridden by the next four if set).
-- @param valuepaddingleft number          (Optional) Left padding for the value.
-- @param valuepaddingright number         (Optional) Right padding for the value.
-- @param valuepaddingtop  number          (Optional) Top padding for the value.
-- @param valuepaddingbottom number        (Optional) Bottom padding for the value.
-- @param bgcolor          number          (Optional) Box background color (must be a resolved LCD color number).

function utils.box(
    x, y, w, h,
    title, titlepos, titlealign, titlefont, titlespacing,
    titlecolor, titlepadding, titlepaddingleft, titlepaddingright,
    titlepaddingtop, titlepaddingbottom,
    displayValue, unit, font, valuealign, textcolor,
    valuepadding, valuepaddingleft, valuepaddingright,
    valuepaddingtop, valuepaddingbottom,
    bgcolor,
    image, imagewidth, imageheight, imagealign
)
    -- Padding defaults
    local DEFAULT_TITLE_PADDING = 0
    local DEFAULT_VALUE_PADDING = 6
    local DEFAULT_TITLE_SPACING = 6

    titlepaddingleft   = titlepaddingleft   or titlepadding   or DEFAULT_TITLE_PADDING
    titlepaddingright  = titlepaddingright  or titlepadding   or DEFAULT_TITLE_PADDING
    titlepaddingtop    = titlepaddingtop    or titlepadding   or DEFAULT_TITLE_PADDING
    titlepaddingbottom = titlepaddingbottom or titlepadding   or DEFAULT_TITLE_PADDING

    valuepaddingleft   = valuepaddingleft   or valuepadding   or DEFAULT_VALUE_PADDING
    valuepaddingright  = valuepaddingright  or valuepadding   or DEFAULT_VALUE_PADDING
    valuepaddingtop    = valuepaddingtop    or valuepadding   or DEFAULT_VALUE_PADDING
    valuepaddingbottom = valuepaddingbottom or valuepadding   or DEFAULT_VALUE_PADDING

    titlespacing = titlespacing or DEFAULT_TITLE_SPACING

    -- Draw background
    if bgcolor then
        lcd.color(bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    -- Cache fonts if not already
    if not fontCache then
        fontCache = utils.getFontListsForResolution()
    end

    -- Title font selection, auto-fit logic
    local actualTitleFont, tsizeW, tsizeH = nil, 0, 0
    if title then
        local minValueFontH = 9999
        for _, vf in ipairs(fontCache.value_default or {FONT_M}) do
            lcd.font(vf)
            local _, vh = lcd.getTextSize("8")
            if vh < minValueFontH then minValueFontH = vh end
        end
        if titlefont and _G[titlefont] then
            actualTitleFont = _G[titlefont]
            lcd.font(actualTitleFont)
            tsizeW, tsizeH = lcd.getTextSize(title)
        else
            for _, tryFont in ipairs(fontCache.value_title or {FONT_XS}) do
                lcd.font(tryFont)
                local tW, tH = lcd.getTextSize(title)
                local remH = h - titlepaddingtop - tH - titlepaddingbottom - valuepaddingtop - valuepaddingbottom
                if tW <= w - titlepaddingleft - titlepaddingright and tH > 0 and remH >= minValueFontH then
                    actualTitleFont, tsizeW, tsizeH = tryFont, tW, tH
                    break
                end
            end
            if not actualTitleFont then
                actualTitleFont = (fontCache.value_title or {FONT_XS})[#(fontCache.value_title or {FONT_XS})]
                lcd.font(actualTitleFont)
                tsizeW, tsizeH = lcd.getTextSize(title)
            end
        end
    end

    -- Calculate region for value/image
    local region_vx, region_vy, region_vw, region_vh
    if title and (titlepos or "top") == "top" then
        region_vy = y + titlepaddingtop + tsizeH + titlepaddingbottom + titlespacing + valuepaddingtop
        region_vh = h - (region_vy - y) - valuepaddingbottom
    elseif title and titlepos == "bottom" then
        region_vy = y + valuepaddingtop
        region_vh = h - tsizeH - titlepaddingtop - titlepaddingbottom - titlespacing - valuepaddingtop - valuepaddingbottom
    else
        region_vy = y + valuepaddingtop
        region_vh = h - valuepaddingtop - valuepaddingbottom
    end
    region_vx = x + valuepaddingleft
    region_vw = w - valuepaddingleft - valuepaddingright

    -- Draw image if specified (fallback to displayValue)
    if image then
        local bitmapPtr = nil
        -- If image is a string (path), load it and cache it
        if type(image) == "string" and rfsuite and rfsuite.utils and rfsuite.utils.loadImage then
            imageCache = imageCache or {}
            local cacheKey = image or "default_image"
            bitmapPtr = imageCache[cacheKey]
            if not bitmapPtr then
                bitmapPtr = rfsuite.utils.loadImage(image, nil, "widgets/dashboard/gfx/logo.png")
                imageCache[cacheKey] = bitmapPtr
            end
        elseif type(image) == "userdata" then
            -- Already a Bitmap object
            bitmapPtr = image
        end

        if bitmapPtr then

            local default_img_w = region_vw
            local default_img_h = region_vh
            local img_w = imagewidth or default_img_w
            local img_h = imageheight or default_img_h
            local align = imagealign or "center"
            local img_x, img_y = region_vx, region_vy
            if align == "center" then
                img_x = region_vx + (region_vw - img_w) / 2
            elseif align == "right" then
                img_x = region_vx + region_vw - img_w
            else
                img_x = region_vx
            end
            if align == "center" then
                img_y = region_vy + (region_vh - img_h) / 2
            elseif align == "bottom" then
                img_y = region_vy + region_vh - img_h
            else
                img_y = region_vy
            end
            lcd.drawBitmap(img_x, img_y, bitmapPtr, img_w, img_h)
        end
    elseif displayValue ~= nil then

        local value_str = tostring(displayValue) .. (unit or "")

        -- replace . and % symbols with 'W' for width calculation
        -- note.  gsub %% is escaping the % symbol as % is the lua pattern escape character
        --        multi subs are used because different characters need different replacements
        local value_str_calc = string.gsub(value_str, "[%%]", "W")
              value_str_calc = string.gsub(value_str, "[°]", ".")

        local valueFont, bestW, bestH = FONT_XXS, 0, 0
        if font and _G[font] then
            valueFont = _G[font]
            lcd.font(valueFont)

            bestW, bestH = lcd.getTextSize(value_str_calc)
        else
            for _, tryFont in ipairs(fontCache.value_default) do
                lcd.font(tryFont)
                local tW, tH = lcd.getTextSize(value_str_calc)
                if tW <= region_vw and tH <= region_vh then
                    valueFont, bestW, bestH = tryFont, tW, tH
                end
            end
            lcd.font(valueFont)
        end

        -- Optional: vertical fudge for title placement
        local fudgeTitle = (title and (titlepos or "top") == "top")
            and -math.floor(bestH * 0.15 + 0.5)
            or (title and titlepos == "bottom")
                and math.floor(bestH * 0.15 + 0.5)
            or 0

        local sy = region_vy + ((region_vh - bestH) / 2) + fudgeTitle
        local align = (valuealign or "center"):lower()
        local sx
        if align == "left" then
            sx = region_vx
        elseif align == "right" then
            sx = region_vx + region_vw - bestW
        else
            sx = region_vx + (region_vw - bestW) / 2 
        end
        lcd.color(textcolor)
        lcd.drawText(sx, sy, value_str)
    end

    -- Draw title text (centered, at top or bottom)
    if title then
        lcd.font(actualTitleFont)
        local region_tw = w - titlepaddingleft - titlepaddingright
        local sy = (titlepos or "top") == "bottom"
            and (y + h - titlepaddingbottom - tsizeH)
            or (y + titlepaddingtop)
        local align = (titlealign or "center"):lower()
        local sx
        if align == "left" then
            sx = x + titlepaddingleft
        elseif align == "right" then
            sx = x + titlepaddingleft + region_tw - tsizeW
        else
            sx = x + titlepaddingleft + (region_tw - tsizeW) / 2
        end
        lcd.color(titlecolor)
        lcd.drawText(sx, sy, title)
    end
end

--- Resolves a color (typically textcolor or fillcolor) for a value using flexible threshold logic.
-- If the box table includes a 'thresholds' array:
    -- For string values, returns the colorKey (e.g. textcolor/fillcolor) for the threshold whose value exactly matches.
    -- For numeric values, returns the colorKey for the first threshold whose value is greater than or equal to the given value (less-than-or-equal logic).
    -- For function-valued thresholds, calls the function with (box, value) to resolve the thresholdValue.
    -- Falls back to the colorKey in box, or a theme default, if no threshold matches.
-- @param value              number|string  -- The value to evaluate against thresholds.
-- @param box                table          -- The widget's config table (may contain thresholds, textcolor, fillcolor, etc.)
-- @param colorKey           string         -- The key to look up in thresholds and box (e.g. "textcolor" or "fillcolor").
-- @param fallbackThemeKey   string         -- The theme key to use if no color is found (e.g. "textcolor", "fillcolor").
-- @return                   number         -- The LCD color to use for rendering.

function utils.resolveThresholdColor(value, box, colorKey, fallbackThemeKey, thresholdsOverride)
    local color = utils.resolveThemeColor(fallbackThemeKey, utils.getParam(box, colorKey))
    local thresholds = thresholdsOverride or utils.getParam(box, "thresholds")
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local thresholdValue = t.value
            if type(thresholdValue) == "function" then
                thresholdValue = thresholdValue(box, value)
            end

            if type(value) == "string" and thresholdValue == value and t[colorKey] then
                color = utils.resolveThemeColor(colorKey, t[colorKey])
                break
            elseif type(value) == "number" and type(thresholdValue) == "number" and value <= thresholdValue and t[colorKey] then
                color = utils.resolveThemeColor(colorKey, t[colorKey])
                break
            end
        end
    end
    return color
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
    if decimals ~= nil and value ~= nil then
        value = string.format("%." .. decimals .. "f", value)
    elseif value ~= nil then
        value = tostring(value)
    end
    return value
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

--- Retrieves a parameter from the given `box` table by `key`.
-- If the value associated with `key` is a function, it calls the function with `box`, `key`, and any additional arguments, and returns the result.
-- Otherwise, it returns the value directly.
-- @param box table: The table from which to retrieve the parameter.
-- @param key any: The key to look up in the table.
-- @param ... any: Additional arguments to pass if the value is a function.
-- @return any: The value associated with `key`, or the result of calling the function if the value is a function.
function utils.getParam(box, key, ...)
    local SKIP_CALL_KEYS = {
        transform = true,
        thresholds = true,
        value = true,
        -- add more keys here if needed
    }

    local v = box[key]
    if type(v) == "function" and not SKIP_CALL_KEYS[key] then
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

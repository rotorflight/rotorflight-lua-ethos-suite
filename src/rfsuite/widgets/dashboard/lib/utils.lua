--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local system = system

local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local rad = math.rad
local format = string.format
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local tonumber = tonumber

local utils = {}

local SKIP_CALL_KEYS = {transform = true, thresholds = true, value = true}

local imageCache = {}
local fontCache
local progressDialog
local MSP_DEBUG_PLACEHOLDER = "MSP Waiting"

function utils.isFullScreen(w, h)

    if (w == 800 and (h == 458 or h == 480)) then return true end
    if (w == 784 and (h == 294 or h == 316)) then return false end

    if (w == 480 and (h == 301 or h == 320)) then return true end
    if (w == 472 and (h == 191 or h == 210)) then return false end

    if (w == 640 and (h == 338 or h == 360)) then return true end
    if (w == 630 and (h == 236 or h == 258)) then return false end

    return nil
end

function utils.isModelPrefsReady() return rfsuite and rfsuite.session and rfsuite.session.modelPreferences end

function utils.resetBoxCache(box) if box._cache then for k in pairs(box._cache) do box._cache[k] = nil end end end

function utils.supportedResolution(W, H, supportedResolutions)

    for _, res in ipairs(supportedResolutions) do if W == res[1] and H == res[2] then return true end end
    return false
end

function utils.drawBarNeedle(cx, cy, length, thickness, angleDeg, color)
    local angleRad = rad(angleDeg)
    local step = 1
    local rad_thick = thickness / 2
    lcd.color(color)
    for i = 0, length, step do
        local px = cx + i * cos(angleRad)
        local py = cy + i * sin(angleRad)
        lcd.drawFilledCircle(px, py, rad_thick)
    end
end

function utils.getFontListsForResolution()
    local version = system.getVersion()
    local LCD_W = version.lcdWidth
    local LCD_H = version.lcdHeight
    local resolution = LCD_W .. "x" .. LCD_H

    local radios = {

        ["800x480"] = {value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL, FONT_XXXXL}, value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L}, value_title = {FONT_XXS, FONT_XS, FONT_S, FONT_STD}},

        ["480x320"] = {value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL}, value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L}, value_title = {FONT_XXS, FONT_XS, FONT_S}},

        ["480x272"] = {value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD}, value_reduced = {FONT_XXS, FONT_XS, FONT_S}, value_title = {FONT_XXS, FONT_XS, FONT_S}},

        ["640x360"] = {value_default = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL}, value_reduced = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L}, value_title = {FONT_XXS, FONT_XS, FONT_S}}
    }
    if not radios[resolution] then
        rfsuite.utils.log("Unsupported resolution: " .. resolution .. ". Using default fonts.", "info")
        return radios["800x480"]
    end
    return radios[resolution]

end

function utils.getHeaderOptions()
    local W, H = lcd.getWindowSize()

    if W == 800 or W == 784 then
        return {
            height = 36,
            font = "FONT_L",
            txbattfont = "FONT_STD",
            txdbattfont = "FONT_S",
            batterysegmentpaddingtop = 4,
            batterysegmentpaddingbottom = 4,
            batterysegmentpaddingleft = 4,
            batterysegmentpaddingright = 4,
            gaugepaddingleft = 25,
            txdgaugepaddingleft = 20,
            gaugepaddingright = 26,
            txdgaugepaddingright = 20,
            gaugepaddingbottom = 2,
            gaugepaddingtop = 2,
            cappaddingright = 3,
            barpaddingleft = 25,
            barpaddingright = 28,
            barpaddingbottom = 2,
            barpaddingtop = 4,
            valuepaddingleft = 20,
            txdvaluepaddingleft = 10,
            valuepaddingbottom = 20,
            txdvaluepaddingtop = 8,
            roundradius = 15
        }

    elseif W == 480 or W == 472 then
        return {
            height = 30,
            font = "FONT_L",
            txbattfont = "FONT_STD",
            txdbattfont = "FONT_S",
            batterysegmentpaddingtop = 4,
            batterysegmentpaddingbottom = 4,
            batterysegmentpaddingleft = 4,
            batterysegmentpaddingright = 4,
            gaugepaddingleft = 8,
            txdgaugepaddingleft = 10,
            gaugepaddingright = 9,
            txdgaugepaddingright = 10,
            gaugepaddingbottom = 2,
            gaugepaddingtop = 2,
            cappaddingright = 4,
            barpaddingleft = 15,
            barpaddingright = 18,
            barpaddingbottom = 2,
            txdvaluepaddingleft = 8,
            barpaddingtop = 2,
            valuepaddingbottom = 20,
            txdvaluepaddingtop = 8,
            roundradius = 10
        }

    elseif W == 640 or W == 630 then
        return {
            height = 30,
            font = "FONT_L",
            txbattfont = "FONT_S",
            txdbattfont = "FONT_S",
            batterysegmentpaddingtop = 4,
            batterysegmentpaddingbottom = 4,
            batterysegmentpaddingleft = 4,
            batterysegmentpaddingright = 4,
            gaugepaddingleft = 21,
            txdgaugepaddingleft = 15,
            gaugepaddingright = 23,
            txdgaugepaddingright = 15,
            gaugepaddingbottom = 2,
            gaugepaddingtop = 2,
            cappaddingright = 4,
            barpaddingleft = 19,
            barpaddingright = 21,
            barpaddingbottom = 2,
            txdvaluepaddingleft = 8,
            barpaddingtop = 2,
            valuepaddingbottom = 20,
            txdvaluepaddingtop = 8,
            roundradius = 10
        }
    end
end

function utils.themeColors()
    local colorMode = {
        dark = {textcolor = "white", titlecolor = "white", bgcolor = "black", fillcolor = "green", fillwarncolor = "orange", fillcritcolor = "red", fillbgcolor = "grey", accentcolor = "white", rssifillcolor = "green", rssifillbgcolor = "darkgrey", txaccentcolor = "grey", txfillcolor = "green", txbgfillcolor = "darkgrey", tbbgcolor = "headergrey", cntextcolor = "white", tbtextcolor = "white", panelbg = "bggrey", paneldarkbg = "bgdarkgrey", panelbgline = "bglines"},
        light = {textcolor = "lmgrey", titlecolor = "lmgrey", bgcolor = "white", fillcolor = "lightgreen", fillwarncolor = "lightorange", fillcritcolor = "lightred", fillbgcolor = "lightgrey", accentcolor = "darkgrey", rssifillcolor = "lightgreen", rssifillbgcolor = "grey", txaccentcolor = "white", txfillcolor = "lightgreen", txbgfillcolor = "grey", tbbgcolor = "darkgrey", cntextcolor = "white", tbtextcolor = "white", panelbg = "darkgrey", paneldarkbg = "grey", panelbgline = "lmgrey"}
    }
    return lcd.darkMode() and colorMode.dark or colorMode.light
end

function utils.standardHeaderLayout(headeropts) return {height = headeropts.height, cols = 7, rows = 1} end

function utils.getTxBatteryVoltageRange()
    if system and system.voltageRange then
        local vmin, vmax = system.voltageRange()
        if vmin and vmax and vmin < vmax then
            return vmin, vmax
        end
    end

    -- Safe default for 2-cell Li-ion / LiPo TX packs
    return 7.2, 8.4
end


function utils.getTxBox(colorMode, headeropts, txbatt_min, txbatt_max, txbatt_warn)
    return {
        col = 6,
        row = 1,
        type = "gauge",
        subtype = "bar",
        source = "txbatt",
        battery = true,
        batteryframe = true,
        hidevalue = true,
        valuealign = "left",
        batterysegments = 4,
        batteryspacing = 1,
        batteryframethickness = 2,
        batterysegmentpaddingtop = headeropts.batterysegmentpaddingtop,
        batterysegmentpaddingbottom = headeropts.batterysegmentpaddingbottom,
        batterysegmentpaddingleft = headeropts.batterysegmentpaddingleft,
        batterysegmentpaddingright = headeropts.batterysegmentpaddingright,
        gaugepaddingright = headeropts.gaugepaddingright,
        gaugepaddingleft = headeropts.gaugepaddingleft,
        gaugepaddingbottom = headeropts.gaugepaddingbottom,
        gaugepaddingtop = headeropts.gaugepaddingtop,
        cappaddingright = headeropts.cappaddingright,
        fillbgcolor = colorMode.txbgfillcolor,
        bgcolor = colorMode.tbbgcolor,
        accentcolor = colorMode.txaccentcolor,
        min = txbatt_min,
        max = txbatt_max,
        thresholds = {{value = txbatt_warn, fillcolor = colorMode.fillwarncolor}, {value = txbatt_max, fillcolor = colorMode.txfillcolor}}
    }
end

local function txTextBox(colorMode, headeropts) return {col = 6, row = 1, type = "text", subtype = "telemetry", source = "txbatt", title = "Tx Batt", titlepos = "bottom", titlefont = "FONT_XXS", valuealign = "center", unit = "v", valuepaddingtop = 8, valuepaddingleft = 8, font = headeropts.txbattfont, decimals = 1, bgcolor = colorMode.tbbgcolor, textcolor = colorMode.tbtextcolor} end

local function txDigitalBox(colorMode, headeropts, txbatt_min, txbatt_max, txbatt_warn)
    return {
        col = 6,
        row = 1,
        type = "gauge",
        subtype = "bar",
        source = "txbatt",
        font = headeropts.txdbattfont,
        battery = false,
        roundradius = headeropts.roundradius,
        decimals = 1,
        unit = "v",
        gaugepaddingright = headeropts.txdgaugepaddingright,
        gaugepaddingleft = headeropts.txdgaugepaddingleft,
        gaugepaddingbottom = headeropts.gaugepaddingbottom,
        gaugepaddingtop = headeropts.gaugepaddingtop,
        valuepaddingleft = headeropts.txdvaluepaddingleft,
        valuepaddingtop = headeropts.txdvaluepaddingtop,
        fillbgcolor = colorMode.txbgfillcolor,
        bgcolor = colorMode.tbbgcolor,
        accentcolor = colorMode.txaccentcolor,
        textcolor = colorMode.tbtextcolor,
        min = txbatt_min,
        max = txbatt_max,
        thresholds = {{value = txbatt_warn, fillcolor = colorMode.fillwarncolor}, {value = txbatt_max, fillcolor = colorMode.txfillcolor}}
    }
end

function utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
    local txbatt_min, txbatt_max = utils.getTxBatteryVoltageRange()
    local txbatt_warn = txbatt_min + 0.2
    txbatt_type = tonumber(txbatt_type) or 0

    local txBox
    if txbatt_type == 2 then
        txBox = txDigitalBox(colorMode, headeropts, txbatt_min, txbatt_max, txbatt_warn)
    elseif txbatt_type == 1 then
        txBox = txTextBox(colorMode, headeropts, txbatt_min, txbatt_max, txbatt_warn)
    else
        txBox = utils.getTxBox(colorMode, headeropts, txbatt_min, txbatt_max, txbatt_warn)
    end

    return {

        {col = 1, row = 1, colspan = 2, type = "text", subtype = "craftname", font = headeropts.font, valuealign = "left", valuepaddingleft = 5, bgcolor = colorMode.tbbgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.cntextcolor}, {col = 3, row = 1, colspan = 3, type = "image", subtype = "image", bgcolor = colorMode.tbbgcolor}, txBox, {
            col = 7,
            row = 1,
            type = "gauge",
            subtype = "step",
            source = "rssi",
            font = "FONT_XS",
            stepgap = 2,
            stepcount = 5,
            decimals = 0,
            valuealign = "left",
            barpaddingleft = headeropts.barpaddingleft,
            barpaddingright = headeropts.barpaddingright,
            barpaddingbottom = headeropts.barpaddingbottom,
            barpaddingtop = headeropts.barpaddingtop,
            valuepaddingleft = headeropts.valuepaddingleft,
            valuepaddingbottom = headeropts.valuepaddingbottom,
            bgcolor = colorMode.tbbgcolor,
            textcolor = colorMode.rssitextcolor,
            fillcolor = colorMode.rssifillcolor,
            fillbgcolor = colorMode.rssifillbgcolor
        }
    }
end

function utils.resetImageCache() for k in pairs(imageCache) do imageCache[k] = nil end end

function utils.screenError(msg, border, pct, padX, padY)

    if not pct then pct = 0.5 end
    if border == nil then border = true end
    if not padX then padX = 8 end
    if not padY then padY = 4 end

    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL, FONT_XXXXL}

    local maxW, maxH = w * pct, h * pct
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

    if border then lcd.drawRectangle(x - padX, y - padY, bestW + padX * 2, bestH + padY * 2) end

    lcd.drawText(x, y, msg)
end

function utils.resolveColor(value, variantFactor)

    local namedColors = {
        red = {255, 0, 0},
        green = {0, 188, 4},
        blue = {0, 122, 255},
        white = {255, 255, 255},
        black = {0, 0, 0},
        gray = {185, 185, 185},
        grey = {185, 185, 185},
        orange = {255, 165, 0},
        yellow = {255, 255, 0},
        cyan = {0, 255, 255},
        magenta = {255, 0, 255},
        pink = {255, 105, 180},
        purple = {128, 0, 128},
        violet = {143, 0, 255},
        brown = {139, 69, 19},
        lime = {0, 255, 0},
        olive = {128, 128, 0},
        gold = {255, 215, 0},
        silver = {192, 192, 192},
        teal = {0, 128, 128},
        navy = {0, 0, 128},
        maroon = {128, 0, 0},
        beige = {245, 245, 220},
        turquoise = {64, 224, 208},
        indigo = {75, 0, 130},
        coral = {255, 127, 80},
        salmon = {250, 128, 114},
        mint = {62, 180, 137},
        lightgreen = {144, 238, 144},
        darkgreen = {0, 100, 0},
        lightred = {255, 102, 102},
        darkred = {139, 0, 0},
        lightorange = {255, 200, 100},
        lightblue = {173, 216, 230},
        darkblue = {0, 0, 139},
        lightpurple = {216, 191, 216},
        darkpurple = {48, 25, 52},
        lightyellow = {255, 255, 224},
        darkyellow = {204, 204, 0},
        lightgrey = {211, 211, 211},
        lightgray = {211, 211, 211},
        darkgrey = {90, 90, 90},
        darkgray = {90, 90, 90},
        lmgrey = {80, 80, 80},
        darkwhite = {245, 245, 245},
        headergrey = {35, 35, 35},
        bggrey = {40, 40, 40},
        bgdarkgrey = {25, 25, 25},
        bglines = {65, 65, 65},
    }

    local VARIANT_FACTOR = type(variantFactor) == "number" and max(0, min(1, variantFactor)) or 0.3

    local function clamp(v) return max(0, min(255, floor(v + 0.5))) end

    local function lighten(rgb) return {clamp(rgb[1] + (255 - rgb[1]) * VARIANT_FACTOR), clamp(rgb[2] + (255 - rgb[2]) * VARIANT_FACTOR), clamp(rgb[3] + (255 - rgb[3]) * VARIANT_FACTOR)} end

    local function darken(rgb) return {clamp(rgb[1] * (1 - VARIANT_FACTOR)), clamp(rgb[2] * (1 - VARIANT_FACTOR)), clamp(rgb[3] * (1 - VARIANT_FACTOR))} end

    if type(value) == "string" then
        local lower = value:lower()

        local prefix, baseName = lower:match("^(bright)(.+)"), lower:match("^bright(.+)")
        if not prefix then prefix, baseName = lower:match("^(light)(.+)"), lower:match("^light(.+)") end
        if not prefix then prefix, baseName = lower:match("^(dark)(.+)"), lower:match("^dark(.+)") end

        if prefix and baseName then
            local baseColor = namedColors[baseName]
            if baseColor then
                local rgb = (prefix == "dark") and darken(baseColor) or lighten(baseColor)
                return lcd.RGB(rgb[1], rgb[2], rgb[3], 1)
            end

        elseif namedColors[lower] then

            local c = namedColors[lower]
            return lcd.RGB(c[1], c[2], c[3], 1)
        end

    elseif type(value) == "table" and #value >= 3 then

        return lcd.RGB(value[1], value[2], value[3], 1)
    end

    return nil
end

function utils.resolveThemeColor(colorkey, value)

    if type(value) == "number" then return value end

    if type(value) == "string" and value == "transparent" then return nil end

    if type(value) == "string" then
        local resolved = utils.resolveColor(value)
        if resolved then return resolved end
    end

    if colorkey == "fillcolor" then
        return lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)
    elseif colorkey == "fillbgcolor" then
        return lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)
    elseif colorkey == "framecolor" then
        return lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)
    elseif colorkey == "textcolor" then
        return lcd.RGB(255, 255, 255)
    elseif colorkey == "titlecolor" then
        return lcd.RGB(255, 255, 255)
    elseif colorkey == "accentcolor" then
        return lcd.RGB(255, 255, 255)
    end

    return lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)
end

function utils.resolveThemeColorArray(colorkey, arr, out)
    local resolved = out or {}
    for i = #resolved, 1, -1 do
        resolved[i] = nil
    end
    if type(arr) == "table" then
        for i = 1, #arr do
            resolved[i] = utils.resolveThemeColor(colorkey, arr[i])
        end
    end
    return resolved
end

function utils.box(x, y, w, h, title, titlepos, titlealign, titlefont, titlespacing, titlecolor, titlepadding, titlepaddingleft, titlepaddingright, titlepaddingtop, titlepaddingbottom, displayValue, unit, font, valuealign, textcolor, valuepadding, valuepaddingleft, valuepaddingright, valuepaddingtop, valuepaddingbottom, bgcolor, image, imagewidth, imageheight, imagealign)

    local DEFAULT_TITLE_PADDING = 0
    local DEFAULT_VALUE_PADDING = 6
    local DEFAULT_TITLE_SPACING = 6

    titlepaddingleft = titlepaddingleft or titlepadding or DEFAULT_TITLE_PADDING
    titlepaddingright = titlepaddingright or titlepadding or DEFAULT_TITLE_PADDING
    titlepaddingtop = titlepaddingtop or titlepadding or DEFAULT_TITLE_PADDING
    titlepaddingbottom = titlepaddingbottom or titlepadding or DEFAULT_TITLE_PADDING

    valuepaddingleft = valuepaddingleft or valuepadding or DEFAULT_VALUE_PADDING
    valuepaddingright = valuepaddingright or valuepadding or DEFAULT_VALUE_PADDING
    valuepaddingtop = valuepaddingtop or valuepadding or DEFAULT_VALUE_PADDING
    valuepaddingbottom = valuepaddingbottom or valuepadding or DEFAULT_VALUE_PADDING

    titlespacing = titlespacing or DEFAULT_TITLE_SPACING

    if bgcolor then
        lcd.color(bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    if not fontCache then fontCache = utils.getFontListsForResolution() end

    local actualTitleFont, tsizeW, tsizeH = nil, 0, 0
    if title then
        local minValueFontH = 9999
        for _, vf in ipairs(fontCache.value_default or {FONT_STD}) do
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

    if image then
        local bitmapPtr = nil

        if type(image) == "string" and rfsuite and rfsuite.utils and rfsuite.utils.loadImage then
            imageCache = imageCache or {}
            local cacheKey = image or "default_image"
            bitmapPtr = imageCache[cacheKey]
            if not bitmapPtr then
                bitmapPtr = rfsuite.utils.loadImage(image, nil, "widgets/dashboard/gfx/logo.png")
                imageCache[cacheKey] = bitmapPtr
            end
        elseif type(image) == "userdata" then

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
                if tW <= region_vw and tH <= region_vh then valueFont, bestW, bestH = tryFont, tW, tH end
            end
            lcd.font(valueFont)
        end

        local fudgeTitle = (title and (titlepos or "top") == "top") and -floor(bestH * 0.15 + 0.5) or (title and titlepos == "bottom") and floor(bestH * 0.15 + 0.5) or 0

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

    if title then
        lcd.font(actualTitleFont)
        local region_tw = w - titlepaddingleft - titlepaddingright
        local sy = (titlepos or "top") == "bottom" and (y + h - titlepaddingbottom - tsizeH) or (y + titlepaddingtop)
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

function utils.resolveThresholdColor(value, box, colorKey, fallbackThemeKey, thresholdsOverride)
    local color = utils.resolveThemeColor(fallbackThemeKey, utils.getParam(box, colorKey))
    local thresholds = thresholdsOverride or utils.getParam(box, "thresholds")
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local thresholdValue = t.value
            if type(thresholdValue) == "function" then thresholdValue = thresholdValue(box, value) end

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

function utils.transformValue(value, box)

    local transform = utils.getParam(box, "transform")

    if transform then
        if type(transform) == "function" then
            value = transform(value)
        elseif transform == "floor" then
            value = floor(value)
        elseif transform == "ceil" then
            value = ceil(value)
        elseif transform == "round" then
            value = floor(value + 0.5)
        end
    end
    local decimals = utils.getParam(box, "decimals")

    if decimals ~= nil and value ~= nil then
        value = format("%." .. decimals .. "f", value)
    elseif value ~= nil then
        value = tostring(value)
    end
    return value
end

function utils.setBackgroundColourBasedOnTheme()
    local w, h = lcd.getWindowSize()
    if lcd.darkMode() then
        lcd.color(lcd.RGB(16, 16, 16))
    else
        lcd.color(lcd.RGB(209, 208, 208))
    end
    lcd.drawFilledRectangle(0, 0, w, h)
end

function utils.getParam(box, key, ...)
    local v = box[key]
    if type(v) == "function" and not SKIP_CALL_KEYS[key] then
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

function utils.registerProgressDialog(handle, baseMessage)
    if not handle then return end
    progressDialog = {
        handle = handle,
        baseMessage = baseMessage or ""
    }
end

function utils.clearProgressDialog(handle)
    if not progressDialog then return end
    if handle == nil or progressDialog.handle == handle then
        progressDialog = nil
    end
end

function utils.updateProgressDialogMessage(statusOverride)
    if not progressDialog or not progressDialog.handle then return end
    local showDebug = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.mspstatusdialog
    local mspStatus = statusOverride or (rfsuite.session and rfsuite.session.mspStatusMessage) or nil
    local msg = progressDialog.baseMessage or ""
    if showDebug then
        msg = mspStatus or MSP_DEBUG_PLACEHOLDER
    end
    pcall(function() progressDialog.handle:message(msg) end)
end

return utils

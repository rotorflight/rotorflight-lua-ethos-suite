--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local _G = _G
local utils = {}

local themeColorCache = {usesThemeColors = nil, primary = nil, secondary = nil, colors = nil, legacyDark = nil, legacyColors = nil}

local function rgb(r, g, b, a) return lcd.RGB(r, g, b, a or 1) end

local function isLegacyDarkMode()
    return type(lcd.darkMode) == "function" and lcd.darkMode() == true
end

local function resolveThemeConstant(name)
    if type(lcd.themeColor) ~= "function" then return nil end
    local key = _G[name]
    if type(key) ~= "number" then return nil end
    return lcd.themeColor(key)
end

local function getThemeColors()
    local primary = resolveThemeConstant("THEME_PRIMARY_COLOR")
    local secondary = resolveThemeConstant("THEME_SECONDARY_COLOR")

    if type(primary) == "number" or type(secondary) == "number" then
        if themeColorCache.colors == nil
            or themeColorCache.usesThemeColors ~= true
            or themeColorCache.primary ~= primary
            or themeColorCache.secondary ~= secondary then
            local fallbackTitle = rgb(77, 73, 77)
            local fallbackText = rgb(77, 73, 77)
            local fallbackMessage = rgb(90, 90, 90)
            themeColorCache.usesThemeColors = true
            themeColorCache.primary = primary
            themeColorCache.secondary = secondary
            themeColorCache.colors = {
                title = secondary or primary or fallbackTitle,
                text = primary or secondary or fallbackText,
                message = primary or secondary or fallbackMessage
            }
        end
        return themeColorCache.colors
    end

    local isDark = isLegacyDarkMode()
    if themeColorCache.legacyColors == nil or themeColorCache.legacyDark ~= isDark then
        themeColorCache.legacyDark = isDark
        themeColorCache.legacyColors = {
            title = isDark and rgb(154, 154, 154) or rgb(77, 73, 77),
            text = isDark and rgb(255, 255, 255) or rgb(77, 73, 77),
            message = isDark and rgb(255, 255, 255) or rgb(90, 90, 90)
        }
    end
    return themeColorCache.legacyColors
end

function utils.box(title, msg)

    local w, h = lcd.getWindowSize()
    local themeColors = getThemeColors()

    local offsetY = 0

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

        local x = (w - bestW) / 2
        local y = bestH / 4
        lcd.color(themeColors.title)
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
    lcd.color(themeColors.text)
    lcd.drawText(x, y, msg)
end

return utils

local LCD_W, LCD_H = lcd.getWindowSize()
local resolution = LCD_W .. "x" .. LCD_H

--[[
    This script defines a table `supportedRadios` that contains configuration settings for different radio models.
    Each key in the table represents a screen resolution, and the value is a table of settings specific to that resolution.
    
    Supported Radios:
    - TANDEM X20, TANDEM XE (800x480)
    - TANDEM X18, TWIN X Lite (480x320)
    - Horus X10, Horus X12 (480x272)
    - Twin X14 (632x314)
    
    Configuration settings include:
    - `inlinesize_mult`: Multiplier for inline size.
    - `menuButtonWidth`: Width of menu buttons.
    - `navbuttonHeight`: Height of navigation buttons.
    - `buttonsPerRow`: Number of buttons per row.
    - `buttonsPerRowSmall`: Number of small buttons per row.
    - `buttonWidth`: Width of buttons.
    - `buttonHeight`: Height of buttons.
    - `buttonPadding`: Padding between buttons.
    - `buttonWidthSmall`: Width of small buttons.
    - `buttonHeightSmall`: Height of small buttons.
    - `buttonPaddingSmall`: Padding between small buttons.
    - `linePaddingTop`: Padding at the top of lines.
    - `logGraphMenuOffset`: Offset for log graph menu.
    - `logGraphWidthPercentage`: Width percentage for log graph.
    - `logGraphButtonsPerRow`: Number of buttons per row in log graph.
    - `logGraphKeyHeight`: Height of log graph key.
    - `logGraphHeightOffset`: Height offset for log graph.
    - `logKeyFont`: Font for log key.
    - `logSliderPaddingLeft`: Left padding for sliders.
]]
local supportedRadios = {
    -- TANDEM X20, TANDEM XE (800x480)
    ["784x406"] = {
            inlinesize_mult = 1,
            menuButtonWidth = 100,
            navbuttonHeight = 40,
            buttonsPerRow = 6,
            buttonsPerRowSmall = 7,
            buttonWidth = 120,
            buttonHeight = 120,
            buttonPadding = 10,
            buttonWidthSmall = 105,
            buttonHeightSmall = 110,
            buttonPaddingSmall = 6,
            linePaddingTop = 8,
            logGraphMenuOffset = 70,
            logGraphWidthPercentage = 0.79,
            logGraphButtonsPerRow = 5,
            logGraphKeyHeight = 65,
            logGraphHeightOffset = -15,
            logKeyFont = FONT_S,
            logKeyFontSmall = FONT_XS,
            logSliderPaddingLeft = 42,
            logShowAvg = true,
    },
    -- TANDEM X18, TWIN X Lite (480x320)
    ["472x288"] = {
            inlinesize_mult = 1.28,
            menuButtonWidth = 60,
            navbuttonHeight = 30,
            navButtonOffset = 47,
            buttonsPerRow = 4,
            buttonsPerRowSmall = 5,
            buttonWidth = 110,
            buttonHeight = 110,
            buttonPadding = 8,
            buttonWidthSmall = 89,
            buttonHeightSmall = 95,
            buttonPaddingSmall = 5,
            linePaddingTop = 6,
            logGraphMenuOffset = 55,
            logGraphWidthPercentage = 0.72,
            logGraphButtonsPerRow = 4,
            logGraphKeyHeight = 45,
            logGraphHeightOffset = 10,
            logKeyFont = FONT_XS,
            logKeyFontSmall = FONT_XXS,
            logSliderPaddingLeft = 30,
            logShowAvg = false,
    },
    -- Horus X10, Horus X12 (480x272)
    ["472x240"] = {
            inlinesize_mult = 1.0715,
            menuButtonWidth = 60,
            navbuttonHeight = 30,
            buttonsPerRow = 4,
            buttonsPerRowSmall = 5,
            buttonWidth = 110,
            buttonHeight = 110,
            buttonPadding = 8,
            buttonWidthSmall = 87,
            buttonHeightSmall = 97,
            buttonPaddingSmall = 7,
            linePaddingTop = 6,
            logGraphMenuOffset = 50,
            logGraphWidthPercentage = 0.65,
            logGraphButtonsPerRow = 4,
            logGraphKeyHeight = 38,
            logGraphHeightOffset = 0,
            logKeyFont = FONT_XS,
            logKeyFontSmall = FONT_XXS,
            logSliderPaddingLeft = 30,
            logShowAvg = false,
    },
    -- Twin X14 (632x314)
    ["632x314"] = {
            menuButtonWidth = 80,
            inlinesize_mult = 1.11,
            navbuttonHeight = 35,
            navButtonOffset = 47,
            buttonsPerRow = 5,
            buttonsPerRowSmall = 6,
            buttonWidth = 118,
            buttonHeight = 120,
            buttonPadding = 7,
            buttonWidthSmall = 97,
            buttonHeightSmall = 115,
            buttonPaddingSmall = 8,
            linePaddingTop = 6,
            logGraphMenuOffset = 60,
            logGraphWidthPercentage = 0.76,
            logGraphButtonsPerRow = 4,
            logGraphKeyHeight = 50,
            logGraphHeightOffset = 0,
            logKeyFont = FONT_XXS,
            logKeyFontSmall = FONT_XXS,
            logSliderPaddingLeft = 30,
            logShowAvg = false,
    }
}

local radio = assert(supportedRadios[resolution], resolution .. " not supported")

return radio

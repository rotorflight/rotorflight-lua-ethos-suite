local LCD_W, LCD_H = lcd.getWindowSize()
local resolution = LCD_W .. "x" .. LCD_H

--[[
  Supported Radios (by scaled resolution):
    • TANDEM X20 / TANDEM XE   → "784x406"
    • TANDEM X18 / TWIN X Lite → "472x288"
    • Twin X14                 → "632x314"

  Notes:
    - Keys appear in the same order in every block for quick side-by-side comparison.
    - Omit keys that don't apply (keeps sections readable while still aligned overall).
]]

local supportedRadios = {
  ---------------------------------------------------------------------------
  -- TANDEM X20 / TANDEM XE (800x480 → 784x406)
  ---------------------------------------------------------------------------
  ["784x406"] = {
    -- Buttons (regular)
    buttonWidth             = 120,
    buttonHeight            = 120,
    buttonPadding           = 10,

    -- Buttons (small)
    buttonWidthSmall        = 105,
    buttonHeightSmall       = 110,
    buttonPaddingSmall      = 6,

    -- Layout
    buttonsPerRow           = 6,
    buttonsPerRowSmall      = 7,
    inlinesize_mult         = 1,
    linePaddingTop          = 8,
    menuButtonWidth         = 100,
    navbuttonHeight         = 40,
    -- navButtonOffset      = (not used on this model)

    -- Log Graph
    logGraphButtonsPerRow   = 5,
    logGraphHeightOffset    = -15,
    logGraphKeyHeight       = 65,
    logGraphMenuOffset      = 70,
    logGraphWidthPercentage = 0.79,
    logKeyFont              = FONT_S,
    logKeyFontSmall         = FONT_XS,
    logShowAvg              = true,
    logSliderPaddingLeft    = 42,
  },

  ---------------------------------------------------------------------------
  -- TANDEM X18 / TWIN X Lite (480x320 → 472x288)
  ---------------------------------------------------------------------------
  ["472x288"] = {
    -- Buttons (regular)
    buttonWidth             = 110,
    buttonHeight            = 110,
    buttonPadding           = 8,

    -- Buttons (small)
    buttonWidthSmall        = 89,
    buttonHeightSmall       = 95,
    buttonPaddingSmall      = 5,

    -- Layout
    buttonsPerRow           = 4,
    buttonsPerRowSmall      = 5,
    inlinesize_mult         = 1.28,
    linePaddingTop          = 6,
    menuButtonWidth         = 60,
    navbuttonHeight         = 30,
    navButtonOffset         = 47,

    -- Log Graph
    logGraphButtonsPerRow   = 4,
    logGraphHeightOffset    = 10,
    logGraphKeyHeight       = 45,
    logGraphMenuOffset      = 55,
    logGraphWidthPercentage = 0.72,
    logKeyFont              = FONT_XS,
    logKeyFontSmall         = FONT_XXS,
    logShowAvg              = false,
    logSliderPaddingLeft    = 30,
  },

  ---------------------------------------------------------------------------
  -- Twin X14 (632x314)
  ---------------------------------------------------------------------------
  ["632x314"] = {
    -- Buttons (regular)
    buttonWidth             = 118,
    buttonHeight            = 120,
    buttonPadding           = 7,

    -- Buttons (small)
    buttonWidthSmall        = 97,
    buttonHeightSmall       = 115,
    buttonPaddingSmall      = 8,

    -- Layout
    buttonsPerRow           = 5,
    buttonsPerRowSmall      = 6,
    inlinesize_mult         = 1.11,
    linePaddingTop          = 6,
    menuButtonWidth         = 80,
    navbuttonHeight         = 35,
    navButtonOffset         = 47,

    -- Log Graph
    logGraphButtonsPerRow   = 4,
    logGraphHeightOffset    = 0,
    logGraphKeyHeight       = 50,
    logGraphMenuOffset      = 60,
    logGraphWidthPercentage = 0.76,
    logKeyFont              = FONT_XXS,
    logKeyFontSmall         = FONT_XXS,
    logShowAvg              = false,
    logSliderPaddingLeft    = 30,
  },
}

-- Select active config
local radio = assert(supportedRadios[resolution], resolution .. " not supported")

-- Nil out the unused sub-tables to let GC reclaim them
for resKey in pairs(supportedRadios) do
  if resKey ~= resolution then
    supportedRadios[resKey] = nil
  end
end

return radio

local LCD_W, LCD_H = rfsuite.utils.getWindowSize()
local resolution = LCD_W .. "x" .. LCD_H

local supportedRadios = {
    -- TANDEM X20, TANDEM XE (800x480)
    ["784x406"] = {
        msp = {
            inlinesize_mult = 1,
            text = 1,
            menuButtonWidth = 100,
            helpQrCodeSize = 100,
            navbuttonHeight = 40,
            buttonsPerRow = 5,
            buttonsPerRowSmall = 6,
            buttonWidth = 135,
            buttonHeight = 140,
            buttonPadding = 23,
            buttonWidthSmall = 120,
            buttonHeightSmall = 120,
            buttonPaddingSmall = 10,
            linePaddingTop = 8,
            formRowHeight = 50,
            logGraphMenuOffset = 70,
            logGraphWidthPercentage = 0.75,
            logGraphButtonsPerRow = 5,
            logGraphKeyHeight = 65,
            logKeyFont = FONT_S
        }
    },
    -- TANDEM X18, TWIN X Lite (480x320)
    ["472x288"] = {
        msp = {
            inlinesize_mult = 1.28,
            text = 2,
            menuButtonWidth = 60,
            helpQrCodeSize = 70,
            navbuttonHeight = 30,
            navButtonOffset = 47,
            buttonsPerRow = 4,
            buttonsPerRowSmall = 5,
            buttonWidth = 110,
            buttonHeight = 110,
            buttonPadding = 8,
            buttonWidthSmall = 87,
            buttonHeightSmall = 97,
            buttonPaddingSmall = 7,
            linePaddingTop = 6,
            formRowHeight = 50,
            logGraphMenuOffset = 55,
            logGraphWidthPercentage = 0.62,
            logGraphButtonsPerRow = 4,  
            logGraphKeyHeight = 45,     
            logKeyFont = FONT_XS           
        }
    },
    -- Horus X10, Horus X12 (480x272)
    ["472x240"] = {
        msp = {
            inlinesize_mult = 1.0715,
            menuButtonWidth = 60,
            helpQrCodeSize = 70,
            navbuttonHeight = 30,
            text = 2,
            buttonsPerRow = 4,
            buttonsPerRowSmall = 5,
            buttonWidth = 110,
            buttonHeight = 110,
            buttonPadding = 8,
            buttonWidthSmall = 87,
            buttonHeightSmall = 97,
            buttonPaddingSmall = 7,
            linePaddingTop = 6,
            formRowHeight = 50,
            logGraphMenuOffset = 50,
            logGraphWidthPercentage = 0.65,
            logGraphButtonsPerRow = 4,  
            logGraphKeyHeight = 38,    
            logKeyFont = FONT_XS            
        }
    },
    -- Twin X14 (632x314)
    ["632x314"] = {
        msp = {
            menuButtonWidth = 80,
            inlinesize_mult = 1.11,
            text = 2,
            helpQrCodeSize = 100,
            navbuttonHeight = 35,
            navButtonOffset = 47,
            buttonsPerRow = 5,
            buttonsPerRowSmall = 6,
            buttonWidth = 112,
            buttonHeight = 120,
            buttonPadding = 15,
            buttonWidthSmall = 97,
            buttonHeightSmall = 97,
            buttonPaddingSmall = 8,
            linePaddingTop = 6,
            formRowHeight = 50,
            logGraphMenuOffset = 60,
            logGraphWidthPercentage = 0.65,
            logGraphButtonsPerRow = 4,  
            logGraphKeyHeight = 50,          
            logKeyFont = FONT_XS            
        }
    }
}

local radio = assert(supportedRadios[resolution], resolution .. " not supported")

return radio

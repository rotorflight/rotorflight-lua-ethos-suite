local function init()
    system.registerTheme({
        key = "KvnD",
        name = "KvnD",
        roundButtons = true,
        focusStyle = "invert",
        colors = {
        lcd.RGB(0xFF, 0xFF, 0xFF), -- PRIMARY_COLOR (Ultra-crisp stark white text)
        lcd.RGB(28,15,68),         -- SECONDARY_BGCOLOR (Clean slate grey for panels)
        lcd.RGB(0xAA, 0x66, 0xFF), -- HIGHLIGHT_COLOR (Vibrant, high-voltage electric violet)
        lcd.RGB(0x0C, 0x0D, 0x12), -- HIGHLIGHT_INVERT_COLOR (Inverted deep ink black)
        lcd.RGB(0x52, 0x5A, 0x7A), -- DISABLE_COLOR (Sleek low-opacity steel blue)
        lcd.RGB(28,15,68),         -- PRIMARY_BGCOLOR (Rich OLED midnight-grey background)
        BLACK,                     -- OVERLAY_COLOR
        lcd.RGB(0xFF, 0xFF, 0xFF), -- SECONDARY_COLOR (Ice blue-grey accent text)
        lcd.RGB(0x00, 0xFF, 0xA3), -- MIXER_OUTPUT_COLOR (Hyper-neon spring green)
        lcd.RGB(0x18, 0x1A, 0x20), -- PAGE_BGCOLOR (Subtle dark backing layout)
        lcd.RGB(0xFF, 0x47, 0x66), -- WARNING_COLOR (Radical synth-wave hot coral)
        lcd.RGB(0x00, 0xFF, 0xA3), -- ACTIVE_COLOR (Hyper-neon spring green)
        lcd.RGB(0xA2, 0xAC, 0xC7), -- INACTIVE_COLOR (Muted silver-blue)
        lcd.RGB(0xCC, 0x00, 0xFF), -- BUTTON_BORDER_ACTIVE_COLOR (Neon violet-magenta trim)
        lcd.RGB(0x23, 0x25, 0x31), -- BUTTON_BORDER_COLOR (Clean, defined dark edge)
        BLACK                      -- TOPLCD_BGCOLOR (XE/S models)
        },
        --toolbarLogo = "none",
        toolbarBackground = lcd.loadBitmap("toolbar-dracula-plain.png"),
    })
    system.registerTheme({
        key = "Teal",
        name = "teal1",
        roundButtons = true,
        focusStyle = "invert",
        darkMode = false,
        colors = {
            lcd.RGB(0x1F, 0x1F, 0x1F), -- PRIMARY_COLOR
            lcd.RGB(118, 145, 137), -- SECONDARY_BGCOLOR
            lcd.RGB(100, 74, 201),     -- HIGHLIGHT_COLOR (#644AC9)
            lcd.RGB(0xFF, 0xFF, 0xF5), -- HIGHLIGHT_INVERT_COLOR
            lcd.RGB(0x87, 0x7F, 0x5E), -- DISABLE_COLOR
            lcd.RGB(0xBD, 0xE6, 0xD6), -- PRIMARY_BGCOLOR
            lcd.GREY(0x60),            -- OVERLAY_COLOR
            lcd.RGB(0xFF, 0x9F, 0x0F), -- SECONDARY_COLOR
            lcd.RGB(0x08, 0x91, 0x08), -- MIXER_OUTPUT_COLOR
            lcd.RGB(242, 240, 232),    -- PAGE_BGCOLOR
            lcd.RGB(0xCB, 0x3A, 0x2A), -- WARNING_COLOR
            lcd.RGB(0x08, 0x91, 0x08), -- ACTIVE_COLOR
            lcd.RGB(0x3E, 0x3A, 0x2B), -- INACTIVE_COLOR
            lcd.RGB(0x81, 0x5C, 0xD6), -- BUTTON_BORDER_ACTIVE_COLOR xCF
            lcd.RGB(118, 145, 137),    -- BUTTON_BORDER_COLOR
            WHITE,                     -- TOPLCD_BGCOLOR (XE/S)
        },
        toolbarLogo = "none",
        toolbarBackground = lcd.loadBitmap("teal1.5.png"),
    })
   system.registerTheme({
    key = "Blues",
    name = "Blues",
    roundButtons = true,
    focusStyle = "outline",
    borderWidth = 4,
    darkMode = false,
    colors = {
        lcd.RGB(24, 16, 16),       -- PRIMARY_COLOR (Black)
        lcd.RGB(103, 139, 193),    -- SECONDARY_BGCOLOR (Soft Navy #678BC1)
        lcd.RGB(249, 121, 4),      -- HIGHLIGHT_COLOR (Mostly desaturated dark blue  #55677c)
        lcd.RGB(249, 121, 4),      -- HIGHLIGHT_INVERT_COLOR ( Chilean Fire #F97904)
        lcd.RGB(0x6B, 0x4D, 0x8A), -- DISABLE_COLOR (violet désaturé)
        lcd.RGB(178, 228, 255),    -- PRIMARY_BGCOLOR (Light Sky Blue #B2E4FF)
        BLACK,                     -- OVERLAY_COLOR
        lcd.RGB(250, 133, 103),    -- SECONDARY_color (Glossy Coral #FA8567)
        lcd.RGB(0x00, 0xFF, 0xCC), -- MIXER_OUTPUT_COLOR (white)
        lcd.RGB(255, 255, 255),    -- PAGE_BGCOLOR (white	#C4EEFF)
        lcd.RGB(0xFF, 0x2D, 0x55), -- WARNING_COLOR (rose-rouge vif)
        lcd.RGB(0x00, 0xFF, 0xCC), -- ACTIVE_COLOR (cyan néon)
        lcd.RGB(0xC4, 0xAE, 0xFF), -- INACTIVE_COLOR (lavande)
        lcd.RGB(0xFF, 0x00, 0xCC), -- BUTTON_BORDER_ACTIVE_COLOR (magenta néon)
        lcd.RGB(85, 103, 124),     -- BUTTON_BORDER_COLOR (Mostly desaturated dark blue #55677c)
        BLACK,                     -- TOPLCD_BGCOLOR (XE/S)
        },
        toolbarLogo ="none",
        toolbarBackground = lcd.loadBitmap("blueslogo1.png")
    })
    system.registerTheme({
        key = "Ocean",
        name = "Ocean",
        roundButtons = true,
        focusStyle = "invert",
        darkMode = true,
        colors = {
            lcd.RGB(0xD8, 0xE8, 0xFF), -- PRIMARY_COLOR (blanc glacé)
            lcd.RGB(0x2C, 0x44, 0x68), -- SECONDARY_BGCOLOR (acier bleu panel — lum ~3.4x PRIMARY)
            lcd.RGB(0x44, 0x88, 0xFF), -- HIGHLIGHT_COLOR (bleu royal vif)
            lcd.RGB(0xE8, 0xF4, 0xFF), -- HIGHLIGHT_INVERT_COLOR (blanc sur bleu)
            lcd.RGB(0x24, 0x36, 0x50), -- DISABLE_COLOR (bleu ardoise éteint)
            lcd.RGB(0x18, 0x20, 0x40), -- PRIMARY_BGCOLOR (bleu nuit — lum ~0.016 = Dracula)
            BLACK,                     -- OVERLAY_COLOR
            lcd.RGB(0x88, 0xBB, 0xDD), -- SECONDARY_COLOR (bleu ciel lisible)
            lcd.RGB(0x84, 0xC3, 0x0F), -- MIXER_OUTPUT_COLOR (vert ethos)
            lcd.RGB(0x0E, 0x18, 0x30), -- PAGE_BGCOLOR (plus sombre que PRIMARY)
            lcd.RGB(0xFF, 0x44, 0x44), -- WARNING_COLOR (rouge vif)
            lcd.RGB(0x44, 0x88, 0xFF), -- ACTIVE_COLOR (bleu royal)
            lcd.RGB(0x2A, 0x50, 0x80), -- INACTIVE_COLOR (bleu terne)
            lcd.RGB(0x44, 0x88, 0xFF), -- BUTTON_BORDER_ACTIVE_COLOR
            lcd.RGB(0x2C, 0x44, 0x68), -- BUTTON_BORDER_COLOR
            BLACK,                     -- TOPLCD_BGCOLOR (XE/S)
        },
        --toolbarLogo = "none",
        toolbarBackground = lcd.loadBitmap("toolbar-ocean.png")
    })
    
end

return {
    init = init
}

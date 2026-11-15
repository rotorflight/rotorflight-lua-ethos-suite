-- Copyright (C) 2026 Rotorflight Project
-- GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
-- Share the bitmap supplied to registerTheme() with the KevD dashboard.
-- Ethos exposes the current palette, but no current theme key/bitmap getter.
local KEY = "rfsuite.widgets.dashboard.themes.kevd.header_bridge"
if package.loaded[KEY] then return package.loaded[KEY] end

local bridge = {}
local headers = {}
-- RegisterTheme's color slots, excluding the overlay/top-LCD slots which
-- are not exposed as Lua theme color constants on all supported radios.
-- Highlight is user-configurable in Ethos, so it cannot identify a theme.
local slots = {
    "THEME_PRIMARY_COLOR", "THEME_SECONDARY_BGCOLOR", false,
    "THEME_HIGHLIGHT_CONTRASTING_COLOR", "THEME_DISABLE_COLOR", "THEME_PRIMARY_BGCOLOR",
    false, "THEME_SECONDARY_COLOR", "THEME_SAFE_COLOR", "THEME_PAGE_BGCOLOR",
    "THEME_ERROR_COLOR", "THEME_ACTIVE_COLOR", "THEME_INACTIVE_COLOR",
    "THEME_BUTTON_BORDER_ACTIVE_COLOR", "THEME_BUTTON_BORDER_COLOR",
    "THEME_WARNING_COLOR", "THEME_SAFE_CONTRASTING_COLOR"
}

local function paletteKey(colors)
    local hash = 0xcbf29ce484222325
    for i = 1, #slots do
        local name = slots[i]
        if name then
            local index = _G[name]
            if index == nil then return nil end
            local color = colors and colors[i] or lcd.themeColor(index)
            if type(color) ~= "number" then return nil end
            hash = (hash ~ color) * 0x100000001b3
        end
    end
    return hash
end

function bridge.registerTheme(theme)
    local result = system.registerTheme(theme)
    local key = theme.colors and paletteKey(theme.colors)
    if key then
        local image = theme.toolbarBackground
        -- Native "light"/"dark" names are not bitmap handles. Palettes shared
        -- by distinct artwork cannot be disambiguated without an Ethos getter.
        if type(image) == "string" then image = nil end
        local previous = headers[key]
        if previous ~= nil and previous ~= image then
            headers[key] = false
        else
            headers[key] = image or false
        end
    end
    return result
end

function bridge.getToolbarBackground()
    if type(lcd.themeColor) ~= "function" then return nil end
    local key = paletteKey()
    return key and headers[key] or nil
end

package.loaded[KEY] = bridge
return bridge

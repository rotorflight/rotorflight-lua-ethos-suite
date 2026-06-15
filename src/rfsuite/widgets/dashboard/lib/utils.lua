--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local system = system
local _G = _G

local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max
local abs = math.abs
local sin = math.sin
local cos = math.cos
local rad = math.rad
local format = string.format
local rep = string.rep

local _fmtCache = {}
local _DOTS = {".", "..", "..."}
local ipairs = ipairs
local pairs = pairs
local type = type
local tostring = tostring
local tonumber = tonumber

local utils = {}

local SKIP_CALL_KEYS = {transform = true, thresholds = true, value = true}
local MAX_BATTERY_PROFILES = 6
local PROFILE_HASH_BASE = 131

local imageCache = {}
local fontCache
local progressDialog
local MSP_DEBUG_PLACEHOLDER = "MSP Waiting"
local DEFAULT_COLOR_VARIANT_FACTOR = 0.3
local batteryConfigCache = {
    config = nil,
    profiles = nil,
    batteryCellCount = 0,
    batteryCapacity = 0,
    vbatmincellvoltage = 0,
    vbatfullcellvoltage = 0,
    profileSig = 0,
    profileCapacityCount = 0,
    hasAnyBatteryCapacity = false
}

local NAMED_COLORS = {
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
    bglines = {65, 65, 65}
}

local resolveColorCache = {}
local resolveColorTableCache = setmetatable({}, {__mode = "k"})
local dashboardThemePaletteCache = {dark = nil, light = nil, signature = nil, palette = nil}
local themeFallbackPaletteCache = {dark = nil, light = nil, signature = nil, palette = nil}
local themeStateCache = {signature = nil, state = nil}
local LOGO_DARK_FALLBACK = "widgets/dashboard/gfx/logo-dark.png"
local LOGO_LIGHT_FALLBACK = "widgets/dashboard/gfx/logo-light.png"
local DASHBOARD_RESOLUTION_TOLERANCE = 12
local DASHBOARD_SUPPORTED_RESOLUTIONS = {
    {784, 294}, {784, 316}, {800, 458}, {800, 480},
    {472, 191}, {472, 210}, {480, 301}, {480, 320},
    {630, 236}, {630, 258}, {640, 338}, {640, 360}
}
local DASHBOARD_THEME_WIDTHS = {800, 784, 640, 630, 480, 472}

local FONT_BY_NAME = {
    FONT_XXS = FONT_XXS,
    FONT_XS = FONT_XS,
    FONT_S = FONT_S,
    FONT_STD = FONT_STD,
    FONT_L = FONT_L,
    FONT_XL = FONT_XL,
    FONT_XXL = FONT_XXL,
    FONT_XXXXL = FONT_XXXXL
}

local THEME_STATE_KEYS = {
    {"defaultColor", "THEME_DEFAULT_COLOR"},
    {"defaultBgColor", "THEME_DEFAULT_BGCOLOR"},
    {"primaryColor", "THEME_PRIMARY_COLOR"},
    {"primaryBgColor", "THEME_PRIMARY_BGCOLOR"},
    {"secondaryColor", "THEME_SECONDARY_COLOR"},
    {"secondaryBgColor", "THEME_SECONDARY_BGCOLOR"},
    {"focusColor", "THEME_FOCUS_COLOR"},
    {"focusBgColor", "THEME_FOCUS_BGCOLOR"},
    {"highlightColor", "THEME_HIGHLIGHT_COLOR"},
    {"highlightInvertColor", "THEME_HIGHLIGHT_INVERT_COLOR"},
    {"disableColor", "THEME_DISABLE_COLOR"},
    {"safeColor", "THEME_SAFE_COLOR"},
    {"warningColor", "THEME_WARNING_COLOR"},
    {"errorColor", "THEME_ERROR_COLOR"},
    {"activeColor", "THEME_ACTIVE_COLOR"},
    {"inactiveColor", "THEME_INACTIVE_COLOR"},
    {"buttonBorderActiveColor", "THEME_BUTTON_BORDER_ACTIVE_COLOR"},
    {"buttonBorderColor", "THEME_BUTTON_BORDER_COLOR"},
    {"mixerOutputColor", "THEME_MIXER_OUTPUT_COLOR"},
    {"safeContrastingColor", "THEME_SAFE_CONTRASTING_COLOR"},
    {"pageBgColor", "THEME_PAGE_BGCOLOR"},
    {"topLcdBgColor", "THEME_TOPLCD_BGCOLOR"}
}

local THEME_SIGNATURE_KEYS = {
    "THEME_DEFAULT_COLOR",
    "THEME_DEFAULT_BGCOLOR",
    "THEME_PRIMARY_COLOR",
    "THEME_PRIMARY_BGCOLOR",
    "THEME_SECONDARY_COLOR",
    "THEME_SECONDARY_BGCOLOR",
    "THEME_FOCUS_COLOR",
    "THEME_FOCUS_BGCOLOR",
    "THEME_HIGHLIGHT_COLOR",
    "THEME_HIGHLIGHT_INVERT_COLOR",
    "THEME_DISABLE_COLOR",
    "THEME_SAFE_COLOR",
    "THEME_WARNING_COLOR",
    "THEME_ERROR_COLOR",
    "THEME_ACTIVE_COLOR",
    "THEME_INACTIVE_COLOR",
    "THEME_BUTTON_BORDER_ACTIVE_COLOR",
    "THEME_BUTTON_BORDER_COLOR",
    "THEME_MIXER_OUTPUT_COLOR",
    "THEME_SAFE_CONTRASTING_COLOR",
    "THEME_PAGE_BGCOLOR",
    "THEME_TOPLCD_BGCOLOR"
}

local function rgb(r, g, b, a) return lcd.RGB(r, g, b, a or 1) end

local GAUGE_TRAFFIC_GREEN = rgb(0, 188, 4)
local GAUGE_TRAFFIC_AMBER = rgb(255, 170, 0)
local GAUGE_TRAFFIC_RED = rgb(224, 64, 64)
local ETHOS_THEME_MIN_VERSION = {26, 1, 0}

local function clampColorByte(v) return max(0, min(255, floor(v + 0.5))) end

local function resolveGaugeThresholdPalette(state)
    local fillcolor = state.safeColor or state.activeColor or state.mixerOutputColor or GAUGE_TRAFFIC_GREEN
    local fillwarncolor = state.warningColor or GAUGE_TRAFFIC_AMBER
    local fillcritcolor = state.errorColor or state.inactiveColor or GAUGE_TRAFFIC_RED
    return fillcolor, fillwarncolor, fillcritcolor
end

local function variantFactorOrDefault(variantFactor)
    if type(variantFactor) == "number" then
        return max(0, min(1, variantFactor))
    end
    return DEFAULT_COLOR_VARIANT_FACTOR
end

local function buildVariantColor(base, prefix, factor)
    if prefix == "dark" then
        return lcd.RGB(clampColorByte(base[1] * (1 - factor)), clampColorByte(base[2] * (1 - factor)), clampColorByte(base[3] * (1 - factor)), 1)
    end
    return lcd.RGB(clampColorByte(base[1] + (255 - base[1]) * factor), clampColorByte(base[2] + (255 - base[2]) * factor), clampColorByte(base[3] + (255 - base[3]) * factor), 1)
end

local function isLegacyDarkMode()
    return type(lcd.darkMode) == "function" and lcd.darkMode() == true
end

local function colorLuma(color)
    if type(color) ~= "number" then return nil end
    color = floor(color)
    if color < 0 then return nil end

    local r, g, b
    if color > 0xFFFFFF then
        local high = (color >> 24) & 0xFF
        local low = color & 0xFF
        if (low == 0 or low == 1 or low == 255) and high ~= 0 and high ~= 1 and high ~= 255 then
            r = high
            g = (color >> 16) & 0xFF
            b = (color >> 8) & 0xFF
        else
            r = (color >> 16) & 0xFF
            g = (color >> 8) & 0xFF
            b = low
        end
    elseif color > 0xFFFF then
        r = (color >> 16) & 0xFF
        g = (color >> 8) & 0xFF
        b = color & 0xFF
    else
        r = ((color >> 11) & 0x1F) * 255 / 31
        g = ((color >> 5) & 0x3F) * 255 / 63
        b = (color & 0x1F) * 255 / 31
    end

    return r * 0.299 + g * 0.587 + b * 0.114
end

local themeLogoOverrideCache = {}

local function getThemeLogoOverride()
    local widgetPath = rfsuite.widgets.dashboard.currentWidgetPath
    if type(widgetPath) ~= "string" or widgetPath == "" then return nil end

    local cached = themeLogoOverrideCache[widgetPath]
    if cached ~= nil then return cached or nil end

    local override = false
    local src, folder = widgetPath:match("([^/]+)/(.+)")
    if src and folder then
        local themeBase
        if src == "user" then
            themeBase = "SCRIPTS:/" .. rfsuite.config.preferences .. "/dashboard/" .. folder .. "/"
        else
            themeBase = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/themes/" .. folder .. "/"
        end

        local chunk = loadfile(themeBase .. "init.lua")
        if chunk then
            local ok, initTable = pcall(chunk)
            if ok and type(initTable) == "table" and type(initTable.logo) == "table" then
                override = {
                    dark = type(initTable.logo.dark) == "string" and (themeBase .. initTable.logo.dark) or nil,
                    light = type(initTable.logo.light) == "string" and (themeBase .. initTable.logo.light) or nil
                }
            end
        end
    end

    themeLogoOverrideCache[widgetPath] = override
    return override or nil
end

local function getLogoFallbackForBackground(bgcolor)
    local luma = colorLuma(bgcolor)
    local useDarkLogo
    if luma then
        useDarkLogo = luma > 127
    else
        useDarkLogo = not isLegacyDarkMode()
    end

    local override = getThemeLogoOverride()
    if override then
        local overridePath = useDarkLogo and override.dark or override.light
        if overridePath then return overridePath end
    end

    return useDarkLogo and LOGO_DARK_FALLBACK or LOGO_LIGHT_FALLBACK
end

function utils.getLogoFallbackForBackground(bgcolor)
    return getLogoFallbackForBackground(bgcolor)
end

local _supportsThemeChecked = false
local _supportsTheme = false

local function supportsSystemThemeColors()
    if not _supportsThemeChecked and rfsuite and rfsuite.utils and rfsuite.utils.ethosVersionAtLeast then
        _supportsTheme = rfsuite.utils.ethosVersionAtLeast(ETHOS_THEME_MIN_VERSION) == true
        _supportsThemeChecked = true
    end
    return _supportsTheme
end

local function resolveThemeConstant(name)
    if not supportsSystemThemeColors() then return nil end
    if type(lcd.themeColor) ~= "function" then return nil end
    local key = _G[name]
    if type(key) ~= "number" then return nil end
    return lcd.themeColor(key)
end

local function buildThemeSignature()
    if not supportsSystemThemeColors() then
        return isLegacyDarkMode() and 1 or 0
    end
    local themeColorFn = lcd.themeColor
    if type(themeColorFn) ~= "function" then
        return isLegacyDarkMode() and 1 or 0
    end
    local signature = 5381
    local hasAnyThemeColor = false
    for i = 1, #THEME_SIGNATURE_KEYS do
        local key = _G[THEME_SIGNATURE_KEYS[i]]
        if type(key) == "number" then
            local color = themeColorFn(key)
            if type(color) == "number" then
                signature = ((signature * 33) + (color % 2147483647)) % 2147483647
                hasAnyThemeColor = true
            end
        end
    end
    if hasAnyThemeColor then return signature end
    return isLegacyDarkMode() and 1 or 0
end

local function buildLegacyDashboardPalette(isDark)
    if isDark then
        return {
            textcolor = rgb(255, 255, 255),
            titlecolor = rgb(255, 255, 255),
            bgcolor = rgb(0, 0, 0),
            fillcolor = rgb(0, 188, 4),
            fillwarncolor = rgb(255, 165, 0),
            fillcritcolor = rgb(255, 0, 0),
            fillbgcolor = rgb(185, 185, 185),
            accentcolor = rgb(255, 255, 255),
            rssifillcolor = rgb(0, 188, 4),
            rssifillbgcolor = rgb(90, 90, 90),
            txaccentcolor = rgb(185, 185, 185),
            txfillcolor = rgb(0, 188, 4),
            txbgfillcolor = rgb(90, 90, 90),
            tbbgcolor = rgb(35, 35, 35),
            cntextcolor = rgb(255, 255, 255),
            tbtextcolor = rgb(255, 255, 255),
            rssitextcolor = rgb(255, 255, 255),
            panelbg = rgb(40, 40, 40),
            paneldarkbg = rgb(25, 25, 25),
            panelbgline = rgb(65, 65, 65)
        }
    end

    return {
        textcolor = rgb(80, 80, 80),
        titlecolor = rgb(80, 80, 80),
        bgcolor = rgb(255, 255, 255),
        fillcolor = rgb(144, 238, 144),
        fillwarncolor = rgb(255, 200, 100),
        fillcritcolor = rgb(255, 102, 102),
        fillbgcolor = rgb(211, 211, 211),
        accentcolor = rgb(90, 90, 90),
        rssifillcolor = rgb(144, 238, 144),
        rssifillbgcolor = rgb(185, 185, 185),
        txaccentcolor = rgb(255, 255, 255),
        txfillcolor = rgb(144, 238, 144),
        txbgfillcolor = rgb(185, 185, 185),
        tbbgcolor = rgb(90, 90, 90),
        cntextcolor = rgb(255, 255, 255),
        tbtextcolor = rgb(255, 255, 255),
        rssitextcolor = rgb(255, 255, 255),
        panelbg = rgb(90, 90, 90),
        paneldarkbg = rgb(185, 185, 185),
        panelbgline = rgb(80, 80, 80)
    }
end

local function getLegacyDashboardPalette(isDark)
    local key = isDark and "dark" or "light"
    local cached = dashboardThemePaletteCache[key]
    if cached then return cached end
    cached = buildLegacyDashboardPalette(isDark)
    dashboardThemePaletteCache[key] = cached
    return cached
end

local function buildLegacyThemeState(isDark)
    if isDark then
        return {
            usesThemeColors = false,
            defaultColor = rgb(255, 255, 255),
            defaultBgColor = rgb(35, 35, 35),
            primaryColor = rgb(255, 255, 255),
            primaryBgColor = rgb(0, 0, 0),
            secondaryColor = rgb(185, 185, 185),
            secondaryBgColor = rgb(40, 40, 40),
            focusColor = rgb(255, 255, 255),
            focusBgColor = rgb(40, 40, 40),
            highlightColor = rgb(0, 188, 4),
            highlightInvertColor = rgb(0, 0, 0),
            disableColor = rgb(112, 112, 112),
            safeColor = rgb(0, 188, 4),
            warningColor = rgb(255, 165, 0),
            errorColor = rgb(255, 0, 0),
            activeColor = rgb(0, 188, 4),
            inactiveColor = rgb(255, 0, 0),
            buttonBorderActiveColor = rgb(255, 255, 255),
            buttonBorderColor = rgb(90, 90, 90),
            mixerOutputColor = rgb(0, 188, 4),
            safeContrastingColor = rgb(0, 0, 0),
            pageBgColor = rgb(16, 16, 16),
            topLcdBgColor = rgb(35, 35, 35)
        }
    end

    return {
        usesThemeColors = false,
        defaultColor = rgb(90, 90, 90),
        defaultBgColor = rgb(230, 230, 230),
        primaryColor = rgb(90, 90, 90),
        primaryBgColor = rgb(255, 255, 255),
        secondaryColor = rgb(117, 117, 117),
        secondaryBgColor = rgb(211, 211, 211),
        focusColor = rgb(0, 0, 0),
        focusBgColor = rgb(230, 230, 230),
        highlightColor = rgb(144, 238, 144),
        highlightInvertColor = rgb(255, 255, 255),
        disableColor = rgb(144, 144, 144),
        safeColor = rgb(144, 238, 144),
        warningColor = rgb(255, 200, 100),
        errorColor = rgb(255, 102, 102),
        activeColor = rgb(144, 238, 144),
        inactiveColor = rgb(255, 102, 102),
        buttonBorderActiveColor = rgb(69, 78, 87),
        buttonBorderColor = rgb(160, 160, 160),
        mixerOutputColor = rgb(16, 64, 224),
        safeContrastingColor = rgb(0, 0, 0),
        pageBgColor = rgb(209, 208, 208),
        topLcdBgColor = rgb(230, 230, 230)
    }
end

local function getThemeStateInternal()
    local signature = buildThemeSignature()
    local cached = themeStateCache.state
    if cached and themeStateCache.signature == signature then return cached, signature end

    local legacyState = buildLegacyThemeState(isLegacyDarkMode())
    if supportsSystemThemeColors() then
        local state = {usesThemeColors = false}
        local hasAnyThemeColor = false

        for i = 1, #THEME_STATE_KEYS do
            local fieldName = THEME_STATE_KEYS[i][1]
            local color = resolveThemeConstant(THEME_STATE_KEYS[i][2])
            if type(color) == "number" then
                state[fieldName] = color
                hasAnyThemeColor = true
            end
        end

        if hasAnyThemeColor then
            for k, v in pairs(legacyState) do
                if state[k] == nil then state[k] = v end
            end
            state.usesThemeColors = true
            themeStateCache.signature = signature
            themeStateCache.state = state
            return state, signature
        end
    end

    themeStateCache.signature = signature
    themeStateCache.state = legacyState
    return legacyState, signature
end

local function resolveDashboardSurfaceBg(state)
    return state and (state.primaryBgColor or state.pageBgColor or state.secondaryBgColor)
end

local function resolveDashboardHeaderBg(state, surfaceBg)
    return state and (state.pageBgColor or surfaceBg)
end

local function resolveDashboardHeaderTextColor(state, headerBg)
    return state and state.primaryColor
end

local function resolveDashboardTitleColor(state)
    return state and (state.secondaryColor or state.primaryColor)
end

local function resolveDashboardPanelColors(state)
    if not state then return nil, nil, nil end
    return state.pageBgColor, state.secondaryBgColor, state.pageBgColor
end

local function resolveGaugeTrackBg(state, background)
    if not state then return background end
    if background == state.pageBgColor then return state.disableColor or state.secondaryBgColor end
    return state.secondaryBgColor or state.disableColor or background
end

local function getThemeFallbackPalette()
    local state, signature = getThemeStateInternal()

    if not state.usesThemeColors then
        local key = isLegacyDarkMode() and "dark" or "light"
        local cached = themeFallbackPaletteCache[key]
        if cached then return cached end

        local fillOrFrame = isLegacyDarkMode() and rgb(40, 40, 40) or rgb(240, 240, 240)
        cached = {
            fillcolor = fillOrFrame,
            fillbgcolor = fillOrFrame,
            framecolor = fillOrFrame,
            textcolor = rgb(255, 255, 255),
            titlecolor = rgb(255, 255, 255),
            accentcolor = rgb(255, 255, 255),
            bgcolor = fillOrFrame,
            defaultColor = fillOrFrame
        }
        themeFallbackPaletteCache[key] = cached
        return cached
    end

    local cached = themeFallbackPaletteCache.palette
    if cached and themeFallbackPaletteCache.signature == signature then return cached end

    local surfaceBg = resolveDashboardSurfaceBg(state)
    local trackBg = resolveGaugeTrackBg(state, surfaceBg)
    local fillcolor = state.safeColor or state.activeColor

    cached = {
        fillcolor = fillcolor,
        fillbgcolor = trackBg,
        framecolor = state.buttonBorderColor,
        textcolor = state.primaryColor,
        titlecolor = state.primaryColor,
        accentcolor = state.secondaryColor,
        bgcolor = surfaceBg,
        defaultColor = state.primaryColor
    }
    themeFallbackPaletteCache.signature = signature
    themeFallbackPaletteCache.palette = cached
    return cached
end

local function findClosestDashboardResolution(W, H, supportedResolutions)
    local bestRes, bestDistance
    local resolutions = supportedResolutions or DASHBOARD_SUPPORTED_RESOLUTIONS

    for _, res in ipairs(resolutions) do
        local distance = abs(W - res[1]) + abs(H - res[2])
        if bestDistance == nil or distance < bestDistance then
            bestRes = res
            bestDistance = distance
        end
    end

    return bestRes, bestDistance
end

local function getClosestDashboardWidth(W)
    local bestWidth, bestDistance

    for i = 1, #DASHBOARD_THEME_WIDTHS do
        local width = DASHBOARD_THEME_WIDTHS[i]
        local distance = abs(W - width)
        if bestDistance == nil or distance < bestDistance then
            bestWidth = width
            bestDistance = distance
        end
    end

    return bestWidth
end

function utils.matchSupportedResolution(W, H, supportedResolutions, maxDistance)
    local bestRes, bestDistance = findClosestDashboardResolution(W, H, supportedResolutions)
    local tolerance = maxDistance or DASHBOARD_RESOLUTION_TOLERANCE

    if bestRes and bestDistance ~= nil and bestDistance <= tolerance then
        return bestRes[1], bestRes[2], bestDistance
    end

    return nil
end

function utils.isFullScreen(w, h)
    local matchedW = utils.matchSupportedResolution(w, h)

    if matchedW == 800 or matchedW == 480 or matchedW == 640 then return true end
    if matchedW == 784 or matchedW == 472 or matchedW == 630 then return false end

    return nil
end

function utils.isModelPrefsReady() return rfsuite and rfsuite.session and rfsuite.session.modelPreferences end

function utils.resetBoxCache(box) if box._cache then for k in pairs(box._cache) do box._cache[k] = nil end end end

function utils.supportedResolution(W, H, supportedResolutions)
    return utils.matchSupportedResolution(W, H, supportedResolutions) ~= nil
end

function utils.getDashboardThemeOptionKey(W)
    local matchedW = getClosestDashboardWidth(W)

    if matchedW == 800 then
        return "ls_full"
    elseif matchedW == 784 then
        return "ls_std"
    elseif matchedW == 640 then
        return "ss_full"
    elseif matchedW == 630 then
        return "ss_std"
    elseif matchedW == 480 then
        return "ms_full"
    elseif matchedW == 472 then
        return "ms_std"
    end
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
    local matchedW = getClosestDashboardWidth(W)

    if matchedW == 800 or matchedW == 784 then
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

    elseif matchedW == 480 or matchedW == 472 then
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

    elseif matchedW == 640 or matchedW == 630 then
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
    local state, signature = getThemeStateInternal()

    if not state.usesThemeColors then
        return getLegacyDashboardPalette(isLegacyDarkMode())
    end

    local cached = dashboardThemePaletteCache.palette
    if cached and dashboardThemePaletteCache.signature == signature then return cached end

    local surfaceBg = resolveDashboardSurfaceBg(state)
    local gaugeTrackBg = resolveGaugeTrackBg(state, surfaceBg)
    local headerBg = resolveDashboardHeaderBg(state, surfaceBg)
    local headerText = resolveDashboardHeaderTextColor(state, headerBg) or state.primaryColor
    local headerGaugeTrackBg = resolveGaugeTrackBg(state, headerBg)
    local fillcolor, fillwarncolor, fillcritcolor = resolveGaugeThresholdPalette(state)
    local titleColor = resolveDashboardTitleColor(state)
    local panelBg, panelAltBg, panelLine = resolveDashboardPanelColors(state)

    cached = {
        textcolor = state.primaryColor,
        titlecolor = titleColor,
        bgcolor = surfaceBg,
        fillcolor = fillcolor,
        fillwarncolor = fillwarncolor,
        fillcritcolor = fillcritcolor,
        fillbgcolor = gaugeTrackBg,
        accentcolor = state.secondaryColor,
        rssifillcolor = fillcolor,
        rssifillbgcolor = headerGaugeTrackBg,
        txaccentcolor = state.buttonBorderActiveColor,
        txfillcolor = fillcolor,
        txbgfillcolor = headerGaugeTrackBg,
        tbbgcolor = headerBg,
        cntextcolor = headerText,
        tbtextcolor = headerText,
        rssitextcolor = headerText,
        panelbg = panelBg,
        paneldarkbg = panelAltBg,
        panelbgline = panelLine
    }
    dashboardThemePaletteCache.signature = signature
    dashboardThemePaletteCache.palette = cached
    return cached
end

function utils.getThemeSignature()
    return buildThemeSignature()
end

function utils.getThemeState()
    local state = getThemeStateInternal()
    return state
end

function utils.getThemeOutlineColor()
    local state = getThemeStateInternal()
    return state.primaryColor
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

-- Shared theme/param-version-checked config cache used by most object renderers.
-- builder(cfg, box) populates a fresh cfg table; the result is cached on box._cfg
-- until rfsuite.theme.version or box._param_version changes.
function utils.ensureCfg(box, builder)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version = theme_version
        cfg._param_version = param_version
        builder(cfg, box)
        box._cfg = cfg
    end
    return box._cfg
end

-- Compiles a value transform spec (number multiplier, "floor"/"ceil"/"round", or a
-- custom function) into a function(v) -> v, with optional rounding to `decimals`.
function utils.compileTransform(t, decimals)
    local pow = decimals and (10 ^ decimals) or nil
    local function round(v) return pow and (floor(v * pow + 0.5) / pow) or v end

    if type(t) == "number" then
        local mul = t
        return function(v) return round(v * mul) end
    elseif t == "floor" then
        return function(v) return floor(v) end
    elseif t == "ceil" then
        return function(v) return ceil(v) end
    elseif t == "round" or t == nil then
        return function(v) return round(v) end
    elseif type(t) == "function" then
        return t
    else
        return function(v) return v end
    end
end

-- Draws an annulus sector (arc) of the given thickness between startAngle and endAngle (degrees).
function utils.drawArc(cx, cy, radius, thickness, startAngle, endAngle, color)
    lcd.color(color)
    local outer = radius
    local inner = max(1, radius - (thickness or 6))

    startAngle = startAngle % 360
    endAngle = endAngle % 360
    if endAngle <= startAngle then endAngle = endAngle + 360 end

    local sweep = endAngle - startAngle
    if sweep <= 180 then
        lcd.drawAnnulusSector(cx, cy, inner, outer, startAngle, endAngle)
    else
        local mid = startAngle + sweep / 2
        lcd.drawAnnulusSector(cx, cy, inner, outer, startAngle, mid)
        lcd.drawAnnulusSector(cx, cy, inner, outer, mid, endAngle)
    end
end

function utils.screenError(msg, border, pct, padX, padY)

    if not pct then pct = 0.5 end
    if border == nil then border = true end
    if not padX then padX = 8 end
    if not padY then padY = 4 end

    local w, h = lcd.getWindowSize()
    local state = getThemeStateInternal()

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

    lcd.color(state.primaryColor)

    local x = (w - bestW) / 2
    local y = (h - bestH) / 2

    if border then lcd.drawRectangle(x - padX, y - padY, bestW + padX * 2, bestH + padY * 2) end

    lcd.drawText(x, y, msg)
end

function utils.resolveColor(value, variantFactor)
    if type(value) == "string" then
        local lower = value:lower()
        local factor = variantFactorOrDefault(variantFactor)
        local cacheKey = lower .. "|" .. factor
        local cached = resolveColorCache[cacheKey]
        if cached ~= nil then return cached end

        local prefix, baseName = lower:match("^(bright|light|dark)(.+)$")

        if prefix and baseName then
            local baseColor = NAMED_COLORS[baseName]
            if baseColor then
                local color = buildVariantColor(baseColor, prefix, factor)
                resolveColorCache[cacheKey] = color
                return color
            end
        else
            local c = NAMED_COLORS[lower]
            if c then
                local color = lcd.RGB(c[1], c[2], c[3], 1)
                resolveColorCache[cacheKey] = color
                return color
            end
        end

    elseif type(value) == "table" and #value >= 3 then
        local cached = resolveColorTableCache[value]
        if cached ~= nil then return cached end
        local color = lcd.RGB(value[1], value[2], value[3], 1)
        resolveColorTableCache[value] = color
        return color
    end

    return nil
end

function utils.resolveThemeColor(colorkey, value)

    if type(value) == "number" then return value end

    if type(value) == "string" and value == "transparent" then return nil end

    if type(value) == "table" then
        -- RGB array tables are still resolved to a color.
        -- Style tables are returned unchanged so a caller can pass a
        -- background style table through c.bgcolor into utils.box()
        -- without patching every individual widget renderer.
        if #value >= 3 then
            local resolved = utils.resolveColor(value)
            if resolved then return resolved end
        end
        return value
    end

    if type(value) == "string" then
        local resolved = utils.resolveColor(value)
        if resolved then return resolved end
    end

    local palette = getThemeFallbackPalette()
    return palette[colorkey] or palette.defaultColor
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

function utils.resolveFont(font, fallback)
    if type(font) == "number" then return font end
    if type(font) == "string" then return FONT_BY_NAME[font] or fallback end
    return fallback
end


local function drawRoundedFilledRectSafe(x, y, w, h, radius, color)
    if not color or w <= 0 or h <= 0 then return end

    radius = tonumber(radius) or 0
    if radius < 1 then
        lcd.color(color)
        lcd.drawFilledRectangle(x, y, w, h)
        return
    end

    local maxRadius = math.floor(math.min(w, h) / 2)
    if radius > maxRadius then radius = maxRadius end

    lcd.color(color)
    -- Center/edge fills create a rounded rectangle using primitives already
    -- used elsewhere in this dashboard renderer.
    lcd.drawFilledRectangle(x + radius, y, w - radius * 2, h)
    lcd.drawFilledRectangle(x, y + radius, w, h - radius * 2)
    lcd.drawFilledCircle(x + radius, y + radius, radius)
    lcd.drawFilledCircle(x + w - radius - 1, y + radius, radius)
    lcd.drawFilledCircle(x + radius, y + h - radius - 1, radius)
    lcd.drawFilledCircle(x + w - radius - 1, y + h - radius - 1, radius)
end

local function drawStyledBoxBackground(x, y, w, h, bgcolor)
    if type(bgcolor) ~= "table" then
        if bgcolor then
            lcd.color(bgcolor)
            lcd.drawFilledRectangle(x, y, w, h)
        end
        return x, y, w, h
    end

    local backfillcolor = bgcolor.backfillcolor or bgcolor.cellbgcolor or bgcolor.outercolor
    if backfillcolor then
        lcd.color(backfillcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    local inset = tonumber(bgcolor.inset or bgcolor.margin) or 0
    local insetleft = tonumber(bgcolor.insetleft or bgcolor.inset_left) or inset
    local insetright = tonumber(bgcolor.insetright or bgcolor.inset_right) or inset
    local insettop = tonumber(bgcolor.insettop or bgcolor.inset_top) or inset
    local insetbottom = tonumber(bgcolor.insetbottom or bgcolor.inset_bottom) or inset
    local borderwidth = tonumber(bgcolor.borderwidth) or 0
    local radius = tonumber(bgcolor.roundradius or bgcolor.radius) or 0
    local fillcolor = bgcolor.bgcolor or bgcolor.fillcolor or bgcolor.fill or bgcolor.color
    local bordercolor = bgcolor.bordercolor

    local bx = x + insetleft
    local by = y + insettop
    local bw = w - insetleft - insetright
    local bh = h - insettop - insetbottom

    if bw <= 0 or bh <= 0 then return x, y, w, h end

    if borderwidth > 0 and bordercolor then
        drawRoundedFilledRectSafe(bx, by, bw, bh, radius, bordercolor)
        local ix = bx + borderwidth
        local iy = by + borderwidth
        local iw = bw - borderwidth * 2
        local ih = bh - borderwidth * 2
        if iw > 0 and ih > 0 then
            drawRoundedFilledRectSafe(ix, iy, iw, ih, math.max(0, radius - borderwidth), fillcolor)
        end
    else
        drawRoundedFilledRectSafe(bx, by, bw, bh, radius, fillcolor)
    end

    local contentPad = tonumber(bgcolor.contentpadding) or 0
    local innerLeft = insetleft + borderwidth + contentPad
    local innerRight = insetright + borderwidth + contentPad
    local innerTop = insettop + borderwidth + contentPad
    local innerBottom = insetbottom + borderwidth + contentPad
    return x + innerLeft, y + innerTop, w - innerLeft - innerRight, h - innerTop - innerBottom
end

function utils.drawBoxBackground(x, y, w, h, bgcolor)
    return drawStyledBoxBackground(x, y, w, h, bgcolor)
end

function utils.setScreenBorderStyle(style)
    utils._screenBorderStyle = style
end

local function drawDashboardScreenBorderSafe()
    local style = utils._screenBorderStyle
    if type(style) ~= "table" or not style.enabled then return end

    local bordercolor = style.bordercolor or style.color
    if not bordercolor then return end

    local borderwidth = tonumber(style.borderwidth or style.width) or 0
    if borderwidth < 1 then return end

    local inset = tonumber(style.inset) or 0
    local w, h = lcd.getWindowSize()
    if w <= 0 or h <= 0 then return end

    local x1 = inset
    local y1 = inset
    local x2 = w - inset - borderwidth
    local y2 = h - inset - borderwidth
    local fullW = w - inset * 2
    local fullH = h - inset * 2

    if fullW <= 0 or fullH <= 0 then return end

    lcd.color(bordercolor)
    -- Draw only the border strips so content is not erased.
    lcd.drawFilledRectangle(x1, y1, fullW, borderwidth)
    lcd.drawFilledRectangle(x1, y2, fullW, borderwidth)
    lcd.drawFilledRectangle(x1, y1, borderwidth, fullH)
    lcd.drawFilledRectangle(x2, y1, borderwidth, fullH)
end

-- Redraw the screen border on top of already-painted boxes so panel
-- backgrounds that extend to the screen edge cannot erase it.
function utils.drawScreenBorder()
    drawDashboardScreenBorderSafe()
end

function utils.box(x, y, w, h, title, titlepos, titlealign, titlefont, titlespacing, titlecolor, titlepadding, titlepaddingleft, titlepaddingright, titlepaddingtop, titlepaddingbottom, displayValue, unit, font, valuealign, textcolor, valuepadding, valuepaddingleft, valuepaddingright, valuepaddingtop, valuepaddingbottom, bgcolor, image, imagewidth, imageheight, imagealign)

    if type(title) ~= "string" and type(title) ~= "number" then
        title = nil
    end

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

    x, y, w, h = drawStyledBoxBackground(x, y, w, h, bgcolor)

    if not fontCache then fontCache = utils.getFontListsForResolution() end

    local actualTitleFont, tsizeW, tsizeH = nil, 0, 0
    if title then
        local minValueFontH = 9999
        for _, vf in ipairs(fontCache.value_default or {FONT_STD}) do
            lcd.font(vf)
            local _, vh = lcd.getTextSize("8")
            if vh < minValueFontH then minValueFontH = vh end
        end
        local resolvedTitleFont = utils.resolveFont(titlefont, nil)
        if resolvedTitleFont then
            actualTitleFont = resolvedTitleFont
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
            local fallbackLogo = getLogoFallbackForBackground(bgcolor)
            local cacheKey = image .. "|" .. fallbackLogo
            bitmapPtr = imageCache[cacheKey]
            if bitmapPtr == false then bitmapPtr = nil end
            if not bitmapPtr then
                bitmapPtr = rfsuite.utils.loadImage(image, nil, fallbackLogo)
                imageCache[cacheKey] = bitmapPtr or false
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
        value_str_calc = string.gsub(value_str_calc, "[°]", ".")

        local valueFont, bestW, bestH = FONT_XXS, 0, 0
        local resolvedValueFont = utils.resolveFont(font, nil)
        if resolvedValueFont then
            valueFont = resolvedValueFont
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
        local fmt = _fmtCache[decimals]
        if not fmt then
            fmt = "%." .. decimals .. "f"
            _fmtCache[decimals] = fmt
        end
        value = format(fmt, value)
    elseif value ~= nil then
        value = tostring(value)
    end
    return value
end

function utils.setBackgroundColourBasedOnTheme()
    local w, h = lcd.getWindowSize()
    local bgColor = getThemeStateInternal().pageBgColor
    local style = utils._screenBorderStyle
    if type(style) == "table" and style.backgroundcolor then
        bgColor = style.backgroundcolor
    end
    lcd.color(bgColor)
    lcd.drawFilledRectangle(0, 0, w, h)
    drawDashboardScreenBorderSafe()
end

function utils.getParam(box, key, ...)
    local v = box[key]
    if type(v) == "function" and not SKIP_CALL_KEYS[key] then
        return v(box, key, ...)
    else
        return v
    end
end

function utils.getPulsingDots(box, counterKey, maxDots)
    if type(box) ~= "table" then return "." end

    local key = counterKey or "_dotCount"
    local maxCount = tonumber(maxDots) or 3
    if maxCount < 1 then maxCount = 1 end

    local count = (tonumber(box[key]) or 0) + 1
    if count > maxCount then count = 0 end
    box[key] = count

    if count == 0 then return "." end
    return _DOTS[count] or rep(".", count)
end

local function extractCapacityValue(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v:match("(%d+)")) end
    if type(v) == "table" then
        if type(v.capacity) == "number" then return v.capacity end
        if type(v.capacity) == "string" then return tonumber(v.capacity:match("(%d+)")) end
        if type(v.name) == "string" then return tonumber(v.name:match("(%d+)")) end
    end
    return nil
end

local function extractProfileCapacity(profiles, idx)
    if type(profiles) ~= "table" then return nil end
    local v = profiles[idx]
    if v == nil then v = profiles[idx + 1] end
    return extractCapacityValue(v)
end

local function refreshBatteryConfigCache()
    local session = rfsuite and rfsuite.session
    local bc = session and session.batteryConfig

    if not bc then
        batteryConfigCache.config = nil
        batteryConfigCache.profiles = nil
        batteryConfigCache.batteryCellCount = 0
        batteryConfigCache.batteryCapacity = 0
        batteryConfigCache.vbatmincellvoltage = 0
        batteryConfigCache.vbatfullcellvoltage = 0
        batteryConfigCache.profileSig = 0
        batteryConfigCache.profileCapacityCount = 0
        batteryConfigCache.hasAnyBatteryCapacity = false
        return nil
    end

    local profiles = bc.profiles
    local batteryCellCount = tonumber(bc.batteryCellCount) or 0
    local batteryCapacity = tonumber(bc.batteryCapacity) or 0
    local vbatmincellvoltage = tonumber(bc.vbatmincellvoltage) or 0
    local vbatfullcellvoltage = tonumber(bc.vbatfullcellvoltage) or 0
    local profileSig = 0
    local profileCapacityCount = 0

    for i = 0, MAX_BATTERY_PROFILES - 1 do
        local cap = extractProfileCapacity(profiles, i)
        local qCap = floor((cap or -1) + 0.5)
        profileSig = profileSig * PROFILE_HASH_BASE + (qCap + 1)
        if cap and cap > 0 then profileCapacityCount = profileCapacityCount + 1 end
    end

    if batteryConfigCache.config == bc and
        batteryConfigCache.profiles == profiles and
        batteryConfigCache.batteryCellCount == batteryCellCount and
        batteryConfigCache.batteryCapacity == batteryCapacity and
        batteryConfigCache.vbatmincellvoltage == vbatmincellvoltage and
        batteryConfigCache.vbatfullcellvoltage == vbatfullcellvoltage and
        batteryConfigCache.profileSig == profileSig then
        return batteryConfigCache
    end

    batteryConfigCache.config = bc
    batteryConfigCache.profiles = profiles
    batteryConfigCache.batteryCellCount = batteryCellCount
    batteryConfigCache.batteryCapacity = batteryCapacity
    batteryConfigCache.vbatmincellvoltage = vbatmincellvoltage
    batteryConfigCache.vbatfullcellvoltage = vbatfullcellvoltage
    batteryConfigCache.profileSig = profileSig
    batteryConfigCache.profileCapacityCount = profileCapacityCount
    batteryConfigCache.hasAnyBatteryCapacity = (batteryCapacity > 0) or (profileCapacityCount > 0)

    return batteryConfigCache
end

function utils.getBatteryCellCount(defaultCellCount)
    local bcCache = refreshBatteryConfigCache()
    local fallback = defaultCellCount or 3
    if not bcCache then return fallback end
    if bcCache.batteryCellCount > 0 then return bcCache.batteryCellCount end
    return fallback
end

function utils.getBatteryVoltageBounds(defaultCellCount, defaultMinCellVoltage, defaultFullCellVoltage)
    local bcCache = refreshBatteryConfigCache()
    local cells = defaultCellCount or 3
    local minCellV = defaultMinCellVoltage or 3.0
    local fullCellV = defaultFullCellVoltage or 4.2

    if bcCache then
        if bcCache.batteryCellCount > 0 then cells = bcCache.batteryCellCount end
        if bcCache.vbatmincellvoltage > 0 then minCellV = bcCache.vbatmincellvoltage end
        if bcCache.vbatfullcellvoltage > 0 then fullCellV = bcCache.vbatfullcellvoltage end
    end

    return cells, minCellV, fullCellV
end

function utils.hasMultipleBatteryProfiles()
    local bcCache = refreshBatteryConfigCache()
    return bcCache ~= nil and (bcCache.profileCapacityCount or 0) > 1
end

function utils.maxVoltageToCellVoltage(value, defaultCellCount)
    if value == nil then return value end
    local cells = utils.getBatteryCellCount(defaultCellCount or 3)
    value = max(0, value / cells)
    return floor(value * 100 + 0.5) / 100
end

function utils.isElectricEngine()
    local batteryPrefs = rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery
    local modelType = batteryPrefs and tonumber(batteryPrefs.smartfuel_model_type) or 0

    if modelType == 0 then
        local bcCache = refreshBatteryConfigCache()
        if not bcCache then return false end
        local cellCount = bcCache.batteryCellCount
        if cellCount ~= 0 then return true end
        return bcCache.hasAnyBatteryCapacity
    end

    return modelType == 1
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

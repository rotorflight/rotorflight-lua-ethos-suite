--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html

  Dashboard-to-configurator theme bridge.
  Theme metadata is loaded only when the selected dashboard theme changes.
  The paint path performs no file I/O and leaves native ETHOS edit controls intact.
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local osClock = os.clock
local type = type
local tostring = tostring
local pcall = pcall
local floor = math.floor

local M = {}
local paletteCache = {}
local activePath
local activePhase
local activePalette
local nextCheck = 0
local navRects = {}
local titleFields = {}
local railCache

local FALLBACK_DARK = {
    name = "ETHOS Dark",
    background = {20, 22, 26}, surface = {38, 41, 47}, surfaceAlt = {49, 53, 61},
    text = {238, 241, 245}, muted = {155, 162, 172}, accent = {61, 174, 255},
    focus = {83, 213, 133}, warning = {255, 181, 64}, error = {255, 86, 103}, border = {80, 88, 101}
}
local FALLBACK_LIGHT = {
    name = "ETHOS Light",
    background = {242, 244, 247}, surface = {255, 255, 255}, surfaceAlt = {229, 233, 239},
    text = {26, 31, 38}, muted = {92, 101, 113}, accent = {0, 112, 210},
    focus = {0, 145, 72}, warning = {190, 112, 0}, error = {205, 38, 58}, border = {158, 166, 177}
}

local function prefEnabled()
    local general = rfsuite.preferences and rfsuite.preferences.general
    local value = general and general.follow_dashboard_theme
    return not (value == false or value == "false" or value == 0 or value == "0")
end

local function rgb(value, fallback)
    if type(value) == "number" then return value end
    if type(value) == "table" then
        local r = tonumber(value.r or value[1])
        local g = tonumber(value.g or value[2])
        local b = tonumber(value.b or value[3])
        local a = tonumber(value.a or value[4]) or 1
        if r and g and b then return lcd.RGB(r, g, b, a) end
    end
    return fallback
end

local function rgbComponents(value, fallback)
    if type(value) == "table" then
        local r = tonumber(value.r or value[1])
        local g = tonumber(value.g or value[2])
        local b = tonumber(value.b or value[3])
        if r and g and b then return {r, g, b} end
    end
    if type(fallback) == "table" then
        return {tonumber(fallback[1]) or 0, tonumber(fallback[2]) or 0, tonumber(fallback[3]) or 0}
    end
    return {0, 0, 0}
end

local function blendColor(background, foreground, amount)
    amount = math.max(0, math.min(1, tonumber(amount) or 0))
    local inverse = 1 - amount
    local r = floor((background[1] * inverse) + (foreground[1] * amount) + 0.5)
    local g = floor((background[2] * inverse) + (foreground[2] * amount) + 0.5)
    local b = floor((background[3] * inverse) + (foreground[3] * amount) + 0.5)
    return lcd.RGB(r, g, b)
end

local function nativeColor(constName, fallback)
    local key = _G[constName]
    if key ~= nil and type(lcd.themeColor) == "function" then
        local ok, value = pcall(lcd.themeColor, key)
        if ok and type(value) == "number" then return value end
    end
    return fallback
end

local function isDarkMode()
    if type(lcd.darkMode) == "function" then
        local ok, value = pcall(lcd.darkMode)
        if ok then return value == true end
    end
    return true
end

local function nativePalette()
    local source = isDarkMode() and FALLBACK_DARK or FALLBACK_LIGHT
    local palette = {}
    for key, value in pairs(source) do palette[key] = value end
    palette.background = nativeColor("THEME_PAGE_BGCOLOR", rgb(source.background))
    palette.surface = nativeColor("THEME_PRIMARY_BGCOLOR", rgb(source.surface))
    palette.surfaceAlt = nativeColor("THEME_SECONDARY_BGCOLOR", rgb(source.surfaceAlt))
    palette.text = nativeColor("THEME_DEFAULT_COLOR", rgb(source.text))
    palette.muted = nativeColor("THEME_DISABLE_COLOR", rgb(source.muted))
    palette.accent = nativeColor("THEME_PRIMARY_COLOR", rgb(source.accent))
    palette.focus = nativeColor("THEME_FOCUS_COLOR", rgb(source.focus))
    palette.warning = nativeColor("THEME_WARNING_COLOR", rgb(source.warning))
    palette.error = nativeColor("THEME_ERROR_COLOR", rgb(source.error))
    palette.border = nativeColor("THEME_BUTTON_BORDER_COLOR", rgb(source.border))
    palette._backgroundRGB = rgbComponents(source.background)
    palette._accentRGB = rgbComponents(source.accent)
    palette.path = "ethos/native"
    return palette
end

local function normalizeThemePath(value)
    if type(value) ~= "string" or value == "" or value == "nil" then return "system/default" end
    if value:find("/", 1, true) then return value end
    return "system/" .. value
end

local function currentPhase()
    local phase = rfsuite.flightmode and rfsuite.flightmode.current
    if phase ~= "preflight" and phase ~= "inflight" and phase ~= "postflight" then phase = "preflight" end
    return phase
end

local function selectedThemePath(phase)
    local preview = rfsuite.session and rfsuite.session.dashboardThemePreview
    if type(preview) == "string" and preview ~= "" and preview ~= "nil" then
        return normalizeThemePath(preview)
    end

    local modelDashboard = rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.dashboard
    local globalDashboard = rfsuite.preferences and rfsuite.preferences.dashboard or {}
    local value = modelDashboard and modelDashboard["theme_" .. phase]
    if value == "nil" then value = nil end
    return normalizeThemePath(value or globalDashboard["theme_" .. phase] or "system/default")
end

local function mergeTheme(base, overlay)
    if type(overlay) ~= "table" then return base end
    for key, value in pairs(overlay) do
        if key ~= "preflight" and key ~= "inflight" and key ~= "postflight" then base[key] = value end
    end
    return base
end

local function compilePalette(path, phase)
    local cachedByPhase = paletteCache[path]
    if cachedByPhase and cachedByPhase[phase] then return cachedByPhase[phase] end

    local source, folder = path:match("([^/]+)/(.+)")
    local initPath
    if source == "user" then
        initPath = "SCRIPTS:/" .. rfsuite.config.preferences .. "/dashboard/" .. folder .. "/init.lua"
    else
        initPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/themes/" .. folder .. "/init.lua"
    end

    local raw
    local chunk = loadfile(initPath)
    if chunk then
        local ok, init = pcall(chunk)
        if ok and type(init) == "table" then
            raw = {}
            mergeTheme(raw, init.appTheme)
            if type(init.appTheme) == "table" then mergeTheme(raw, init.appTheme[phase]) end
            raw.name = raw.name or init.name or folder
        end
    end

    local native = nativePalette()
    local rail = raw and raw.rail
    local palette = {
        path = path,
        phase = phase,
        name = raw and raw.name or native.name,
        background = rgb(raw and raw.background, native.background),
        surface = rgb(raw and raw.surface, native.surface),
        surfaceAlt = rgb(raw and raw.surfaceAlt, native.surfaceAlt),
        text = rgb(raw and raw.text, native.text),
        muted = rgb(raw and raw.muted, native.muted),
        accent = rgb(raw and raw.accent, native.accent),
        focus = rgb(raw and raw.focus, native.focus),
        warning = rgb(raw and raw.warning, native.warning),
        error = rgb(raw and raw.error, native.error),
        border = rgb(raw and raw.border, native.border),
        _backgroundRGB = rgbComponents(raw and raw.background, native._backgroundRGB),
        _accentRGB = rgbComponents(raw and raw.accent, native._accentRGB)
    }

    -- Optional multicolor rail. Themes that omit this keep the original
    -- single-accent rail with its soft fade into the page background.
    if type(rail) == "table" then
        local start = rail.start or rail[1]
        local middle = rail.middle or rail.mid or rail[2]
        local finish = rail.finish or rail[3]
        if start and middle and finish then
            palette._railStartRGB = rgbComponents(start, palette._accentRGB)
            palette._railMiddleRGB = rgbComponents(middle, palette._accentRGB)
            palette._railFinishRGB = rgbComponents(finish, palette._accentRGB)
        end
    end

    cachedByPhase = cachedByPhase or {}
    paletteCache[path] = cachedByPhase
    cachedByPhase[phase] = palette
    return palette
end

local function applyTitles()
    local palette = activePalette
    if not palette then return end
    for i = #titleFields, 1, -1 do
        local field = titleFields[i]
        if field and field.color then
            pcall(field.color, field, palette.accent)
        else
            table.remove(titleFields, i)
        end
    end
end

function M.refresh(force)
    local phase = currentPhase()
    local path = selectedThemePath(phase)
    if not force and path == activePath and phase == activePhase and activePalette then return false end

    activePath = path
    activePhase = phase
    activePalette = prefEnabled() and compilePalette(path, phase) or nativePalette()
    railCache = nil
    applyTitles()
    if lcd.invalidate then lcd.invalidate() end
    return true
end

-- Mark the cached palette stale without recompiling it inline. compilePalette()
-- does file I/O to load a theme's init.lua, which is too heavy to run in the
-- same tick as a caller's own expensive work (e.g. a full menu rebuild) -
-- doing both back-to-back can trip Ethos's per-tick instruction budget. The
-- next M.wakeup() picks up the change and recompiles on its own tick instead.
function M.invalidate()
    activePath = nil
    activePhase = nil
    nextCheck = 0
end

function M.wakeup()
    local now = osClock()
    if now < nextCheck then return end
    nextCheck = now + 0.50
    if rfsuite.session and rfsuite.session.mspBusy then return end
    M.refresh(false)
end

function M.getPalette()
    return activePalette or nativePalette()
end

function M.styleStaticText(field, role)
    if not prefEnabled() or not field or not field.color then return field end
    local palette = M.getPalette()
    local color = palette[role or "text"] or palette.text
    pcall(field.color, field, color)
    if role == "accent" then titleFields[#titleFields + 1] = field end
    return field
end

function M.clearPage()
    for i = #navRects, 1, -1 do navRects[i] = nil end
    for i = #titleFields, 1, -1 do titleFields[i] = nil end
end

function M.registerNavigationRect(rect, kind)
    if type(rect) ~= "table" then return end
    navRects[#navRects + 1] = {
        x = floor(tonumber(rect.x) or 0), y = floor(tonumber(rect.y) or 0),
        w = floor(tonumber(rect.w) or 0), h = floor(tonumber(rect.h) or 0), kind = kind or "nav"
    }
end

local function appendThreeColorGradient(target, x, y, w, h, startRGB, middleRGB, finishRGB)
    if w <= 0 or h <= 0 then return end
    local steps = math.min(64, math.max(12, w))

    for step = 1, steps do
        local x0 = floor(((step - 1) * w) / steps)
        local x1 = floor((step * w) / steps)
        local segmentSize = math.max(1, x1 - x0)
        local t = (step - 1) / math.max(1, steps - 1)
        local color
        if t <= 0.5 then
            color = blendColor(startRGB, middleRGB, t * 2)
        else
            color = blendColor(middleRGB, finishRGB, (t - 0.5) * 2)
        end

        target[#target + 1] = {x = x + x0, y = y, w = segmentSize, h = h, color = color}
    end
end

function M.paint()
    if not prefEnabled() then return end
    local palette = activePalette
    if not palette then return end
    local app = rfsuite.app
    if not app or not app.radio then return end

    local windowWidth, windowHeight = lcd.getWindowSize()
    -- Use the full canvas captured when the app opened. Some deep/scrollable
    -- forms report a smaller current window, which previously shortened the
    -- rail or moved its fade compared with the first menu page.
    local width = tonumber(app.lcdWidth) or tonumber(windowWidth) or 0
    local height = tonumber(app.lcdHeight) or tonumber(windowHeight) or 0
    if width <= 0 then width = tonumber(windowWidth) or 0 end
    if height <= 0 then height = tonumber(windowHeight) or 0 end
    if width <= 0 or height <= 0 then return end

    local headerY = tonumber(app.radio.linePaddingTop) or 0
    local headerH = tonumber(app.radio.navbuttonHeight) or 36
    local underlineY = math.min(height - 2, headerY + headerH + 7)

    -- Cache geometry and blended colors until dimensions or palette change.
    -- The paint loop then performs only draw calls and no table/function/color
    -- allocation, which is important on lower-memory ETHOS radios.
    local cache = railCache
    if not cache or cache.width ~= width or cache.height ~= height or cache.underlineY ~= underlineY or cache.palette ~= palette then
        local dividerH = 2
        local dividerW = 2
        local fadeSteps = 18
        local horizontalFade = math.min(96, math.max(48, math.floor(width / 8)))
        local verticalFade = math.min(84, math.max(42, math.floor(height / 8)))
        local accentRGB = palette._accentRGB or {0, 240, 255}
        local backgroundRGB = palette._backgroundRGB or {0, 0, 0}
        local horizontal = {}
        local vertical = {}

        if palette._railStartRGB and palette._railMiddleRGB and palette._railFinishRGB then
            appendThreeColorGradient(
                horizontal, 0, underlineY, width, dividerH,
                palette._railStartRGB, palette._railMiddleRGB, palette._railFinishRGB
            )
            appendThreeColorGradient(
                vertical, 0, underlineY, math.max(0, height - underlineY), dividerW,
                palette._railStartRGB, palette._railMiddleRGB, palette._railFinishRGB
            )
            -- Vertical segments are generated horizontally by the helper;
            -- rotate their geometry into a top-to-bottom rail.
            for i = 1, #vertical do
                local item = vertical[i]
                item.x, item.y, item.w, item.h = 0, underlineY + (item.x or 0), dividerW, item.w
            end
        else
            local fadeLength = math.min(horizontalFade, math.max(0, width - dividerW))
            local segment = math.max(1, math.floor(fadeLength / fadeSteps))
            local actualFade = math.min(width, segment * fadeSteps)
            local bodyW = math.max(0, width - actualFade)
            if bodyW > 0 then
                horizontal[#horizontal + 1] = {x = 0, y = underlineY, w = bodyW, h = dividerH, color = palette.accent}
            end
            for step = 1, fadeSteps do
                local t = (step - 1) / math.max(1, fadeSteps - 1)
                local smooth = t * t * (3 - (2 * t))
                local amount = 1 - smooth
                local x = bodyW + ((step - 1) * segment)
                if x < width and amount > 0.035 then
                    horizontal[#horizontal + 1] = {
                        x = x, y = underlineY, w = math.min(segment, width - x), h = dividerH,
                        color = blendColor(backgroundRGB, accentRGB, amount)
                    }
                end
            end

            local verticalTop = underlineY
            local verticalHeight = math.max(0, height - verticalTop)
            if verticalHeight > 0 then
                fadeLength = math.min(verticalFade, verticalHeight)
                segment = math.max(1, math.floor(fadeLength / fadeSteps))
                actualFade = math.min(verticalHeight, segment * fadeSteps)
                local bodyH = math.max(0, verticalHeight - actualFade)
                if bodyH > 0 then
                    vertical[#vertical + 1] = {x = 0, y = verticalTop, w = dividerW, h = bodyH, color = palette.accent}
                end
                for step = 1, fadeSteps do
                    local t = (step - 1) / math.max(1, fadeSteps - 1)
                    local smooth = t * t * (3 - (2 * t))
                    local amount = 1 - smooth
                    local y = verticalTop + bodyH + ((step - 1) * segment)
                    if y < height and amount > 0.035 then
                        vertical[#vertical + 1] = {
                            x = 0, y = y, w = dividerW, h = math.min(segment, height - y),
                            color = blendColor(backgroundRGB, accentRGB, amount)
                        }
                    end
                end
            end
        end

        cache = {
            width = width, height = height, underlineY = underlineY, palette = palette,
            horizontal = horizontal, vertical = vertical
        }
        railCache = cache
    end

    for i = 1, #cache.horizontal do
        local segment = cache.horizontal[i]
        lcd.color(segment.color)
        lcd.drawFilledRectangle(segment.x, segment.y, segment.w, segment.h)
    end
    for i = 1, #cache.vertical do
        local segment = cache.vertical[i]
        lcd.color(segment.color)
        lcd.drawFilledRectangle(segment.x, segment.y, segment.w, segment.h)
    end

    for i = 1, #navRects do
        local rect = navRects[i]
        if rect.w > 4 and rect.h > 4 then
            lcd.color(palette.border)
            lcd.drawRectangle(rect.x, rect.y, rect.w, rect.h, 1)
            lcd.color(palette.accent)
            lcd.drawFilledRectangle(rect.x + 2, rect.y + rect.h - 3, math.max(1, rect.w - 4), 2)
        end
    end
end

function M.clearCache()
    if rfsuite.session then rfsuite.session.dashboardThemePreview = nil end
    paletteCache = {}
    activePath = nil
    activePhase = nil
    activePalette = nil
    railCache = nil
    M.clearPage()
end

return M

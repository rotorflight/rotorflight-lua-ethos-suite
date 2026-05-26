--[[
  Debug log panel helper for dashboard
]] --

local rfsuite = require("rfsuite")

local collectgarbage = collectgarbage
local floor = math.floor
local format = string.format
local max = math.max
local min = math.min
local system = system
local tostring = tostring
local type = type

local M = {}

local LOG_LEVELS = {info = true, error = true}
local LOG_OPTS = {levels = LOG_LEVELS, noLevel = false}
local TITLE_INFO = "System Log"
local TITLE_DEBUG = "System Log"
local TITLE_OFF = "Logging Off"
local EMPTY_INFO_TEXT = "No info log entries"
local EMPTY_DEBUG_TEXT = "No debug log entries"

local function clearArray(t)
    if not t then return end
    for i = #t, 1, -1 do t[i] = nil end
end

local function resolveThemeColor(lcd, themeColorKey, fallback)
    if type(themeColorKey) == "number"
        and rfsuite
        and rfsuite.utils
        and rfsuite.utils.ethosVersionAtLeast
        and rfsuite.utils.ethosVersionAtLeast({26, 1, 0})
        and type(lcd.themeColor) == "function" then
        return lcd.themeColor(themeColorKey)
    end
    return fallback
end

local function ellipsizeRight(lcd, text, maxW)
    text = tostring(text or "")
    if lcd.getTextSize(text) <= maxW then return text end
    local ell = "..."
    local ellW = lcd.getTextSize(ell)
    if ellW >= maxW then return ell end
    local s = text
    while #s > 1 do
        s = s:sub(1, #s - 1)
        if lcd.getTextSize(s) + ellW <= maxW then return s .. ell end
    end
    return ell
end

local function getBounds(dashboard, lcd)
    local W, H = lcd.getWindowSize()
    local bounds = dashboard and dashboard._layoutBounds
    local x = 0
    local y = 0
    local w = W
    local baseH = H
    if bounds and bounds.w and bounds.h then
        x = bounds.x or 0
        y = bounds.y or 0
        w = bounds.w or W
        baseH = bounds.h or H
    end
    local panelH = floor((baseH * 0.70) + 0.5)
    if panelH > baseH then panelH = baseH end
    if w < 1 or panelH < 1 then return end
    return x, y, w, panelH
end

local function getCache(dashboard)
    dashboard._debugLogPanelCache = dashboard._debugLogPanelCache or {}
    return dashboard._debugLogPanelCache
end

local function getLogLevel()
    local prefs = rfsuite.preferences
    local dev = prefs and prefs.developer
    local level = dev and dev.loglevel or "off"
    if level ~= "debug" and level ~= "info" then return "off" end
    return level
end

local function updateLogOpts(level)
    LOG_LEVELS.debug = (level == "debug") or nil
    LOG_LEVELS.info = (level == "info" or level == "debug") or nil
    LOG_LEVELS.error = (level ~= "off") or nil
end

local function getTitle(level)
    if level == "debug" then return TITLE_DEBUG end
    if level == "info" then return TITLE_INFO end
    return TITLE_OFF
end

local function roundInt(v)
    return floor((v or 0) + 0.5)
end

local function refreshHeader(cache)
    local perf = rfsuite.performance or {}
    local cpu = roundInt(perf.cpuload or 0)
    local used = roundInt(perf.usedram or 0)
    local free = roundInt(perf.luaRamKB or perf.freeram or 0)

    if (free == 0 or used == 0) and system and system.getMemoryUsage then
        local mem = system.getMemoryUsage()
        if type(mem) == "table" then
            if free == 0 then free = roundInt((mem.luaRamAvailable or 0) / 1024) end
            if used == 0 and collectgarbage then used = roundInt(collectgarbage("count") or 0) end
        end
    end

    if cache.headerCpu == cpu and cache.headerUsed == used and cache.headerFree == free then
        return cache.headerText
    end

    cache.headerCpu = cpu
    cache.headerUsed = used
    cache.headerFree = free
    cache.headerText = format("CPU %d%%  RAM %dk  Lua %dk", cpu, used, free)
    return cache.headerText
end

local function refreshLines(dashboard, lcd, maxLines, textW)
    local cache = getCache(dashboard)
    local logger = rfsuite.tasks and rfsuite.tasks.logger or nil
    local seq = logger and logger.getSessionSeq and logger.getSessionSeq() or 0
    local level = getLogLevel()
    local source = cache.sourceLines
    if not source then
        source = {}
        cache.sourceLines = source
    end
    local display = cache.displayLines
    if not display then
        display = {}
        cache.displayLines = display
    end

    if cache.seq == seq and cache.maxLines == maxLines and cache.textW == textW and cache.level == level then
        return display
    end

    cache.seq = seq
    cache.maxLines = maxLines
    cache.textW = textW
    cache.level = level
    clearArray(source)
    clearArray(display)

    if level ~= "off" and logger and logger.getSessionLines then
        updateLogOpts(level)
        logger.getSessionLines(maxLines, LOG_OPTS, source)
    end

    if #source == 0 then
        if level == "off" then
            display[1] = "Logging is disabled in developer preferences"
        elseif level == "debug" then
            display[1] = EMPTY_DEBUG_TEXT
        else
            display[1] = EMPTY_INFO_TEXT
        end
        return display
    end

    for i = 1, #source do
        display[i] = ellipsizeRight(lcd, source[i], textW)
    end
    return display
end

function M.clearCaches(dashboard)
    if not dashboard then return end
    local cache = dashboard._debugLogPanelCache
    if cache then
        clearArray(cache.sourceLines)
        clearArray(cache.displayLines)
    end
    dashboard._debugLogPanelCache = nil
    dashboard._debugLogPanelRects = nil
end

function M.draw(dashboard, lcd, FONT_S, FONT_XS, FONT_XXS, CENTERED, THEME_DEFAULT_COLOR, THEME_DEFAULT_BGCOLOR)
    if not (dashboard and dashboard.debugLogPanelVisible) then return end

    local x, y, w, h = getBounds(dashboard, lcd)
    if not x then return end

    local themeState = dashboard.utils and dashboard.utils.getThemeState and dashboard.utils.getThemeState() or nil
    local isLegacyDark = type(lcd.darkMode) == "function" and lcd.darkMode() == true
    local themeDefault = resolveThemeColor(lcd, THEME_DEFAULT_COLOR, (themeState and themeState.primaryColor) or lcd.RGB(40, 40, 40))
    local themeDefaultBg = resolveThemeColor(lcd, THEME_DEFAULT_BGCOLOR, (themeState and themeState.primaryBgColor) or lcd.RGB(245, 245, 245))
    local useThemeColors = themeState and themeState.usesThemeColors
    local bg = (useThemeColors and themeState.pageBgColor) or themeDefaultBg
    local fg = (useThemeColors and themeState.primaryColor) or (isLegacyDark and lcd.RGB(255, 255, 255, 1.0) or themeDefault)
    local line = (useThemeColors and (themeState.buttonBorderColor or themeState.secondaryColor or fg)) or fg

    lcd.color(bg)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(line)
    lcd.drawFilledRectangle(x, y + h - 4, w, 4)

    local cache = getCache(dashboard)
    local level = getLogLevel()
    local pad = max(8, floor(w * 0.02))
    local headerH = max(24, floor(h * 0.16))

    lcd.font(FONT_XXS or FONT_XS)
    lcd.color(fg)
    local headerText = refreshHeader(cache)
    local headerW = max(1, w - pad * 2)
    local stats = ellipsizeRight(lcd, headerText, floor(headerW * 0.45))
    local statsW = lcd.getTextSize(stats)
    lcd.drawText(x + w - pad - statsW, y + 2, stats)

    lcd.font(FONT_S)
    lcd.color(fg)
    local title = ellipsizeRight(lcd, getTitle(level), max(1, w - (pad * 3) - statsW))
    local titleY = y + max(2, floor((headerH - 18) * 0.5))
    lcd.drawText(x + pad, titleY, title)

    lcd.font(FONT_XXS or FONT_XS)
    local _, lineH = lcd.getTextSize("Ay")
    lineH = max(1, lineH)
    local logX = x + pad
    local logY = y + headerH
    local logW = w - (pad * 2)
    local logH = h - headerH - pad
    local maxLines = max(1, floor(logH / lineH))
    local lines = refreshLines(dashboard, lcd, maxLines, logW)
    local n = min(#lines, maxLines)
    for i = 1, n do
        lcd.drawText(logX, logY + (i - 1) * lineH, lines[i])
    end

    local rect = dashboard._debugLogPanelRects
    if not rect then
        rect = {}
        dashboard._debugLogPanelRects = rect
    end
    rect.x, rect.y, rect.w, rect.h = x, y, w, h
end

function M.handleEvent(dashboard, widget, category, value, x, y, lcd)
    if not (dashboard and dashboard.debugLogPanelVisible) then return false end

    if category == EVT_KEY and lcd.hasFocus() then
        if value == KEY_DOWN_BREAK or value == KEY_RTN_BREAK or value == KEY_EXIT_BREAK then
            dashboard.debugLogPanelVisible = false
            dashboard._debugLogPanelLastActive = 0
            M.clearCaches(dashboard)
            lcd.invalidate(widget)
            return true
        end
        return true
    end

    if category == EVT_TOUCH and value == TOUCH_END and x and y then
        local r = dashboard._debugLogPanelRects
        if not r or x < r.x or x >= (r.x + r.w) or y < r.y or y >= (r.y + r.h) then
            dashboard.debugLogPanelVisible = false
            dashboard._debugLogPanelLastActive = 0
            M.clearCaches(dashboard)
            lcd.invalidate(widget)
            return true
        end
        return true
    end

    return false
end

return M

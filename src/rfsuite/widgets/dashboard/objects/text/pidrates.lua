--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
Profile Source Selection
    object                  : string                    -- Required: must be "pid" or "rates"; maps to telemetry source "pid_profile" or "rate_profile"
    profilecount            : number                    -- (Optional) How many profile numbers to draw (1 to 6, default 6)
Telemetry and Value Handling
    value                   : number                    -- (Optional) Static fallback value if telemetry is unavailable
    transform               : string|function|number    -- (Optional) Value transform logic (e.g., "floor", multiplier, or custom function)
    decimals                : number                    -- (Optional) Decimal precision for transformed value
    thresholds              : table                     -- (Optional) Value threshold list: { value=..., textcolor=... }
    novalue                 : string                    -- (Optional) Fallback text if no telemetry or static value is available
    unit                    : string                    -- (Optional) Placeholder only; not used in this object
Value Styling and Alignment
    font                    : font                      -- (Optional) Font for profile number text
    textcolor               : color                     -- (Optional) Text color for inactive profile / rates
    fillcolor               : color                     -- (Optional) Text color for active profile / rates
    valuealign              : string                    -- (Optional) Ignored; profile numbers are always centered
    valuepadding            : number                    -- (Optional) General padding around value area (overridden by sides)
    valuepaddingleft        : number
    valuepaddingright       : number
    valuepaddingtop         : number
    valuepaddingbottom      : number
Title Styling
    title                   : string                    -- (Optional) Title label (e.g., "Active Profile")
    titlepos                : string                    -- (Optional) "top" or "bottom"
    titlealign              : string                    -- (Optional) Title alignment: "center", "left", or "right"
    titlefont               : font                      -- (Optional) Title font (e.g., FONT_L)
    titlespacing            : number                    -- (Optional) Gap between title and profile number row
    titlecolor              : color                     -- (Optional) Title text color
    titlepadding            : number                    -- (Optional) General padding around title (overridden by sides)
    titlepaddingleft        : number
    titlepaddingright       : number
    titlepaddingtop         : number
    titlepaddingbottom      : number
Row Layout and Font Options
    rowalign                : string                    -- (Optional) Alignment for number row: "left", "center", or "right"
    rowspacing              : number                    -- (Optional) Spacing between profile numbers (default: width / profilecount)
    rowfont                 : font                      -- (Optional) Font for profile numbers (fallbacks to `font`)
    rowpadding              : number                    -- (Optional) General padding for number row (overridden by sides)
    rowpaddingleft          : number
    rowpaddingright         : number
    rowpaddingtop           : number
    rowpaddingbottom        : number
    highlightlarger         : boolean                   -- (Optional) If true, enlarges the active index using the next font in the list
Background
    bgcolor                 : color                     -- (Optional) Widget background color
]]

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd

local min = math.min
local max = math.max
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber

local render = {}

local PROFILE_STR = {"1", "2", "3", "4", "5", "6"}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local resolveFont = utils.resolveFont
local getPulsingDots = utils.getPulsingDots
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout

function render.invalidate(box)
    box._cfg = nil
    box._textLayout = nil
end

-- Caches the profile-number row's font/geometry (base/larger font, per-digit
-- spacing, start position) -- previously all recomputed unconditionally in
-- paint() on every screen redraw, including an ipairs() scan of the
-- resolution's font list to find baseFont's index. See context.lua's
-- utils.prepareTextLayout() for the fuller rationale on why paint() is the
-- wrong place for this. Does not depend on which profile is active, so it's
-- stable across frames until config or box dimensions actually change.
local function prepareGeometry(x, y, w, h, box, c)
    local g = box._geom
    local rowpadding = c.rowpadding or 0
    local padLeft = c.rowpaddingleft or rowpadding
    local padRight = c.rowpaddingright or rowpadding
    local padTop = c.rowpaddingtop or rowpadding
    local padBottom = c.rowpaddingbottom or rowpadding
    local count = c.profilecount or 6

    local needGeo = (not g) or g.x ~= x or g.y ~= y or g.w ~= w or g.h ~= h
        or g.title ~= c.title or g.rowfont ~= c.rowfont or g.font ~= c.font
        or g.highlightlarger ~= c.highlightlarger
        or g.padLeft ~= padLeft or g.padRight ~= padRight or g.padTop ~= padTop or g.padBottom ~= padBottom
        or g.rowspacing ~= c.rowspacing or g.rowalign ~= c.rowalign or g.count ~= count

    if not needGeo then return g end

    g = g or {}
    g.x, g.y, g.w, g.h = x, y, w, h
    g.title = c.title
    g.rowfont, g.font = c.rowfont, c.font
    g.highlightlarger = c.highlightlarger
    g.padLeft, g.padRight, g.padTop, g.padBottom = padLeft, padRight, padTop, padBottom
    g.rowspacing, g.rowalign, g.count = c.rowspacing, c.rowalign, count

    local fontList = c.fontList or {}
    local baseFont = resolveFont(c.rowfont, nil) or resolveFont(c.font, FONT_L)

    local baseIndex
    for i, f in ipairs(fontList) do
        if f == baseFont then
            baseIndex = i
            break
        end
    end
    local largerFont = baseFont
    if c.highlightlarger and baseIndex and baseIndex < #fontList then largerFont = fontList[baseIndex + 1] end

    lcd.font(baseFont)
    local _, baseHeight = lcd.getTextSize("8")

    local rowY = y + padTop
    if c.title then rowY = y + h - baseHeight - padBottom end

    local totalWidth = w - padLeft - padRight
    local spacing = c.rowspacing or (totalWidth / count)
    local align = c.rowalign or "center"

    local totalContentWidth = spacing * count
    local startX
    if align == "left" then
        startX = x + padLeft
    elseif align == "right" then
        startX = x + w - padRight - totalContentWidth
    else
        startX = x + padLeft + (totalWidth - totalContentWidth) / 2
    end

    g.baseFont, g.largerFont, g.baseHeight = baseFont, largerFont, baseHeight
    g.rowY, g.spacing, g.startX = rowY, spacing, startX

    box._geom = g
    return g
end

function render.dirty(box)
    return utils.dirtyOnDisplayValueChange(box)
end

local function ensureCfg(box)
    return utils.ensureCfg(box, function(cfg, box)
        cfg.object = getParam(box, "object")
        if cfg.object == "pid" then
            cfg.source = "pid_profile"
        elseif cfg.object == "rates" then
            cfg.source = "rate_profile"
        else
            cfg.source = nil
        end

        cfg.title = getParam(box, "title")
        cfg.titlepos = getParam(box, "titlepos")
        cfg.titlealign = getParam(box, "titlealign")
        cfg.titlefont = getParam(box, "titlefont")
        cfg.titlespacing = getParam(box, "titlespacing")
        cfg.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.titlepadding = getParam(box, "titlepadding")
        cfg.titlepaddingleft = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")

        cfg.font = getParam(box, "font") or FONT_L
        cfg.valuealign = getParam(box, "valuealign")
        cfg.defaultTextColor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.fillcolor = utils.resolveThemeColor("fillcolor", getParam(box, "fillcolor"))
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")

        cfg.rowalign = getParam(box, "rowalign")
        cfg.rowpadding = getParam(box, "rowpadding")
        cfg.rowpaddingleft = getParam(box, "rowpaddingleft")
        cfg.rowpaddingright = getParam(box, "rowpaddingright")
        cfg.rowpaddingtop = getParam(box, "rowpaddingtop")
        cfg.rowpaddingbottom = getParam(box, "rowpaddingbottom")
        cfg.rowspacing = getParam(box, "rowspacing")
        cfg.rowfont = getParam(box, "rowfont")
        cfg.highlightlarger = getParam(box, "highlightlarger")
        cfg.profilecount = max(1, min(6, tonumber(getParam(box, "profilecount")) or 6))

        cfg.novalue = getParam(box, "novalue") or "-"
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.fontList = (utils.getFontListsForResolution().value_default) or {}
    end)
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local telemetry = rfsuite.tasks.telemetry
    local value
    if telemetry and cfg.source then value = select(1, telemetry.getSensor(cfg.source)) end
    if value == nil then value = getParam(box, "value") end

    local displayValue
    if value == nil then
        displayValue = getPulsingDots(box)
    else
        displayValue = utils.transformValue(value, box)
    end

    local index = tonumber(displayValue)
    if index == nil or index < 1 or index > 6 then if value ~= nil then displayValue = cfg.novalue end end

    local dynColor = utils.resolveThresholdColor(value, box, "textcolor", "textcolor") or cfg.defaultTextColor

    box._currentDisplayValue = displayValue
    box._dynamicTextColor = dynColor
    box._isLoadingDots = (value == nil)

    if box._dashboardRectW and box._dashboardRectH then
        local gx, gy = utils.applyOffset(box._dashboardRectX or 0, box._dashboardRectY or 0, box)
        local gw, gh
        gx, gy, gw, gh = utils.boxContentRect(gx, gy, box._dashboardRectW, box._dashboardRectH, cfg.bgcolor)
        prepareGeometry(gx, gy, gw, gh, box, cfg)
        prepareTextLayout(box, gx, gy, gw, gh, cfg.title, cfg.titlepos, cfg.titlealign, cfg.titlefont, cfg.titlespacing, cfg.titlepadding, cfg.titlepaddingleft, cfg.titlepaddingright, cfg.titlepaddingtop, cfg.titlepaddingbottom, nil, nil, cfg.font, cfg.valuealign, cfg.valuepadding, cfg.valuepaddingleft, cfg.valuepaddingright, cfg.valuepaddingtop, cfg.valuepaddingbottom)
    end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)
    -- displayValue is always nil here -- this widget draws its own profile
    -- number row, not value text -- so this call only ever measures/caches
    -- the title (the expensive part utils.box() used to redo every paint()).
    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, nil, nil, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, box._dynamicTextColor or c.defaultTextColor, c.titlecolor)

    local g = prepareGeometry(x, y, w, h, box, c)
    local count = g.count
    local activeIndex = tonumber(box._currentDisplayValue)

    for i = 1, count do
        local cx = g.startX + (i - 1) * g.spacing
        local text = PROFILE_STR[i] or tostring(i)
        local isActive = (activeIndex ~= nil) and (activeIndex == i)
        local currentFont = (isActive and c.highlightlarger and g.largerFont) or g.baseFont

        lcd.font(currentFont)
        local tw, th = lcd.getTextSize(text)
        local yOffset = (isActive and c.highlightlarger and g.largerFont ~= g.baseFont) and (g.baseHeight - th) / 2 or 0

        if isActive then
            lcd.color(c.fillcolor or c.defaultTextColor or WHITE)
        else
            lcd.color(c.defaultTextColor or WHITE)
        end

        lcd.drawText(cx + (g.spacing - tw) / 2, g.rowY + yOffset, text)
    end
end

return render


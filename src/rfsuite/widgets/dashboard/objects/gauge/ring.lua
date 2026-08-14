--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
Timing
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
Title parameters
    title               : string    -- (Optional) Title text
    titlepos            : string    -- (Optional) If `title` is present but `titlepos` is not set, title is placed at the top by default
    titlealign          : string    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font      -- (Optional) Title font (e.g., FONT_L, FONT_XL)
    titlespacing        : number    -- (Optional) Vertical gap between title and value
    titlecolor          : color     -- (Optional) Title text color (theme/text fallback)
    titlepadding        : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number    -- (Optional) Left padding for title
    titlepaddingright   : number    -- (Optional) Right padding for title
    titlepaddingtop     : number    -- (Optional) Top padding for title
    titlepaddingbottom  : number    -- (Optional) Bottom padding for title
Value/Source parameters
    value               : any       -- (Optional) Static value to display if telemetry is not present
    source              : string    -- Telemetry sensor source name (e.g., "temp_esc")
    transform           : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number    -- (Optional) Number of decimal places for numeric display
    thresholds          : table     -- (Optional) List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue             : string    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string    -- (Optional) Unit label to append to value ("" hides, default resolves dynamically)
    font                : font      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color     -- (Optional) Value text color (theme/text fallback)
    valuepadding        : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number    -- (Optional) Left padding for value
    valuepaddingright   : number    -- (Optional) Right padding for value
    valuepaddingtop     : number    -- (Optional) Top padding for value
    valuepaddingbottom  : number    -- (Optional) Bottom padding for value
Appearance/Theming
    bgcolor             : color     -- (Optional) Widget background color (theme fallback)
    fillbgcolor         : color     -- (Optional) Ring background color (theme fallback)
    fillcolor           : color     -- (Optional) Ring foreground color (theme fallback)
Geometry
    thickness           : number    -- (Optional) Ring thickness in pixels (default is proportional to radius)
Battery Ring Mode (Optional fuel-based battery style)
    ringbatt                 : bool      -- If true, draws 360° fill ring based on fuel (%) and shows mAh consumption
    ringbattsubfont          : font      -- (Optional) Font for subtext in ringbatt mode (e.g., FONT_XS, FONT_S, FONT_STD; default: FONT_XS)
    innerringcolor           : color     -- Color of the inner decorative ring in ringbatt mode (default: white)
    ringbattsubtext          : string|bool -- (Optional) Overrides subtext below value in ringbatt mode (set "" or false to hide)
    innerringthickness       : number    -- (Optional) Thickness of inner decorative ring in ringbatt mode (default: 8)
    ringbattsubalign         : string    -- (Optional) "left", "center", or "right" alignment of subtext (default: center under value)
    ringbattsubpadding       : number    -- (Optional) General padding (px) for subtext (applies if per-side not set)
    ringbattsubpaddingleft   : number    -- (Optional) Left padding override for subtext
    ringbattsubpaddingright  : number    -- (Optional) Right padding override for subtext
    ringbattsubpaddingtop    : number    -- (Optional) Top padding override for subtext
    ringbattsubpaddingbottom : number    -- (Optional) Bottom padding override for subtext
]]

local requireModule = assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd

local floor = math.floor
local min = math.min
local max = math.max
local format = string.format

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local resolveThresholdColor = utils.resolveThresholdColor
local resolveFont = utils.resolveFont
local getPulsingDots = utils.getPulsingDots
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout
local lastDisplayValue = nil

function render.dirty(box)
    return utils.dirtyOnDisplayValueChange(box)
end

local drawArc = utils.drawArc

-- Caches the ring's center/radius/thickness (which needs a title font
-- measurement to derive) so paint() -- Ethos's tight-instruction-budget path
-- -- doesn't redo that measurement every redraw. See context.lua's
-- utils.prepareTextLayout() for the fuller rationale.
local function prepareGeometry(x, y, w, h, box, c)
    local g = box._geom
    -- g.thicknessParam is the raw (possibly nil) c.thickness, used as the
    -- cache key; g.thickness is the resolved value used for drawing. Keeping
    -- these separate matters -- see arc.lua's prepareGeometry for why
    -- comparing the resolved value against the raw param breaks the cache.
    local needGeo = (not g) or g.x ~= x or g.y ~= y or g.w ~= w or g.h ~= h
        or g.title ~= c.title or g.titlefont ~= c.titlefont or g.titlespacing ~= (c.titlespacing or 0)
        or g.titlepaddingtop ~= (c.titlepaddingtop or 0) or g.titlepaddingbottom ~= (c.titlepaddingbottom or 0)
        or g.titlepos ~= c.titlepos or g.thicknessParam ~= (c.thickness or 0)

    if not needGeo then return g end

    g = g or {}
    g.x, g.y, g.w, g.h = x, y, w, h
    g.title, g.titlefont = c.title, c.titlefont
    g.titlespacing = c.titlespacing or 0
    g.titlepaddingtop = c.titlepaddingtop or 0
    g.titlepaddingbottom = c.titlepaddingbottom or 0
    g.titlepos = c.titlepos
    g.thicknessParam = c.thickness or 0

    local titleHeight = 0
    if c.title then
        lcd.font(resolveFont(c.titlefont, FONT_XS))
        local _, th = lcd.getTextSize(c.title)
        titleHeight = (th or 0) + g.titlespacing + g.titlepaddingtop + g.titlepaddingbottom
    end

    local cy
    if c.titlepos == "top" then
        cy = y + titleHeight + (h - titleHeight) * 0.45
    elseif c.titlepos == "bottom" then
        cy = y + (h - titleHeight) * 0.5
    else
        cy = y + h * 0.5
    end

    local ringPadding = 2
    local baseSize = min(w, h - (c.title and ringPadding * 2 or 0))
    local ringSize = min(0.88 * (c.title and 1 or 1.05), 1.0)
    local radius = baseSize * 0.5 * ringSize
    local thickness = c.thickness or max(8, radius * 0.18)

    g.cx = x + w / 2
    g.cy = cy
    g.radius = radius
    g.thickness = thickness

    box._geom = g
    return g
end

function render.wakeup(box)

    local telemetry = rfsuite.tasks.telemetry

    local source = getParam(box, "source")
    local value, _, dynamicUnit
    if telemetry and source then value, _, dynamicUnit = telemetry.getSensor(source) end

    local ringbatt = getParam(box, "ringbatt")
    local percent = 0
    local mahUnit = ""
    local fuel = 0
    local consumption = 0

    if ringbatt and telemetry and telemetry.getSensor then
        fuel = telemetry.getSensor("fuel") or 0
        consumption = telemetry.getSensor("consumption") or 0
        percent = max(0, min(1, fuel / 100))
        mahUnit = format("%dmah", floor(consumption + 0.5))

        local override = getParam(box, "ringbattsubtext")
        if override == "" or override == false then
            mahUnit = nil
        elseif override then
            mahUnit = override
        end
    end

    local manualUnit = getParam(box, "unit")
    local unit

    if manualUnit ~= nil then
        unit = manualUnit
    elseif dynamicUnit ~= nil then
        unit = dynamicUnit
    elseif source and telemetry and telemetry.sensorTable[source] then
        unit = telemetry.sensorTable[source].unit_string or ""
    else
        unit = ""
    end

    local displayValue
    if value ~= nil then displayValue = utils.transformValue(value, box) end

    if value == nil then
        displayValue = getPulsingDots(box)
        unit = nil
    end

    if type(displayValue) == "string" and displayValue:match("^%.+$") then unit = nil end

    box._currentDisplayValue = value

    local c = box._cache
    if not c then
        c = {}
        box._cache = c
    end

    local thresholds = getParam(box, "thresholds")

    c.value = value
    c.displayValue = displayValue
    c.unit = unit
    c.ringbatt = ringbatt
    c.percent = percent
    c.mahUnit = mahUnit
    c.novalue = getParam(box, "novalue") or "-"
    c.fillcolor = resolveThresholdColor(value, box, "fillcolor", "fillcolor", thresholds)
    c.textcolor = resolveThresholdColor(value, box, "textcolor", "textcolor", thresholds)
    c.fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor"))
    c.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
    c.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
    c.thresholds = thresholds
    c.title = getParam(box, "title")
    c.titlepos = getParam(box, "titlepos") or (getParam(box, "title") and "top")
    c.titlealign = getParam(box, "titlealign")
    c.titlefont = getParam(box, "titlefont")
    c.titlespacing = getParam(box, "titlespacing")
    c.titlepadding = getParam(box, "titlepadding")
    c.titlepaddingleft = getParam(box, "titlepaddingleft")
    c.titlepaddingright = getParam(box, "titlepaddingright")
    c.titlepaddingtop = getParam(box, "titlepaddingtop")
    c.titlepaddingbottom = getParam(box, "titlepaddingbottom")
    c.font = getParam(box, "font") or "FONT_STD"
    c.decimals = getParam(box, "decimals")
    c.valuealign = getParam(box, "valuealign")
    c.valuepadding = getParam(box, "valuepadding")
    c.valuepaddingleft = getParam(box, "valuepaddingleft")
    c.valuepaddingright = getParam(box, "valuepaddingright")
    c.valuepaddingtop = getParam(box, "valuepaddingtop")
    c.valuepaddingbottom = getParam(box, "valuepaddingbottom")
    c.thickness = getParam(box, "thickness")
    c.innerringcolor = resolveThemeColor("innerringcolor", getParam(box, "innerringcolor") or "white")
    c.innerringthickness = getParam(box, "innerringthickness") or 8
    c.ringbattsubalign = getParam(box, "ringbattsubalign")
    c.ringbattsubpadding = getParam(box, "ringbattsubpadding") or 2
    c.ringbattsubpaddingleft = getParam(box, "ringbattsubpaddingleft")
    c.ringbattsubpaddingright = getParam(box, "ringbattsubpaddingright")
    c.ringbattsubpaddingtop = getParam(box, "ringbattsubpaddingtop")
    c.ringbattsubpaddingbottom = getParam(box, "ringbattsubpaddingbottom")
    c.ringbattsubfont = getParam(box, "ringbattsubfont") or "FONT_XS"

    if box._dashboardRectW and box._dashboardRectH then
        local gx, gy = utils.applyOffset(box._dashboardRectX or 0, box._dashboardRectY or 0, box)
        local gw, gh
        gx, gy, gw, gh = utils.boxContentRect(gx, gy, box._dashboardRectW, box._dashboardRectH, c.bgcolor)
        prepareGeometry(gx, gy, gw, gh, box, c)
        prepareTextLayout(box, gx, gy, gw, gh, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.displayValue, c.unit, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    end
end

function render.paint(x, y, w, h, box)
    -- Matches objects/navigation/ah.lua's own guard: box._cache is only ever
    -- populated by render.wakeup() below, so painting before the first
    -- wakeup (e.g. a host context that calls paint() without ever pairing
    -- it with wakeup()) must draw nothing, not fall through to a ring
    -- rendered from bare w/h defaults in legacyPalette()'s fallback color.
    local c = box._cache
    if not c then return end

    x, y = utils.applyOffset(x, y, box)

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)

    local g = prepareGeometry(x, y, w, h, box, c)
    local cx, cy, radius, thickness = g.cx, g.cy, g.radius, g.thickness

    if c.ringbatt then

        drawArc(cx, cy, radius, thickness, 0, 360, c.fillbgcolor)

        local startAngle = 360 - (c.percent * 360)
        drawArc(cx, cy, radius, thickness, startAngle, 360, c.fillcolor)

        drawArc(cx, cy, radius - thickness, c.innerringthickness, 0, 360, c.innerringcolor)
    else

        drawArc(cx, cy, radius, thickness, 0, 360, c.fillbgcolor)
        drawArc(cx, cy, radius, thickness, 0, 360, c.fillcolor)
    end

    if c.ringbatt and c.mahUnit then

        lcd.font(resolveFont(c.ringbattsubfont, FONT_XS))
        local tw, th = lcd.getTextSize(c.mahUnit)

        local padL = c.ringbattsubpaddingleft or c.ringbattsubpadding or 0
        local padR = c.ringbattsubpaddingright or c.ringbattsubpadding or 0
        local padT = c.ringbattsubpaddingtop or c.ringbattsubpadding or 0
        local padB = c.ringbattsubpaddingbottom or c.ringbattsubpadding or 0

        local textX
        if c.ringbattsubalign == "left" then
            textX = x + padL
        elseif c.ringbattsubalign == "right" then
            textX = x + w - tw - padR
        else
            textX = x + (w - tw) / 2 + (padL - padR)
        end

        lcd.font(resolveFont(c.font, FONT_STD))
        local _, mainH = lcd.getTextSize("0")
        local centerY = y + h / 2
        local textY = centerY + mainH / 2 + padT - padB

        lcd.font(resolveFont(c.ringbattsubfont, FONT_XS))
        lcd.color(c.textcolor)
        lcd.drawText(textX, textY, c.mahUnit)
    end

    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.displayValue, c.unit, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, c.textcolor, c.titlecolor)
end

return render

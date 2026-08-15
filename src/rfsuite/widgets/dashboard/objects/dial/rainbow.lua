--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
    wakeupinterval          : number   -- Optional wakeup interval in seconds (set in wrapper)
title parameters
    title                   : string    -- (Optional) Title text
    titlealign              : string    -- (Optional) "center", "left", "right"
    titlefont               : font      -- (Optional) Title font (e.g., font_l, font_xl)
    titlespacing            : number    -- (Optional) Gap below title
    titlecolor              : color     -- (Optional) Title text color
    titlepadding            : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft        : number    -- (Optional)
    titlepaddingright       : number    -- (Optional)
    titlepaddingtop         : number    -- (Optional)
    titlepaddingbottom      : number    -- (Optional)
value / source parameters
    value                   : any       -- (Optional) Static value to display if telemetry is not present
    showvalue               : bool      -- (Optional) If false, hides the main value text (default true)
    source                  : string    -- Telemetry sensor name
    transform               : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", etc.)
    decimals                : number    -- (Optional) Decimal precision
    novalue                 : string    -- (Optional) Text if telemetry is missing (default: "-")
    unit                    : string    -- (Optional) Unit label ("" hides unit)
    font                    : font      -- (Optional) Value font (e.g., font_l)
    valuealign              : string    -- (Optional) "center", "left", "right"
    textcolor               : color     -- (Optional) Text color
    valuepadding            : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft        : number    -- (Optional)
    valuepaddingright       : number    -- (Optional)
    valuepaddingtop         : number    -- (Optional)
    valuepaddingbottom      : number    -- (Optional)
arc band parameters
    bandlabels              : table     -- List of labels for each band (e.g. {"Low", "Med", "High"})
    bandcolors              : table     -- List of band colors (e.g. {lcd.RGB(180,50,50), lcd.RGB(...)})
    bandlabeloffset         : number    -- (Optional) Outward for left/right labels (default 18)
    bandlabeloffsettop      : number    -- (Optional) Down from the arc edge for the top label (default 8)
    bandlabelfont           : font      -- (Optional) Font for band labels (e.g. FONT_XS, FONT_S). Defaults to FONT_XS
appearance / theming
    bgcolor                 : color     -- (Optional) Widget background color
    fillbgcolor             : color     -- (Optional) Arc background color (optional)
    titlecolor              : color     -- (Optional) Title text color fallback
needle styling
    accentcolor             : color     -- (Optional) Needle and hub color
    needlethickness         : number    -- (Optional) Needle width (default: 5)
    needlehubsize           : number    -- (Optional) Needle hub circle radius (default: 7)
]]

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd

local sin = math.sin
local cos = math.cos
local rad = math.rad
local ipairs = ipairs

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThresholdColor = utils.resolveThresholdColor
local resolveThemeColor = utils.resolveThemeColor
local resolveThemeColorArray = utils.resolveThemeColorArray
local resolveFont = utils.resolveFont
local getPulsingDots = utils.getPulsingDots
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout
local lastDisplayValue = nil

local DEFAULT_BAND_LABELS = {"Low", "Med", "High"}
local DEFAULT_BAND_COLORS = {"red", "orange", "green"}

function render.dirty(box)
    return utils.dirtyOnDisplayValueChange(box)
end

local function drawRainbowArc(cx, cy, radius, thickness, startAngle, endAngle, colors)
    local inner = math.max(1, radius - thickness)
    local outer = radius
    local segmentCount = #colors
    if segmentCount == 0 then return end

    startAngle = startAngle % 360
    endAngle = endAngle % 360
    if endAngle <= startAngle then endAngle = endAngle + 360 end

    local angleSweep = endAngle - startAngle
    local anglePerSegment = angleSweep / segmentCount

    for i, color in ipairs(colors) do
        local segStart = startAngle + (i - 1) * anglePerSegment
        local segEnd = startAngle + i * anglePerSegment

        lcd.color(color)
        lcd.drawAnnulusSector(cx, cy, inner, outer, segStart, segEnd)
    end
end

local function calDialAngle(percent, startAngle, sweepAngle) return (startAngle or 135) + (sweepAngle or 270) * (percent or 0) end

-- Caches the arc's center/radius/thickness (needs a title + band-label font
-- measurement to derive) so paint() doesn't redo that work every redraw.
-- See context.lua's utils.prepareTextLayout() for the fuller rationale.
local function prepareGeometry(x, y, w, h, box, c)
    local g = box._geom
    -- g.thicknessParam is the raw (possibly nil) c.thickness, used as the
    -- cache key; g.thickness is the resolved value used for drawing --
    -- see arc.lua's prepareGeometry for why these must stay separate.
    local needGeo = (not g) or g.x ~= x or g.y ~= y or g.w ~= w or g.h ~= h
        or g.title ~= c.title or g.titlefont ~= c.titlefont or g.titlespacing ~= (c.titlespacing or 0)
        or g.titlepaddingtop ~= (c.titlepaddingtop or 0) or g.titlepaddingbottom ~= (c.titlepaddingbottom or 0)
        or g.bandlabelfont ~= c.bandlabelfont or g.thicknessParam ~= (c.thickness or 0)

    if not needGeo then return g end

    g = g or {}
    g.x, g.y, g.w, g.h = x, y, w, h
    g.title, g.titlefont = c.title, c.titlefont
    g.titlespacing = c.titlespacing or 0
    g.titlepaddingtop = c.titlepaddingtop or 0
    g.titlepaddingbottom = c.titlepaddingbottom or 0
    g.bandlabelfont = c.bandlabelfont
    g.thicknessParam = c.thickness or 0

    lcd.font(resolveFont(c.bandlabelfont, FONT_XS))
    local subtextHeight = select(2, lcd.getTextSize("Med")) + 2

    local titleHeight = 0
    if c.title then
        lcd.font(resolveFont(c.titlefont, FONT_XS))
        local _, th = lcd.getTextSize(c.title)
        titleHeight = (th or 0) + g.titlespacing + g.titlepaddingtop + g.titlepaddingbottom
    end

    local arcRegionY = y + subtextHeight
    local arcRegionH = h - subtextHeight - titleHeight
    local arcMargin = 2
    local usableW = w - arcMargin * 2
    local usableH = arcRegionH - arcMargin
    local thickness = c.thickness or math.max(6, math.min(usableW, usableH) * 0.25)
    local radius = math.min(usableW / 2, usableH) - (thickness / 2)
    if radius < 8 then radius = 8 end

    g.cx = x + w / 2
    g.cy = arcRegionY + arcRegionH / 2 + 15
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

    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100
    local percent = 0
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end

    local displayValue
    if value ~= nil then displayValue = utils.transformValue(value, box) end

    if value == nil then
        displayValue = getPulsingDots(box)
        unit = nil
    end

    local showvalue = getParam(box, "showvalue")
    if showvalue == nil then showvalue = true end

    if type(displayValue) == "string" and displayValue:match("^%.+$") then unit = nil end

    box._currentDisplayValue = value

    local c = box._cache
    if not c then
        c = {}
        box._cache = c
    end

    c.value = value
    c.displayValue = displayValue
    c.percent = percent
    c.unit = unit
    c.min = min
    c.max = max
    c.showvalue = showvalue
    c.titlepos = "bottom"
    c.font = getParam(box, "font") or "FONT_STD"
    c.textcolor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
    c.fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor"))
    c.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
    c.title = getParam(box, "title")
    c.titlefont = getParam(box, "titlefont")
    c.titlealign = getParam(box, "titlealign")
    c.titlespacing = getParam(box, "titlespacing") or 0
    c.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
    c.titlepadding = getParam(box, "titlepadding")
    c.titlepaddingleft = getParam(box, "titlepaddingleft")
    c.titlepaddingright = getParam(box, "titlepaddingright")
    c.titlepaddingtop = getParam(box, "titlepaddingtop")
    c.titlepaddingbottom = getParam(box, "titlepaddingbottom")
    c.valuealign = getParam(box, "valuealign")
    c.valuepadding = getParam(box, "valuepadding")
    c.valuepaddingleft = getParam(box, "valuepaddingleft")
    c.valuepaddingright = getParam(box, "valuepaddingright")
    c.valuepaddingtop = getParam(box, "valuepaddingtop")
    c.valuepaddingbottom = getParam(box, "valuepaddingbottom")
    c.bandlabeloffset = getParam(box, "bandlabeloffset") or 14
    c.bandlabeloffsettop = getParam(box, "bandlabeloffsettop") or 8
    c.bandlabelfont = getParam(box, "bandlabelfont") or "FONT_XS"
    c.bandlabels = getParam(box, "bandlabels") or DEFAULT_BAND_LABELS
    c.bandcolors = resolveThemeColorArray("fillcolor", getParam(box, "bandcolors") or DEFAULT_BAND_COLORS, c.bandcolors)
    c.needlethickness = getParam(box, "needlethickness") or 5
    c.needlehubsize = getParam(box, "needlehubsize") or 7
    c.needlestartangle = getParam(box, "needlestartangle") or 150
    c.needlesweepangle = getParam(box, "needlesweepangle") or 240
    c.accentcolor = resolveThemeColor("accentcolor", getParam(box, "accentcolor"))

    if box._dashboardRectW and box._dashboardRectH then
        local gx, gy = utils.applyOffset(box._dashboardRectX or 0, box._dashboardRectY or 0, box)
        local gw, gh
        gx, gy, gw, gh = utils.boxContentRect(gx, gy, box._dashboardRectW, box._dashboardRectH, c.bgcolor)
        prepareGeometry(gx, gy, gw, gh, box, c)
        prepareTextLayout(box, gx, gy, gw, gh, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.showvalue ~= false and c.displayValue or nil, c.showvalue ~= false and c.unit or nil, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)

    local g = prepareGeometry(x, y, w, h, box, c)
    local cx, cy, radius, thickness = g.cx, g.cy, g.radius, g.thickness

    local bandCount = #c.bandlabels
    local startAngle = 240
    local endAngle = 120
    if bandCount > 0 and c.bandcolors then drawRainbowArc(cx, cy, radius, thickness, startAngle, endAngle, c.bandcolors) end

    local needleHubYOffset = 6

    if c.percent then
        local angleDeg = calDialAngle(c.percent, c.needlestartangle or 150, c.needlesweepangle or 240)
        local needleLen = radius
        local cy_needle = cy
        utils.drawBarNeedle(cx, cy_needle, needleLen, c.needlethickness, angleDeg, c.accentcolor)
        lcd.color(c.accentcolor)
        lcd.drawFilledCircle(cx, cy_needle, c.needlehubsize)
    end

    local sweep = (endAngle - startAngle + 360) % 360
    lcd.font(resolveFont(c.bandlabelfont, FONT_XS))

    local angleOffset = -30

    for i = 1, bandCount do
        local midAngle = startAngle - (i - 0.5) * (sweep / bandCount) + angleOffset
        local degNorm = (midAngle + 360) % 360

        local labelRadius
        if degNorm > 80 and degNorm < 100 then
            labelRadius = radius + thickness / 2 + c.bandlabeloffsettop
        else
            labelRadius = radius + thickness / 2 + c.bandlabeloffset
        end

        local tx = cx + labelRadius * cos(rad(midAngle))
        local ty = cy - labelRadius * sin(rad(midAngle))
        ty = ty + 12

        local label = c.bandlabels[i]
        if label then
            local tw, th = lcd.getTextSize(label)
            lcd.color(c.textcolor)
            lcd.drawText(tx - tw / 2, ty - th / 2, label)
        end
    end

    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.showvalue ~= false and c.displayValue or nil, c.showvalue ~= false and c.unit or nil, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, c.textcolor, c.titlecolor)
end

return render

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
    source                  : string    -- Telemetry sensor name
    transform               : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", etc.)
    decimals                : number    -- (Optional) Decimal precision
    novalue                 : string    -- (Optional) Text if telemetry is missing (default: "-")
    unit                    : string    -- (Optional) Unit label ("" hides unit)
    font                    : font      -- (Optional) Value font (e.g. font_l)
    valuealign              : string    -- (Optional) "center", "left", "right"
    textcolor               : color     -- (Optional) Text color
    valuepadding            : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft        : number    -- (Optional)
    valuepaddingright       : number    -- (Optional)
    valuepaddingtop         : number    -- (Optional)
    valuepaddingbottom      : number    -- (Optional)
dial image & needle styling
    dial                    : string|number|function -- Dial image selector (used for asset path)
    scalefactor             : number   -- (Optional) Image scale multiplier (default: 0.4)
    needlecolor             : color    -- (Optional) Needle color (default: theme)
    needlehubcolor          : color    -- (Optional) Hub color (default: theme)
    needlethickness         : number   -- (Optional) Needle width in pixels (default: 3)
    needlehubsize           : number   -- (Optional) Hub circle radius in pixels (default: needle thickness + 2)
    needlestartangle        : number   -- (Optional) Needle starting angle in degrees (default: 135)
    needlesweepangle        : number   -- (Optional) Needle sweep angle in degrees (default: 270)

    bgcolor                 : color    -- Widget background color (default: theme fallback)
]]

local rfsuite = assert(loadfile("widgets/dashboard/context.lua"))()
local lcd = lcd

local format = string.format
local tostring = tostring
local tonumber = tonumber

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local resolveFont = utils.resolveFont
local getPulsingDots = utils.getPulsingDots
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout

function render.dirty(box)
    return utils.dirtyOnDisplayValueChange(box)
end

local function resolveDialAsset(value, basePath)
    if type(value) == "function" then value = value() end
    if type(value) == "number" then
        return format("%s/%d.png", basePath, value)
    elseif type(value) == "string" then
        if value:match("^%d+$") then
            return format("%s/%s.png", basePath, value)
        else
            return value
        end
    end
    return nil
end

rfsuite.session.dialImageCache = rfsuite.session.dialImageCache or {}
local function loadDialPanelCached(dialId)
    local key = tostring(dialId or "panel1")
    if not rfsuite.session.dialImageCache[key] then
        local panelPath = resolveDialAsset(dialId, "widgets/dashboard/gfx/dials") or "widgets/dashboard/gfx/dials/panel1.png"
        rfsuite.session.dialImageCache[key] = rfsuite.utils.loadImage(panelPath)
    end
    return rfsuite.session.dialImageCache[key]
end

local function calDialAngle(percent, startAngle, sweepAngle) return (startAngle or 315) + (sweepAngle or 270) * (percent or 0) / 100 end

local function computeDrawArea(img, x, y, w, h, scalefactor)
    if not img then return x, y, w, h end

    local iw, ih = img:width(), img:height()
    local scale = math.max(w / iw, h / ih) * (scalefactor or 1.0)
    local drawW = iw * scale
    local drawH = ih * scale
    local drawX = x + (w - drawW) / 2
    local drawY = y + (h - drawH) / 2
    return drawX, drawY, drawW, drawH
end

-- Caches the title-area height + panel-image draw rect (needs a title font
-- measurement plus a couple of image-size lookups to derive) so paint()
-- doesn't redo that work every redraw. See context.lua's
-- utils.prepareTextLayout() for the fuller rationale.
local function prepareGeometry(x, y, w, h, box, c)
    local g = box._geom
    local needGeo = (not g) or g.x ~= x or g.y ~= y or g.w ~= w or g.h ~= h
        or g.title ~= c.title or g.titlefont ~= c.titlefont or g.titlespacing ~= (c.titlespacing or 0)
        or g.titlepaddingtop ~= (c.titlepaddingtop or 0) or g.titlepaddingbottom ~= (c.titlepaddingbottom or 0)
        or g.titlepos ~= c.titlepos or g.panelimg ~= c.panelimg or g.scalefactor ~= c.scalefactor

    if not needGeo then return g end

    g = g or {}
    g.x, g.y, g.w, g.h = x, y, w, h
    g.title, g.titlefont = c.title, c.titlefont
    g.titlespacing = c.titlespacing or 0
    g.titlepaddingtop = c.titlepaddingtop or 0
    g.titlepaddingbottom = c.titlepaddingbottom or 0
    g.titlepos = c.titlepos
    g.panelimg = c.panelimg
    g.scalefactor = c.scalefactor

    local titleHeight = 0
    if c.title then
        lcd.font(resolveFont(c.titlefont, FONT_XS))
        local _, th = lcd.getTextSize(c.title)
        titleHeight = (th or 0) + g.titlespacing + g.titlepaddingtop + g.titlepaddingbottom
    end

    local imgRegionY, imgRegionH
    if c.titlepos == "top" then
        imgRegionY = y + titleHeight
        imgRegionH = h - titleHeight
    elseif c.titlepos == "bottom" then
        imgRegionY = y
        imgRegionH = h - titleHeight
    else
        imgRegionY = y
        imgRegionH = h
    end

    local drawX, drawY, drawW, drawH = x, y, w, h
    if c.panelimg then
        drawX, drawY, drawW, drawH = computeDrawArea(c.panelimg, x, imgRegionY, w, imgRegionH, c.scalefactor)
    end
    g.drawX, g.drawY, g.drawW, g.drawH = drawX, drawY, drawW, drawH

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
    if value and max ~= min then percent = math.max(0, math.min(1, (value - min) / (max - min))) end

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

    c.value = value
    c.displayvalue = displayValue
    c.percent = percent * 100
    c.unit = unit
    c.min = min
    c.max = max
    c.title = getParam(box, "title")
    c.titlepos = getParam(box, "titlepos")
    c.titlefont = getParam(box, "titlefont")
    c.titlealign = getParam(box, "titlealign")
    c.titlespacing = getParam(box, "titlespacing") or 0
    c.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
    c.titlepadding = getParam(box, "titlepadding")
    c.titlepaddingleft = getParam(box, "titlepaddingleft")
    c.titlepaddingright = getParam(box, "titlepaddingright")
    c.titlepaddingtop = getParam(box, "titlepaddingtop")
    c.titlepaddingbottom = getParam(box, "titlepaddingbottom")
    c.font = getParam(box, "font") or "FONT_STD"
    c.textcolor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
    c.valuealign = getParam(box, "valuealign")
    c.valuepadding = getParam(box, "valuepadding")
    c.valuepaddingleft = getParam(box, "valuepaddingleft")
    c.valuepaddingright = getParam(box, "valuepaddingright")
    c.valuepaddingtop = getParam(box, "valuepaddingtop")
    c.valuepaddingbottom = getParam(box, "valuepaddingbottom")

    local dialid = getParam(box, "dial")
    if c.dialid ~= dialid then
        c.dialid = dialid
        c.panelimg = loadDialPanelCached(dialid)
    end

    c.scalefactor = tonumber(getParam(box, "scalefactor")) or 0.4
    c.needlecolor = resolveThemeColor("needlecolor", getParam(box, "needlecolor"))
    c.hubcolor = resolveThemeColor("needlehubcolor", getParam(box, "needlehubcolor"))
    c.needlethickness = getParam(box, "needlethickness") or 3
    c.hubradius = getParam(box, "needlehubsize") or 5
    c.needlestartangle = getParam(box, "needlestartangle") or 135
    c.sweep = getParam(box, "needlesweepangle") or 270
    c.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))

    if box._dashboardRectW and box._dashboardRectH then
        local gx, gy = utils.applyOffset(box._dashboardRectX or 0, box._dashboardRectY or 0, box)
        local gw, gh
        gx, gy, gw, gh = utils.boxContentRect(gx, gy, box._dashboardRectW, box._dashboardRectH, c.bgcolor)
        prepareGeometry(gx, gy, gw, gh, box, c)
        prepareTextLayout(box, gx, gy, gw, gh, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.displayvalue, c.unit, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)

    local g = prepareGeometry(x, y, w, h, box, c)
    local drawX, drawY, drawW, drawH = g.drawX, g.drawY, g.drawW, g.drawH

    if c.panelimg then
        lcd.drawBitmap(drawX, drawY, c.panelimg, drawW, drawH)
    end

    if c.value ~= nil then
        local angle = calDialAngle(c.percent, c.needlestartangle, c.sweep)
        local cx = drawX + drawW / 2
        local cy = drawY + drawH / 2
        local radius = math.min(drawW, drawH) * 0.40
        local needleLength = radius - 6
        if c.percent and type(c.percent) == "number" and not (c.percent ~= c.percent) then utils.drawBarNeedle(cx, cy, needleLength, c.needlethickness, angle, c.needlecolor) end
        lcd.color(c.hubcolor)
        lcd.drawFilledCircle(cx, cy, c.hubradius)
    end

    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.displayvalue, c.unit, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, c.textcolor, c.titlecolor)
end

return render

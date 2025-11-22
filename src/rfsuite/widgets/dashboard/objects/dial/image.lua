--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

function render.dirty(box)

    if box._lastDisplayValue == nil then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end

    if box._lastDisplayValue ~= box._currentDisplayValue then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end

    return false
end

local function resolveDialAsset(value, basePath)
    if type(value) == "function" then value = value() end
    if type(value) == "number" then
        return string.format("%s/%d.png", basePath, value)
    elseif type(value) == "string" then
        if value:match("^%d+$") then
            return string.format("%s/%s.png", basePath, value)
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
        local maxDots = 3
        if box._dotCount == nil then box._dotCount = 0 end
        box._dotCount = (box._dotCount + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then displayValue = "." end
        unit = nil
    end

    if type(displayValue) == "string" and displayValue:match("^%.+$") then unit = nil end

    box._currentDisplayValue = value

    box._cache = {
        value = value,
        displayvalue = displayValue,
        percent = percent * 100,
        unit = unit,
        min = min,
        max = max,
        title = getParam(box, "title"),
        titlepos = getParam(box, "titlepos"),
        titlefont = getParam(box, "titlefont"),
        titlealign = getParam(box, "titlealign"),
        titlespacing = getParam(box, "titlespacing") or 0,
        titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        titlepadding = getParam(box, "titlepadding"),
        titlepaddingleft = getParam(box, "titlepaddingleft"),
        titlepaddingright = getParam(box, "titlepaddingright"),
        titlepaddingtop = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        font = getParam(box, "font") or "FONT_STD",
        textcolor = resolveThemeColor("textcolor", getParam(box, "textcolor")),
        valuealign = getParam(box, "valuealign"),
        valuepadding = getParam(box, "valuepadding"),
        valuepaddingleft = getParam(box, "valuepaddingleft"),
        valuepaddingright = getParam(box, "valuepaddingright"),
        valuepaddingtop = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        dialid = getParam(box, "dial"),
        panelimg = loadDialPanelCached(getParam(box, "dial")),
        scalefactor = tonumber(getParam(box, "scalefactor")) or 0.4,
        needlecolor = resolveThemeColor("needlecolor", getParam(box, "needlecolor")),
        hubcolor = resolveThemeColor("needlehubcolor", getParam(box, "needlehubcolor")),
        needlethickness = getParam(box, "needlethickness") or 3,
        hubradius = getParam(box, "needlehubsize") or 5,
        needlestartangle = getParam(box, "needlestartangle") or 135,
        sweep = getParam(box, "needlesweepangle") or 270,
        bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    local titleHeight = 0
    if c.title then
        lcd.font(_G[c.titlefont] or FONT_XS)
        local _, th = lcd.getTextSize(c.title)
        titleHeight = (th or 0) + (c.titlespacing or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0)
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

    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    local drawX, drawY, drawW, drawH = x, y, w, h
    if c.panelimg then
        drawX, drawY, drawW, drawH = computeDrawArea(c.panelimg, x, imgRegionY, w, imgRegionH, c.scalefactor)
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

    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.displayvalue, c.unit, c.font, c.valuealign, c.textcolor, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, nil)
end

return render

--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThresholdColor = utils.resolveThresholdColor
local resolveThemeColor = utils.resolveThemeColor
local resolveThemeColorArray = utils.resolveThemeColorArray
local lastDisplayValue = nil

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
        local maxDots = 3
        if box._dotCount == nil then box._dotCount = 0 end
        box._dotCount = (box._dotCount + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then displayValue = "." end
        unit = nil
    end

    local showvalue = getParam(box, "showvalue")
    if showvalue == nil then showvalue = true end

    if type(displayValue) == "string" and displayValue:match("^%.+$") then unit = nil end

    box._currentDisplayValue = value

    box._cache = {
        value = value,
        displayValue = displayValue,
        percent = percent,
        unit = unit,
        min = min,
        max = max,
        showvalue = showvalue,
        titlepos = "bottom",
        font = getParam(box, "font") or "FONT_M",
        textcolor = resolveThemeColor("textcolor", getParam(box, "textcolor")),
        fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor")),
        bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        title = getParam(box, "title"),
        titlefont = getParam(box, "titlefont"),
        titlealign = getParam(box, "titlealign"),
        titlespacing = getParam(box, "titlespacing") or 0,
        titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        titlepadding = getParam(box, "titlepadding"),
        titlepaddingleft = getParam(box, "titlepaddingleft"),
        titlepaddingright = getParam(box, "titlepaddingright"),
        titlepaddingtop = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        valuealign = getParam(box, "valuealign"),
        valuepadding = getParam(box, "valuepadding"),
        valuepaddingleft = getParam(box, "valuepaddingleft"),
        valuepaddingright = getParam(box, "valuepaddingright"),
        valuepaddingtop = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        bandlabeloffset = getParam(box, "bandlabeloffset") or 14,
        bandlabeloffsettop = getParam(box, "bandlabeloffsettop") or 8,
        bandlabelfont = getParam(box, "bandlabelfont") or "FONT_XS",
        bandlabels = getParam(box, "bandlabels") or {"Low", "Med", "High"},
        bandcolors = resolveThemeColorArray("fillcolor", getParam(box, "bandcolors") or {"red", "orange", "green"}),
        needlethickness = getParam(box, "needlethickness") or 5,
        needlehubsize = getParam(box, "needlehubsize") or 7,
        needlestartangle = getParam(box, "needlestartangle") or 150,
        needlesweepangle = getParam(box, "needlesweepangle") or 240,
        accentcolor = resolveThemeColor("accentcolor", getParam(box, "accentcolor"))
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    lcd.font(_G[c.bandlabelfont] or FONT_XS)
    local subtextHeight = select(2, lcd.getTextSize("Med")) + 2

    local titleHeight = 0
    if c.title then
        lcd.font(_G[c.titlefont] or FONT_XS)
        local _, th = lcd.getTextSize(c.title)
        titleHeight = (th or 0) + (c.titlespacing or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0)
    end

    local arcRegionY = y + subtextHeight
    local arcRegionH = h - subtextHeight - titleHeight
    local arcMargin = 2
    local usableW = w - arcMargin * 2
    local usableH = arcRegionH - arcMargin
    local thickness = c.thickness or math.max(6, math.min(usableW, usableH) * 0.25)
    local radius = math.min(usableW / 2, usableH) - (thickness / 2)
    if radius < 8 then radius = 8 end
    local cx = x + w / 2
    local cy = arcRegionY + arcRegionH / 2 + 15

    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

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
    lcd.font(_G[c.bandlabelfont] or FONT_XS)

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

        local tx = cx + labelRadius * math.cos(math.rad(midAngle))
        local ty = cy - labelRadius * math.sin(math.rad(midAngle))
        ty = ty + 12

        local label = c.bandlabels[i]
        if label then
            local tw, th = lcd.getTextSize(label)
            lcd.color(c.textcolor)
            lcd.drawText(tx - tw / 2, ty - th / 2, label)
        end
    end

    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.showvalue ~= false and c.displayValue or nil, c.showvalue ~= false and c.unit or nil, c.font,
        c.valuealign, c.textcolor, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, nil)
end

return render

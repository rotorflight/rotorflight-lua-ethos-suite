--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local resolveThresholdColor = utils.resolveThresholdColor
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

local function drawArc(cx, cy, radius, thickness, startAngle, endAngle, color)
    lcd.color(color)
    local outer = radius
    local inner = math.max(1, radius - (thickness or 6))

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
        percent = math.max(0, math.min(1, fuel / 100))
        mahUnit = string.format("%dmah", math.floor(consumption + 0.5))

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
        displayValue = displayValue,
        unit = unit,
        ringbatt = ringbatt,
        percent = percent,
        mahUnit = mahUnit,
        novalue = getParam(box, "novalue") or "-",
        fillcolor = resolveThresholdColor(value, box, "fillcolor", "fillcolor", getParam(box, "thresholds")),
        textcolor = resolveThresholdColor(value, box, "textcolor", "textcolor", thresholds),
        fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor")),
        bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        thresholds = getParam(box, "thresholds"),
        title = getParam(box, "title"),
        titlepos = getParam(box, "titlepos") or (getParam(box, "title") and "top"),
        titlealign = getParam(box, "titlealign"),
        titlefont = getParam(box, "titlefont"),
        titlespacing = getParam(box, "titlespacing"),
        titlepadding = getParam(box, "titlepadding"),
        titlepaddingleft = getParam(box, "titlepaddingleft"),
        titlepaddingright = getParam(box, "titlepaddingright"),
        titlepaddingtop = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        font = getParam(box, "font") or "FONT_M",
        decimals = getParam(box, "decimals"),
        valuealign = getParam(box, "valuealign"),
        valuepadding = getParam(box, "valuepadding"),
        valuepaddingleft = getParam(box, "valuepaddingleft"),
        valuepaddingright = getParam(box, "valuepaddingright"),
        valuepaddingtop = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        thickness = getParam(box, "thickness"),
        innerringcolor = resolveThemeColor("innerringcolor", getParam(box, "innerringcolor") or "white"),
        innerringthickness = getParam(box, "innerringthickness") or 8,
        ringbattsubalign = getParam(box, "ringbattsubalign"),
        ringbattsubpadding = getParam(box, "ringbattsubpadding") or 2,
        ringbattsubpaddingleft = getParam(box, "ringbattsubpaddingleft"),
        ringbattsubpaddingright = getParam(box, "ringbattsubpaddingright"),
        ringbattsubpaddingtop = getParam(box, "ringbattsubpaddingtop"),
        ringbattsubpaddingbottom = getParam(box, "ringbattsubpaddingbottom"),
        ringbattsubfont = getParam(box, "ringbattsubfont") or "FONT_XS"
    }

end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    local cx = x + w / 2

    local titleHeight = 0
    if c.title then
        lcd.font(_G[c.titlefont] or FONT_XS)
        local _, th = lcd.getTextSize(c.title)
        titleHeight = (th or 0) + (c.titlespacing or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0)
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
    local baseSize = math.min(w, h - (c.title and ringPadding * 2 or 0))
    local ringSize = math.min(0.88 * (c.title and 1 or 1.05), 1.0)
    local radius = baseSize * 0.5 * ringSize
    local thickness = c.thickness or math.max(8, radius * 0.18)

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

        lcd.font(_G[c.ringbattsubfont] or FONT_XS)
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

        lcd.font(_G[c.font] or FONT_M)
        local _, mainH = lcd.getTextSize("0")
        local centerY = y + h / 2
        local textY = centerY + mainH / 2 + padT - padB

        lcd.font(_G[c.ringbattsubfont] or FONT_XS)
        lcd.color(c.textcolor)
        lcd.drawText(textX, textY, c.mahUnit)
    end

    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.displayValue, c.unit, c.font, c.valuealign, c.textcolor, c.valuepadding, c.valuepaddingleft,
        c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, nil)
end

return render

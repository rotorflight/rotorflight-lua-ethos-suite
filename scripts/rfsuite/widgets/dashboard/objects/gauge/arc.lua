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

local function compileTransform(t, decimals)
    local pow = decimals and (10 ^ decimals) or nil
    local function round(v) return pow and (math.floor(v * pow + 0.5) / pow) or v end

    if type(t) == "number" then
        local mul = t
        return function(v) return round(v * mul) end
    elseif t == "floor" then
        return function(v) return math.floor(v) end
    elseif t == "ceil" then
        return function(v) return math.ceil(v) end
    elseif t == "round" or t == nil then
        return function(v) return round(v) end
    elseif type(t) == "function" then
        return t
    else
        return function(v) return v end
    end
end

function render.wakeup(box)
    local telemetry = rfsuite.tasks.telemetry

    local c = box._cache or {}
    box._cache = c

    local cfg = box._cfg
    if not cfg then
        cfg = {}
        cfg.title = getParam(box, "title")
        cfg.titlepos = getParam(box, "titlepos") or (cfg.title and "top" or nil)
        cfg.titlealign = getParam(box, "titlealign")
        cfg.titlefont = getParam(box, "titlefont")
        cfg.titlespacing = getParam(box, "titlespacing") or 0
        cfg.titlepadding = getParam(box, "titlepadding")
        cfg.titlepaddingleft = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")
        cfg.font = getParam(box, "font") or "FONT_M"
        cfg.maxfont = getParam(box, "maxfont") or "FONT_S"
        cfg.decimals = getParam(box, "decimals")
        cfg.valuealign = getParam(box, "valuealign")
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop") or 18
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.thickness = getParam(box, "thickness")
        cfg.maxprefix = getParam(box, "maxprefix") or "+"
        cfg.maxpadding = getParam(box, "maxpadding") or 0
        cfg.maxpaddingleft = getParam(box, "maxpaddingleft") or 0
        cfg.maxpaddingtop = getParam(box, "maxpaddingtop") or 0
        cfg.gaugepadding = getParam(box, "gaugepadding") or 0
        cfg.gaugepaddingbottom = getParam(box, "gaugepaddingbottom") or 0
        cfg.fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor"))
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.manualUnit = getParam(box, "unit")
        cfg.source = getParam(box, "source")
        cfg.transform = getParam(box, "transform")
        cfg.transformFn = compileTransform(cfg.transform, cfg.decimals)

        box._cfg = cfg
    end

    local source = cfg.source
    local minCfg = getParam(box, "min")
    local maxCfg = getParam(box, "max")
    local thresholdsCfg = getParam(box, "thresholds")

    local value, _, dynamicUnit, sensorMin, sensorMax, sensorThresholds
    if telemetry and source then value, _, dynamicUnit, sensorMin, sensorMax, sensorThresholds = telemetry.getSensor(source, minCfg, maxCfg, thresholdsCfg) end

    local arcmax = getParam(box, "arcmax") == true
    local maxval = nil
    if arcmax and source and telemetry then
        local stats = telemetry.getSensorStats(source)
        local currentMax = stats and stats.max or nil
        local prevMax = c.maxval or nil
        maxval = currentMax or prevMax
    end

    local manualUnit = cfg.manualUnit
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

    local min = sensorMin or minCfg or 0
    local max = sensorMax or maxCfg or 100
    local thresholds = sensorThresholds or thresholdsCfg

    local percent = 0
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end
    local maxPercent = 0
    if arcmax and maxval and max ~= min then
        maxPercent = (maxval - min) / (max - min)
        maxPercent = math.max(0, math.min(1, maxPercent))
    end

    local displayValue
    if value ~= nil then displayValue = cfg.transformFn(value) end

    local displayMaxValue = nil
    if arcmax and maxval ~= nil then displayMaxValue = cfg.transformFn(maxval) end

    if value == nil then
        local maxDots = 3
        if c._dotCount == nil then c._dotCount = 0 end
        c._dotCount = (c._dotCount + 1) % (maxDots + 1)
        displayValue = string.rep(".", c._dotCount)
        if displayValue == "" then displayValue = "." end
        unit = nil
    end

    if type(displayValue) == "string" and displayValue:match("^%.+$") then unit = nil end

    box._currentDisplayValue = value

    c.value = value
    c.maxval = maxval
    c.displayValue = displayValue
    c.displayMaxValue = displayMaxValue
    c.arcmax = arcmax
    c.min = min
    c.max = max
    c.percent = percent
    c.maxPercent = maxPercent
    c.unit = unit
    c.textcolor = resolveThresholdColor(value, box, "textcolor", "textcolor", thresholds)
    c.maxtextcolor = resolveThresholdColor(maxval, box, "maxtextcolor", "textcolor", thresholds)
    c.fillcolor = resolveThresholdColor(value, box, "fillcolor", "fillcolor", thresholds)
    c.maxfillcolor = resolveThresholdColor(maxval, box, "fillcolor", "fillcolor", thresholds)
    c.fillbgcolor = cfg.fillbgcolor
    c.bgcolor = cfg.bgcolor
    c.titlecolor = cfg.titlecolor
    c.title = cfg.title
    c.titlepos = cfg.titlepos
    c.titlealign = cfg.titlealign
    c.titlefont = cfg.titlefont
    c.titlespacing = cfg.titlespacing
    c.titlepadding = cfg.titlepadding
    c.titlepaddingleft = cfg.titlepaddingleft
    c.titlepaddingright = cfg.titlepaddingright
    c.titlepaddingtop = cfg.titlepaddingtop
    c.titlepaddingbottom = cfg.titlepaddingbottom
    c.font = cfg.font
    c.maxfont = cfg.maxfont
    c.valuealign = cfg.valuealign
    c.valuepadding = cfg.valuepadding
    c.valuepaddingleft = cfg.valuepaddingleft
    c.valuepaddingright = cfg.valuepaddingright
    c.valuepaddingtop = cfg.valuepaddingtop
    c.valuepaddingbottom = cfg.valuepaddingbottom
    c.thickness = cfg.thickness
    c.maxprefix = cfg.maxprefix
    c.maxpadding = cfg.maxpadding
    c.maxpaddingleft = cfg.maxpaddingleft
    c.maxpaddingtop = cfg.maxpaddingtop
    c.gaugepadding = cfg.gaugepadding
    c.gaugepaddingbottom = cfg.gaugepaddingbottom
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    local g = box._geom
    local needGeo = (not g) or g.w ~= w or g.h ~= h or g.title ~= c.title or g.titlefont ~= c.titlefont or g.titlespacing ~= (c.titlespacing or 0) or g.titlepaddingtop ~= (c.titlepaddingtop or 0) or g.titlepaddingbottom ~= (c.titlepaddingbottom or 0) or g.titlepos ~= c.titlepos or g.thickness ~= (c.thickness or 0) or g.gaugepadding ~= (c.gaugepadding or 0) or g.gaugepaddingbottom ~= (c.gaugepaddingbottom or 0)

    if needGeo then
        g = g or {}
        g.w, g.h = w, h
        g.title, g.titlefont = c.title, c.titlefont
        g.titlespacing = c.titlespacing or 0
        g.titlepaddingtop = c.titlepaddingtop or 0
        g.titlepaddingbottom = c.titlepaddingbottom or 0
        g.titlepos = c.titlepos
        g.thickness = c.thickness or math.max(6, math.min(w, h) * 0.07)
        g.gaugepadding = c.gaugepadding or 0
        g.gaugepaddingbottom = c.gaugepaddingbottom or 0

        local titleHeight = 0
        if c.title then
            lcd.font(_G[c.titlefont] or FONT_XS)
            local _, th = lcd.getTextSize(c.title)
            titleHeight = (th or 0) + g.titlespacing + g.titlepaddingtop + g.titlepaddingbottom
        end

        local arcRegionY, arcRegionH, cy
        if c.titlepos == "top" then
            arcRegionY = y + titleHeight
            arcRegionH = h - titleHeight - g.gaugepaddingbottom
            cy = arcRegionY + arcRegionH * 0.5
        elseif c.titlepos == "bottom" then
            arcRegionY = y
            arcRegionH = h - titleHeight - g.gaugepaddingbottom
            cy = arcRegionY + arcRegionH * 0.6
        else
            arcRegionY = y
            arcRegionH = h - g.gaugepaddingbottom
            cy = arcRegionY + arcRegionH * 0.55
        end

        local thickness = g.thickness
        local maxRadius = (arcRegionH / 2) - (thickness / 2)
        local radius = math.min((w / 2) - g.gaugepadding, maxRadius + 8)

        g.cx = x + w / 2
        g.cy = cy
        g.radius = radius

        local startAngle = 225
        g.startAngle = startAngle
        g.endAngleFull = (startAngle + 270) % 360

        box._geom = g
    end

    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    drawArc(g.cx, g.cy, g.radius, c.thickness, g.startAngle, g.endAngleFull, c.fillbgcolor)

    if c.percent and c.percent > 0 then
        local valueEndAngle = (g.startAngle + 270 * c.percent) % 360
        drawArc(g.cx, g.cy, g.radius, c.thickness, g.startAngle, valueEndAngle, c.fillcolor)
    end

    if c.arcmax and c.maxval and c.max ~= c.min and c.maxPercent > 0 then
        local innerRadius = g.radius * 0.74
        local innerThickness = (c.thickness or g.thickness) * 0.8
        local maxEndAngle = (g.startAngle + 270 * c.maxPercent) % 360
        drawArc(g.cx, g.cy, innerRadius, innerThickness, g.startAngle, maxEndAngle, c.maxfillcolor)
    end

    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.displayValue, c.unit, c.font, c.valuealign, c.textcolor, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, nil)

    if c.arcmax and c.maxval then
        local maxStr = tostring(c.maxprefix or "") .. (c.displayMaxValue or c.maxval) .. (c.unit or "")
        local maxTextColor = c.maxtextcolor or c.textcolor
        lcd.color(maxTextColor)
        lcd.font(_G[c.maxfont] or FONT_S)
        local tw2, th2 = lcd.getTextSize(maxStr)
        lcd.drawText(g.cx - tw2 / 2 + (c.maxpaddingleft or 0), g.cy + g.radius * 0.25 + (c.maxpadding or 0) + (c.maxpaddingtop or 0), maxStr)
    end
end

return render

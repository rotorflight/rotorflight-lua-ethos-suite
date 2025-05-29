local render = {}

rfsuite.session.dialImageCache = rfsuite.session.dialImageCache or {}

-- Helper: resolves dial or pointer value to an image path
local function resolveDialAsset(value, basePath)
    if type(value) == "function" then
        value = value()
    end
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

local function loadDialPanelCached(dialId)
    local key = tostring(dialId or "panel1")
    if not rfsuite.session.dialImageCache[key] then
        local panelPath = resolveDialAsset(dialId, "widgets/dashboard/gfx/dials") or "widgets/dashboard/gfx/dials/panel1.png"
        rfsuite.session.dialImageCache[key] = rfsuite.utils.loadImage(panelPath)
    end
    return rfsuite.session.dialImageCache[key]
end

local function calDialAngle(percent, startAngle, sweepAngle)
    return (startAngle or 315) + (sweepAngle or 270) * (percent or 0) / 100
end

local function computeDrawArea(img, x, y, w, h, aspect, align)
    local iw, ih = img:width(), img:height()
    local drawW, drawH = w, h

    if aspect == "fit" then
        local scale = math.min(w / iw, h / ih)
        drawW = iw * scale
        drawH = ih * scale
    elseif aspect == "fill" then
        local scale = math.max(w / iw, h / ih)
        drawW = iw * scale
        drawH = ih * scale
    elseif not aspect or aspect == "original" then
        drawW = iw
        drawH = ih
    end

    local drawX, drawY = x, y
    align = align or "center"
    if align:find("right") then
        drawX = x + w - drawW
    elseif align:find("center") or not align:find("left") then
        drawX = x + (w - drawW) / 2
    end
    if align:find("bottom") then
        drawY = y + h - drawH
    elseif align:find("center") or not align:find("top") then
        drawY = y + (h - drawH) / 2
    end

    return drawX, drawY, drawW, drawH
end

function render.wakeup(box, telemetry)
    -- Value logic
    local value = nil
    local source = rfsuite.widgets.dashboard.utils.getParam(box, "source")
    if source then
        local sensor = telemetry and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
        local transform = rfsuite.widgets.dashboard.utils.getParam(box, "transform")
        if type(transform) == "string" and math[transform] then
            value = value and math[transform](value)
        elseif type(transform) == "function" then
            value = value and transform(value)
        elseif type(transform) == "number" then
            value = value and transform(value)
        end
    end
    local displayValue
    local unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit") or ""

    if value ~= nil then
        displayValue = value
    else
        displayValue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
        unit = nil --Suppress unit if using fallback
    end
    local min = rfsuite.widgets.dashboard.utils.getParam(box, "min") or 0
    local max = rfsuite.widgets.dashboard.utils.getParam(box, "max") or 100
    local percent = 0
    if value and max ~= min then
        percent = ((value - min) / (max - min)) * 100
        percent = math.max(0, math.min(100, percent))
    end

    local dialId = rfsuite.widgets.dashboard.utils.getParam(box, "dial")
    local panelImg = loadDialPanelCached(dialId)
    local aspect = rfsuite.widgets.dashboard.utils.getParam(box, "aspect")
    local align = rfsuite.widgets.dashboard.utils.getParam(box, "align") or "center"

    -- Needle/hub parameters
    local needleColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "needlecolor")) or lcd.RGB(255, 0, 0)
    local hubColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "needlehubcolor")) or lcd.RGB(0, 0, 0)
    local needleThickness = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "needlethickness")) or 3
    local hubRadius = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "needlehubsize")) or (math.max(2, needleThickness + 2))

    local needleStartAngle = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "needlestartangle")) or 135
    local needleEndAngle = rfsuite.widgets.dashboard.utils.getParam(box, "needleendangle")
    if needleEndAngle then
        needleEndAngle = tonumber(needleEndAngle)
    end
    local sweep
    if needleEndAngle then
        sweep = (needleEndAngle - needleStartAngle)
        if math.abs(sweep) > 180 then
            if sweep > 0 then
                sweep = sweep - 360
            else
                sweep = sweep + 360
            end
        end
    else
        sweep = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "needlesweepangle")) or 270
    end

    -- Other params
    local bgcolor = rfsuite.widgets.dashboard.utils.resolveColor(
        rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor")
    ) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    local title = rfsuite.widgets.dashboard.utils.getParam(box, "title")

    box._cache = {
        value = value,
        displayValue = displayValue,
        unit = unit,
        percent = percent,
        min = min,
        max = max,
        dialId = dialId,
        panelImg = panelImg,
        aspect = aspect,
        align = align,
        needleColor = needleColor,
        hubColor = hubColor,
        needleThickness = needleThickness,
        hubRadius = hubRadius,
        needleStartAngle = needleStartAngle,
        sweep = sweep,
        bgcolor = bgcolor,
        title = title,
    }
end

function render.paint(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Draw background
    local bgcolor = c.bgcolor or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.color(bgcolor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Draw dial panel image
    local drawX, drawY, drawW, drawH = x, y, w, h
    if c.panelImg then
        drawX, drawY, drawW, drawH = computeDrawArea(c.panelImg, x, y, w, h, c.aspect, c.align)
        lcd.drawBitmap(drawX, drawY, c.panelImg, drawW, drawH)
    end

    -- Draw needle/hub
    if c.value ~= nil then
        local angle = calDialAngle(c.percent, c.needleStartAngle, c.sweep)
        local cx = drawX + drawW / 2
        local cy = drawY + drawH / 2
        local radius = math.min(drawW, drawH) * 0.40
        local needleLength = radius - 6

        if c.percent and type(c.percent) == "number" and not (c.percent ~= c.percent) then
            rfsuite.widgets.dashboard.utils.drawBarNeedle(cx, cy, needleLength, c.needleThickness, angle, c.needleColor)
        end

        lcd.color(c.hubColor)
        lcd.drawFilledCircle(cx, cy, c.hubRadius)
    end

    -- Optional title
    if c.title then
        lcd.font(FONT_XS)
        local tW, tH = lcd.getTextSize(c.title)
        tW = tW or 0
        tH = tH or 0
        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawText(x + (w - tW) / 2, y + h - tH, c.title)
    end

    -- Value display
    if c.displayValue ~= nil then
        lcd.font(FONT_STD)
        local str = tostring(c.displayValue or "") .. (c.unit or "")
        if str == "" then str = "-" end
        local vW, vH = lcd.getTextSize(str)
        vW = vW or 0
        vH = vH or 0
        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawText(x + (w - vW) / 2, y + h - vH - 16, str)
    end
end

return render

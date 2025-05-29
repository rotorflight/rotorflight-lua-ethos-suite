-- battery.lua (aligned with gauge.lua style and proper title layout)

local render = {}

function render.wakeup(box, telemetry)
    local value
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

    local min = rfsuite.widgets.dashboard.utils.getParam(box, "gaugemin") or 0
    if type(min) == "function" then min = min() end
    local max = rfsuite.widgets.dashboard.utils.getParam(box, "gaugemax") or 100
    if type(max) == "function" then max = max() end
    local percent = 0
    if value and max ~= min then
        percent = ((value - min) / (max - min))
        percent = math.max(0, math.min(1, percent))
    end

    local orientation = rfsuite.widgets.dashboard.utils.getParam(box, "gaugeorientation") or "horizontal"
    local title = rfsuite.widgets.dashboard.utils.getParam(box, "title")
    local titlepos = rfsuite.widgets.dashboard.utils.getParam(box, "titlepos") or "bottom"
    local titlepadding = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "titlepadding")) or 1
    local showValue = rfsuite.widgets.dashboard.utils.getParam(box, "showvalue")
    local valueFormat = rfsuite.widgets.dashboard.utils.getParam(box, "valueformat")
    local unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit")
    local valueColor = rfsuite.widgets.dashboard.utils.resolveColor(
        rfsuite.widgets.dashboard.utils.getParam(box, "valuecolor")
    )
    local valueFontSize = rfsuite.widgets.dashboard.utils.getParam(box, "valuefontsize")
    if type(valueFontSize) == "string" then
        valueFontSize = _G[valueFontSize]
    end
    local fontList = rfsuite.widgets.dashboard.utils.getFontListsForResolution().value_default
    local gaugepadding = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "gaugepadding")) or 2
    local gaugeSegments = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "gaugesegments")) or 6
    local gaugeFrameColor = rfsuite.widgets.dashboard.utils.resolveColor(
        rfsuite.widgets.dashboard.utils.getParam(box, "gaugeframecolor")) or lcd.RGB(255, 255, 255)
    local gaugeColor = rfsuite.widgets.dashboard.utils.resolveColor(
        rfsuite.widgets.dashboard.utils.getParam(box, "gaugecolor")) or lcd.RGB(0, 255, 0)

    local thresholds = rfsuite.widgets.dashboard.utils.getParam(box, "thresholds")
    if type(thresholds) == "table" and value then
        for _, threshold in ipairs(thresholds) do
            local thresholdValue = threshold.value
            if type(thresholdValue) == "function" then
                thresholdValue = thresholdValue()
            end
            if value <= thresholdValue then
                if threshold.color then
                    gaugeColor = rfsuite.widgets.dashboard.utils.resolveColor(threshold.color)
                end
                if threshold.valuecolor then
                    valueColor = rfsuite.widgets.dashboard.utils.resolveColor(threshold.valuecolor)
                end
                break
            end
        end
    end

    box._cache = {
        value = value,
        percent = percent or 0,
        orientation = orientation,
        title = title,
        titlepos = titlepos,
        titlepadding = titlepadding,
        showValue = showValue == true or showValue == "true",
        valueFormat = valueFormat,
        unit = unit,
        valueColor = valueColor,
        valueFontSize = valueFontSize,
        fontList = fontList,
        gaugepadding = gaugepadding,
        gaugeSegments = gaugeSegments,
        gaugeframecolor = gaugeFrameColor,
        gaugecolor = gaugeColor,
        gaugebgcolor = rfsuite.widgets.dashboard.utils.resolveColor(
            rfsuite.widgets.dashboard.utils.getParam(box, "gaugebgcolor")) or lcd.RGB(0, 0, 0)
    }
end

local function drawBattery(x, y, w, h, percent, orientation, padding, segments, c)
    percent = percent or 0
    padding = padding or 2
    local capW, capH = 4, h / 3
    local bodyW, bodyH = w - capW, h
    if orientation == "vertical" then
        capW, capH = w / 3, 4
        bodyW, bodyH = w, h - capH
    end

    lcd.color(c.gaugeframecolor or lcd.RGB(255, 255, 255))
    lcd.drawFilledRectangle(x, y, bodyW, bodyH)
    lcd.color(c.gaugebgcolor)
    lcd.drawFilledRectangle(x + padding, y + padding, bodyW - 2 * padding, bodyH - 2 * padding)

    lcd.color(c.gaugecolor)
    local filled = math.floor(percent * segments + 0.5)
    local spacing = 2

    if orientation == "horizontal" then
        local segW = math.floor((bodyW - 2 * padding - (segments - 1) * spacing) / segments)
        local segH = bodyH - 2 * padding
        for i = 1, filled do
            local sx = x + padding + (i - 1) * (segW + spacing)
            lcd.drawFilledRectangle(sx, y + padding, segW, segH)
        end
    else
        local segH = math.floor((bodyH - 2 * padding - (segments - 1) * spacing) / segments)
        local segW = bodyW - 2 * padding
        for i = 1, filled do
            local sy = y + bodyH - padding - i * (segH + spacing) + spacing
            lcd.drawFilledRectangle(x + padding, sy, segW, segH)
        end
    end

    lcd.color(c.gaugeframecolor or lcd.RGB(200, 200, 200))
    if orientation == "horizontal" then
        lcd.drawFilledRectangle(x + bodyW, y + (h - capH) / 2, capW, capH)
    else
        lcd.drawFilledRectangle(x + (w - capW) / 2, y - capH, capW, capH)
    end
end

function render.paint(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local c = box._cache or {}

    local titleH = 0
    if c.title then
        lcd.font(FONT_XS)
        local _, th = lcd.getTextSize(c.title)
        titleH = th + c.titlepadding
    end

    local drawX, drawY, drawW, drawH = x, y, w, h
    if c.title and c.titlepos == "top" then
        drawY = y + titleH
        drawH = h - titleH
    elseif c.title and c.titlepos == "bottom" then
        drawH = h - titleH
    end

    local segments = c.gaugeSegments or 6
    drawBattery(drawX, drawY, drawW, drawH, c.percent or 0, c.orientation, c.gaugepadding, segments, c)

    if c.showValue and c.value ~= nil then
        local str = tostring(c.value)
        if c.valueFormat and type(c.value) == "number" then
            str = string.format(c.valueFormat, c.value)
        end
        if c.unit then
            str = str .. c.unit
        end
        local color = c.valueColor or lcd.RGB(255, 255, 255)
        local fontList = rfsuite.widgets.dashboard.utils.getFontListsForResolution().value_default
        lcd.color(color)

        local function drawTextFit()
            local strForWidth = (c.unit == "°" or (c.unit and tostring(c.unit):find("°"))) and (tostring(c.value) .. "0") or str
            local innerX = drawX + c.gaugepadding
            local innerY = drawY + c.gaugepadding
            local innerW = drawW - 2 * c.gaugepadding
            local innerH = drawH - 2 * c.gaugepadding
            if c.orientation == "vertical" then
                innerH = innerH - 4
            end

            local bestFont, bestW, bestH = FONT_XXS, 0, 0
            for _, font in ipairs(fontList) do
                lcd.font(font)
                local tw, th = lcd.getTextSize(strForWidth)
                if tw <= innerW and th <= innerH then
                    bestFont, bestW, bestH = font, tw, th
                else
                    break
                end
            end

            lcd.font(bestFont)
            local sx = innerX + math.floor((innerW - bestW) / 2 + 0.5)
            -- Shift slightly *down* (5–10% of height)
            local verticalOffset = math.floor(bestH * 0.07 + 0.5)
            local sy = innerY + math.floor((innerH - bestH) / 2 + 0.5) + verticalOffset
            lcd.drawText(sx, sy, str)
        end

        if c.valueFontSize and type(c.valueFontSize) == "number" then
            lcd.font(c.valueFontSize)
            local tw, th = lcd.getTextSize(str)
            local innerX = drawX + c.gaugepadding
            local innerY = drawY + c.gaugepadding
            local innerW = drawW - 2 * c.gaugepadding
            local innerH = drawH - 2 * c.gaugepadding
            if c.orientation == "vertical" then
                innerH = innerH - 4
            end
            if tw <= innerW and th <= innerH then
                lcd.drawText(innerX + (innerW - tw) / 2, innerY + (innerH - th) / 2, str)
            else
                drawTextFit()
            end
        else
            drawTextFit()
        end
    end

    if c.title then
        lcd.font(FONT_XS)
        local tw, th = lcd.getTextSize(c.title)
        local tx = x + (w - tw) / 2
        local ty = (c.titlepos == "top") and (y) or (y + h - th)
        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawText(tx, ty, c.title)
    end
end

return render

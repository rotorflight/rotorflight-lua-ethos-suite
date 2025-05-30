local render = {}

function render.wakeup(box, telemetry)
    local utils = rfsuite.widgets.dashboard.utils
    local getParam = utils.getParam
    local resolveColor = utils.resolveColor

    -- Value extraction and transform
    local value
    local source = getParam(box, "source")
    if source then
        local sensor = telemetry and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
        local transform = getParam(box, "transform")
        if type(transform) == "string" and math[transform] then
            value = value and math[transform](value)
        elseif type(transform) == "function" then
            value = value and transform(value)
        elseif type(transform) == "number" then
            value = value and transform(value)
        end
    end

    -- Gauge logic
    local min = getParam(box, "gaugemin") or 0
    if type(min) == "function" then min = min() end
    local max = getParam(box, "gaugemax") or 100
    if type(max) == "function" then max = max() end
    local percent = 0
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end

    -- Compose display value
    local displayValue = "-"
    if value ~= nil then
        local valueFormat = getParam(box, "valueformat")
        if valueFormat and type(value) == "number" then
            displayValue = string.format(valueFormat, value)
        else
            displayValue = tostring(value)
        end
        local unit = getParam(box, "unit")
        if unit then displayValue = displayValue .. unit end
    else
        displayValue = getParam(box, "novalue") or "-"
    end

    -- Color resolution (may be overridden by thresholds)
    local textcolor   = resolveColor(getParam(box, "textcolor")) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
    local bgcolor     = resolveColor(getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    local fillcolor   = resolveColor(getParam(box, "fillcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    local fillbgcolor = resolveColor(getParam(box, "fillbgcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    local framecolor  = resolveColor(getParam(box, "framecolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    local titlecolor  = resolveColor(getParam(box, "titlecolor")) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))

    -- Threshold logic: override colors if needed
    local thresholds = getParam(box, "thresholds")
    if type(thresholds) == "table" and value then
        for _, t in ipairs(thresholds) do
            local tval = (type(t.value) == "function") and t.value() or t.value
            if value <= tval then
                if t.fillcolor then fillcolor = resolveColor(t.fillcolor) end
                if t.textcolor  then textcolor = resolveColor(t.textcolor)  end
                break
            end
        end
    end

    -- Store all box-relevant fields in cache
    box._cache = {
        displayValue       = displayValue,
        bgcolor            = bgcolor,
        textcolor          = textcolor,
        fillcolor          = fillcolor,
        fillbgcolor        = fillbgcolor,
        framecolor         = framecolor,
        titlecolor         = titlecolor,
        title              = getParam(box, "title"),
        titlealign         = getParam(box, "titlealign"),
        valuealign         = getParam(box, "valuealign"),
        titlepos           = getParam(box, "titlepos"),
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        font               = getParam(box, "font"),
        percent            = percent,
        orientation        = getParam(box, "gaugeorientation") or "horizontal",
        gaugepadding       = tonumber(getParam(box, "gaugepadding")) or 2,
        gaugeSegments      = tonumber(getParam(box, "gaugesegments")) or 6,
        showValue          = getParam(box, "showvalue") == true or getParam(box, "showvalue") == "true",
    }
end

local function drawBatteryBar(x, y, w, h, percent, orientation, padding, segments, c)
    percent = percent or 0
    padding = padding or 2
    local capW, capH = 4, h / 3
    local bodyW, bodyH = w - capW, h
    if orientation == "vertical" then
        capW, capH = w / 3, 4
        bodyW, bodyH = w, h - capH
    end

    lcd.color(c.framecolor)
    lcd.drawFilledRectangle(x, y, bodyW, bodyH)
    lcd.color(c.fillbgcolor)
    lcd.drawFilledRectangle(x + padding, y + padding, bodyW - 2 * padding, bodyH - 2 * padding)

    lcd.color(c.fillcolor)
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

    lcd.color(c.framecolor)
    if orientation == "horizontal" then
        lcd.drawFilledRectangle(x + bodyW, y + (h - capH) / 2, capW, capH)
    else
        lcd.drawFilledRectangle(x + (w - capW) / 2, y - capH, capW, capH)
    end
end

function render.paint(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local c = box._cache or {}

    drawBatteryBar(
        x, y, w, h,
        c.percent or 0, c.orientation, c.gaugepadding, c.gaugeSegments, c
    )

    -- Text/title/value box
    rfsuite.widgets.dashboard.utils.box(
        x, y, w, h,
        c.title, c.displayValue, nil, c.bgcolor,
        c.titlealign, c.valuealign, c.titlecolor, c.titlepos,
        c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.font, c.textcolor
    )
end

return render

local render = {}

-- Draw a solid ring by overlaying two filled circles
local function drawSolidRing(cx, cy, radius, thickness, fillcolor, fillbgcolor)
    lcd.color(fillcolor)
    lcd.drawFilledCircle(cx, cy, radius)
    lcd.color(fillbgcolor)
    lcd.drawFilledCircle(cx, cy, radius - thickness)
end

function render.wakeup(box, telemetry)
    local utils = rfsuite.widgets.dashboard.utils
    local getParam, resolveColor = utils.getParam, utils.resolveColor

    local ringsize = getParam(box, "ringsize") or 0.88
    ringsize = math.max(0.1, math.min(ringsize, 1.0))

    local source = getParam(box, "source")
    local value
    if source and telemetry and telemetry.getSensorSource then
        local sensor = telemetry.getSensorSource(source)
        if sensor and sensor.value then
            value = sensor:value()
        end
    end

    -- Transform (floor, ceil, round, or function)
    local transform = getParam(box, "transform")
    if value ~= nil and transform ~= nil then
        if type(transform) == "function" then
            value = transform(value)
        elseif transform == "floor" then
            value = math.floor(value)
        elseif transform == "ceil" then
            value = math.ceil(value)
        elseif transform == "round" then
            value = math.floor(value + 0.5)
        end
    end

    local min = getParam(box, "min")
    local max = getParam(box, "max")
    if type(min) == "function" then min = min() end
    if type(max) == "function" then max = max() end
    if min ~= nil and max ~= nil and value ~= nil then
        value = math.max(min, math.min(max, value))
    end

    local fillbgcolor = resolveColor(getParam(box, "fillbgcolor")) or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240))
    local fillcolor = resolveColor(getParam(box, "fillcolor")) or lcd.RGB(0,200,0)

    local thresholds = getParam(box, "thresholds")
    if thresholds and value ~= nil then
        -- Last threshold as default, then override on match
        local last = thresholds[#thresholds]
        fillcolor = (last.fillcolor and resolveColor(last.fillcolor)) or fillcolor
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            local t_color = t.fillcolor and resolveColor(t.fillcolor)
            if value < t_val and t_color then
                fillcolor = t_color
                break
            end
        end
    end

    local textcolor = resolveColor(getParam(box, "textcolor")) or lcd.RGB(255,255,255)

    box._cache = {
        ringsize = ringsize,
        value = value,
        fillcolor = fillcolor,
        fillbgcolor = fillbgcolor,
        thresholds = thresholds,
        novalue = getParam(box, "novalue") or "-",
        unit = (value ~= nil) and getParam(box, "unit") or nil,
        textcolor = textcolor,
        textalign = getParam(box, "textalign") or "center",
        textoffset = getParam(box, "textoffset") or 0,
        title = getParam(box, "title"),
        titlealign = getParam(box, "titlealign") or "center",
        titlepos = getParam(box, "titlepos") or "above",
        titleoffset = getParam(box, "titleoffset") or 0,
        bgcolor = resolveColor(getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240)),
    }
end

function render.paint(x, y, w, h, box)
    local c = box._cache or {}
    local ringsize = c.ringsize or 0.88
    local value = c.value
    local fillcolor = c.fillcolor or lcd.RGB(0,200,0)
    local fillbgcolor = c.fillbgcolor or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240))
    local novalue = c.novalue or "-"
    local unit = c.unit or ""
    local textcolor = c.textcolor or lcd.RGB(255,255,255)
    local textalign = c.textalign or "center"
    local textoffset = c.textoffset or 0
    local title = c.title
    local titlealign = c.titlealign or "center"
    local titlepos = c.titlepos or "above"
    local titleoffset = c.titleoffset or 0

    local cx = x + w / 2
    local cy = y + h / 2
    local radius = math.min(w, h) * 0.5 * ringsize
    local thickness = math.max(8, radius * 0.18)

    lcd.color(c.bgcolor or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240)))
    lcd.drawFilledRectangle(x, y, w, h)

    drawSolidRing(cx, cy, radius, thickness, fillcolor, fillbgcolor)

    local displayValue = value or novalue
    local valStr = tostring(displayValue) .. (unit or "")

    local fontSizes = {"FONT_XXL", "FONT_XL", "FONT_L", "FONT_M", "FONT_S"}
    local maxWidth = radius * 1.6
    local maxHeight = radius * 0.7
    local bestFont = FONT_XXL
    local vw, vh

    for _, fname in ipairs(fontSizes) do
        lcd.font(_G[fname])
        local tw, th = lcd.getTextSize(valStr)
        if tw <= maxWidth and th <= maxHeight then
            bestFont = _G[fname]
            vw, vh = tw, th
            break
        end
    end
    if not vw then
        lcd.font(_G[fontSizes[#fontSizes]])
        vw, vh = lcd.getTextSize(valStr)
        bestFont = _G[fontSizes[#fontSizes]]
    end
    lcd.font(bestFont)

    lcd.color(textcolor)
    local text_x
    if textalign == "left" then
        text_x = cx - radius + 8
    elseif textalign == "right" then
        text_x = cx + radius - vw - 8
    else
        text_x = cx - vw / 2
    end

    if title then
        lcd.font(FONT_XS)
        local tw, th = lcd.getTextSize(title)
        lcd.color(lcd.RGB(255, 255, 255))
        local title_x
        if titlealign == "left" then
            title_x = cx - radius + 4
        elseif titlealign == "right" then
            title_x = cx + radius - tw - 4
        else
            title_x = cx - tw / 2
        end
        local title_y
        if titlepos == "below" then
            title_y = cy + vh / 2 + 2 + titleoffset
        else
            title_y = cy - vh / 2 - th - 2 + titleoffset
        end
        if title_y < y then title_y = y + 2 end
        if title_y + th > y + h then title_y = y + h - th - 2 end

        lcd.drawText(title_x, title_y, title)
    end

    lcd.font(bestFont)
    lcd.color(textcolor)
    lcd.drawText(text_x, cy - vh / 2 + textoffset, valStr)
end

return render

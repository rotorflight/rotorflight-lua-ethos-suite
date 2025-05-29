local render = {}

-- Draw a solid ring by overlaying two filled circles
local function drawSolidRing(cx, cy, radius, thickness, ringColor, bgColor)
    lcd.color(ringColor)
    lcd.drawFilledCircle(cx, cy, radius)
    lcd.color(bgColor)
    lcd.drawFilledCircle(cx, cy, radius - thickness)
end

function render.wakeup(box, telemetry)
    local ringsize = rfsuite.widgets.dashboard.utils.getParam(box, "ringsize") or 0.88
    ringsize = math.max(0.1, math.min(ringsize, 1.0))

    local source = rfsuite.widgets.dashboard.utils.getParam(box, "source")
    local value
    if source and telemetry and telemetry.getSensorSource then
        local sensor = telemetry.getSensorSource(source)
        if sensor and sensor.value then
            value = sensor:value()
        end
    end

    -- Transform (floor, ceil, round, or function)
    local transform = rfsuite.widgets.dashboard.utils.getParam(box, "transform")
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

    -- Min/Max scaling/clamping
    local min = rfsuite.widgets.dashboard.utils.getParam(box, "min")
    local max = rfsuite.widgets.dashboard.utils.getParam(box, "max")
    if type(min) == "function" then min = min() end
    if type(max) == "function" then max = max() end
    if min ~= nil and max ~= nil and value ~= nil then
        value = math.max(min, math.min(max, value))
    end

    local ringColor = rfsuite.widgets.dashboard.utils.resolveColor(
        rfsuite.widgets.dashboard.utils.getParam(box, "ringColor")
    ) or lcd.RGB(0,200,0)
    local thresholds = rfsuite.widgets.dashboard.utils.getParam(box, "thresholds")

    if thresholds and value ~= nil then
        -- Always set to last color as default
        local last = thresholds[#thresholds]
        local t_color = type(last.color) == "function" and last.color(box, value) or last.color
        ringColor = rfsuite.widgets.dashboard.utils.resolveColor(t_color) or ringColor

        for i, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            local t_color = type(t.color) == "function" and t.color(box, value) or t.color
            if value < t_val then
                if type(t_color) == "number" then
                    ringColor = t_color
                else
                    ringColor = rfsuite.widgets.dashboard.utils.resolveColor(t_color) or ringColor
                end
                break
            end
        end
    end

    box._cache = {
        ringsize = ringsize,
        value = value,
        ringColor = ringColor,
        thresholds = thresholds,
        novalue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-",
        unit = (value ~= nil) and rfsuite.widgets.dashboard.utils.getParam(box, "unit") or nil,
        textColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "textColor")) or lcd.RGB(255,255,255),
        textalign = rfsuite.widgets.dashboard.utils.getParam(box, "textalign") or "center",
        textoffset = rfsuite.widgets.dashboard.utils.getParam(box, "textoffset") or 0,
        title = rfsuite.widgets.dashboard.utils.getParam(box, "title"),
        titlealign = rfsuite.widgets.dashboard.utils.getParam(box, "titlealign") or "center",
        titlepos = rfsuite.widgets.dashboard.utils.getParam(box, "titlepos") or "above",
        titleoffset = rfsuite.widgets.dashboard.utils.getParam(box, "titleoffset") or 0,
        bgcolor = rfsuite.widgets.dashboard.utils.resolveColor(
            rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor")
        ) or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240)),
    }
end

function render.paint(x, y, w, h, box)
    local c = box._cache or {}
    local ringsize = c.ringsize or 0.88
    local value = c.value
    local ringColor = c.ringColor or lcd.RGB(0,200,0)
    local bgColor = c.bgcolor or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240))
    local novalue = c.novalue or "-"
    local unit = c.unit or ""
    local textColor = c.textColor or lcd.RGB(255,255,255)
    local textalign = c.textalign or "center"
    local textoffset = c.textoffset or 0
    local title = c.title
    local titlealign = c.titlealign or "center"
    local titlepos = c.titlepos or "above"
    local titleoffset = c.titleoffset or 0

    -- Geometry
    local cx = x + w / 2
    local cy = y + h / 2
    local radius = math.min(w, h) * 0.5 * ringsize
    local thickness = math.max(8, radius * 0.18)

    -- Background
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Draw ring (solid style)
    drawSolidRing(cx, cy, radius, thickness, ringColor, bgColor)

    -- Value text
    local displayValue = value or novalue
    local valStr = tostring(displayValue) .. (unit or "")

    -- Auto-size value font to fit inside ring
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

    lcd.color(textColor)
    local text_x
    if textalign == "left" then
        text_x = cx - radius + 8
    elseif textalign == "right" then
        text_x = cx + radius - vw - 8
    else
        text_x = cx - vw/2
    end

    -- Title text (above or below value)
    if title then
        lcd.font(FONT_XS)
        local tw, th = lcd.getTextSize(title)
        lcd.color(lcd.RGB(255,255,255))
        local title_x
        if titlealign == "left" then
            title_x = cx - radius + 4
        elseif titlealign == "right" then
            title_x = cx + radius - tw - 4
        else
            title_x = cx - tw/2
        end
        local title_y
        if titlepos == "below" then
            title_y = cy + vh/2 + 2 + titleoffset
        else
            title_y = cy - vh/2 - th - 2 + titleoffset
        end
        -- Clamp to widget area
        if title_y < y then title_y = y + 2 end
        if title_y + th > y + h then title_y = y + h - th - 2 end

        lcd.drawText(title_x, title_y, title)
    end

    -- Draw value text last
    lcd.font(bestFont)
    lcd.color(textColor)
    lcd.drawText(text_x, cy - vh/2 + textoffset, valStr)
end

return render

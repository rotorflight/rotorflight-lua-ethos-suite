local render = {}

-- Draw a solid ring by overlaying two filled circles
local function drawSolidRing(cx, cy, radius, thickness, ringColor, bgColor)
    -- Outer ring
    lcd.color(ringColor)
    lcd.drawFilledCircle(cx, cy, radius)
    -- Inner mask
    lcd.color(bgColor)
    lcd.drawFilledCircle(cx, cy, radius - thickness)
end

function render.heatring(x, y, w, h, box, telemetry)
    -- Ring size (percentage of area)
    local ringsize = rfsuite.widgets.dashboard.utils.getParam(box, "ringsize") or 0.88
    ringsize = math.max(0.1, math.min(ringsize, 1.0))

    local cx = x + w / 2
    local cy = y + h / 2
    local radius = math.min(w, h) * 0.5 * ringsize
    local thickness = math.max(8, radius * 0.18)

    -- Background
    local bgColor = rfsuite.widgets.dashboard.utils.resolveColor(
        rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor")
    ) or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240))
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Value
    local value
    local source = rfsuite.widgets.dashboard.utils.getParam(box, "source")
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

    -- Draw ring (solid style: outer, then inner as mask)
    drawSolidRing(cx, cy, radius, thickness, ringColor, bgColor)

    -- Value text (centered, offset, aligned)
    local displayValue = value or rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
    local unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit") or ""
    local fontName = rfsuite.widgets.dashboard.utils.getParam(box, "font") or "FONT_XXL"
    lcd.font(_G[fontName] or FONT_XXL)
    local valStr = tostring(displayValue) .. unit
    local vw, vh = lcd.getTextSize(valStr)
    local textColor = rfsuite.widgets.dashboard.utils.resolveColor(
        rfsuite.widgets.dashboard.utils.getParam(box, "textColor")
    ) or lcd.RGB(255,255,255)
    lcd.color(textColor)
    local textalign = rfsuite.widgets.dashboard.utils.getParam(box, "textalign") or "center"
    local textoffset = rfsuite.widgets.dashboard.utils.getParam(box, "textoffset") or 0
    local text_x
    if textalign == "left" then
        text_x = cx - radius + 8
    elseif textalign == "right" then
        text_x = cx + radius - vw - 8
    else
        text_x = cx - vw/2
    end
    lcd.drawText(text_x, cy - vh/2 + textoffset, valStr)

    -- Title (above/below, align, offset)
    local title = rfsuite.widgets.dashboard.utils.getParam(box, "title")
    if title then
        lcd.font(FONT_XS)
        local tw, th = lcd.getTextSize(title)
        lcd.color(lcd.RGB(255,255,255))
        local titlealign = rfsuite.widgets.dashboard.utils.getParam(box, "titlealign") or "center"
        local titlepos = rfsuite.widgets.dashboard.utils.getParam(box, "titlepos") or "top"
        local titleoffset = rfsuite.widgets.dashboard.utils.getParam(box, "titleoffset") or 0
        local title_y
        if titlepos == "bottom" then
            title_y = cy + radius + thickness/2 + 4 + titleoffset
            if title_y > (y + h - th) then title_y = y + h - th - 2 end
        else
            title_y = cy - radius - thickness/2 - th - 4 + titleoffset
            if title_y < y then title_y = y + 2 end
        end
        local title_x
        if titlealign == "left" then
            title_x = cx - radius + 4
        elseif titlealign == "right" then
            title_x = cx + radius - tw - 4
        else
            title_x = cx - tw/2
        end
        lcd.drawText(title_x, title_y, title)
    end
end

return render

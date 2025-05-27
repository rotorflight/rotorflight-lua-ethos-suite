local render = {}



-- Draws an arc from angle1 to angle2 (degrees, counter-clockwise, 0°=right)
local function drawArc(cx, cy, radius, thickness, angleStart, angleEnd, color, cachedStepRad)
    local step = 4  -- degrees per circle
    local rad_thick = thickness / 2
    angleStart = math.rad(angleStart)
    angleEnd = math.rad(angleEnd)
    if angleEnd > angleStart then
        angleEnd = angleEnd - 2 * math.pi
    end
    lcd.color(color or lcd.RGB(255,128,0))
    local stepRad = cachedStepRad or math.rad(step)
    for a = angleStart, angleEnd, -stepRad do
        local x = cx + radius * math.cos(a)
        local y = cy - radius * math.sin(a)
        lcd.drawFilledCircle(x, y, rad_thick)
    end
    -- Ensure end cap is filled
    local x_end = cx + radius * math.cos(angleEnd)
    local y_end = cy - radius * math.sin(angleEnd)
    lcd.drawFilledCircle(x_end, y_end, rad_thick)
end


function render.arcgauge(x, y, w, h, box, telemetry)
    -- Cache only geometry/layout math (not getParam or resolveColor)
    box._layoutcache = box._layoutcache or {}
    local cache = box._layoutcache

    -- Only recalculate geometry when x/y/w/h/arcOffsetY changes
    local arcOffsetY = rfsuite.widgets.dashboard.utils.getParam(box, "arcOffsetY") or 0
    local layoutKey = string.format("%d,%d,%d,%d,%d", x, y, w, h, arcOffsetY)
    if cache._layoutKey ~= layoutKey then
        cache.cx = x + w / 2
        cache.cy = y + h / 2 - arcOffsetY
        cache.radius = math.min(w, h) * 0.42
        cache.thickness = math.max(6, cache.radius * 0.22)
        cache.stepRad = math.rad(4) -- for drawArc
        cache._layoutKey = layoutKey
    end

    local cx, cy, radius, thickness, stepRad = cache.cx, cache.cy, cache.radius, cache.thickness, cache.stepRad

    -- The rest: run as usual, DO NOT cache
    local bgColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    local min = rfsuite.widgets.dashboard.utils.getParam(box, "min") or 0
    local max = rfsuite.widgets.dashboard.utils.getParam(box, "max") or 100

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
            value = value and transform
        end
    end

    local displayValue = value or rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
    local displayUnit = rfsuite.widgets.dashboard.utils.getParam(box, "unit")
    min = rfsuite.widgets.dashboard.utils.getParam(box, "gaugemin") or 0
    max = rfsuite.widgets.dashboard.utils.getParam(box, "gaugemax") or 100

    local percent = 0
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end

    local startAngle = rfsuite.widgets.dashboard.utils.getParam(box, "startAngle") or 135
    local sweep = rfsuite.widgets.dashboard.utils.getParam(box, "sweep") or 270
    local endAngle = startAngle - sweep * percent

    -- Draw base arc
    drawArc(
        cx, cy, radius, thickness,
        startAngle, startAngle - sweep,
        rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "arcBgColor")) or lcd.RGB(55,55,55),
        stepRad
    )

    -- Draw value arc (with thresholds)
    local arcColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "arcColor")) or lcd.RGB(255,128,0)
    local thresholds = rfsuite.widgets.dashboard.utils.getParam(box, "thresholds")
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            local t_color = type(t.color) == "function" and t.color(box, value) or t.color
            if value < t_val then
                arcColor = rfsuite.widgets.dashboard.utils.resolveColor(t_color) or arcColor
                break
            end
        end
    end
    if percent > 0 then
        drawArc(cx, cy, radius, thickness, startAngle, endAngle, arcColor, stepRad)
    end


    -- Value text (centered)
    local fontName = rfsuite.widgets.dashboard.utils.getParam(box, "font")
    lcd.font(fontName and _G[fontName] or FONT_XL)
    lcd.color(rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "textColor")) or lcd.RGB(255,255,255))

    local valueFormat = rfsuite.widgets.dashboard.utils.getParam(box, "valueFormat")
    local unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit") or ""
    local decimals = rfsuite.widgets.dashboard.utils.getParam(box, "decimals")
    local valStr

    if valueFormat then
        valStr = valueFormat(value)
    elseif type(value) == "number" then
        if decimals ~= nil then
            -- Always use fixed decimal formatting if explicitly requested
            if decimals == 0 then
                valStr = string.format("%d", value)
            else
                valStr = string.format("%." .. decimals .. "f", value)
            end
        else
            -- Default smart formatting: remove .0 if unnecessary
            if math.floor(value) == value then
                valStr = string.format("%d", value)
            else
                valStr = string.format("%.1f", value)
            end
        end
    else
        valStr = "-"
    end

    valStr = valStr .. unit

    local tw, th = lcd.getTextSize(valStr)
    local xOffset = rfsuite.widgets.dashboard.utils.getParam(box, "textoffsetx") or 0
    lcd.drawText(cx - tw/2 + xOffset, cy - th/2, valStr)

    -- Title above, subText below
    local title = rfsuite.widgets.dashboard.utils.getParam(box, "title")
    if title then
        local titlepadding = rfsuite.widgets.dashboard.utils.getParam(box, "titlepadding") or 0
        local titlepaddingleft = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingleft") or titlepadding
        local titlepaddingright = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingright") or titlepadding
        local titlepaddingtop = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingtop") or titlepadding
        local titlepaddingbottom = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingbottom") or titlepadding

        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(title)
        local region_x = x + titlepaddingleft
        local region_w = w - titlepaddingleft - titlepaddingright
        local sy = (rfsuite.widgets.dashboard.utils.getParam(box, "titlepos") == "bottom")
            and (y + h - titlepaddingbottom - tsizeH)
            or (y + titlepaddingtop)
        local align = (rfsuite.widgets.dashboard.utils.getParam(box, "titlealign") or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - tsizeW
        else
            sx = region_x + (region_w - tsizeW) / 2
        end
        lcd.color(rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor")) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90)))
        lcd.drawText(sx, sy, title)
    end
    local subText = rfsuite.widgets.dashboard.utils.getParam(box, "subText")
    if subText then
        lcd.font(FONT_XS)
        local tw, th = lcd.getTextSize(subText)
        lcd.drawText(cx - tw/2, cy + radius * 0.55, subText)
    end
end


return render
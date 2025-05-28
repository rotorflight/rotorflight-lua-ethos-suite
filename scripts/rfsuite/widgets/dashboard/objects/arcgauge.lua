local render = {}

-- Arc drawing helper
local function drawArc(cx, cy, radius, thickness, angleStart, angleEnd, color, cachedStepRad)
    local step = 4
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
    local x_end = cx + radius * math.cos(angleEnd)
    local y_end = cy - radius * math.sin(angleEnd)
    lcd.drawFilledCircle(x_end, y_end, rad_thick)
end

-- Caches value, param, and display settings
function render.wakeup(box, telemetry)
    local min = rfsuite.widgets.dashboard.utils.getParam(box, "min") or 0
    local max = rfsuite.widgets.dashboard.utils.getParam(box, "max") or 100
    local gaugemin = rfsuite.widgets.dashboard.utils.getParam(box, "gaugemin") or min
    local gaugemax = rfsuite.widgets.dashboard.utils.getParam(box, "gaugemax") or max

    local source = rfsuite.widgets.dashboard.utils.getParam(box, "source")
    local value = nil
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

    local percent = 0
    if value and gaugemax ~= gaugemin then
        percent = (value - gaugemin) / (gaugemax - gaugemin)
        percent = math.max(0, math.min(1, percent))
    end

    -- Main config cache
    box._cache = {
        min = min,
        max = max,
        gaugemin = gaugemin,
        gaugemax = gaugemax,
        value = value,
        percent = percent,
        arcOffsetY = rfsuite.widgets.dashboard.utils.getParam(box, "arcOffsetY") or 0,
        startAngle = rfsuite.widgets.dashboard.utils.getParam(box, "startAngle") or 135,
        sweep = rfsuite.widgets.dashboard.utils.getParam(box, "sweep") or 270,
        arcBgColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "arcBgColor")) or lcd.RGB(55,55,55),
        arcColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "arcColor")) or lcd.RGB(255,128,0),
        thresholds = rfsuite.widgets.dashboard.utils.getParam(box, "thresholds"),
        font = rfsuite.widgets.dashboard.utils.getParam(box, "font"),
        textColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "textColor")) or lcd.RGB(255,255,255),
        valueFormat = rfsuite.widgets.dashboard.utils.getParam(box, "valueFormat"),
        unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit") or "",
        decimals = rfsuite.widgets.dashboard.utils.getParam(box, "decimals"),
        title = rfsuite.widgets.dashboard.utils.getParam(box, "title"),
        titlepadding = rfsuite.widgets.dashboard.utils.getParam(box, "titlepadding") or 0,
        titlepaddingleft = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingleft"),
        titlepaddingright = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingright"),
        titlepaddingtop = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingtop"),
        titlepaddingbottom = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingbottom"),
        titlepos = rfsuite.widgets.dashboard.utils.getParam(box, "titlepos"),
        titlealign = rfsuite.widgets.dashboard.utils.getParam(box, "titlealign"),
        titlecolor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor")) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90)),
        subText = rfsuite.widgets.dashboard.utils.getParam(box, "subText"),
        textoffsetx = rfsuite.widgets.dashboard.utils.getParam(box, "textoffsetx") or 0,
        novalue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-",
        bgcolor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240)),
    }
end

function render.paint(x, y, w, h, box)
    local c = box._cache or {}

    -- Geometry/layout caching (safe if cache missing)
    box._layoutcache = box._layoutcache or {}
    local layoutcache = box._layoutcache

    local arcOffsetY = c.arcOffsetY or 0
    local layoutKey = string.format("%d,%d,%d,%d,%d",
        math.floor(x + 0.5), math.floor(y + 0.5),
        math.floor(w + 0.5), math.floor(h + 0.5),
        math.floor(arcOffsetY + 0.5)
    )
    if layoutcache._layoutKey ~= layoutKey then
        layoutcache.cx = x + w / 2
        layoutcache.cy = y + h / 2 - arcOffsetY
        layoutcache.radius = math.min(w, h) * 0.42
        layoutcache.thickness = math.max(6, layoutcache.radius * 0.22)
        layoutcache.stepRad = math.rad(4)
        layoutcache._layoutKey = layoutKey
    end

    local cx, cy, radius, thickness, stepRad = layoutcache.cx, layoutcache.cy, layoutcache.radius, layoutcache.thickness, layoutcache.stepRad

    -- Paint everything else
    local bgColor = c.bgcolor or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    local min = c.min or 0
    local max = c.max or 100
    local value = c.value
    local percent = c.percent or 0
    local startAngle = c.startAngle or 135
    local sweep = c.sweep or 270
    local endAngle = startAngle - sweep * percent

    -- Base arc
    drawArc(cx, cy, radius, thickness, startAngle, startAngle - sweep, c.arcBgColor or lcd.RGB(55,55,55), stepRad)

    -- Value arc with thresholds
    local arcColor = c.arcColor or lcd.RGB(255,128,0)
    local thresholds = c.thresholds
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
    lcd.font(c.font and _G[c.font] or FONT_XL)
    lcd.color(c.textColor or lcd.RGB(255,255,255))

    local valStr
    if c.valueFormat then
        valStr = c.valueFormat(value)
    elseif type(value) == "number" then
        if c.decimals ~= nil then
            if c.decimals == 0 then
                valStr = string.format("%d", value)
            else
                valStr = string.format("%." .. c.decimals .. "f", value)
            end
        else
            if math.floor(value) == value then
                valStr = string.format("%d", value)
            else
                valStr = string.format("%.1f", value)
            end
        end
    else
        valStr = c.novalue or "-"
    end
    valStr = valStr .. (c.unit or "")
    local tw, th = lcd.getTextSize(valStr)
    lcd.drawText(cx - tw/2 + (c.textoffsetx or 0), cy - th/2, valStr)

    -- Title above, subText below
    local title = c.title
    if title then
        local titlepadding = c.titlepadding or 0
        local titlepaddingleft = c.titlepaddingleft or titlepadding
        local titlepaddingright = c.titlepaddingright or titlepadding
        local titlepaddingtop = c.titlepaddingtop or titlepadding
        local titlepaddingbottom = c.titlepaddingbottom or titlepadding
        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(title)
        local region_x = x + titlepaddingleft
        local region_w = w - titlepaddingleft - titlepaddingright
        local sy = (c.titlepos == "bottom")
            and (y + h - titlepaddingbottom - tsizeH)
            or (y + titlepaddingtop)
        local align = (c.titlealign or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - tsizeW
        else
            sx = region_x + (region_w - tsizeW) / 2
        end
        lcd.color(c.titlecolor)
        lcd.drawText(sx, sy, title)
    end

    local subText = c.subText
    if subText then
        lcd.font(FONT_XS)
        local tw, th = lcd.getTextSize(subText)
        lcd.drawText(cx - tw/2, cy + radius * 0.55, subText)
    end
end

return render

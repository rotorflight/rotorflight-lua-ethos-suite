local render = {}

-- Arc drawing helper
local function drawArc(cx, cy, radius, thickness, angleStart, angleEnd, color, cachedStepRad)
    local step = 1
    local rad_thick = thickness / 2
    angleStart = math.rad(angleStart)
    angleEnd = math.rad(angleEnd)
    if angleEnd > angleStart then
        angleEnd = angleEnd2 - 2 * math.pi
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

-- Wakeup: all calculations and caching
function render.wakeup(box, telemetry)
    -- Fallbacks for all params
    local bandLabels = rfsuite.widgets.dashboard.utils.getParam(box, "bandLabels") or {"Bad", "OK", "Good", "Excellent"}
    local bandColors = rfsuite.widgets.dashboard.utils.getParam(box, "bandColors") or {
        lcd.RGB(180,50,50),
        lcd.RGB(220,150,40),
        lcd.RGB(90,180,90),
        lcd.RGB(170,180,120)
    }
    local startAngle = rfsuite.widgets.dashboard.utils.getParam(box, "startAngle") or 180
    local sweep = rfsuite.widgets.dashboard.utils.getParam(box, "sweep") or 180
    local min = rfsuite.widgets.dashboard.utils.getParam(box, "min") or 0
    local max = rfsuite.widgets.dashboard.utils.getParam(box, "max") or 100
    local source = rfsuite.widgets.dashboard.utils.getParam(box, "source")
    local value, percent = nil, 0
    if source and telemetry then
        local sensor = telemetry.getSensorSource and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
    end
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end

    -- Cache all params for paint
    box._cache = {
        bandLabels = bandLabels,
        bandColors = bandColors,
        startAngle = startAngle,
        sweep = sweep,
        min = min,
        max = max,
        value = value,
        percent = percent,
        unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit") or "",
        title = rfsuite.widgets.dashboard.utils.getParam(box, "title"),
        needleColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "needlecolor")) or lcd.RGB(0,0,0),
        needleThickness = rfsuite.widgets.dashboard.utils.getParam(box, "needlethickness") or 5,
        needlehubcolor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "needlehubcolor")) or lcd.RGB(0,0,0),
        needlehubsize = rfsuite.widgets.dashboard.utils.getParam(box, "needlehubsize") or 7,
        bgcolor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240)),
        novalue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-",
    }
end

-- Paint: robust fallbacks for all cached fields!
function render.paint(x, y, w, h, box)
    local c = box._cache or {}
    -- Robust band labels/colors
    local bandLabels = (c.bandLabels and type(c.bandLabels) == "table") and c.bandLabels or {"Bad", "OK", "Good", "Excellent"}
    local bandColors = (c.bandColors and type(c.bandColors) == "table") and c.bandColors or {
        lcd.RGB(180,50,50),
        lcd.RGB(220,150,40),
        lcd.RGB(90,180,90),
        lcd.RGB(170,180,120)
    }
    local bandCount = #bandLabels
    local startAngle = c.startAngle or 180
    local sweep = c.sweep or 180
    local min = c.min or 0
    local max = c.max or 100
    local value = c.value
    local percent = c.percent or 0
    local unit = c.unit or ""
    local title = c.title
    local needleColor = c.needleColor or lcd.RGB(0,0,0)
    local needleThickness = c.needleThickness or 5
    local needlehubcolor = c.needlehubcolor or lcd.RGB(0,0,0)
    local needlehubsize = c.needlehubsize or 7
    local bgcolor = c.bgcolor or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240))
    local novalue = c.novalue or "-"

    -- Center & sizing
    local cx = x + w / 2
    local cy = y + h * 0.92
    local radius = math.min(w, h*2) * 0.40
    local thickness = math.max(8, radius * 0.25)

    -- Background
    lcd.color(bgcolor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Draw colored bands
    for i=1,bandCount do
        local segStart = startAngle - (i-1)*(sweep/bandCount)
        local segEnd   = startAngle - i*(sweep/bandCount)
        drawArc(cx, cy, radius, thickness, segStart, segEnd, bandColors[i])
    end

    -- Draw needle
    if percent then
        local needleLen = radius - 8
        local needleAngle = startAngle + sweep * percent
        rfsuite.widgets.dashboard.utils.drawBarNeedle(cx, cy, needleLen, needleThickness, needleAngle, needleColor)
        lcd.color(needlehubcolor)
        lcd.drawFilledCircle(cx, cy, needlehubsize)
    end

    -- Draw band labels
    lcd.font(FONT_XS)
    for i=1,bandCount do
        local midAngle = startAngle - ((i-0.5)*(sweep/bandCount))
        local tx = cx + (radius + thickness*0.7) * math.cos(math.rad(midAngle))
        local ty = cy - (radius + thickness*0.7) * math.sin(math.rad(midAngle))
        local text = bandLabels[i]
        if text then
            local tw, th = lcd.getTextSize(text)
            lcd.color(lcd.RGB(255,255,255))
            lcd.drawText(tx-tw/2, ty-th/2, text)
        end
    end

    -- Value display
    lcd.font(FONT_STD)
    local valStr = ""
    if value ~= nil then
        valStr = tostring(value) .. unit
    else
        valStr = novalue
    end
    local vw, vh = lcd.getTextSize(valStr)
    lcd.color(lcd.RGB(255,255,255))
    lcd.drawText(cx - vw / 2, cy - thickness - 18, valStr)

    -- Title (below)
    if title then
        lcd.font(FONT_XS)
        local tw, th = lcd.getTextSize(title)
        lcd.color(lcd.RGB(255,255,255))
        lcd.drawText(cx-tw/2, y+h-14, title)
    end
end

return render

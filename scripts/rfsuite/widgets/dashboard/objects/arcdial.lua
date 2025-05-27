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

-- Needle drawing helper
local function drawBarNeedle(cx, cy, length, thickness, angleDeg, color)
    local angleRad = math.rad(angleDeg)
    local cosA = math.cos(angleRad)
    local sinA = math.sin(angleRad)
    local tipX = cx + cosA * length
    local tipY = cy + sinA * length
    local perpA = angleRad + math.pi / 2
    local dx = math.cos(perpA) * (thickness / 2)
    local dy = math.sin(perpA) * (thickness / 2)
    local base1X = cx + dx
    local base1Y = cy + dy
    local base2X = cx - dx
    local base2Y = cy - dy
    local tip1X = tipX + dx
    local tip1Y = tipY + dy
    local tip2X = tipX - dx
    local tip2Y = tipY - dy
    lcd.color(color)
    lcd.drawFilledTriangle(base1X, base1Y, tip1X, tip1Y, tip2X, tip2Y)
    lcd.drawFilledTriangle(base1X, base1Y, tip2X, tip2Y, base2X, base2Y)
    lcd.drawLine(cx, cy, tipX, tipY)
end

-- Main render function
function render.arcdial(x, y, w, h, box, telemetry)

    -- Parameters & defaults
    local bandLabels = rfsuite.widgets.dashboard.utils.getParam(box, "bandLabels") or {"Bad", "OK", "Good", "Excellent"}
    local bandColors = rfsuite.widgets.dashboard.utils.getParam(box, "bandColors") or {
        lcd.RGB(180,50,50),
        lcd.RGB(220,150,40),
        lcd.RGB(90,180,90),
        lcd.RGB(170,180,120)
    }
    local startAngle = rfsuite.widgets.dashboard.utils.getParam(box, "startAngle") or 180
    local sweep = rfsuite.widgets.dashboard.utils.getParam(box, "sweep") or 180
    local bgColor = rfsuite.widgets.dashboard.utils.resolveColor(
        rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor")
    ) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))

    -- Center & sizing
    local cx = x + w / 2
    local cy = y + h * 0.92
    local radius = math.min(w, h*2) * 0.40
    local thickness = math.max(8, radius * 0.25)

    -- Background
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Value
    local min = rfsuite.widgets.dashboard.utils.getParam(box, "min") or 0
    local max = rfsuite.widgets.dashboard.utils.getParam(box, "max") or 100
    local value, percent = nil, 0
    local source = rfsuite.widgets.dashboard.utils.getParam(box, "source")
    if source and telemetry then
        local sensor = telemetry.getSensorSource and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
    end
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end

    -- Draw colored bands
    local bandCount = #bandLabels
    for i=1,bandCount do
        local segStart = startAngle - (i-1)*(sweep/bandCount)
        local segEnd   = startAngle - i*(sweep/bandCount)
        drawArc(cx, cy, radius, thickness, segStart, segEnd, bandColors[i])
    end

    -- Draw needle
    if percent then
        local needleColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "needlecolor")) or lcd.RGB(0,0,0)
        local needleThickness = rfsuite.widgets.dashboard.utils.getParam(box, "needlethickness") or 5
        local needleLen = radius - 8
        local needleAngle = startAngle + sweep * percent
        drawBarNeedle(cx, cy, needleLen, needleThickness, needleAngle, needleColor)
        local hubColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "needlehubcolor")) or lcd.RGB(0,0,0)
        local hubSize = rfsuite.widgets.dashboard.utils.getParam(box, "needlehubsize") or 7
        lcd.color(hubColor)
        lcd.drawFilledCircle(cx, cy, hubSize)
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
    local displayValue = value or rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
    local unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit") or ""
    lcd.font(FONT_STD)
    local valStr = tostring(displayValue) .. unit
    local vw, vh = lcd.getTextSize(valStr)
    lcd.color(lcd.RGB(255,255,255))
    lcd.drawText(cx-vw/2, cy-thickness-18, valStr)

    -- Title (below)
    local title = rfsuite.widgets.dashboard.utils.getParam(box, "title")
    if title then
        lcd.font(FONT_XS)
        local tw, th = lcd.getTextSize(title)
        lcd.color(lcd.RGB(255,255,255))
        lcd.drawText(cx-tw/2, y+h-14, title)
    end
end

return render

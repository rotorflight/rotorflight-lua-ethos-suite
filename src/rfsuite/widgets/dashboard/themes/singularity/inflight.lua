local rfsuite = require("rfsuite")
local lcd = lcd
local math = math
local floor = math.floor
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local rad = math.rad
local tonumber = tonumber
local tostring = tostring
local type = type
local format = string.format
local ipairs = ipairs

local utils = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()
local header_layout = utils.standardHeaderLayout(headeropts)

local C = {
    space = lcd.RGB(3, 5, 12),
    void = lcd.RGB(0, 0, 3),
    panel = lcd.RGB(8, 12, 24),
    panel2 = lcd.RGB(13, 18, 34),
    line = lcd.RGB(37, 57, 87),
    line2 = lcd.RGB(75, 101, 140),
    white = lcd.RGB(228, 240, 255),
    muted = lcd.RGB(122, 147, 177),
    cyan = lcd.RGB(58, 236, 255),
    cyanDim = lcd.RGB(16, 74, 92),
    violet = lcd.RGB(170, 97, 255),
    violetDim = lcd.RGB(53, 27, 89),
    blue = lcd.RGB(58, 111, 255),
    blueDim = lcd.RGB(18, 38, 91),
    green = lcd.RGB(98, 255, 165),
    greenDim = lcd.RGB(21, 87, 59),
    amber = lcd.RGB(255, 190, 70),
    amberDim = lcd.RGB(94, 64, 17),
    red = lcd.RGB(255, 72, 110),
    redDim = lcd.RGB(90, 19, 38),
    magenta = lcd.RGB(255, 74, 235)
}

local THEME_SECTION = "system/singularity"
local DEFAULTS = {
    rpm_max = 2500,
    bec_min = 6.5,
    bec_warn = 7.0,
    esc_warn = 110,
    esc_max = 150,
    fuel_warn = 25,
    link_warn = 50,
    current_warn = 120,
    watts_warn = 3500
}

local STARFIELD = {
    {2,6,1},{7,18,1},{11,9,2},{15,29,1},{19,14,1},{23,5,1},{27,24,2},{31,12,1},
    {35,32,1},{39,20,1},{43,7,2},{47,27,1},{51,16,1},{55,4,1},{59,31,2},{63,11,1},
    {67,23,1},{71,6,1},{75,18,2},{79,29,1},{83,13,1},{87,2,1},{91,24,2},{95,9,1},
    {5,38,1},{13,44,2},{21,36,1},{29,48,1},{37,40,2},{45,50,1},{53,37,1},{61,46,2},
    {69,39,1},{77,49,1},{85,35,2},{93,45,1},{9,58,1},{18,67,2},{26,56,1},{34,71,1},
    {42,62,2},{50,75,1},{58,59,1},{66,69,2},{74,55,1},{82,73,1},{90,61,2},{97,76,1},
    {4,85,1},{12,94,2},{24,82,1},{32,91,1},{40,79,2},{48,96,1},{56,84,1},{64,93,2},
    {72,81,1},{80,97,1},{88,86,2},{96,92,1}
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function getThemeValue(key)
    local session = rfsuite and rfsuite.session
    local prefs = session and session.modelPreferences and session.modelPreferences[THEME_SECTION]
    local value = prefs and tonumber(prefs[key])
    return value or DEFAULTS[key]
end

local function sensor(telemetry, name, alias1, alias2)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    if not (telemetry and telemetry.getSensor) then return nil end
    local value = telemetry.getSensor(name)
    if value ~= nil then return tonumber(value) end
    if alias1 then
        value = telemetry.getSensor(alias1)
        if value ~= nil then return tonumber(value) end
    end
    if alias2 then
        value = telemetry.getSensor(alias2)
        if value ~= nil then return tonumber(value) end
    end
    return nil
end

local function stat(telemetry, source, statType, alias1, alias2)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    local stats = telemetry and telemetry.sensorStats
    local data = stats and stats[source]
    local value = data and data[statType]
    if value ~= nil then return tonumber(value) end
    if alias1 then
        data = stats and stats[alias1]
        value = data and data[statType]
        if value ~= nil then return tonumber(value) end
    end
    if alias2 then
        data = stats and stats[alias2]
        value = data and data[statType]
        if value ~= nil then return tonumber(value) end
    end
    return nil
end

local function fmt(value, decimals, suffix, missing)
    if value == nil then return missing or "--" end
    local text
    if decimals == 1 then text = format("%.1f", value)
    elseif decimals == 2 then text = format("%.2f", value)
    else text = tostring(floor(value + 0.5)) end
    return text .. (suffix or "")
end

local function resolveFont(name)
    return utils.resolveFont(name, nil)
end

local function drawTextAligned(x, y, w, text, fontName, color, align)
    local font = resolveFont(fontName)
    if type(font) ~= "number" then return 0, 0 end
    lcd.font(font)
    lcd.color(color)
    local tw, th = lcd.getTextSize(text)
    local tx = x
    if align == "center" then tx = x + (w - tw) / 2
    elseif align == "right" then tx = x + w - tw end
    lcd.drawText(floor(tx + 0.5), floor(y + 0.5), text)
    return tw, th
end

local function drawStars(x, y, w, h)
    for i = 1, #STARFIELD do
        local s = STARFIELD[i]
        local sx = floor(x + w * s[1] / 100)
        local sy = floor(y + h * s[2] / 100)
        local size = s[3]
        lcd.color(size == 2 and C.line2 or C.line)
        lcd.drawFilledRectangle(sx, sy, size, size)
    end
end

local function drawPanel(x, y, w, h, accent, title)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.line)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(accent or C.cyan)
    lcd.drawFilledRectangle(x, y, 3, h)
    if title then
        drawTextAligned(x + 11, y + 7, w - 20, title, "FONT_XXS", C.muted, "left")
    end
end

local function drawNode(x, y, w, h, title, value, accent, subtitle)
    drawPanel(x, y, w, h, accent, title)
    drawTextAligned(x + 11, y + 28, w - 22, value, "FONT_L", C.white, "left")
    if subtitle then drawTextAligned(x + 11, y + h - 22, w - 22, subtitle, "FONT_XXS", C.muted, "left") end
end

local function drawHex(cx, cy, radius, color)
    local px, py = nil, nil
    local firstx, firsty = nil, nil
    lcd.color(color)
    for i = 0, 6 do
        local a = rad(30 + (i % 6) * 60)
        local x = floor(cx + cos(a) * radius)
        local y = floor(cy + sin(a) * radius)
        if i == 0 then firstx, firsty = x, y else lcd.drawLine(px, py, x, y) end
        px, py = x, y
    end
    if px and firstx then lcd.drawLine(px, py, firstx, firsty) end
end

local function drawRingSegments(cx, cy, radius, count, percent, activeColor, dimColor, thickness, startAngle, sweep)
    count = count or 24
    percent = clamp(percent or 0, 0, 100)
    thickness = thickness or 8
    startAngle = startAngle or 0
    sweep = sweep or 360
    local active = percent > 0 and max(1, min(count, floor(percent * count / 100 + 0.999))) or 0
    for i = 0, count - 1 do
        local a = rad(startAngle + sweep * i / count)
        local r1 = radius - thickness
        local r2 = radius
        local x1 = floor(cx + cos(a) * r1)
        local y1 = floor(cy + sin(a) * r1)
        local x2 = floor(cx + cos(a) * r2)
        local y2 = floor(cy + sin(a) * r2)
        lcd.color(i < active and activeColor or dimColor)
        lcd.drawLine(x1, y1, x2, y2)
    end
end

local function drawOrbit(cx, cy, rx, ry, color, segments)
    segments = segments or 48
    local lastx, lasty
    lcd.color(color)
    for i = 0, segments do
        local a = rad(360 * i / segments)
        local x = floor(cx + cos(a) * rx)
        local y = floor(cy + sin(a) * ry)
        if lastx then lcd.drawLine(lastx, lasty, x, y) end
        lastx, lasty = x, y
    end
end

local function drawOrbitalMarker(cx, cy, rx, ry, angle, color, size)
    local a = rad(angle)
    local x = floor(cx + cos(a) * rx)
    local y = floor(cy + sin(a) * ry)
    size = size or 6
    lcd.color(color)
    lcd.drawFilledRectangle(x - floor(size/2), y - floor(size/2), size, size)
end

local function drawProgress(x, y, w, h, percent, color)
    percent = clamp(percent or 0, 0, 1)
    lcd.color(C.line)
    lcd.drawRectangle(floor(x), floor(y), floor(w), floor(h), 1)
    if percent > 0 then
        lcd.color(color)
        lcd.drawFilledRectangle(floor(x + 2), floor(y + 2), floor((w - 4) * percent), max(1, floor(h - 4)))
    end
end

local function drawHeaderTitle(x, y, w, h)
    lcd.color(C.space)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    local t1, t2, t3 = "ETHOS ", "// ", "ROTORFLIGHT"
    local font = resolveFont("FONT_L")
    if type(font) ~= "number" then return end
    lcd.font(font)
    local w1, th = lcd.getTextSize(t1)
    local w2 = lcd.getTextSize(t2)
    local w3 = lcd.getTextSize(t3)

    local watermarkFont = resolveFont("FONT_XS")
    local watermarkText = "MWRC"
    local watermarkWidth, watermarkHeight = 0, 0
    if type(watermarkFont) == "number" then
        lcd.font(watermarkFont)
        watermarkWidth, watermarkHeight = lcd.getTextSize(watermarkText)
        lcd.font(font)
    end

    local titleWidth = w1 + w2 + w3
    local dividerGap = watermarkWidth > 0 and 14 or 0
    local total = titleWidth + dividerGap + watermarkWidth
    local tx = floor(x + (w - total) / 2)
    local ty = floor(y + (h - th) / 2)
    lcd.color(C.violet)
    lcd.drawText(tx, ty, t1)
    lcd.color(C.cyan)
    lcd.drawText(tx + w1, ty, t2)
    lcd.color(C.white)
    lcd.drawText(tx + w1 + w2, ty, t3)

    if watermarkWidth > 0 then
        local dividerX = tx + titleWidth + 6
        lcd.color(C.line2)
        lcd.drawLine(dividerX, y + 7, dividerX, y + h - 7)
        lcd.font(watermarkFont)
        lcd.color(C.magenta)
        lcd.drawText(dividerX + 7, floor(y + (h - watermarkHeight) / 2), watermarkText)
    end
end

local header_boxes_cache = nil
local last_txbatt_type = nil
local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end
    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        for _, b in ipairs(boxes) do
            b.bgcolor = C.space
            if b.type == "image" then
                b.type = "func"
                b.subtype = "func"
                b.paint = drawHeaderTitle
            end
        end
        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function flightTimeText()
    local session = rfsuite and rfsuite.session
    local seconds = session and session.timer and tonumber(session.timer.live) or 0
    seconds = max(0, seconds)
    return format("%02d:%02d", floor(seconds / 60), floor(seconds % 60))
end

local STATE_LABELS = {
    [0] = "OFFLINE",
    [1] = "IDLE",
    [2] = "IGNITION",
    [3] = "RECOVERY",
    [4] = "STABLE ORBIT",
    [5] = "THRUST CUT",
    [6] = "SIGNAL LOST",
    [7] = "AUTOROTATION",
    [8] = "BAILOUT",
    [100] = "GOV DISABLED",
    [101] = "COLD"
}
local STATE_COLORS = {
    [0] = C.amber,[1] = C.amber,[2] = C.magenta,[3] = C.amber,[4] = C.green,
    [5] = C.green,[6] = C.red,[7] = C.amber,[8] = C.red,[100] = C.muted,[101] = C.cyan
}

local function getReactorState(telemetry)
    local armflags = sensor(telemetry, "armflags")
    local governor = sensor(telemetry, "governor")
    local armed = nil
    if rfsuite.utils and rfsuite.utils.armFlagsToIsArmed then
        armed = rfsuite.utils.armFlagsToIsArmed(armflags)
    end
    if armed == nil and armflags == nil and governor == nil then
        local session = rfsuite and rfsuite.session
        if session and session.telemetryState then armed = session.isArmed == true end
    end
    if armed == false then return "COLD", C.cyan end
    local code = governor and floor(governor + 0.5) or nil
    if code == 101 then return "COLD", C.cyan end
    if armed == true then
        if code and STATE_LABELS[code] then return STATE_LABELS[code], STATE_COLORS[code] or C.red end
        return "ARMED", C.red
    end
    if code and STATE_LABELS[code] then return STATE_LABELS[code], STATE_COLORS[code] or C.cyan end
    return "STATE --", C.muted
end

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}

local function inflightWakeup(box, telemetry)
    local c = box._cache or {maxRpm = 0}
    box._cache = c
    c.rpm = sensor(telemetry, "rpm", "headspeed", "erpm") or 0
    c.maxRpm = max(c.maxRpm or 0, c.rpm)
    c.throttle = sensor(telemetry, "throttle_percent", "throttle") or 0
    c.esc = sensor(telemetry, "temp_esc", "esc_temp")
    c.fuel = sensor(telemetry, "smartfuel")
    c.current = sensor(telemetry, "current")
    c.watts = sensor(telemetry, "watts")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    c.link = sensor(telemetry, "link", "vfr")
    c.consumed = sensor(telemetry, "smartconsumption", "consumption")
    c.reactorState, c.reactorColor = getReactorState(telemetry)
    c.timer = flightTimeText()
    return c
end

local function drawThermalPlume(x, y, w, h, value, maximum, color)
    drawPanel(x, y, w, h, color, "THERMAL PLUME")
    local pct = maximum > 0 and clamp((value or 0) / maximum, 0, 1) or 0
    local baseY = y + h - 28
    local center = x + w * 0.5
    for i = 0, 7 do
        local bh = floor((h - 68) * pct * (0.48 + i / 15))
        local bw = 5 + (i % 3) * 2
        local bx = floor(center - 32 + i * 9)
        lcd.color(i < 3 and C.cyanDim or color)
        lcd.drawFilledRectangle(bx, floor(baseY - bh), bw, bh)
    end
    drawTextAligned(x + 10, y + 30, w - 20, fmt(value,0," C"), "FONT_L", C.white, "center")
end

local function drawThrustArray(x, y, w, h, throttle)
    drawPanel(x, y, w, h, C.cyan, "THRUST ARRAY")
    local pct = clamp((throttle or 0) / 100, 0, 1)
    local bars = 10
    local gap = 4
    local bw = floor((w - 24 - gap * (bars - 1)) / bars)
    for i = 0, bars - 1 do
        local bh = 14 + i * 5
        local bx = x + 12 + i * (bw + gap)
        local by = y + h - 20 - bh
        lcd.color(i < floor(pct * bars + 0.999) and C.cyan or C.line)
        lcd.drawFilledRectangle(floor(bx), floor(by), bw, bh)
    end
    drawTextAligned(x + 10, y + 30, w - 20, fmt(throttle,0,"%"), "FONT_L", C.white, "center")
end

local function inflightPaint(x, y, w, h, box, c)
    x, y = utils.applyOffset(x, y, box)
    c = c or box._cache or {}

    lcd.color(C.space)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    drawStars(x, y, w, h)

    drawTextAligned(x + 14, y + 8, w * 0.45, "SINGULARITY // FLIGHT", "FONT_STD", C.violet, "left")
    drawTextAligned(x + w * 0.35, y + 3, w * 0.30, c.timer or "00:00", "FONT_XL", C.white, "center")
    drawTextAligned(x + w - 250, y + 9, 236, c.reactorState or "STATE --", "FONT_STD", c.reactorColor or C.muted, "right")

    local bodyY = y + 44
    local bodyH = h - 56
    local sideW = floor(w * 0.21)
    local leftX = x + 12
    local rightX = x + w - sideW - 12
    local centerX = leftX + sideW + 12
    local centerW = w - sideW * 2 - 48

    local halfH = floor((bodyH - 10) / 2)
    local escColor = c.esc and (c.esc >= getThemeValue("esc_max") and C.red or (c.esc >= getThemeValue("esc_warn") and C.amber or C.green)) or C.muted
    drawThermalPlume(leftX, bodyY, sideW, halfH, c.esc, getThemeValue("esc_max"), escColor)
    drawThrustArray(leftX, bodyY + halfH + 10, sideW, halfH, c.throttle)

    drawPanel(centerX, bodyY, centerW, bodyH, C.violet, nil)
    local cx = centerX + centerW * 0.5
    local cy = bodyY + bodyH * 0.47
    local radius = min(centerW, bodyH) * 0.40
    local rpmMax = getThemeValue("rpm_max")
    local rpmPct = rpmMax > 0 and clamp((c.rpm or 0) / rpmMax * 100, 0, 100) or 0
    local fuel = c.fuel or 0
    local fuelColor = fuel <= getThemeValue("fuel_warn") and C.red or (fuel <= 50 and C.amber or C.green)
    local rpmColor = (c.rpm or 0) > rpmMax and C.red or C.violet

    drawOrbit(cx, cy, radius * 1.12, radius * 0.54, C.line, 64)
    drawOrbit(cx, cy, radius * 0.78, radius * 1.10, C.line, 64)
    drawRingSegments(cx, cy, radius * 1.05, 36, rpmPct, rpmColor, C.line, 13, 145, 250)
    drawRingSegments(cx, cy, radius * 0.86, 30, fuel, fuelColor, C.line, 10, 0, 360)
    drawHex(cx, cy, radius * 0.62, C.line2)
    drawHex(cx, cy, radius * 0.44, c.reactorColor or C.muted)
    drawHex(cx, cy, radius * 0.26, C.violet)

    drawTextAligned(cx - radius, cy - 58, radius * 2, fmt(c.rpm,0,""), "FONT_XXL", C.white, "center")
    drawTextAligned(cx - radius, cy - 2, radius * 2, "HEADSPEED", "FONT_XS", C.muted, "center")
    drawTextAligned(cx - radius, cy + 24, radius * 2, c.reactorState or "STATE --", "FONT_S", c.reactorColor or C.muted, "center")
    drawTextAligned(cx - radius, cy + 52, radius * 2, "EVENT HORIZON", "FONT_XXS", C.violet, "center")
    drawTextAligned(centerX + 18, bodyY + bodyH - 34, centerW - 36, "MAX " .. fmt(c.maxRpm,0," RPM"), "FONT_XS", C.amber, "left")
    drawTextAligned(centerX + 18, bodyY + bodyH - 34, centerW - 36, "ENERGY " .. fmt(c.fuel,0,"%"), "FONT_XS", fuelColor, "right")

    local currentColor = c.current and c.current >= getThemeValue("current_warn") and C.red or C.cyan
    local wattsColor = c.watts and c.watts >= getThemeValue("watts_warn") and C.red or C.violet
    local becColor = c.bec and (c.bec < getThemeValue("bec_min") and C.red or (c.bec < getThemeValue("bec_warn") and C.amber or C.cyan)) or C.muted
    local linkColor = c.link and (c.link < getThemeValue("link_warn") and C.amber or C.cyan) or C.muted

    local nodeH = floor((bodyH - 30) / 4)
    drawNode(rightX, bodyY, sideW, nodeH, "REACTOR LOAD", fmt(c.current,1," A"), currentColor, fmt(c.watts,0," W"))
    drawNode(rightX, bodyY + nodeH + 10, sideW, nodeH, "POWER CORE", fmt(c.bec,1," V"), becColor, "BEC STABILITY")
    drawNode(rightX, bodyY + (nodeH + 10) * 2, sideW, nodeH, "SIGNAL CONSTELLATION", fmt(c.link,0,"%"), linkColor, "LINK LOCK")
    drawNode(rightX, bodyY + (nodeH + 10) * 3, sideW, nodeH, "MATTER CONSUMED", fmt(c.consumed,0," mAh"), wattsColor, "FLIGHT ENERGY")
end

local boxes_cache
local function boxes()
    if not boxes_cache then boxes_cache = {{col=1,row=1,colspan=12,rowspan=12,type="func",subtype="func",wakeup=inflightWakeup,paint=inflightPaint,bgcolor="transparent"}} end
    return boxes_cache
end

return {layout=layout,boxes=boxes,header_boxes=header_boxes,header_layout=header_layout,screenBorderStyle=screenBorderStyle,scheduler={spread_scheduling=true,spread_scheduling_paint=false,spread_ratio=0.85}}

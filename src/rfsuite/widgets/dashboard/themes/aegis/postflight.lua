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

local utils = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
local header_layout = utils.standardHeaderLayout(headeropts)
local header_boxes = utils.standardHeaderBoxes(headeropts)

local THEME_SECTION = "system/aegis"
local DEFAULTS = {
    rpm_max = 2500,
    bec_min = 6.5,
    bec_warn = 8.0,
    esc_warn = 110,
    esc_max = 150,
    fuel_warn = 25,
    link_warn = 50
}

local C = {
    bg = lcd.RGB(7, 11, 16),
    panel = lcd.RGB(14, 21, 29),
    panel2 = lcd.RGB(19, 28, 38),
    line = lcd.RGB(50, 67, 82),
    line2 = lcd.RGB(76, 97, 115),
    white = lcd.RGB(230, 239, 247),
    muted = lcd.RGB(132, 151, 168),
    cyan = lcd.RGB(48, 218, 238),
    cyanDim = lcd.RGB(17, 75, 86),
    green = lcd.RGB(75, 224, 149),
    greenDim = lcd.RGB(18, 79, 54),
    amber = lcd.RGB(255, 183, 72),
    amberDim = lcd.RGB(93, 61, 17),
    red = lcd.RGB(255, 86, 103),
    redDim = lcd.RGB(91, 25, 35),
    violet = lcd.RGB(174, 133, 255),
    violetDim = lcd.RGB(55, 41, 88)
}

local function getThemeValue(key)
    local session = rfsuite and rfsuite.session
    local prefs = session and session.modelPreferences and session.modelPreferences[THEME_SECTION]
    local value = prefs and tonumber(prefs[key])
    return value or DEFAULTS[key]
end

local function sensor(telemetry, name, alias1, alias2)
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

local function fmt(value, decimals, suffix, missing)
    if value == nil then return missing or "--" end
    local text
    if decimals == 1 then
        text = format("%.1f", value)
    elseif decimals == 2 then
        text = format("%.2f", value)
    else
        text = tostring(floor(value + 0.5))
    end
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
    if align == "center" then
        tx = x + (w - tw) / 2
    elseif align == "right" then
        tx = x + w - tw
    end
    lcd.drawText(floor(tx + 0.5), floor(y + 0.5), text)
    return tw, th
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
        drawTextAligned(x + 12, y + 7, w - 22, title, "FONT_XS", C.muted, "left")
    end
end

local function drawMetric(x, y, w, h, title, valueText, accent, subtitle)
    drawPanel(x, y, w, h, accent, title)
    drawTextAligned(x + 12, y + 26, w - 24, valueText, "FONT_XL", C.white, "left")
    if subtitle then
        drawTextAligned(x + 12, y + h - 22, w - 24, subtitle, "FONT_XXS", C.muted, "left")
    end
end

local function drawSegments(x, y, w, h, percent, count, activeColor, emptyColor)
    count = count or 10
    percent = max(0, min(100, percent or 0))
    local gap = 4
    local segW = floor((w - gap * (count - 1)) / count)
    if segW < 2 then return end
    local active = percent > 0 and max(1, min(count, floor(percent * count / 100 + 0.999))) or 0
    for i = 1, count do
        local sx = x + (i - 1) * (segW + gap)
        if i <= active then
            lcd.color(activeColor)
            lcd.drawFilledRectangle(floor(sx), floor(y), segW, floor(h))
        else
            lcd.color(emptyColor or C.line)
            lcd.drawRectangle(floor(sx), floor(y), segW, floor(h), 1)
        end
    end
end

local function drawProgress(x, y, w, h, percent, color)
    percent = max(0, min(1, percent or 0))
    lcd.color(C.line)
    lcd.drawRectangle(floor(x), floor(y), floor(w), floor(h), 1)
    if percent > 0 then
        lcd.color(color)
        lcd.drawFilledRectangle(floor(x + 2), floor(y + 2), floor((w - 4) * percent), max(1, floor(h - 4)))
    end
end

local function drawHex(x, y, radius, color)
    local points = {}
    for i = 0, 5 do
        local a = rad(30 + i * 60)
        points[i + 1] = {x + cos(a) * radius, y + sin(a) * radius}
    end
    lcd.color(color)
    for i = 1, 6 do
        local a = points[i]
        local b = points[(i % 6) + 1]
        lcd.drawLine(floor(a[1]), floor(a[2]), floor(b[1]), floor(b[2]))
    end
end

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}

local function stat(telemetry, source, statType, alias1, alias2)
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

local function postflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c

    c.rpm = stat(telemetry, "rpm", "max", "headspeed", "erpm")
    c.esc = stat(telemetry, "temp_esc", "max", "esc_temp")
    c.current = stat(telemetry, "current", "max")
    c.watts = stat(telemetry, "watts", "max")
    c.bec = stat(telemetry, "bec_voltage", "min", "bec")
    c.link = stat(telemetry, "link", "min", "vfr")
    c.fuel = stat(telemetry, "smartfuel", "min")
    c.consumed = stat(telemetry, "smartconsumption", "max", "consumption")
    c.voltage = stat(telemetry, "voltage", "min")
    c.altitude = stat(telemetry, "altitude", "max")

    local session = rfsuite and rfsuite.session
    local seconds = session and session.timer and tonumber(session.timer.live) or 0
    c.time = format("%02d:%02d", floor(seconds / 60), floor(seconds % 60))

    local faults = 0
    local cautions = 0
    if c.esc and c.esc >= getThemeValue("esc_max") then faults = faults + 1
    elseif c.esc and c.esc >= getThemeValue("esc_warn") then cautions = cautions + 1 end
    if c.bec and c.bec < getThemeValue("bec_min") then faults = faults + 1
    elseif c.bec and c.bec < getThemeValue("bec_warn") then cautions = cautions + 1 end
    if c.fuel and c.fuel <= getThemeValue("fuel_warn") then cautions = cautions + 1 end
    if c.link and c.link < getThemeValue("link_warn") then cautions = cautions + 1 end
    if c.rpm and c.rpm > getThemeValue("rpm_max") * 1.05 then cautions = cautions + 1 end

    if faults > 0 then
        c.grade = "INSPECT"
        c.gradeColor = C.red
        c.gradeSub = "CRITICAL LIMIT EXCEEDED"
    elseif cautions > 0 then
        c.grade = "REVIEW"
        c.gradeColor = C.amber
        c.gradeSub = tostring(cautions) .. " ITEM" .. (cautions == 1 and "" or "S") .. " FLAGGED"
    else
        c.grade = "NOMINAL"
        c.gradeColor = C.green
        c.gradeSub = "FLIGHT DATA WITHIN LIMITS"
    end

    return c
end

local function drawReportCard(x, y, w, h, title, value, accent, percent)
    drawPanel(x, y, w, h, accent, title)
    drawTextAligned(x + 12, y + 28, w - 24, value, "FONT_L", C.white, "left")
    drawProgress(x + 12, y + h - 19, w - 24, 7, percent or 0, accent)
end

local function postflightPaint(x, y, w, h, box, c)
    x, y = utils.applyOffset(x, y, box)
    c = c or box._cache or {}

    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))

    local pad = 12
    drawTextAligned(x + pad, y + 8, w * 0.5, "AEGIS // DEBRIEF", "FONT_STD", C.cyan, "left")
    drawTextAligned(x + w - 240, y + 6, 228, c.grade or "NOMINAL", "FONT_L", c.gradeColor or C.green, "right")

    local summaryY = y + 42
    local summaryH = 62
    drawPanel(x + pad, summaryY, w - pad * 2, summaryH, c.gradeColor or C.green, nil)
    drawTextAligned(x + pad + 16, summaryY + 10, w * 0.5, c.gradeSub or "FLIGHT DATA WITHIN LIMITS", "FONT_S", C.white, "left")
    drawTextAligned(x + w - 220, summaryY + 8, 190, c.time or "00:00", "FONT_XL", C.white, "right")
    drawTextAligned(x + w - 220, summaryY + 39, 190, "FLIGHT TIME", "FONT_XXS", C.muted, "right")

    local gridY = summaryY + summaryH + pad
    local gridH = h - (gridY - y) - pad
    local cols = 3
    local rows = 3
    local gap = 10
    local cardW = floor((w - pad * 2 - gap * (cols - 1)) / cols)
    local cardH = floor((gridH - gap * (rows - 1)) / rows)

    local rpmColor = c.rpm and c.rpm > getThemeValue("rpm_max") * 1.05 and C.amber or C.cyan
    local escColor = c.esc and (c.esc >= getThemeValue("esc_max") and C.red or (c.esc >= getThemeValue("esc_warn") and C.amber or C.green)) or C.muted
    local becColor = c.bec and (c.bec < getThemeValue("bec_min") and C.red or (c.bec < getThemeValue("bec_warn") and C.amber or C.cyan)) or C.muted
    local fuelColor = c.fuel and c.fuel <= getThemeValue("fuel_warn") and C.amber or C.green
    local linkColor = c.link and c.link < getThemeValue("link_warn") and C.amber or C.cyan

    local cards = {
        {"MAX HEADSPEED", fmt(c.rpm, 0, " RPM"), rpmColor, c.rpm and c.rpm / getThemeValue("rpm_max") or 0},
        {"MAX ESC TEMP", fmt(c.esc, 0, "°C"), escColor, c.esc and c.esc / getThemeValue("esc_max") or 0},
        {"PEAK CURRENT", fmt(c.current, 1, " A"), C.violet, c.current and c.current / 150 or 0},
        {"MIN BEC", fmt(c.bec, 2, " V"), becColor, c.bec and c.bec / 15 or 0},
        {"MIN LINK", fmt(c.link, 0, "%"), linkColor, c.link and c.link / 100 or 0},
        {"FUEL REMAINING", fmt(c.fuel, 0, "%"), fuelColor, c.fuel and c.fuel / 100 or 0},
        {"CONSUMED", fmt(c.consumed, 0, " mAh"), C.amber, c.consumed and c.consumed / 5000 or 0},
        {"PEAK POWER", fmt(c.watts, 0, " W"), C.violet, c.watts and c.watts / 5000 or 0},
        {"MIN PACK / ALT", fmt(c.voltage, 1, " V") .. "  /  " .. fmt(c.altitude, 0, " ft"), C.cyan, c.voltage and c.voltage / 60 or 0}
    }

    for i = 1, #cards do
        local row = floor((i - 1) / cols)
        local col = (i - 1) % cols
        local card = cards[i]
        local cx = x + pad + col * (cardW + gap)
        local cy = gridY + row * (cardH + gap)
        drawReportCard(cx, cy, cardW, cardH, card[1], card[2], card[3], card[4])
    end
end

local function boxes()
    return {{
        col = 1, row = 1, colspan = 12, rowspan = 12,
        type = "func", subtype = "func",
        wakeup = postflightWakeup,
        paint = postflightPaint,
        bgcolor = "transparent"
    }}
end

return {
    layout = layout,
    boxes = boxes,
    header_boxes = header_boxes,
    header_layout = header_layout,
    screenBorderStyle = screenBorderStyle,
    scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.85}
}

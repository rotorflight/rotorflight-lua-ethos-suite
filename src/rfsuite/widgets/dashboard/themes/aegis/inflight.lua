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
local colorMode = utils.themeColors()
local header_layout = utils.standardHeaderLayout(headeropts)
local header_boxes_cache = nil
local last_txbatt_type = nil
local C

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)

        -- Replace the stock Rotorflight logo with the MWRC-style title while
        -- keeping the radio's native header surface and battery/RSSI widgets.
        for _, headerBox in ipairs(boxes) do
            if headerBox.type == "image" then
                headerBox.type = "func"
                headerBox.subtype = "func"
                headerBox.bgcolor = "transparent"
                headerBox.paint = function(x, y, w, h)
                    local headerBg = colorMode.tbbgcolor or colorMode.bgcolor
                    if type(headerBg) == "number" then
                        lcd.color(headerBg)
                        lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
                    end

                    local font = utils.resolveFont("FONT_L", nil)
                    if type(font) ~= "number" then return end
                    lcd.font(font)

                    local t1, t2, t3 = "ETHOS ", "// ", "ROTORFLIGHT"
                    local tw1, th = lcd.getTextSize(t1)
                    local tw2 = lcd.getTextSize(t2)
                    local tw3 = lcd.getTextSize(t3)
                    local totalW = tw1 + tw2 + tw3
                    local tx = floor(x + (w - totalW) / 2)
                    local ty = floor(y + (h - th) / 2)

                    lcd.color(C.cyan)
                    lcd.drawText(tx, ty, t1)
                    lcd.color(C.amber)
                    lcd.drawText(tx + tw1, ty, t2)
                    lcd.color(C.white)
                    lcd.drawText(tx + tw1 + tw2, ty, t3)
                end
            end
        end

        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local THEME_SECTION = "system/aegis"
local DEFAULTS = {
    rpm_max = 2500,
    bec_min = 6.5,
    bec_warn = 7.0,
    esc_warn = 110,
    esc_max = 150,
    fuel_warn = 25,
    link_warn = 50
}

C = {
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

-- Use the radio's actual header surface for the dashboard and every panel.
-- This removes the separate near-black Aegis backdrop while preserving the
-- instrument borders, accents, and high-contrast telemetry.
C.bg = colorMode.tbbgcolor or colorMode.bgcolor or C.bg
C.panel = C.bg
C.panel2 = C.bg

local function getThemeValue(key)
    local session = rfsuite and rfsuite.session
    local prefs = session and session.modelPreferences and session.modelPreferences[THEME_SECTION]
    local value = prefs and tonumber(prefs[key])

    -- Migrate the v1/v1.2 BEC healthy threshold. 8.0 V marked normal
    -- 7.2 V BEC systems as a caution, so the new baseline is 7.0 V.
    if key == "bec_warn" and value == 8 then value = 7.0 end

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

local GOVERNOR_LABELS = {
    [0] = "OFF",
    [1] = "IDLE",
    [2] = "SPOOLUP",
    [3] = "RECOVERY",
    [4] = "ACTIVE",
    [5] = "THR OFF",
    [6] = "LOST HS",
    [7] = "AUTOROT",
    [8] = "BAILOUT",
    [100] = "GOV DISABLED",
    [101] = "DISARMED"
}

local GOVERNOR_COLORS = {
    [0] = C.amber,
    [1] = C.amber,
    [2] = C.red,
    [3] = C.amber,
    [4] = C.red,
    [5] = C.green,
    [6] = C.red,
    [7] = C.amber,
    [8] = C.red,
    [100] = C.muted,
    [101] = C.green
}

local function getFlightState(telemetry)
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

    if armed == false then return "DISARMED", C.green end

    local governorCode = governor and floor(governor + 0.5) or nil
    local governorLabel = governorCode and GOVERNOR_LABELS[governorCode] or nil
    local governorColor = governorCode and GOVERNOR_COLORS[governorCode] or nil

    if governorCode == 101 then return "DISARMED", C.green end
    if armed == true then
        if governorLabel and governorCode ~= 100 then
            return "ARMED / " .. governorLabel, governorColor or C.red
        end
        return "ARMED", C.red
    end
    if governorLabel then return governorLabel, governorColor or C.cyan end
    return "STATE --", C.muted
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

local function drawStateBadge(x, y, w, h, label, color)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    color = color or C.muted
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.line)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(color)
    lcd.drawFilledRectangle(x, y, 4, h)
    drawTextAligned(x + 10, y + 5, w - 18, label or "STATE --", "FONT_XS", color, "center")
end

local function drawMetric(x, y, w, h, title, valueText, accent, subtitle)
    drawPanel(x, y, w, h, accent, title)
    drawTextAligned(x + 12, y + 26, w - 24, valueText, "FONT_XL", C.white, "left")
    if subtitle then
        -- Leave a clear gap above the screen footer.
        drawTextAligned(x + 12, y + h - 31, w - 24, subtitle, "FONT_XXS", C.muted, "left")
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

local function flightTimeText()
    local session = rfsuite and rfsuite.session
    local seconds = session and session.timer and tonumber(session.timer.live) or 0
    seconds = max(0, seconds)
    return format("%02d:%02d", floor(seconds / 60), floor(seconds % 60))
end

local function inflightWakeup(box, telemetry)
    local c = box._cache or {maxRpm = 0}
    box._cache = c

    c.rpm = sensor(telemetry, "rpm", "headspeed", "erpm") or 0
    c.maxRpm = max(c.maxRpm or 0, c.rpm)
    c.throttle = sensor(telemetry, "throttle_percent", "throttle") or 0
    c.esc = sensor(telemetry, "temp_esc", "esc_temp")
    c.fuel = sensor(telemetry, "smartfuel")
    c.current = sensor(telemetry, "current")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    c.link = sensor(telemetry, "link", "vfr")
    c.consumed = sensor(telemetry, "smartconsumption", "consumption")
    c.flightState, c.flightStateColor = getFlightState(telemetry)
    c.timer = flightTimeText()

    return c
end

local function drawRadialGauge(cx, cy, radius, value, maximum, color)
    local startA = 140
    local sweep = 260
    local ticks = 32
    local pct = maximum > 0 and max(0, min(1, value / maximum)) or 0
    local active = floor(ticks * pct + 0.5)

    for i = 0, ticks - 1 do
        local a = rad(startA + sweep * i / (ticks - 1))
        local r1 = radius - 14
        local r2 = radius
        local x1 = cx + cos(a) * r1
        local y1 = cy + sin(a) * r1
        local x2 = cx + cos(a) * r2
        local y2 = cy + sin(a) * r2
        lcd.color(i < active and color or C.line)
        lcd.drawLine(floor(x1), floor(y1), floor(x2), floor(y2))
    end

    lcd.color(C.line2)
    lcd.drawLine(floor(cx - radius * 0.68), floor(cy + radius * 0.72), floor(cx + radius * 0.68), floor(cy + radius * 0.72))
end

local function drawVerticalMeter(x, y, w, h, title, value, maximum, color, unit)
    drawPanel(x, y, w, h, color, title)
    local barX = x + 15
    local barY = y + 34
    local barW = 14
    local barH = h - 52
    local pct = maximum > 0 and max(0, min(1, (value or 0) / maximum)) or 0
    lcd.color(C.line)
    lcd.drawRectangle(floor(barX), floor(barY), floor(barW), floor(barH), 1)
    if pct > 0 then
        local fillH = floor((barH - 4) * pct)
        lcd.color(color)
        lcd.drawFilledRectangle(floor(barX + 2), floor(barY + barH - 2 - fillH), floor(barW - 4), fillH)
    end
    drawTextAligned(x + 38, y + 44, w - 50, fmt(value, 0, unit), "FONT_L", C.white, "left")
end

local function inflightPaint(x, y, w, h, box, c)
    x, y = utils.applyOffset(x, y, box)
    c = c or box._cache or {}

    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))

    local pad = 12
    drawTextAligned(x + pad, y + 8, w * 0.5, "AEGIS // FLIGHT", "FONT_STD", C.cyan, "left")
    drawTextAligned(x + w * 0.35, y + 3, w * 0.30, c.timer or "00:00", "FONT_XL", C.white, "center")

    local bodyY = y + 42
    local bodyH = h - 54
    local leftW = floor(w * 0.18)
    local rightW = floor(w * 0.24)
    local centerX = x + pad + leftW + pad
    local centerW = w - leftW - rightW - pad * 4
    local leftX = x + pad
    local rightX = centerX + centerW + pad

    local escColor = c.esc and (c.esc >= getThemeValue("esc_max") and C.red or (c.esc >= getThemeValue("esc_warn") and C.amber or C.green)) or C.muted
    local throttleColor = (c.throttle or 0) >= 90 and C.amber or C.cyan
    local fuel = c.fuel or 0
    local fuelColor = fuel <= getThemeValue("fuel_warn") and C.red or (fuel <= 50 and C.amber or C.green)
    local becColor = c.bec and (c.bec < getThemeValue("bec_min") and C.red or (c.bec < getThemeValue("bec_warn") and C.amber or C.cyan)) or C.muted
    local linkColor = c.link and (c.link < getThemeValue("link_warn") and C.amber or C.cyan) or C.muted

    local halfH = floor((bodyH - pad) / 2)
    drawVerticalMeter(leftX, bodyY, leftW, halfH, "ESC TEMP", c.esc, getThemeValue("esc_max"), escColor, "°")
    drawVerticalMeter(leftX, bodyY + halfH + pad, leftW, halfH, "THROTTLE", c.throttle, 100, throttleColor, "%")

    drawPanel(centerX, bodyY, centerW, bodyH, C.cyan, nil)
    local cx = centerX + centerW / 2
    local cy = bodyY + bodyH * 0.48
    local radius = min(centerW * 0.43, bodyH * 0.43)
    local rpmMax = getThemeValue("rpm_max")
    local rpmColor = (c.rpm or 0) > rpmMax and C.red or C.cyan
    drawRadialGauge(cx, cy, radius, c.rpm or 0, rpmMax, rpmColor)
    drawTextAligned(centerX, cy - 44, centerW, fmt(c.rpm, 0, ""), "FONT_XXL", C.white, "center")
    drawTextAligned(centerX, cy + 10, centerW, "HEADSPEED  RPM", "FONT_XS", C.muted, "center")
    drawTextAligned(centerX + 22, bodyY + bodyH - 33, centerW - 44, "MAX " .. fmt(c.maxRpm, 0, " RPM"), "FONT_XS", C.amber, "left")
    drawTextAligned(centerX + 22, bodyY + bodyH - 33, centerW - 44, "LIMIT " .. fmt(rpmMax, 0, " RPM"), "FONT_XS", C.muted, "right")

    local fuelH = floor(bodyH * 0.34)
    drawPanel(rightX, bodyY, rightW, fuelH, fuelColor, "SMART FUEL")
    drawTextAligned(rightX + 12, bodyY + 34, rightW - 24, fmt(c.fuel, 0, "%"), "FONT_XL", C.white, "right")
    drawSegments(rightX + 12, bodyY + fuelH - 39, rightW - 32, 16, fuel, 10, fuelColor, C.line)
    lcd.color(fuelColor)
    lcd.drawFilledRectangle(floor(rightX + rightW - 16), floor(bodyY + fuelH - 35), 4, 8)

    -- Arm/governor state sits immediately below the Smart Fuel battery.
    local stateGap = 8
    local stateH = 28
    local stateY = bodyY + fuelH + stateGap
    drawStateBadge(rightX, stateY, rightW, stateH, c.flightState, c.flightStateColor)

    local smallY = stateY + stateH + stateGap
    local smallH = floor((bodyY + bodyH - smallY - pad) / 2)
    drawMetric(rightX, smallY, rightW, smallH, "CURRENT LOAD", fmt(c.current, 1, " A"), C.violet, "instantaneous")
    drawMetric(rightX, smallY + smallH + pad, rightW, smallH, "BEC / LINK", fmt(c.bec, 1, " V") .. "   " .. fmt(c.link, 0, "%"), becColor == C.red and C.red or linkColor, "power and RF health")

    -- Keep consumed capacity inside the throttle card as two centered rows.
    -- Separating the label and value prevents overlap in the narrow X20 Pro panel.
    local throttleY = bodyY + halfH + pad
    local consumedX = leftX + 38
    local consumedW = leftW - 50
    local consumedLabelY = throttleY + halfH - 64
    local consumedValueY = consumedLabelY + 18
    drawTextAligned(consumedX, consumedLabelY, consumedW, "CONSUMED", "FONT_XXS", C.muted, "center")
    drawTextAligned(consumedX, consumedValueY, consumedW, fmt(c.consumed, 0, " mAh"), "FONT_XS", C.white, "center")

    local monitorY = y + h - 22
    drawTextAligned(x + w * 0.67, monitorY, w * 0.31 - pad, "AEGIS MONITORING", "FONT_XXS", C.line2, "right")
end

local boxes_cache = nil

local function boxes()
    if boxes_cache == nil then
        boxes_cache = {{
        col = 1, row = 1, colspan = 12, rowspan = 12,
        type = "func", subtype = "func",
        wakeup = inflightWakeup,
        paint = inflightPaint,
        bgcolor = "transparent"
        }}
    end
    return boxes_cache
end

return {
    layout = layout,
    boxes = boxes,
    header_boxes = header_boxes,
    header_layout = header_layout,
    screenBorderStyle = screenBorderStyle,
    scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.85}
}

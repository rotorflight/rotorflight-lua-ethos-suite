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

-- Dashboard-level cache survives the handoff from inflight.lua to
-- postflight.lua even when ETHOS replaces or refreshes the session table.
local dashboardState = rfsuite.widgets and rfsuite.widgets.dashboard
local sharedFlightStats = dashboardState and dashboardState._america250FlightStats
if type(sharedFlightStats) ~= "table" then
    sharedFlightStats = {}
    if dashboardState then dashboardState._america250FlightStats = sharedFlightStats end
end

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(colorMode, headeropts, txbatt_type)

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

                    local watermarkFont = utils.resolveFont("FONT_XS", nil)
                    local watermarkText = "MWRC"
                    local watermarkWidth, watermarkHeight = 0, 0
                    if type(watermarkFont) == "number" then
                        lcd.font(watermarkFont)
                        watermarkWidth, watermarkHeight = lcd.getTextSize(watermarkText)
                        lcd.font(font)
                    end

                    local titleW = tw1 + tw2 + tw3
                    local dividerGap = watermarkWidth > 0 and 14 or 0
                    local totalW = titleW + dividerGap + watermarkWidth
                    local tx = floor(x + (w - totalW) / 2)
                    local ty = floor(y + (h - th) / 2)

                    lcd.color(C.white)
                    lcd.drawText(tx, ty, t1)
                    lcd.color(C.amber)
                    lcd.drawText(tx + tw1, ty, t2)
                    lcd.color(C.white)
                    lcd.drawText(tx + tw1 + tw2, ty, t3)

                    if watermarkWidth > 0 then
                        local dividerX = tx + titleW + 6
                        lcd.color(C.line2)
                        lcd.drawLine(dividerX, y + 7, dividerX, y + h - 7)
                        lcd.font(watermarkFont)
                        lcd.color(C.red)
                        lcd.drawText(dividerX + 7, floor(y + (h - watermarkHeight) / 2), watermarkText)
                    end
                end
            end
        end

        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local THEME_SECTION = "system/america250"
local DEFAULTS = {
    rpm_max = 3000,
    bec_min = 6.5,
    bec_warn = 7.0,
    esc_warn = 110,
    esc_max = 150,
    fuel_warn = 25,
    link_warn = 50
}

C = {
    bg = lcd.RGB(4, 14, 31),
    panel = lcd.RGB(8, 24, 47),
    panel2 = lcd.RGB(12, 34, 61),
    line = lcd.RGB(68, 91, 116),
    line2 = lcd.RGB(153, 126, 72),
    white = lcd.RGB(240, 231, 207),
    muted = lcd.RGB(160, 174, 187),
    cyan = lcd.RGB(49, 120, 198),
    cyanDim = lcd.RGB(19, 55, 94),
    green = lcd.RGB(86, 188, 125),
    greenDim = lcd.RGB(26, 79, 51),
    amber = lcd.RGB(216, 170, 78),
    amberDim = lcd.RGB(92, 61, 18),
    red = lcd.RGB(184, 48, 49),
    redDim = lcd.RGB(83, 24, 29),
    violet = lcd.RGB(184, 194, 207),
    violetDim = lcd.RGB(70, 80, 94)
}

-- America 250 uses a dedicated deep-navy instrument surface.

-- Cached red -> parchment white -> patriotic blue colors. The gradient is
-- built once at load time so the paint loop only replays draw calls.
local PATRIOTIC_GRADIENT = {}
local GRADIENT_STEPS = 18

local function lerp(a, b, t)
    return floor(a + (b - a) * t + 0.5)
end

local function buildPatrioticGradient()
    local red = {184, 48, 49}
    local white = {240, 231, 207}
    local blue = {49, 120, 198}
    for i = 0, GRADIENT_STEPS - 1 do
        local t = i / max(1, GRADIENT_STEPS - 1)
        local a, b, localT
        if t <= 0.5 then
            a, b, localT = red, white, t * 2
        else
            a, b, localT = white, blue, (t - 0.5) * 2
        end
        PATRIOTIC_GRADIENT[i + 1] = lcd.RGB(
            lerp(a[1], b[1], localT),
            lerp(a[2], b[2], localT),
            lerp(a[3], b[3], localT)
        )
    end
end

buildPatrioticGradient()

local function drawPatrioticGradient(x, y, w, h, reverse)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    if w <= 0 or h <= 0 then return end
    local lastX = x
    for i = 1, GRADIENT_STEPS do
        local nextX = x + floor(i * w / GRADIENT_STEPS)
        local colorIndex = reverse and (GRADIENT_STEPS - i + 1) or i
        lcd.color(PATRIOTIC_GRADIENT[colorIndex])
        lcd.drawFilledRectangle(lastX, y, max(1, nextX - lastX), h)
        lastX = nextX
    end
end

local function drawPatrioticTitleRail(x, y, w)
    drawPatrioticGradient(x, y, w, 4)
end

local function drawPatrioticTitle(x, y, w)
    local font = utils.resolveFont("FONT_STD", nil)
    if type(font) ~= "number" then return end
    lcd.font(font)
    local a, b, c, d = "AMERICA ", "250", "  //  ", "FREEDOM FLIGHT"
    local aw = lcd.getTextSize(a)
    local bw = lcd.getTextSize(b)
    local cw = lcd.getTextSize(c)
    local dw = lcd.getTextSize(d)
    local total = aw + bw + cw + dw
    local tx = x + max(0, (w - total) / 2)
    lcd.color(C.red)
    lcd.drawText(floor(tx), floor(y), a)
    lcd.color(C.white)
    lcd.drawText(floor(tx + aw), floor(y), b)
    lcd.color(C.amber)
    lcd.drawText(floor(tx + aw + bw), floor(y), c)
    lcd.color(C.cyan)
    lcd.drawText(floor(tx + aw + bw + cw), floor(y), d)
end

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

local function drawCenteredDotLine(x, y, w, leftText, rightText, fontName, textColor, dotColor)
    local font = resolveFont(fontName)
    if type(font) ~= "number" then return end
    lcd.font(font)

    local leftW, textH = lcd.getTextSize(leftText)
    local rightW = lcd.getTextSize(rightText)
    local dotSize = 3
    local gap = 7
    local totalW = leftW + gap + dotSize + gap + rightW
    local tx = floor(x + (w - totalW) / 2 + 0.5)
    local ty = floor(y + 0.5)

    lcd.color(textColor)
    lcd.drawText(tx, ty, leftText)

    local dotX = tx + leftW + gap
    local dotY = floor(y + (textH - dotSize) / 2 + 0.5)
    lcd.color(dotColor or textColor)
    lcd.drawFilledRectangle(dotX, dotY, dotSize, dotSize)

    lcd.color(textColor)
    lcd.drawText(dotX + dotSize + gap, ty, rightText)
end

local function drawCenteredTripleDotLine(x, y, w, leftText, middleText, rightText, fontName, textColor, dotColor)
    local font = resolveFont(fontName)
    if type(font) ~= "number" then return end
    lcd.font(font)

    local leftW, textH = lcd.getTextSize(leftText)
    local middleW = lcd.getTextSize(middleText)
    local rightW = lcd.getTextSize(rightText)
    local dotSize = 3
    local gap = 7
    local totalW = leftW + middleW + rightW + dotSize * 2 + gap * 4
    local tx = floor(x + (w - totalW) / 2 + 0.5)
    local ty = floor(y + 0.5)
    local dotY = floor(y + (textH - dotSize) / 2 + 0.5)

    lcd.color(textColor)
    lcd.drawText(tx, ty, leftText)

    local dot1X = tx + leftW + gap
    lcd.color(dotColor or textColor)
    lcd.drawFilledRectangle(dot1X, dotY, dotSize, dotSize)

    local middleX = dot1X + dotSize + gap
    lcd.color(textColor)
    lcd.drawText(middleX, ty, middleText)

    local dot2X = middleX + middleW + gap
    lcd.color(dotColor or textColor)
    lcd.drawFilledRectangle(dot2X, dotY, dotSize, dotSize)

    lcd.color(textColor)
    lcd.drawText(dot2X + dotSize + gap, ty, rightText)
end

local function drawPanel(x, y, w, h, accent, title)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.line)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(C.line2)
    lcd.drawRectangle(x + 2, y + 2, max(1, w - 4), max(1, h - 4), 1)

    drawPatrioticGradient(x + 3, y + 3, max(1, w - 6), 3)
    lcd.color(accent or C.cyan)
    lcd.drawFilledRectangle(x + 3, y + 6, 3, max(1, h - 9))

    if title then
        drawTextAligned(x + 13, y + 9, w - 24, title, "FONT_XS", C.muted, "left")
    end
end

local function drawStateBadge(x, y, w, h, label, color)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    color = color or C.muted
    lcd.color(C.panel2)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.line)
    lcd.drawRectangle(x, y, w, h, 1)
    drawPatrioticGradient(x + 2, y + 2, max(1, w - 4), 3)
    lcd.color(color)
    lcd.drawFilledRectangle(x + 2, y + 5, 4, max(1, h - 7))
    drawTextAligned(x + 10, y + 7, w - 18, label or "STATE --", "FONT_XS", color, "center")
end

local function drawMetric(x, y, w, h, title, valueText, accent, subtitle, subtitleYOffset)
    drawPanel(x, y, w, h, accent, title)
    drawTextAligned(x + 13, y + 30, w - 26, valueText, "FONT_XL", C.white, "left")
    if subtitle then
        drawTextAligned(x + 13, y + h - 24 + (subtitleYOffset or 0), w - 26, subtitle, "FONT_XXS", C.muted, "left")
    end
end

local function drawDualMetric(x, y, w, h, title, leftValue, rightValue, accent, subtitle)
    drawPanel(x, y, w, h, accent, title)
    drawTextAligned(x + 13, y + 30, w - 26, leftValue, "FONT_XL", C.white, "left")
    drawTextAligned(x + 13, y + 30, w - 26, rightValue, "FONT_XL", C.white, "right")
    if subtitle then
        drawTextAligned(x + 13, y + h - 24, w - 26, subtitle, "FONT_XXS", C.muted, "left")
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
            local segmentColor = activeColor
            if activeColor ~= C.red and activeColor ~= C.amber then
                if i <= floor(count / 3) then
                    segmentColor = C.red
                elseif i <= floor(count * 2 / 3) then
                    segmentColor = C.white
                else
                    segmentColor = C.cyan
                end
            end
            lcd.color(segmentColor)
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

local HEX_UNIT = {}
for i = 0, 5 do
    local a = rad(30 + i * 60)
    HEX_UNIT[i + 1] = {cos(a), sin(a)}
end

local function drawHex(x, y, radius, color)
    local points = {}
    for i = 1, 6 do
        local u = HEX_UNIT[i]
        points[i] = {x + u[1] * radius, y + u[2] * radius}
    end
    lcd.color(color)
    for i = 1, 6 do
        local a = points[i]
        local b = points[(i % 6) + 1]
        lcd.drawLine(floor(a[1]), floor(a[2]), floor(b[1]), floor(b[2]))
    end
end


local STAR_UNIT = {}
for i = 0, 9 do
    local a = rad(-90 + i * 36)
    STAR_UNIT[i + 1] = {cos(a), sin(a)}
end

local function drawStar(cx, cy, outerRadius, innerRadius, color)
    -- Streams the vertices instead of building a point list: this ran 13 times
    -- per drawStarRing call, so the old form cost 143 throwaway tables a frame.
    -- Same closed 10-gon (edges 1-2..9-10,10-1), same per-point floor.
    innerRadius = innerRadius or outerRadius * 0.45
    lcd.color(color)
    local firstx, firsty, px, py
    for i = 0, 9 do
        local radius = (i % 2 == 0) and outerRadius or innerRadius
        local u = STAR_UNIT[i + 1]
        local sx = floor(cx + u[1] * radius)
        local sy = floor(cy + u[2] * radius)
        if i == 0 then firstx, firsty = sx, sy else lcd.drawLine(px, py, sx, sy) end
        px, py = sx, sy
    end
    lcd.drawLine(px, py, firstx, firsty)
end

local STAR_RING13_UNIT = {}
for i = 0, 12 do
    local a = rad(-90 + (i + 0.5) * 360 / 13)
    STAR_RING13_UNIT[i + 1] = {cos(a), sin(a)}
end

local function drawPatrioticStarRing(cx, cy, radius, count)
    count = count or 13
    -- Rotate the 13-star ring by half a step so the title rail has a clean
    -- gap at twelve o'clock instead of a star touching the upper frame.
    for i = 0, count - 1 do
        local ux, uy
        if count == 13 then
            local u = STAR_RING13_UNIT[i + 1]
            ux, uy = u[1], u[2]
        else
            local angle = rad(-90 + (i + 0.5) * 360 / count)
            ux, uy = cos(angle), sin(angle)
        end
        local color
        local band = i / max(1, count - 1)
        if band < 0.34 then
            color = C.red
        elseif band < 0.67 then
            color = C.white
        else
            color = C.cyan
        end
        drawStar(cx + ux * radius, cy + uy * radius, 5, 2.2, color)
    end
end

local function drawShield(cx, cy, w, h, color)
    local top = cy - h * 0.50
    local left = cx - w * 0.50
    local right = cx + w * 0.50
    local shoulder = cy - h * 0.20
    local lower = cy + h * 0.22
    local tip = cy + h * 0.52
    lcd.color(color)
    lcd.drawLine(floor(left), floor(top), floor(right), floor(top))
    lcd.drawLine(floor(left), floor(top), floor(left), floor(shoulder))
    lcd.drawLine(floor(right), floor(top), floor(right), floor(shoulder))
    lcd.drawLine(floor(left), floor(shoulder), floor(cx - w * 0.34), floor(lower))
    lcd.drawLine(floor(right), floor(shoulder), floor(cx + w * 0.34), floor(lower))
    lcd.drawLine(floor(cx - w * 0.34), floor(lower), floor(cx), floor(tip))
    lcd.drawLine(floor(cx + w * 0.34), floor(lower), floor(cx), floor(tip))
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
    -- Match the proven Aegis telemetry path: keep the highest live RPM seen
    -- for the full inflight state and do not reset it from the flight timer.
    local c = box._cache
    if not c then
        c = {maxRpm = 0}
        box._cache = c
        sharedFlightStats.maxRpm = 0
    end

    c.rpm = sensor(telemetry, "rpm", "headspeed", "erpm") or 0
    c.maxRpm = max(c.maxRpm or 0, c.rpm)

    -- Mirror the Aegis live peak into a dashboard-level table so Mission
    -- Debrief can use it when ETHOS does not publish an RPM statistic.
    sharedFlightStats.maxRpm = c.maxRpm
    local session = rfsuite and rfsuite.session
    if session then
        local flightStats = session.america250FlightStats
        if type(flightStats) ~= "table" then
            flightStats = {}
            session.america250FlightStats = flightStats
        end
        flightStats.maxRpm = c.maxRpm
    end

    c.throttle = sensor(telemetry, "throttle_percent", "throttle") or 0
    c.esc = sensor(telemetry, "temp_esc", "esc_temp")
    c.fuel = sensor(telemetry, "smartfuel")
    c.current = sensor(telemetry, "current")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    c.link = sensor(telemetry, "link", "vfr")
    c.consumed = sensor(telemetry, "smartconsumption", "consumption")
    c.flightState, c.flightStateColor = getFlightState(telemetry)
    c.timer = flightTimeText()

    -- Cache theme thresholds here (wakeup runs at a bounded rate) instead of
    -- calling getThemeValue() from paint(), which runs on every invalidate.
    c.escMax = getThemeValue("esc_max")
    c.escWarn = getThemeValue("esc_warn")
    c.fuelWarn = getThemeValue("fuel_warn")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    c.linkWarn = getThemeValue("link_warn")
    c.rpmMax = getThemeValue("rpm_max")

    return c
end

local function drawRadialGauge(cx, cy, radius, value, maximum, color)
    local startA = 140
    local sweep = 260
    local ticks = 32
    local pct = maximum > 0 and max(0, min(1, value / maximum)) or 0
    local active = floor(ticks * pct + 0.5)
    local warning = color == C.red or color == C.amber

    for i = 0, ticks - 1 do
        local a = rad(startA + sweep * i / (ticks - 1))
        local r1 = radius - 14
        local r2 = radius
        local x1 = cx + cos(a) * r1
        local y1 = cy + sin(a) * r1
        local x2 = cx + cos(a) * r2
        local y2 = cy + sin(a) * r2
        local tickColor = C.line
        if i < active then
            if warning then
                tickColor = color
            else
                local gradientIndex = 1 + floor(i * (GRADIENT_STEPS - 1) / max(1, ticks - 1))
                tickColor = PATRIOTIC_GRADIENT[gradientIndex]
            end
        end
        lcd.color(tickColor)
        lcd.drawLine(floor(x1), floor(y1), floor(x2), floor(y2))
    end

end

local function drawVerticalMeter(x, y, w, h, title, value, maximum, color, unit)
    drawPanel(x, y, w, h, color, title)
    local barX = x + 15
    local barY = y + 38
    local barW = 14
    local barH = h - 58
    local pct = maximum > 0 and max(0, min(1, (value or 0) / maximum)) or 0
    lcd.color(C.line)
    lcd.drawRectangle(floor(barX), floor(barY), floor(barW), floor(barH), 1)
    if pct > 0 then
        local fillH = floor((barH - 4) * pct)
        lcd.color(color)
        lcd.drawFilledRectangle(floor(barX + 2), floor(barY + barH - 2 - fillH), floor(barW - 4), fillH)
    end
    drawTextAligned(x + 38, y + 48, w - 50, fmt(value, 0, unit), "FONT_L", C.white, "left")
    drawPatrioticGradient(x + 38, y + h - 21, max(8, w - 53), 3)
end

local function inflightPaint(x, y, w, h, box, c)
    x, y = utils.applyOffset(x, y, box)
    c = c or box._cache or {}

    -- Safety net: if paint() runs before the first wakeup() cycle has
    -- populated the cache (e.g. very first frame), fall back to a live
    -- lookup so we never compare a number against a nil threshold.
    c.escMax = c.escMax or getThemeValue("esc_max")
    c.escWarn = c.escWarn or getThemeValue("esc_warn")
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")
    c.rpmMax = c.rpmMax or getThemeValue("rpm_max")

    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))

    local pad = 12
    local topY = y + 6
    drawPatrioticTitleRail(x, y + 1, w)
    drawPatrioticTitle(x + pad, topY, w - 260)
    drawTextAligned(x + w - 222, topY - 3, 210, c.timer or "00:00", "FONT_XL", C.white, "right")
    drawPatrioticTitleRail(x + pad, y + 34, w - pad * 2)

    local bodyY = y + 44
    local bodyH = h - 58
    local leftW = floor(w * 0.18)
    local rightW = floor(w * 0.24)
    local centerX = x + pad + leftW + pad
    local centerW = w - leftW - rightW - pad * 4
    local leftX = x + pad
    local rightX = centerX + centerW + pad

    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.green)) or C.muted
    local throttleColor = (c.throttle or 0) >= 90 and C.amber or C.cyan
    local fuel = c.fuel or 0
    local fuelColor = fuel <= c.fuelWarn and C.red or (fuel <= 50 and C.amber or C.green)
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.cyan)) or C.muted
    local linkColor = c.link and (c.link < c.linkWarn and C.amber or C.cyan) or C.muted

    local halfH = floor((bodyH - pad) / 2)
    drawVerticalMeter(leftX, bodyY, leftW, halfH, "ESC TEMP", c.esc, c.escMax, escColor, "°")
    drawVerticalMeter(leftX, bodyY + halfH + pad, leftW, halfH, "THROTTLE", c.throttle, 100, throttleColor, "%")

    drawPanel(centerX, bodyY, centerW, bodyH, C.cyan, nil)
    local cx = centerX + centerW / 2
    local cy = bodyY + bodyH * 0.46
    local radius = min(centerW * 0.41, bodyH * 0.41)
    local rpmMax = c.rpmMax
    local rpmColor = (c.rpm or 0) > rpmMax and C.red or C.cyan

    drawPatrioticStarRing(cx, cy, radius + 17, 13)
    drawShield(cx, cy + 2, radius * 0.88, radius * 1.02, C.line2)
    drawRadialGauge(cx, cy, radius, c.rpm or 0, rpmMax, rpmColor)
    drawCenteredDotLine(centerX, cy - 59, centerW, "1776", "2026", "FONT_S", C.amber, C.amber)
    drawTextAligned(centerX, cy - 32, centerW, fmt(c.rpm, 0, ""), "FONT_XXL", C.white, "center")
    drawTextAligned(centerX, cy + 22, centerW, "HEADSPEED  RPM", "FONT_XS", C.muted, "center")
    drawTextAligned(centerX + 22, bodyY + bodyH - 34, centerW - 44, "MAX " .. fmt(c.maxRpm, 0, " RPM"), "FONT_XS", C.amber, "left")
    drawTextAligned(centerX + 22, bodyY + bodyH - 34, centerW - 44, "LIMIT " .. fmt(rpmMax, 0, " RPM"), "FONT_XS", C.muted, "right")

    local fuelH = floor(bodyH * 0.34)
    drawPanel(rightX, bodyY, rightW, fuelH, fuelColor, "SMART FUEL")
    drawTextAligned(rightX + 12, bodyY + 38, rightW - 24, fmt(c.fuel, 0, "%"), "FONT_XL", C.white, "right")
    drawSegments(rightX + 12, bodyY + fuelH - 38, rightW - 32, 16, fuel, 10, fuelColor, C.line)
    lcd.color(fuelColor)
    lcd.drawFilledRectangle(floor(rightX + rightW - 16), floor(bodyY + fuelH - 34), 4, 8)

    local stateGap = 8
    local stateH = 30
    local stateY = bodyY + fuelH + stateGap
    drawStateBadge(rightX, stateY, rightW, stateH, c.flightState, c.flightStateColor)

    local smallY = stateY + stateH + stateGap
    local smallH = floor((bodyY + bodyH - smallY - pad) / 2)
    drawMetric(rightX, smallY, rightW, smallH, "POWER LOAD", fmt(c.current, 1, " A"), C.violet, "INSTANTANEOUS", 3)
    drawDualMetric(
        rightX,
        smallY + smallH + pad,
        rightW,
        smallH,
        "BEC / LINK",
        fmt(c.bec, 1, " V"),
        fmt(c.link, 0, "%"),
        becColor == C.red and C.red or linkColor,
        "POWER + RADIO HEALTH"
    )

    local throttleY = bodyY + halfH + pad
    local consumedX = leftX + 38
    local consumedW = leftW - 50
    local consumedLabelY = throttleY + halfH - 71
    local consumedValueY = consumedLabelY + 18
    drawTextAligned(consumedX, consumedLabelY, consumedW, "CONSUMED", "FONT_XXS", C.muted, "center")
    drawTextAligned(consumedX, consumedValueY, consumedW, fmt(c.consumed, 0, " mAh"), "FONT_XS", C.white, "center")

    drawCenteredTripleDotLine(
        x + pad, y + h - 16, w - pad * 2,
        "13 ORIGINAL COLONIES", "FREEDOM FLIGHT", "MWRC",
        "FONT_XXS", C.line2, C.amber
    )
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

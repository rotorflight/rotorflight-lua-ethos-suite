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
-- built once when the theme loads so the paint loop only performs draw calls.
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

-- Medium-weight patriotic title rail. Four pixels keeps the transition
-- visible on the radio while staying sharper than the original heavy bands.
local function drawPatrioticTitleRail(x, y, w)
    drawPatrioticGradient(x, y, w, 4)
end

local function drawPatrioticTitle(x, y, w)
    local font = utils.resolveFont("FONT_STD", nil)
    if type(font) ~= "number" then return end
    lcd.font(font)
    local a, b, c, d = "AMERICA ", "250", "  //  ", "LIBERTY READINESS"
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

-- Draw a separator as geometry instead of relying on the UTF-8 bullet glyph,
-- which is not present in every ETHOS font build.
local function drawCenteredDotLine(x, y, w, leftText, rightText, fontName, color)
    local font = resolveFont(fontName)
    if type(font) ~= "number" then return end
    lcd.font(font)
    local leftW, textH = lcd.getTextSize(leftText)
    local rightW = lcd.getTextSize(rightText)
    local dotSize = 4
    local gap = 8
    local totalW = leftW + gap + dotSize + gap + rightW
    local tx = floor(x + (w - totalW) / 2 + 0.5)

    lcd.color(color)
    lcd.drawText(tx, floor(y + 0.5), leftText)

    local dotX = tx + leftW + gap
    local dotY = floor(y + (textH - dotSize) / 2 + 0.5)
    lcd.drawFilledRectangle(dotX, dotY, dotSize, dotSize)

    lcd.drawText(dotX + dotSize + gap, floor(y + 0.5), rightText)
end

local function drawPanel(x, y, w, h, accent, title)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.line)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(C.line2)
    lcd.drawRectangle(x + 2, y + 2, max(1, w - 4), max(1, h - 4), 1)

    -- Patriotic identity rail across every instrument card, while the slim
    -- state strip preserves warning/healthy meaning.
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

local function drawMetric(x, y, w, h, title, valueText, accent, subtitle)
    drawPanel(x, y, w, h, accent, title)
    drawTextAligned(x + 13, y + 30, w - 26, valueText, "FONT_XL", C.white, "left")
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

local function drawStarRing(cx, cy, radius, count, color)
    count = count or 13
    for i = 0, count - 1 do
        local angle = rad(-90 + i * 360 / count)
        drawStar(cx + cos(angle) * radius, cy + sin(angle) * radius, 5, 2.2, color)
    end
end

local STAR_RING13_UNIT = {}
for i = 0, 12 do
    local a = rad(-90 + i * 360 / 13)
    STAR_RING13_UNIT[i + 1] = {cos(a), sin(a)}
end

local function drawPatrioticStarRing(cx, cy, radius, count)
    count = count or 13
    for i = 0, count - 1 do
        local ux, uy
        if count == 13 then
            local u = STAR_RING13_UNIT[i + 1]
            ux, uy = u[1], u[2]
        else
            local angle = rad(-90 + i * 360 / count)
            ux, uy = cos(angle), sin(angle)
        end
        local sx = cx + ux * radius
        local sy = cy + uy * radius
        local color
        if sx < cx - radius * 0.22 then
            color = C.red
        elseif sx > cx + radius * 0.22 then
            color = C.cyan
        else
            color = C.white
        end

        -- Keep all 13 original-colony stars, but shrink the two lowest ones
        -- so the readiness details below the seal remain open and readable.
        local lowerArc = uy > 0.82
        drawStar(sx, sy, lowerArc and 3.5 or 5, lowerArc and 1.6 or 2.2, color)
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

local function preflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c

    c.fuel = sensor(telemetry, "smartfuel")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    c.esc = sensor(telemetry, "temp_esc", "esc_temp")
    c.link = sensor(telemetry, "link", "vfr")
    c.rate = sensor(telemetry, "rate_profile")
    c.pid = sensor(telemetry, "pid_profile")
    c.voltage = sensor(telemetry, "voltage")
    c.flightState, c.flightStateColor = getFlightState(telemetry)

    -- Cache theme thresholds here (wakeup runs at a bounded rate) instead of
    -- calling getThemeValue() from paint(), which runs on every invalidate.
    c.fuelWarn = getThemeValue("fuel_warn")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    c.escMax = getThemeValue("esc_max")
    c.escWarn = getThemeValue("esc_warn")
    c.linkWarn = getThemeValue("link_warn")

    local available = 0
    local faults = 0
    local warnings = 0
    local issues = {}

    if c.fuel ~= nil then
        available = available + 1
        if c.fuel <= c.fuelWarn then
            faults = faults + 1
            issues[#issues + 1] = "SMART FUEL " .. fmt(c.fuel, 0, "%") .. " AT RESERVE"
        end
    end
    if c.bec ~= nil then
        available = available + 1
        if c.bec < c.becMin then
            faults = faults + 1
            issues[#issues + 1] = "BEC " .. fmt(c.bec, 1, "V") .. " BELOW " .. fmt(c.becMin, 1, "V")
        elseif c.bec < c.becWarn then
            warnings = warnings + 1
            issues[#issues + 1] = "BEC " .. fmt(c.bec, 1, "V") .. " BELOW " .. fmt(c.becWarn, 1, "V")
        end
    end
    if c.esc ~= nil then
        available = available + 1
        if c.esc >= c.escMax then
            faults = faults + 1
            issues[#issues + 1] = "ESC " .. fmt(c.esc, 0, "°C") .. " AT LIMIT"
        elseif c.esc >= c.escWarn then
            warnings = warnings + 1
            issues[#issues + 1] = "ESC " .. fmt(c.esc, 0, "°C") .. " ABOVE WARNING"
        end
    end
    if c.link ~= nil then
        available = available + 1
        if c.link < c.linkWarn then
            warnings = warnings + 1
            issues[#issues + 1] = "LINK " .. fmt(c.link, 0, "%") .. " BELOW " .. fmt(c.linkWarn, 0, "%")
        end
    end

    local issueCount = faults + warnings
    c.issueText = issues[1]
    c.issueMore = max(0, issueCount - 1)

    if available == 0 then
        c.status = "WAITING"
        c.statusColor = C.muted
        c.statusSub = "AWAITING TELEMETRY"
        c.issueText = nil
    elseif faults > 0 then
        c.status = "CHECK"
        c.statusColor = C.red
        c.statusSub = tostring(issueCount) .. " ITEM" .. (issueCount == 1 and "" or "S") .. " FLAGGED"
    elseif warnings > 0 then
        c.status = "CAUTION"
        c.statusColor = C.amber
        c.statusSub = tostring(issueCount) .. " ITEM" .. (issueCount == 1 and "" or "S") .. " TO REVIEW"
    else
        c.status = "READY"
        c.statusColor = C.green
        c.statusSub = "READY FOR FLIGHT"
        c.issueText = nil
    end

    return c
end

local function drawCheckRow(x, y, w, label, value, stateColor)
    lcd.color(stateColor)
    lcd.drawFilledRectangle(floor(x), floor(y + 6), 7, 7)

    -- Reserve a fixed right-hand value column so every profile value lands on
    -- the same edge regardless of label length or number of digits.
    local valueW = 64
    drawTextAligned(x + 14, y, max(1, w - valueW - 18), label, "FONT_XS", C.muted, "left")
    drawTextAligned(x + w - valueW, y, valueW, value, "FONT_S", C.white, "right")
end

local function preflightPaint(x, y, w, h, box, c)
    x, y = utils.applyOffset(x, y, box)
    c = c or box._cache or {}

    -- Safety net: if paint() runs before the first wakeup() cycle has
    -- populated the cache (e.g. very first frame), fall back to a live
    -- lookup so we never compare a number against a nil threshold.
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    c.escMax = c.escMax or getThemeValue("esc_max")
    c.escWarn = c.escWarn or getThemeValue("esc_warn")
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")

    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))

    local pad = 12
    local topY = y + 6

    -- Medium-thickness smooth gradients preserve the red-to-white-to-blue
    -- transition while keeping the title framing crisp and restrained.
    drawPatrioticTitleRail(x, y + 1, w)
    drawPatrioticTitle(x + pad, topY, w - 250)
    drawTextAligned(x + w - 222, topY, 210, c.status or "WAITING", "FONT_STD", c.statusColor or C.muted, "right")
    drawPatrioticTitleRail(x + pad, y + 34, w - pad * 2)

    local bodyY = y + 44
    local bodyH = h - 58
    local sideW = floor(w * 0.25)
    local centerW = w - sideW * 2 - pad * 4
    local leftX = x + pad
    local centerX = leftX + sideW + pad
    local rightX = centerX + centerW + pad

    local cardH = floor((bodyH - pad) / 2)
    local fuel = c.fuel or 0
    local fuelColor = fuel <= c.fuelWarn and C.red or (fuel <= 50 and C.amber or C.green)
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.cyan)) or C.muted
    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.green)) or C.muted
    local linkColor = c.link and (c.link < c.linkWarn and C.amber or C.cyan) or C.muted

    local progressInset = 14
    local progressH = 8

    drawMetric(leftX, bodyY, sideW, cardH, "BEC POWER", fmt(c.bec, 1, " V"), becColor, "REGULATED SUPPLY")
    drawProgress(leftX + progressInset, bodyY + cardH - 37, sideW - progressInset * 2, progressH, c.bec and c.bec / 15 or 0, becColor)

    drawMetric(leftX, bodyY + cardH + pad, sideW, cardH, "RADIO LINK", fmt(c.link, 0, "%"), linkColor, "FRAME QUALITY")
    drawProgress(leftX + progressInset, bodyY + cardH * 2 + pad - 37, sideW - progressInset * 2, progressH, c.link and c.link / 100 or 0, linkColor)

    drawPanel(centerX, bodyY, centerW, bodyH, c.statusColor or C.muted, nil)
    local cx = centerX + centerW / 2
    local cy = bodyY + bodyH * 0.38
    local radius = min(centerW * 0.33, bodyH * 0.29)

    -- Commemorative readiness seal: 13 original-colony stars and a double
    -- shield. The hierarchy deliberately gives the main state the most space,
    -- followed by the anniversary line and one concise diagnostic line.
    drawPatrioticStarRing(cx, cy - 1, radius + 19, 13)
    drawShield(cx, cy, radius * 1.24, radius * 1.52, C.line2)
    drawShield(cx, cy, radius * 1.08, radius * 1.34, c.statusColor or C.muted)
    drawTextAligned(centerX, cy - 46, centerW, c.status or "WAITING", "FONT_XXL", C.white, "center")
    drawCenteredDotLine(centerX, cy + 7, centerW, "1776", "2026", "FONT_XS", C.amber)

    if c.issueText then
        drawTextAligned(centerX + 16, cy + 33, centerW - 32, c.issueText, "FONT_XXS", C.white, "center")
        drawTextAligned(centerX, cy + 51, centerW, c.statusSub or "ITEM TO REVIEW", "FONT_XXS", c.statusColor or C.muted, "center")
    else
        drawTextAligned(centerX, cy + 37, centerW, c.statusSub or "AWAITING TELEMETRY", "FONT_XXS", c.statusColor or C.muted, "center")
    end

    local segY = bodyY + bodyH - 86
    drawTextAligned(centerX + 18, segY - 24, centerW - 36, "SMART FUEL", "FONT_XS", C.muted, "left")
    drawTextAligned(centerX + 18, segY - 26, centerW - 36, fmt(c.fuel, 0, "%"), "FONT_S", C.white, "right")
    drawSegments(centerX + 18, segY, centerW - 42, 18, fuel, 12, fuelColor, C.line)
    lcd.color(fuelColor)
    lcd.drawFilledRectangle(floor(centerX + centerW - 20), floor(segY + 5), 5, 8)

    drawStateBadge(centerX + 18, segY + 31, centerW - 36, 29, c.flightState, c.flightStateColor)

    -- Keep the commemorative signature inside the center Smart Fuel panel so
    -- it reads as part of the flight-readiness instrument rather than as a
    -- detached screen footer.
    drawCenteredDotLine(
        centerX + 18,
        segY + 65,
        centerW - 36,
        "13 ORIGINAL COLONIES",
        "250 YEARS OF LIBERTY",
        "FONT_XXS",
        C.line2
    )

    drawMetric(rightX, bodyY, sideW, cardH, "ESC THERMAL", fmt(c.esc, 0, "°C"), escColor, "CONTROLLER TEMP")
    drawProgress(rightX + progressInset, bodyY + cardH - 37, sideW - progressInset * 2, progressH, c.esc and c.esc / c.escMax or 0, escColor)

    drawPanel(rightX, bodyY + cardH + pad, sideW, cardH, C.violet, "LIBERTY PROFILE")
    drawCheckRow(rightX + 14, bodyY + cardH + pad + 38, sideW - 28, "RATES", fmt(c.rate, 0, ""), C.red)
    drawCheckRow(rightX + 14, bodyY + cardH + pad + 72, sideW - 28, "PID BANK", fmt(c.pid, 0, ""), C.white)
    drawCheckRow(rightX + 14, bodyY + cardH + pad + 106, sideW - 28, "PACK", fmt(c.voltage, 1, " V"), C.cyan)

end

local boxes_cache = nil

local function boxes()
    if boxes_cache == nil then
        boxes_cache = {{
        col = 1, row = 1, colspan = 12, rowspan = 12,
        type = "func", subtype = "func",
        wakeup = preflightWakeup,
        paint = preflightPaint,
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

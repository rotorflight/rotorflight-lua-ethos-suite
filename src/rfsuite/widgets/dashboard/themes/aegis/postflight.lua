local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd
local math = math
local floor = math.floor
local min = math.min
local max = math.max
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

                    lcd.color(C.cyan)
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
                        lcd.color(C.cyan)
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

local THEME_SECTION = "system/aegis"
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

local function drawProgress(x, y, w, h, percent, color)
    percent = max(0, min(1, percent or 0))
    lcd.color(C.line)
    lcd.drawRectangle(floor(x), floor(y), floor(w), floor(h), 1)
    if percent > 0 then
        lcd.color(color)
        lcd.drawFilledRectangle(floor(x + 2), floor(y + 2), floor((w - 4) * percent), max(1, floor(h - 4)))
    end
end

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}

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

local function temperatureStat(telemetry, warning, maximum)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    local stats = telemetry and telemetry.getSensorStats and telemetry.getSensorStats("temp_esc")
    local value = stats and tonumber(stats.max) or nil
    local unit = "°C"
    local displayWarning = warning
    local displayMaximum = maximum

    if telemetry and telemetry.getSensor then
        local _, _, localizedUnit, localizedWarning, localizedMaximum = telemetry.getSensor("temp_esc", warning, maximum)
        unit = localizedUnit or unit
        displayWarning = tonumber(localizedWarning) or displayWarning
        displayMaximum = tonumber(localizedMaximum) or displayMaximum
    end

    return value, unit, displayWarning, displayMaximum
end


local function ensureCards(c)
    if c.cards then return c.cards end
    c.cards = {
        {"MAX HEADSPEED", "--", C.muted, 0},
        {"MAX ESC TEMP", "--", C.muted, 0},
        {"PEAK CURRENT", "--", C.muted, 0},
        {"MIN BEC", "--", C.muted, 0},
        {"MIN LINK", "--", C.muted, 0},
        {"FUEL REMAINING", "--", C.muted, 0},
        {"CONSUMED", "--", C.muted, 0},
        {"PEAK POWER", "--", C.muted, 0},
        {"MIN PACK / ALT", "--  /  --", C.muted, 0}
    }
    return c.cards
end

local function updateCard(card, value, decimals, suffix, color, percent)
    if card._value ~= value or card._suffix ~= suffix then
        card._value = value
        card._suffix = suffix
        card[2] = fmt(value, decimals, suffix)
    end
    card[3] = color
    card[4] = percent or 0
end

local function updatePackAltitudeCard(card, voltage, altitude, color, percent)
    if card._voltage ~= voltage or card._altitude ~= altitude then
        card._voltage = voltage
        card._altitude = altitude
        card[2] = fmt(voltage, 1, " V") .. "  /  " .. fmt(altitude, 0, " m")
    end
    card[3] = color
    card[4] = percent or 0
end

local function postflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c

    c.rpmMax = getThemeValue("rpm_max")
    local escWarnC = getThemeValue("esc_warn")
    local escMaxC = getThemeValue("esc_max")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    c.fuelWarn = getThemeValue("fuel_warn")
    c.linkWarn = getThemeValue("link_warn")

    c.rpm = stat(telemetry, "rpm", "max", "headspeed", "erpm")
    if c.rpm and c.rpm <= 0 then c.rpm = nil end
    c.esc, c.escUnit, c.escWarn, c.escMax = temperatureStat(telemetry, escWarnC, escMaxC)
    c.current = stat(telemetry, "current", "max")
    c.watts = stat(telemetry, "watts", "max")
    c.bec = stat(telemetry, "bec_voltage", "min", "bec")
    c.link = stat(telemetry, "vfr", "min")
    c.fuel = stat(telemetry, "smartfuel", "min")
    c.consumed = stat(telemetry, "smartconsumption", "max", "consumption")
    c.voltage = stat(telemetry, "voltage", "min")
    c.altitude = stat(telemetry, "altitude", "max")

    local session = rfsuite and rfsuite.session
    local seconds = session and session.timer and tonumber(session.timer.live) or 0
    seconds = floor(max(0, seconds))
    if c._timeSecond ~= seconds then
        c._timeSecond = seconds
        c.time = format("%02d:%02d", floor(seconds / 60), seconds % 60)
    end

    local faults = 0
    local cautions = 0
    if c.esc and c.esc >= c.escMax then faults = faults + 1
    elseif c.esc and c.esc >= c.escWarn then cautions = cautions + 1 end
    if c.bec and c.bec < c.becMin then faults = faults + 1
    elseif c.bec and c.bec < c.becWarn then cautions = cautions + 1 end
    if c.fuel and c.fuel <= c.fuelWarn then cautions = cautions + 1 end
    if c.link and c.link < c.linkWarn then cautions = cautions + 1 end
    if c.rpm and c.rpm > c.rpmMax * 1.05 then cautions = cautions + 1 end

    local available = 0
    if c.rpm ~= nil then available = available + 1 end
    if c.esc ~= nil then available = available + 1 end
    if c.current ~= nil then available = available + 1 end
    if c.watts ~= nil then available = available + 1 end
    if c.bec ~= nil then available = available + 1 end
    if c.link ~= nil then available = available + 1 end
    if c.fuel ~= nil then available = available + 1 end
    if c.consumed ~= nil then available = available + 1 end
    if c.voltage ~= nil then available = available + 1 end
    if c.altitude ~= nil then available = available + 1 end

    if available == 0 then
        c.grade = "NO DATA"
        c.gradeColor = C.muted
        c.gradeSub = "NO FLIGHT TELEMETRY"
    elseif faults > 0 then
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

    local rpmColor = c.rpm == nil and C.muted or (c.rpm > c.rpmMax * 1.05 and C.amber or C.cyan)
    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.green)) or C.muted
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.cyan)) or C.muted
    local fuelColor = c.fuel == nil and C.muted or (c.fuel <= c.fuelWarn and C.amber or C.green)
    local linkColor = c.link == nil and C.muted or (c.link < c.linkWarn and C.amber or C.cyan)
    local currentColor = c.current ~= nil and C.violet or C.muted
    local consumedColor = c.consumed ~= nil and C.amber or C.muted
    local wattsColor = c.watts ~= nil and C.violet or C.muted
    local packAltitudeColor = (c.voltage ~= nil or c.altitude ~= nil) and C.cyan or C.muted

    local cards = ensureCards(c)
    updateCard(cards[1], c.rpm, 0, " RPM", rpmColor, c.rpm and c.rpm / c.rpmMax or 0)
    updateCard(cards[2], c.esc, 0, c.escUnit, escColor, c.esc and c.esc / c.escMax or 0)
    updateCard(cards[3], c.current, 1, " A", currentColor, c.current and c.current / 150 or 0)
    updateCard(cards[4], c.bec, 2, " V", becColor, c.bec and c.bec / 15 or 0)
    updateCard(cards[5], c.link, 0, "%", linkColor, c.link and c.link / 100 or 0)
    updateCard(cards[6], c.fuel, 0, "%", fuelColor, c.fuel and c.fuel / 100 or 0)
    updateCard(cards[7], c.consumed, 0, " mAh", consumedColor, c.consumed and c.consumed / 5000 or 0)
    updateCard(cards[8], c.watts, 0, " W", wattsColor, c.watts and c.watts / 5000 or 0)
    updatePackAltitudeCard(cards[9], c.voltage, c.altitude, packAltitudeColor, c.voltage and c.voltage / 60 or 0)

    return c
end

local function drawReportCard(x, y, w, h, title, value, accent, percent)
    drawPanel(x, y, w, h, accent, title)
    local valueColor = accent == C.muted and C.muted or C.white
    drawTextAligned(x + 12, y + 28, w - 24, value, "FONT_L", valueColor, "left")
    drawProgress(x + 12, y + h - 19, w - 24, 7, percent or 0, accent)
end

local EMPTY_CARDS = {}

local function postflightPaint(x, y, w, h, box, c, telemetry)
    c = c or box._cache or {}

    -- Safety net: if paint() runs before the first wakeup() cycle has
    -- populated the cache (e.g. very first frame), fall back to a live
    -- lookup so we never compare a number against a nil threshold.
    c.rpmMax = c.rpmMax or getThemeValue("rpm_max")
    if c.escMax == nil or c.escWarn == nil then
        local escWarnC = getThemeValue("esc_warn")
        local escMaxC = getThemeValue("esc_max")
        local _, unit, displayWarn, displayMax = temperatureStat(telemetry, escWarnC, escMaxC)
        c.escUnit, c.escWarn, c.escMax = unit, displayWarn, displayMax
    end
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")

    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))

    local pad = 12
    drawTextAligned(x + pad, y + 8, w * 0.5, "AEGIS // DEBRIEF", "FONT_STD", C.cyan, "left")
    drawTextAligned(x + w - 240, y + 6, 228, c.grade or "NO DATA", "FONT_L", c.gradeColor or C.muted, "right")

    local summaryY = y + 42
    local summaryH = 62
    drawPanel(x + pad, summaryY, w - pad * 2, summaryH, c.gradeColor or C.muted, nil)
    drawTextAligned(x + pad + 16, summaryY + 10, w * 0.5, c.gradeSub or "NO FLIGHT TELEMETRY", "FONT_S", C.white, "left")
    drawTextAligned(x + w - 220, summaryY + 8, 190, c.time or "00:00", "FONT_XL", C.white, "right")
    drawTextAligned(x + w - 220, summaryY + 39, 190, "FLIGHT TIME", "FONT_XXS", C.muted, "right")

    local gridY = summaryY + summaryH + pad
    local gridH = h - (gridY - y) - pad
    local cols = 3
    local rows = 3
    local gap = 10
    local cardW = floor((w - pad * 2 - gap * (cols - 1)) / cols)
    local cardH = floor((gridH - gap * (rows - 1)) / rows)

    local cards = c.cards or EMPTY_CARDS

    for i = 1, #cards do
        local row = floor((i - 1) / cols)
        local col = (i - 1) % cols
        local card = cards[i]
        local cx = x + pad + col * (cardW + gap)
        local cy = gridY + row * (cardH + gap)
        drawReportCard(cx, cy, cardW, cardH, card[1], card[2], card[3], card[4])
    end
end

local boxes_cache = nil

local function boxes()
    if boxes_cache == nil then
        boxes_cache = {{
        col = 1, row = 1, colspan = 12, rowspan = 12,
        type = "func", subtype = "func",
        wakeup = postflightWakeup,
        paint = postflightPaint,
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

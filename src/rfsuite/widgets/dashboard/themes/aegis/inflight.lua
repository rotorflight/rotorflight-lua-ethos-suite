local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd
local math = math
local floor = math.floor
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local rad = math.rad
local rawNumber = tonumber
local function tonumber(value)
    local number = rawNumber(value)
    if number and number == number and number >= -1000000000 and number <= 1000000000 then return number end
    return nil
end
local tostring = tostring
local type = type
local format = string.format

local utils = rfsuite.widgets.dashboard.utils

-- Keep the live craft/model name readable inside its native header slot.
local function paintModelName(x, y, w, h, box)
    local value = rfsuite.session and rfsuite.session.craftName
    if type(value) ~= "string" or value:match("^%s*$") then
        value = model and model.name and model.name() or "--"
    end
    if type(value) ~= "string" or value == "" then value = "--" end
    if box._modelValue ~= value or box._modelWidth ~= w then
        local text = value
        local font = utils.resolveFont("FONT_S", nil)
        lcd.font(font)
        local tw, th = lcd.getTextSize(text)
        if tw > w - 10 then
            font = utils.resolveFont("FONT_XS", nil)
            lcd.font(font)
            tw, th = lcd.getTextSize(text)
        end
        if tw > w - 10 then
            -- Shorten whole UTF-8 characters, only when name or geometry changes.
            local cut = #text
            repeat
                while cut > 1 and text:byte(cut) >= 128 and text:byte(cut) < 192 do cut = cut - 1 end
                cut = cut - 1
                text = value:sub(1, cut)
                tw, th = lcd.getTextSize(text .. "...")
            until tw <= w - 10 or cut == 0
            text = text .. "..."
        end
        box._modelValue, box._modelWidth = value, w
        box._modelText, box._modelFont, box._modelHeight = text, font, th
    end
    utils.drawBoxBackground(x, y, w, h, box.bgcolor)
    lcd.font(box._modelFont)
    lcd.color(box.textcolor)
    lcd.drawText(math.floor(x + 5), math.floor(y + (h - box._modelHeight) / 2), box._modelText)
end
local headeropts = utils.getHeaderOptions()
-- This theme owns its header geometry; leave the Suite defaults unchanged.
headeropts.height = math.max(headeropts.height or 0, 44)
-- The Suite caches its native palette; each theme owns its presentation copy.
local colorMode = {}
for key, value in pairs(utils.themeColors()) do colorMode[key] = value end
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
            if headerBox.subtype == "craftname" then
                headerBox.type, headerBox.subtype = "func", "func"
                headerBox.paint = paintModelName
            end
            if headerBox.type == "image" then
                headerBox.type = "func"
                headerBox.subtype = "func"
                headerBox.bgcolor = "transparent"
                headerBox.paint = function(x, y, w, h)
                    lcd.color(C.panel)
                    lcd.drawFilledRectangle(math.floor(x), math.floor(y), math.floor(w), math.floor(h))
                    local cache = headerBox
                    -- Measure only when the header geometry changes; keep the builder mark smaller.
                    if cache._titleWidth ~= w or cache._titleLayoutHeight ~= h then
                        local titleFont = utils.resolveFont("FONT_L", nil)
                        local markFont = utils.resolveFont("FONT_XS", nil)
                        if type(titleFont) ~= "number" or type(markFont) ~= "number" then return end
                        lcd.font(markFont)
                        local mw, mh = lcd.getTextSize("| MWRC")
                        lcd.font(titleFont)
                        local tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        if tw + mw + 24 > w or th > h - 4 then
                            titleFont = utils.resolveFont("FONT_STD", nil) or titleFont
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        end
                        if tw + mw + 24 > w or th > h - 4 then
                            titleFont = utils.resolveFont("FONT_S", nil) or titleFont
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        end
                        -- Narrow header slots retain the same hierarchy with the smallest pair.
                        if tw + mw + 24 > w or th > h - 4 then
                            titleFont = utils.resolveFont("FONT_XS", nil) or titleFont
                            markFont = utils.resolveFont("FONT_XXS", nil) or markFont
                            lcd.font(markFont)
                            mw, mh = lcd.getTextSize("| MWRC")
                            lcd.font(titleFont)
                            tw, th = lcd.getTextSize("Rotorflight // Ethos")
                        end
                        cache._titleWidth = w
                        cache._titleLayoutHeight = h
                        cache._titleFont = titleFont
                        cache._titleHeight = th
                        cache._titleTextWidth = tw
                        cache._markFont = markFont
                        cache._markHeight = mh
                        cache._titleGroupWidth = tw + 8 + mw
                    end
                    local screenW = lcd.getWindowSize()
                    local groupX = math.floor((screenW - cache._titleGroupWidth) / 2 + 0.5)
                    lcd.font(cache._titleFont)
                    lcd.color(C.cyan)
                    lcd.drawText(groupX, math.floor(y + (h - cache._titleHeight) / 2), "Rotorflight // Ethos")
                    lcd.font(cache._markFont)
                    lcd.color(C.muted)
                    lcd.drawText(groupX + cache._titleTextWidth + 8, math.floor(y + (h - cache._markHeight) / 2), "| MWRC")
                end
            end
        end

        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

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

-- Keep telemetry contrast stable when the transmitter uses a light system theme.
colorMode.bgcolor = C.bg
colorMode.tbbgcolor = C.panel
colorMode.tbtextcolor = C.white
colorMode.cntextcolor = C.white
colorMode.rssitextcolor = C.white
colorMode.rssifillcolor = C.cyan or C.turquoise
colorMode.rssifillbgcolor = C.line
colorMode.txbgfillcolor = C.line
colorMode.txfillcolor = C.green or C.emerald

local function getThemeValue(key)
    -- The rewritten Suite binds preferences to the active dashboard theme.
    local value = tonumber(rfsuite.widgets.dashboard.getPreference(key))

    return value or DEFAULTS[key]
end

local function sensor(telemetry, name, alias1, alias2)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    if not (telemetry and telemetry.getSensor) then return nil end
    local value = tonumber((telemetry.getSensor(name)))
    if value ~= nil then return value end
    if alias1 then
        value = tonumber((telemetry.getSensor(alias1)))
        if value ~= nil then return value end
    end
    if alias2 then
        value = tonumber((telemetry.getSensor(alias2)))
        if value ~= nil then return value end
    end
    return nil
end

local function temperatureSensor(telemetry, warning, maximum)
    telemetry = telemetry or (rfsuite.tasks and rfsuite.tasks.telemetry)
    if not (telemetry and telemetry.getSensor) then
        return nil, "°C", warning, maximum
    end

    local value, _, unit, displayWarning, displayMaximum = telemetry.getSensor("temp_esc", warning, maximum)
    return tonumber(value), unit or "°C", tonumber(displayWarning) or warning, tonumber(displayMaximum) or maximum
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

local function cacheText(c, textKey, valueKey, unitKey, value, decimals, suffix, prefix)
    suffix = suffix or ""
    local scale = decimals == 2 and 100 or (decimals == 1 and 10 or 1)
    value = value and floor(value * scale + 0.5) / scale or nil
    if c[valueKey] ~= value or c[unitKey] ~= suffix or c[textKey] == nil then
        c[valueKey] = value
        c[unitKey] = suffix
        c[textKey] = (prefix or "") .. fmt(value, decimals, suffix)
    end
end

local function resolveFont(name)
    return utils.resolveFont(name, nil)
end

local FONT_FALLBACK = {
    FONT_XXL = "FONT_XL", FONT_XL = "FONT_L", FONT_L = "FONT_STD",
    FONT_STD = "FONT_S", FONT_S = "FONT_XS", FONT_XS = "FONT_XXS"
}

local function drawTextAligned(x, y, w, text, fontName, color, align)
    local font = resolveFont(fontName)
    if type(font) ~= "number" then return 0, 0 end
    lcd.font(font)
    lcd.color(color)
    local tw, th = lcd.getTextSize(text)
    -- Step down through native fonts when narrow cards cannot fit a reading.
    local nextFont = FONT_FALLBACK[fontName]
    while tw > w and nextFont do
        local smaller = resolveFont(nextFont)
        if type(smaller) == "number" then
            lcd.font(smaller)
            tw, th = lcd.getTextSize(text)
        end
        nextFont = FONT_FALLBACK[nextFont]
    end
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
    local compact = h < 110
    local valueY = h < 64 and 22 or 28
    local valueFont = h < 64 and "FONT_S" or (compact and "FONT_L" or "FONT_XL")
    drawTextAligned(x + 13, y + valueY, w - 26, valueText, valueFont, valueText == "--" and C.muted or C.white, "left")
    if subtitle and h >= 100 then
        drawTextAligned(x + 13, y + h - 22, w - 26, subtitle, "FONT_XXS", C.muted, "left")
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

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}

local function updateFlightTime(c)
    local session = rfsuite and rfsuite.session
    local rawTime = session and session.timer and session.timer.live
    local seconds = tonumber(rawTime)
    local invalidTime = rawTime ~= nil and (seconds == nil or seconds < 0)
    seconds = floor(max(0, seconds or 0))
    if c._timerSecond ~= seconds or c._invalidTime ~= invalidTime then
        c._invalidTime = invalidTime
        c._timerSecond = seconds
        c.timer = invalidTime and "--:--" or format("%02d:%02d", floor(seconds / 60), seconds % 60)
    end
end

local function inflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c

    local escWarnC = getThemeValue("esc_warn")
    local escMaxC = getThemeValue("esc_max")

    c.rpm = sensor(telemetry, "rpm", "headspeed", "erpm")
    local rpmStats = telemetry and telemetry.sensorStats and telemetry.sensorStats.rpm
    c.maxRpm = tonumber(rpmStats and rpmStats.max)
    if c.rpm ~= nil and (c.maxRpm == nil or c.rpm > c.maxRpm) then
        c.maxRpm = c.rpm
    end
    c.throttle = sensor(telemetry, "throttle_percent", "throttle")
    c.esc, c.escUnit, c.escWarn, c.escMax = temperatureSensor(telemetry, escWarnC, escMaxC)
    c.fuel = sensor(telemetry, "smartfuel")
    c.current = sensor(telemetry, "current")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    c.link = sensor(telemetry, "vfr", "rssi")
    c.consumed = sensor(telemetry, "smartconsumption", "consumption")
    c.flightState, c.flightStateColor = getFlightState(telemetry)
    updateFlightTime(c)

    -- Cache theme thresholds here (wakeup runs at a bounded rate) instead of
    -- calling getThemeValue() from paint(), which runs on every invalidate.
    c.fuelWarn = getThemeValue("fuel_warn")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    c.linkWarn = getThemeValue("link_warn")
    c.rpmMax = getThemeValue("rpm_max")

    cacheText(c, "rpmText", "_rpmTextValue", "_rpmTextUnit", c.rpm, 0, "")
    cacheText(c, "maxRpmText", "_maxRpmTextValue", "_maxRpmTextUnit", c.maxRpm, 0, " RPM", "MAX ")
    cacheText(c, "rpmLimitText", "_rpmLimitTextValue", "_rpmLimitTextUnit", c.rpmMax, 0, " RPM", "LIMIT ")
    cacheText(c, "escText", "_escTextValue", "_escTextUnit", c.esc, 0, c.escUnit)
    cacheText(c, "throttleText", "_throttleTextValue", "_throttleTextUnit", c.throttle, 0, "%")
    cacheText(c, "fuelText", "_fuelTextValue", "_fuelTextUnit", c.fuel, 0, "%")
    cacheText(c, "currentText", "_currentTextValue", "_currentTextUnit", c.current, 1, " A")
    cacheText(c, "becText", "_becTextValue", "_becTextUnit", c.bec, 1, " V")
    cacheText(c, "linkText", "_linkTextValue", "_linkTextUnit", c.link, 0, "%")
    cacheText(c, "consumedText", "_consumedTextValue", "_consumedTextUnit", c.consumed, 0, " mAh")
    if c._becLinkBecText ~= c.becText or c._becLinkLinkText ~= c.linkText then
        c._becLinkBecText = c.becText
        c._becLinkLinkText = c.linkText
        c.becLinkText = c.becText .. "   " .. c.linkText
    end

    return c
end

local GAUGE_TICKS = 32
local GAUGE_COS = {}
local GAUGE_SIN = {}
for i = 0, GAUGE_TICKS - 1 do
    local angle = rad(140 + 260 * i / (GAUGE_TICKS - 1))
    GAUGE_COS[i + 1] = cos(angle)
    GAUGE_SIN[i + 1] = sin(angle)
end

local function drawRadialGauge(cx, cy, radius, value, maximum, color)
    local pct = maximum > 0 and max(0, min(1, value / maximum)) or 0
    local active = floor(GAUGE_TICKS * pct + 0.5)
    local r1 = radius - 14
    local r2 = radius

    for i = 0, GAUGE_TICKS - 1 do
        local unitCos = GAUGE_COS[i + 1]
        local unitSin = GAUGE_SIN[i + 1]
        local x1 = cx + unitCos * r1
        local y1 = cy + unitSin * r1
        local x2 = cx + unitCos * r2
        local y2 = cy + unitSin * r2
        lcd.color(i < active and color or C.line)
        lcd.drawLine(floor(x1), floor(y1), floor(x2), floor(y2))
    end

    lcd.color(C.line2)
    lcd.drawLine(floor(cx - radius * 0.68), floor(cy + radius * 0.72), floor(cx + radius * 0.68), floor(cy + radius * 0.72))
end

local function drawVerticalMeter(x, y, w, h, title, value, maximum, color, valueText)
    drawPanel(x, y, w, h, color, title)
    local barX = x + 15
    local barY = y + 30
    local barW = 14
    local barH = max(8, h - 44)
    local pct = maximum > 0 and max(0, min(1, (value or 0) / maximum)) or 0
    lcd.color(C.line)
    lcd.drawRectangle(floor(barX), floor(barY), floor(barW), floor(barH), 1)
    if pct > 0 then
        local fillH = floor((barH - 4) * pct)
        lcd.color(color)
        lcd.drawFilledRectangle(floor(barX + 2), floor(barY + barH - 2 - fillH), floor(barW - 4), fillH)
    end
    local valueColor = value == nil and C.muted or C.white
    drawTextAligned(x + 38, y + 31, w - 50, valueText or "--", "FONT_L", valueColor, "left")
end

local function inflightPaint(x, y, w, h, box, c, telemetry)
    c = c or box._cache or {}
    box._cache = c

    -- Safety net: if paint() runs before the first wakeup() cycle has
    -- populated the cache (e.g. very first frame), fall back to a live
    -- lookup so we never compare a number against a nil threshold.
    if c.escMax == nil or c.escWarn == nil then
        local escWarnC = getThemeValue("esc_warn")
        local escMaxC = getThemeValue("esc_max")
        local _, unit, displayWarn, displayMax = temperatureSensor(telemetry, escWarnC, escMaxC)
        c.escUnit, c.escWarn, c.escMax = unit, displayWarn, displayMax
    end
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")
    c.rpmMax = c.rpmMax or getThemeValue("rpm_max")

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

    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.green)) or C.muted
    local throttleColor = c.throttle == nil and C.muted or (c.throttle >= 90 and C.amber or C.cyan)
    local fuel = c.fuel or 0
    local fuelColor = c.fuel == nil and C.muted or (fuel <= c.fuelWarn and C.red or (fuel <= 50 and C.amber or C.green))
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.cyan)) or C.muted
    local linkColor = c.link and (c.link < c.linkWarn and C.amber or C.cyan) or C.muted

    local halfH = floor((bodyH - pad) / 2)
    drawVerticalMeter(leftX, bodyY, leftW, halfH, "ESC TEMP", c.esc, c.escMax, escColor, c.escText)
    drawVerticalMeter(leftX, bodyY + halfH + pad, leftW, halfH, "THROTTLE", c.throttle, 100, throttleColor, c.throttleText)

    drawPanel(centerX, bodyY, centerW, bodyH, C.cyan, nil)
    local cx = centerX + centerW / 2
    local cy = bodyY + bodyH * 0.48
    local radius = min(centerW * 0.43, bodyH * 0.43)
    local rpmMax = c.rpmMax
    local rpmColor = c.rpm == nil and C.muted or (c.rpm > rpmMax and C.red or C.cyan)
    drawRadialGauge(cx, cy, radius, c.rpm or 0, rpmMax, rpmColor)
    drawTextAligned(centerX, cy - 44, centerW, c.rpmText or "--", "FONT_XXL", c.rpm == nil and C.muted or C.white, "center")
    drawTextAligned(centerX, cy + 10, centerW, "HEADSPEED  RPM", "FONT_XS", C.muted, "center")
    drawTextAligned(centerX + 22, bodyY + bodyH - 33, centerW - 44, c.maxRpmText or "MAX --", "FONT_XS", c.maxRpm == nil and C.muted or C.amber, "left")
    drawTextAligned(centerX + 22, bodyY + bodyH - 33, centerW - 44, c.rpmLimitText or "LIMIT --", "FONT_XS", C.muted, "right")

    local fuelH = floor(bodyH * 0.30)
    drawPanel(rightX, bodyY, rightW, fuelH, fuelColor, "SMART FUEL")
    drawTextAligned(rightX + 12, bodyY + 25, rightW - 24, c.fuelText or "--", "FONT_XL", C.white, "right")
    drawSegments(rightX + 12, bodyY + fuelH - 17, rightW - 32, 10, fuel, 10, fuelColor, C.line)
    lcd.color(fuelColor)
    lcd.drawFilledRectangle(floor(rightX + rightW - 16), floor(bodyY + fuelH - 13), 4, 8)

    -- Arm/governor state sits immediately below the Smart Fuel battery.
    local stateGap = bodyH < 260 and 5 or 8
    local stateH = bodyH < 260 and 24 or 28
    local stateY = bodyY + fuelH + stateGap
    drawStateBadge(rightX, stateY, rightW, stateH, c.flightState, c.flightStateColor)

    local smallY = stateY + stateH + stateGap
    local smallH = floor((bodyY + bodyH - smallY - pad) / 2)
    drawMetric(rightX, smallY, rightW, smallH, "CURRENT LOAD", c.currentText or "--", C.violet, "instantaneous")
    drawMetric(rightX, smallY + smallH + pad, rightW, smallH, "BEC / LINK", c.becLinkText or "--   --", becColor == C.red and C.red or linkColor, "power and RF health")

    -- Keep consumed capacity inside the throttle card as two centered rows.
    -- Separating the label and value prevents overlap in the narrow X20 Pro panel.
    local throttleY = bodyY + halfH + pad
    local consumedX = leftX + 38
    local consumedW = leftW - 50
    local consumedLabelY = throttleY + halfH - 38
    local consumedValueY = consumedLabelY + 15
    drawTextAligned(consumedX, consumedLabelY, consumedW, "CONSUMED", "FONT_XXS", C.muted, "center")
    drawTextAligned(consumedX, consumedValueY, consumedW, c.consumedText or "--", "FONT_XS", C.white, "center")

    local monitorY = y + h - 13
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

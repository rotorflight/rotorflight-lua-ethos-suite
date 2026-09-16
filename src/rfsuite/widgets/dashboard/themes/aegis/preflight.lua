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

local function cacheText(c, textKey, valueKey, unitKey, value, decimals, suffix)
    suffix = suffix or ""
    local scale = decimals == 2 and 100 or (decimals == 1 and 10 or 1)
    value = value and floor(value * scale + 0.5) / scale or nil
    if c[valueKey] ~= value or c[unitKey] ~= suffix or c[textKey] == nil then
        c[valueKey] = value
        c[unitKey] = suffix
        c[textKey] = fmt(value, decimals, suffix)
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
    -- Stream vertices to avoid allocating seven temporary tables per call.
    lcd.color(color)
    local firstx, firsty, px, py
    for i = 1, 6 do
        local u = HEX_UNIT[i]
        local hx = floor(x + u[1] * radius)
        local hy = floor(y + u[2] * radius)
        if i == 1 then firstx, firsty = hx, hy else lcd.drawLine(px, py, hx, hy) end
        px, py = hx, hy
    end
    lcd.drawLine(px, py, firstx, firsty)
end

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}

local function preflightWakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c

    c.fuelWarn = getThemeValue("fuel_warn")
    c.becMin = getThemeValue("bec_min")
    c.becWarn = getThemeValue("bec_warn")
    local escWarnC = getThemeValue("esc_warn")
    local escMaxC = getThemeValue("esc_max")
    c.linkWarn = getThemeValue("link_warn")

    c.fuel = sensor(telemetry, "smartfuel")
    c.bec = sensor(telemetry, "bec_voltage", "bec")
    c.esc, c.escUnit, c.escWarn, c.escMax = temperatureSensor(telemetry, escWarnC, escMaxC)
    c.link = sensor(telemetry, "vfr", "rssi")
    c.rate = sensor(telemetry, "rate_profile")
    c.pid = sensor(telemetry, "pid_profile")
    c.voltage = sensor(telemetry, "voltage")
    c.flightState, c.flightStateColor = getFlightState(telemetry)

    local available = 0
    local faults = 0
    local warnings = 0
    local firstIssue

    if c.fuel ~= nil then
        available = available + 1
        if c.fuel <= c.fuelWarn then
            faults = faults + 1
            if firstIssue == nil then firstIssue = "SMART FUEL " .. fmt(c.fuel, 0, "%") .. " AT RESERVE" end
        end
    end
    if c.bec ~= nil then
        available = available + 1
        if c.bec < c.becMin then
            faults = faults + 1
            if firstIssue == nil then firstIssue = "BEC " .. fmt(c.bec, 1, "V") .. " BELOW " .. fmt(c.becMin, 1, "V") end
        elseif c.bec < c.becWarn then
            warnings = warnings + 1
            if firstIssue == nil then firstIssue = "BEC " .. fmt(c.bec, 1, "V") .. " BELOW " .. fmt(c.becWarn, 1, "V") end
        end
    end
    if c.esc ~= nil then
        available = available + 1
        if c.esc >= c.escMax then
            faults = faults + 1
            if firstIssue == nil then firstIssue = "ESC " .. fmt(c.esc, 0, c.escUnit) .. " AT LIMIT" end
        elseif c.esc >= c.escWarn then
            warnings = warnings + 1
            if firstIssue == nil then firstIssue = "ESC " .. fmt(c.esc, 0, c.escUnit) .. " ABOVE WARNING" end
        end
    end
    if c.link ~= nil then
        available = available + 1
        if c.link < c.linkWarn then
            warnings = warnings + 1
            if firstIssue == nil then firstIssue = "LINK " .. fmt(c.link, 0, "%") .. " BELOW " .. fmt(c.linkWarn, 0, "%") end
        end
    end

    local issueCount = faults + warnings
    c.issueText = firstIssue
    if issueCount > 1 and c.issueText then
        c.issueText = c.issueText .. "  +" .. tostring(issueCount - 1) .. " MORE"
    end

    if available == 0 then
        c.status = "WAITING"
        c.statusColor = C.muted
        c.statusSub = "CONNECT TELEMETRY"
        c.issueText = nil
    elseif faults > 0 then
        c.status = "CHECK"
        c.statusColor = C.red
        c.statusSub = tostring(issueCount) .. " ITEM" .. (issueCount == 1 and "" or "S") .. " FLAGGED"
    elseif warnings > 0 then
        c.status = "CAUTION"
        c.statusColor = C.amber
        c.statusSub = tostring(issueCount) .. " ITEM" .. (issueCount == 1 and "" or "S") .. " TO REVIEW"
    elseif available < 4 then
        -- Missing channels cannot establish that every monitored system is ready.
        c.status = "PARTIAL DATA"
        c.statusColor = C.amber
        c.statusSub = "CHECK MISSING SENSORS"
        c.issueText = nil
    else
        c.status = "READY"
        c.statusColor = C.green
        c.statusSub = "SYSTEMS NOMINAL"
        c.issueText = nil
    end

    cacheText(c, "becText", "_becTextValue", "_becTextUnit", c.bec, 1, " V")
    cacheText(c, "linkText", "_linkTextValue", "_linkTextUnit", c.link, 0, "%")
    cacheText(c, "fuelText", "_fuelTextValue", "_fuelTextUnit", c.fuel, 0, "%")
    cacheText(c, "escText", "_escTextValue", "_escTextUnit", c.esc, 0, c.escUnit)
    cacheText(c, "rateText", "_rateTextValue", "_rateTextUnit", c.rate, 0, "")
    cacheText(c, "pidText", "_pidTextValue", "_pidTextUnit", c.pid, 0, "")
    cacheText(c, "voltageText", "_voltageTextValue", "_voltageTextUnit", c.voltage, 1, " V")

    return c
end

local function drawCheckRow(x, y, w, label, value, stateColor)
    lcd.color(stateColor)
    lcd.drawFilledRectangle(floor(x), floor(y + 6), 7, 7)
    drawTextAligned(x + 14, y, w * 0.45, label, "FONT_XS", C.muted, "left")
    drawTextAligned(x + w * 0.48, y, w * 0.52, value, "FONT_S", C.white, "right")
end

local function preflightPaint(x, y, w, h, box, c, telemetry)
    c = c or box._cache or {}
    box._cache = c

    -- Safety net: if paint() runs before the first wakeup() cycle has
    -- populated the cache (e.g. very first frame), fall back to a live
    -- lookup so we never compare a number against a nil threshold.
    c.fuelWarn = c.fuelWarn or getThemeValue("fuel_warn")
    c.becMin = c.becMin or getThemeValue("bec_min")
    c.becWarn = c.becWarn or getThemeValue("bec_warn")
    if c.escMax == nil or c.escWarn == nil then
        local escWarnC = getThemeValue("esc_warn")
        local escMaxC = getThemeValue("esc_max")
        local _, unit, displayWarn, displayMax = temperatureSensor(telemetry, escWarnC, escMaxC)
        c.escUnit, c.escWarn, c.escMax = unit, displayWarn, displayMax
    end
    c.linkWarn = c.linkWarn or getThemeValue("link_warn")

    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))

    local pad = 12
    local topY = y + 8
    drawTextAligned(x + pad, topY, w * 0.55, "AEGIS // PRE-FLIGHT", "FONT_STD", C.cyan, "left")
    drawTextAligned(x + w - 220, topY, 208, c.status or "WAITING", "FONT_STD", c.statusColor or C.muted, "right")

    local bodyY = y + 42
    local bodyH = h - 54
    local sideW = floor(w * 0.25)
    local centerW = w - sideW * 2 - pad * 4
    local leftX = x + pad
    local centerX = leftX + sideW + pad
    local rightX = centerX + centerW + pad

    local cardH = floor((bodyH - pad) / 2)
    local fuel = c.fuel or 0
    local fuelColor = c.fuel == nil and C.muted or (fuel <= c.fuelWarn and C.red or (fuel <= 50 and C.amber or C.green))
    local becColor = c.bec and (c.bec < c.becMin and C.red or (c.bec < c.becWarn and C.amber or C.cyan)) or C.muted
    local escColor = c.esc and (c.esc >= c.escMax and C.red or (c.esc >= c.escWarn and C.amber or C.green)) or C.muted
    local linkColor = c.link and (c.link < c.linkWarn and C.amber or C.cyan) or C.muted

    drawMetric(leftX, bodyY, sideW, cardH, "BEC POWER", c.becText or "--", becColor, "regulated supply")
    drawProgress(leftX + 12, bodyY + cardH - 36, sideW - 24, 9, c.bec and c.bec / 15 or 0, becColor)

    drawMetric(leftX, bodyY + cardH + pad, sideW, cardH, "RADIO LINK", c.linkText or "--", linkColor, "frame quality")
    drawProgress(leftX + 12, bodyY + cardH * 2 + pad - 36, sideW - 24, 9, c.link and c.link / 100 or 0, linkColor)

    drawPanel(centerX, bodyY, centerW, bodyH, c.statusColor or C.muted, nil)
    local cx = centerX + centerW / 2
    local cy = bodyY + bodyH * (bodyH < 260 and 0.27 or 0.36)
    local radius = min(centerW * 0.33, bodyH * (bodyH < 260 and 0.18 or 0.27))
    drawHex(cx, cy, radius + 12, C.line2)
    drawHex(cx, cy, radius, c.statusColor or C.muted)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(floor(cx - radius * 0.95), floor(cy - (bodyH < 260 and 20 or 34)), floor(radius * 1.90), bodyH < 260 and 55 or 75)
    drawTextAligned(centerX, cy - (bodyH < 260 and 20 or 34), centerW, c.status or "WAITING", bodyH < 260 and "FONT_XL" or "FONT_XXL", C.white, "center")
    if c.issueText then
        drawTextAligned(centerX + 12, cy + 15, centerW - 24, c.issueText, "FONT_XS", C.white, "center")
        drawTextAligned(centerX, cy + 40, centerW, c.statusSub or "ITEM TO REVIEW", "FONT_XXS", c.statusColor or C.muted, "center")
    else
        drawTextAligned(centerX, cy + 20, centerW, c.statusSub or "CONNECT TELEMETRY", "FONT_XXS", c.statusColor or C.muted, "center")
    end

    local segY = bodyY + bodyH - 86
    drawTextAligned(centerX + 18, segY - 22, centerW - 36, "SMART FUEL", "FONT_XS", C.muted, "left")
    drawTextAligned(centerX + 18, segY - 24, centerW - 36, c.fuelText or "--", "FONT_S", C.white, "right")
    drawSegments(centerX + 18, segY, centerW - 42, 18, fuel, 12, fuelColor, C.line)
    lcd.color(fuelColor)
    lcd.drawFilledRectangle(floor(centerX + centerW - 20), floor(segY + 5), 5, 8)

    -- Put the arm/governor state directly below the Smart Fuel battery.
    drawStateBadge(centerX + 18, segY + 31, centerW - 36, 27, c.flightState, c.flightStateColor)

    drawMetric(rightX, bodyY, sideW, cardH, "ESC THERMAL", c.escText or "--", escColor, "controller temperature")
    drawProgress(rightX + 12, bodyY + cardH - 36, sideW - 24, 9, c.esc and c.esc / c.escMax or 0, escColor)

    drawPanel(rightX, bodyY + cardH + pad, sideW, cardH, C.violet, "FLIGHT PROFILE")
    drawCheckRow(rightX + 14, bodyY + cardH + pad + floor(cardH * 0.3), sideW - 28, "RATES", c.rateText or "--", C.violet)
    drawCheckRow(rightX + 14, bodyY + cardH + pad + floor(cardH * 0.54), sideW - 28, "PID BANK", c.pidText or "--", C.violet)
    drawCheckRow(rightX + 14, bodyY + cardH + pad + floor(cardH * 0.78), sideW - 28, "PACK", c.voltageText or "--", C.cyan)
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

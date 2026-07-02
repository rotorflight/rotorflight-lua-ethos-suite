local rfsuite = require("rfsuite")
local lcd = lcd
local math = math
local floor = math.floor
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local rad = math.rad
local pi = math.pi
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
    bg = lcd.RGB(34, 26, 42),
    panel = lcd.RGB(34, 26, 42),
    line = lcd.RGB(104, 75, 119),
    line2 = lcd.RGB(151, 107, 160),
    white = lcd.RGB(246, 239, 255),
    muted = lcd.RGB(190, 166, 199),
    gold = lcd.RGB(255, 199, 91),
    goldDim = lcd.RGB(112, 77, 28),
    turquoise = lcd.RGB(58, 238, 216),
    turquoiseDim = lcd.RGB(16, 86, 79),
    emerald = lcd.RGB(81, 241, 139),
    emeraldDim = lcd.RGB(22, 91, 52),
    fuchsia = lcd.RGB(255, 78, 203),
    fuchsiaDim = lcd.RGB(105, 26, 78),
    violet = lcd.RGB(187, 107, 255),
    violetDim = lcd.RGB(67, 34, 99),
    coral = lcd.RGB(255, 104, 112),
    amber = lcd.RGB(255, 166, 62),
    red = lcd.RGB(255, 74, 96)
}

-- Use the native ETHOS header surface everywhere so the theme is visually
-- continuous from the system header through the custom dashboard.
C.bg = colorMode.tbbgcolor or colorMode.bgcolor or C.bg
C.panel = C.bg

local THEME_SECTION = "system/zafira"
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

local function drawDiamond(cx, cy, radius, color, innerColor)
    cx, cy, radius = floor(cx), floor(cy), floor(radius)
    lcd.color(color)
    lcd.drawLine(cx, cy - radius, cx + radius, cy)
    lcd.drawLine(cx + radius, cy, cx, cy + radius)
    lcd.drawLine(cx, cy + radius, cx - radius, cy)
    lcd.drawLine(cx - radius, cy, cx, cy - radius)
    if innerColor and radius > 4 then
        local r = floor(radius * 0.55)
        lcd.color(innerColor)
        lcd.drawLine(cx, cy - r, cx + r, cy)
        lcd.drawLine(cx + r, cy, cx, cy + r)
        lcd.drawLine(cx, cy + r, cx - r, cy)
        lcd.drawLine(cx - r, cy, cx, cy - r)
    end
end

local function drawPetal(cx, cy, length, width, angleDeg, color)
    local a = rad(angleDeg)
    local ax, ay = cos(a), sin(a)
    local px, py = -ay, ax
    local lastLx, lastLy, lastRx, lastRy
    lcd.color(color)
    for i = 0, 8 do
        local t = i / 8
        local centerDist = length * t
        local side = sin(pi * t) * width
        local ccx = cx + ax * centerDist
        local ccy = cy + ay * centerDist
        local lx = floor(ccx + px * side)
        local ly = floor(ccy + py * side)
        local rx = floor(ccx - px * side)
        local ry = floor(ccy - py * side)
        if lastLx then
            lcd.drawLine(lastLx, lastLy, lx, ly)
            lcd.drawLine(lastRx, lastRy, rx, ry)
        end
        lastLx, lastLy, lastRx, lastRy = lx, ly, rx, ry
    end
end

local function drawLattice(x, y, w, h)
    local step = 42
    lcd.color(C.line)
    for sx = floor(x - h), floor(x + w), step do
        lcd.drawLine(sx, floor(y + h), sx + floor(h), floor(y))
    end
    for sx = floor(x), floor(x + w + h), step do
        lcd.drawLine(sx, floor(y), sx - floor(h), floor(y + h))
    end
end

local function drawPanel(x, y, w, h, accent, title)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.line2)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(accent or C.gold)
    lcd.drawFilledRectangle(x, y, 3, h)
    drawDiamond(x + 8, y + 8, 5, accent or C.gold, C.line2)
    drawDiamond(x + w - 8, y + h - 8, 5, accent or C.gold, C.line2)
    if title then drawTextAligned(x + 16, y + 7, w - 30, title, "FONT_XXS", C.muted, "left") end
end

local function drawMetric(x, y, w, h, title, value, accent, subtitle)
    drawPanel(x, y, w, h, accent, title)
    drawTextAligned(x + 13, y + 28, w - 26, value, "FONT_L", C.white, "left")
    if subtitle then drawTextAligned(x + 13, y + h - 23, w - 26, subtitle, "FONT_XXS", C.muted, "left") end
end

local function drawProgress(x, y, w, h, percent, color)
    percent = clamp(percent or 0, 0, 1)
    lcd.color(C.line2)
    lcd.drawRectangle(floor(x), floor(y), floor(w), floor(h), 1)
    if percent > 0 then
        lcd.color(color)
        lcd.drawFilledRectangle(floor(x + 2), floor(y + 2), floor((w - 4) * percent), max(1, floor(h - 4)))
    end
end

local function drawGemLine(x, y, w, count, percent, activeColor, dimColor)
    percent = clamp(percent or 0, 0, 100)
    local active = percent > 0 and max(1, min(count, floor(percent * count / 100 + 0.999))) or 0
    local spacing = w / count
    for i = 0, count - 1 do
        local cx = x + spacing * (i + 0.5)
        drawDiamond(cx, y, min(8, spacing * 0.34), i < active and activeColor or dimColor, i < active and C.white or nil)
    end
end

local function drawHeaderTitle(x, y, w, h)
    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    local t1, t2, t3 = "ETHOS ", "// ", "ROTORFLIGHT"
    local f = resolveFont("FONT_L")
    if type(f) ~= "number" then return end
    lcd.font(f)
    local w1, th = lcd.getTextSize(t1)
    local w2 = lcd.getTextSize(t2)
    local w3 = lcd.getTextSize(t3)

    local watermarkFont = resolveFont("FONT_XS")
    local watermarkText = "MWRC"
    local watermarkWidth, watermarkHeight = 0, 0
    if type(watermarkFont) == "number" then
        lcd.font(watermarkFont)
        watermarkWidth, watermarkHeight = lcd.getTextSize(watermarkText)
        lcd.font(f)
    end

    local titleWidth = w1 + w2 + w3
    local dividerGap = watermarkWidth > 0 and 14 or 0
    local totalWidth = titleWidth + dividerGap + watermarkWidth
    local tx = floor(x + (w - totalWidth) / 2)
    local ty = floor(y + (h - th) / 2)
    lcd.color(C.gold); lcd.drawText(tx, ty, t1)
    lcd.color(C.fuchsia); lcd.drawText(tx + w1, ty, t2)
    lcd.color(C.white); lcd.drawText(tx + w1 + w2, ty, t3)

    if watermarkWidth > 0 then
        local dividerX = tx + titleWidth + 6
        lcd.color(C.line2)
        lcd.drawLine(dividerX, y + 7, dividerX, y + h - 7)
        lcd.font(watermarkFont)
        lcd.color(C.gold)
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
            b.bgcolor = C.bg
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

local STATE_LABELS = {
    [0] = "ARMED / OFF",
    [1] = "ARMED / IDLE",
    [2] = "ARMED / SPOOLUP",
    [3] = "ARMED / RECOVERY",
    [4] = "ARMED / ACTIVE",
    [5] = "ARMED / THR CUT",
    [6] = "ARMED / LINK LOST",
    [7] = "ARMED / AUTOROT",
    [8] = "ARMED / BAILOUT",
    [100] = "GOVERNOR OFF",
    [101] = "DISARMED"
}
local STATE_COLORS = {
    [0] = C.amber, [1] = C.amber, [2] = C.fuchsia, [3] = C.amber,
    [4] = C.emerald, [5] = C.emerald, [6] = C.red, [7] = C.amber,
    [8] = C.red, [100] = C.muted, [101] = C.turquoise
}

local function getFlightState(telemetry)
    local armflags = sensor(telemetry, "armflags")
    local governor = sensor(telemetry, "governor")
    local armed = nil
    if rfsuite.utils and rfsuite.utils.armFlagsToIsArmed then armed = rfsuite.utils.armFlagsToIsArmed(armflags) end
    if armed == nil and armflags == nil and governor == nil then
        local session = rfsuite and rfsuite.session
        if session and session.telemetryState then armed = session.isArmed == true end
    end
    if armed == false then return "DISARMED", C.turquoise end
    local code = governor and floor(governor + 0.5) or nil
    if code == 101 then return "DISARMED", C.turquoise end
    if armed == true then
        if code and STATE_LABELS[code] then return STATE_LABELS[code], STATE_COLORS[code] or C.red end
        return "ARMED", C.red
    end
    if code and STATE_LABELS[code] then return STATE_LABELS[code], STATE_COLORS[code] or C.turquoise end
    return "STATE --", C.muted
end

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {enabled = false}

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
    local session = rfsuite and rfsuite.session
    local seconds = session and session.timer and tonumber(session.timer.live) or 0
    c.time = format("%02d:%02d", floor(seconds / 60), floor(seconds % 60))

    local faults, cautions = 0, 0
    if c.esc and c.esc >= getThemeValue("esc_max") then faults = faults + 1
    elseif c.esc and c.esc >= getThemeValue("esc_warn") then cautions = cautions + 1 end
    if c.bec and c.bec < getThemeValue("bec_min") then faults = faults + 1
    elseif c.bec and c.bec < getThemeValue("bec_warn") then cautions = cautions + 1 end
    if c.fuel and c.fuel <= getThemeValue("fuel_warn") then cautions = cautions + 1 end
    if c.link and c.link < getThemeValue("link_warn") then cautions = cautions + 1 end
    if c.rpm and c.rpm > getThemeValue("rpm_max") * 1.05 then cautions = cautions + 1 end

    if faults > 0 then c.grade, c.gradeSub, c.gradeColor = "JEWEL FRACTURE", "SYSTEM INSPECTION REQUIRED", C.red
    elseif cautions > 0 then c.grade, c.gradeSub, c.gradeColor = "FLIGHT REVIEW", tostring(cautions) .. " ITEM" .. (cautions == 1 and "" or "S") .. " FLAGGED", C.amber
    else c.grade, c.gradeSub, c.gradeColor = "FLAWLESS FLIGHT", "ALL VALUES WITHIN LIMITS", C.emerald end
    return c
end

local function drawReportCard(x, y, w, h, title, value, accent, pct)
    drawPanel(x, y, w, h, accent, title)
    drawTextAligned(x + 14, y + 30, w - 28, value, "FONT_L", C.white, "left")
    drawGemLine(x + 16, y + h - 22, w - 32, 8, clamp((pct or 0) * 100, 0, 100), accent, C.line)
end

local function postflightPaint(x, y, w, h, box, c)
    x, y = utils.applyOffset(x, y, box)
    c = c or box._cache or {}
    lcd.color(C.bg); lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    drawLattice(x, y, w, h)

    drawTextAligned(x + 14, y + 7, w * 0.50, "ZAFIRA // FLIGHT CHRONICLE", "FONT_STD", C.gold, "left")
    drawTextAligned(x + w - 300, y + 8, 286, c.grade or "FLIGHT REVIEW", "FONT_STD", c.gradeColor or C.muted, "right")

    local summaryY, summaryH = y + 43, 82
    drawPanel(x + 12, summaryY, w - 24, summaryH, c.gradeColor or C.gold, nil)
    local cx, cy = x + 76, summaryY + summaryH * 0.5
    for i = 0, 5 do drawPetal(cx, cy, 31, 8, i * 60, i % 2 == 0 and C.fuchsia or C.turquoise) end
    drawDiamond(cx, cy, 20, c.gradeColor or C.gold, C.white)
    drawTextAligned(x + 124, summaryY + 15, w * 0.55, c.gradeSub or "FLIGHT DATA READY", "FONT_S", C.white, "left")
    drawTextAligned(x + w - 230, summaryY + 10, 198, c.time or "00:00", "FONT_XL", C.white, "right")
    drawTextAligned(x + w - 230, summaryY + 49, 198, "FLIGHT TIME", "FONT_XXS", C.muted, "right")

    local gridY = summaryY + summaryH + 10
    local gridH = h - (gridY - y) - 12
    local cols, rows, gap = 3, 3, 9
    local cardW = floor((w - 24 - gap * 2) / cols)
    local cardH = floor((gridH - gap * 2) / rows)

    local rpmColor = c.rpm and c.rpm > getThemeValue("rpm_max") * 1.05 and C.amber or C.violet
    local escColor = c.esc and (c.esc >= getThemeValue("esc_max") and C.red or (c.esc >= getThemeValue("esc_warn") and C.amber or C.emerald)) or C.muted
    local becColor = c.bec and (c.bec < getThemeValue("bec_min") and C.red or (c.bec < getThemeValue("bec_warn") and C.amber or C.turquoise)) or C.muted
    local fuelColor = c.fuel and c.fuel <= getThemeValue("fuel_warn") and C.amber or C.emerald
    local linkColor = c.link and c.link < getThemeValue("link_warn") and C.amber or C.turquoise

    local cards = {
        {"PLUME RPM", fmt(c.rpm,0," RPM"), rpmColor, c.rpm and c.rpm / getThemeValue("rpm_max") or 0},
        {"EMBER PEAK", fmt(c.esc,0,"C"), escColor, c.esc and c.esc / getThemeValue("esc_max") or 0},
        {"RUBY CURRENT", fmt(c.current,1," A"), C.fuchsia, c.current and c.current / getThemeValue("current_warn") or 0},
        {"SAPPHIRE BEC", fmt(c.bec,2," V"), becColor, c.bec and c.bec / 15 or 0},
        {"TURQUOISE LINK", fmt(c.link,0,"%"), linkColor, c.link and c.link / 100 or 0},
        {"EMERALD FUEL", fmt(c.fuel,0,"%"), fuelColor, c.fuel and c.fuel / 100 or 0},
        {"GOLD CONSUMED", fmt(c.consumed,0," mAh"), C.gold, c.consumed and c.consumed / 5000 or 0},
        {"VIOLET POWER", fmt(c.watts,0," W"), C.violet, c.watts and c.watts / getThemeValue("watts_warn") or 0},
        {"PACK MINIMUM", fmt(c.voltage,1," V"), C.turquoise, c.voltage and c.voltage / 60 or 0}
    }
    for i = 1, #cards do
        local row = floor((i - 1) / cols)
        local col = (i - 1) % cols
        local card = cards[i]
        local px = x + 12 + col * (cardW + gap)
        local py = gridY + row * (cardH + gap)
        drawReportCard(px, py, cardW, cardH, card[1], card[2], card[3], card[4])
    end
end

local boxes_cache
local function boxes()
    if not boxes_cache then boxes_cache = {{col=1,row=1,colspan=12,rowspan=12,type="func",subtype="func",wakeup=postflightWakeup,paint=postflightPaint,bgcolor="transparent"}} end
    return boxes_cache
end
return {layout=layout,boxes=boxes,header_boxes=header_boxes,header_layout=header_layout,screenBorderStyle=screenBorderStyle,scheduler={spread_scheduling=true,spread_scheduling_paint=false,spread_ratio=0.85}}

--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local tonumber = tonumber
local tostring = tostring
local type = type
local ipairs = ipairs
local clock = os.clock
local format = string.format
local math = math
local floor = math.floor
local min = math.min
local max = math.max
local cos = math.cos
local sin = math.sin
local rad = math.rad

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()

-- Pre-cached Render Colors for Zero-Lag Performance
local rc = {
    strobeBright = lcd.RGB(255, 30, 30),
    strobeDark = lcd.RGB(60, 0, 0),
    amber = lcd.RGB(255, 170, 0),
    red = lcd.RGB(255, 0, 60),
    cyan = lcd.RGB(0, 240, 255),
    green = lcd.RGB(57, 255, 20),
    dim = lcd.RGB(30, 45, 60),
    bg = lcd.RGB(5, 8, 14),           
    panel = lcd.RGB(12, 18, 28),
    white = lcd.RGB(230, 240, 255),
    orange = lcd.RGB(255, 105, 0),
    tick = lcd.RGB(64, 86, 110),
    cyanDim = lcd.RGB(0, 42, 52),
    amberDim = lcd.RGB(64, 38, 0)
}

-- Force Cyberpunk Neon Palette
local colorMode = {
    bgcolor = rc.bg,           
    tbbgcolor = rc.panel,       
    headerbgcolor = "transparent",     
    titlecolor = rc.cyan,     
    textcolor = rc.white,    
    fillcolor = rc.green,      
    fillwarncolor = rc.amber,  
    fillcritcolor = rc.red,   
    accentcolor = rc.cyan,    
    rssifillbgcolor = rc.cyan,
    fillbgcolor = rc.dim      
}




local theme_section = "system/mwrc"

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 2500, bec_min = 6.5, bec_warn = 8.0, bec_max = 12.0, esctemp_warn = 110, esctemp_max = 150}

local function getThemeValue(key)
    if key == "tx_min" or key == "tx_warn" or key == "tx_max" then
        if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
            local val = rfsuite.preferences.general[key]
            if val ~= nil then return tonumber(val) end
        end
    end

    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then return val end
    end
    return THEME_DEFAULTS[key]
end

local function getThemeOptionKey(W)
    return utils.getDashboardThemeOptionKey(W)
end

local themeOptions = {
    ls_full = {arctitlefont = "FONT_STD", tilefont = "FONT_XL", govfont = "FONT_XL", titlefont = "FONT_XS", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 3, flightvaluepaddingbottom = 0, thickness = 32, titlepaddingbottom = 25},
    ls_std = {arctitlefont = "FONT_STD", tilefont = "FONT_STD", govfont = "FONT_STD", titlefont = "FONT_XS", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 18, titlepaddingbottom = 18},
    ms_full = {arctitlefont = "FONT_S", tilefont = "FONT_STD", govfont = "FONT_STD", titlefont = "FONT_XS", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 19, titlepaddingbottom = 16},
    ms_std = {arctitlefont = "FONT_S", tilefont = "FONT_S", govfont = "FONT_S", titlefont = "FONT_XS", tiletitlespacing = 3, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 14, titlepaddingbottom = 10},
    ss_full = {arctitlefont = "FONT_S", tilefont = "FONT_STD", govfont = "FONT_STD", titlefont = "FONT_XS", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 25, titlepaddingbottom = 15},
    ss_std = {arctitlefont = "FONT_S", tilefont = "FONT_S", govfont = "FONT_S", titlefont = "FONT_XS", tiletitlespacing = 3, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, flightvaluepaddingtop = 2, flightvaluepaddingbottom = 0, thickness = 14, titlepaddingbottom = 15}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local layout = {cols = 7, rows = 12, padding = 0}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 4
if header_layout and header_layout.height then
    header_layout.height = header_layout.height + topbarShiftY
end

-- Completely Disabled Outer Screen Border
local screenBorderStyle = {
    enabled = false,
    bordercolor = colorMode.accentcolor,
    backgroundcolor = colorMode.bgcolor,
    borderwidth = 6,
    inset = -1
}

local HEADER_TEXT_1 = "ETHOS "
local HEADER_TEXT_2 = "// "
local HEADER_TEXT_3 = "ROTORFLIGHT"
local HEADER_WATERMARK = "MWRC"
local headerTextWidth1 = nil
local headerTextWidth2 = nil
local headerTextWidth3 = nil
local headerWatermarkWidth = nil

local function paintHeaderLogo(x, y)
    lcd.font(FONT_L or 0)

    if headerTextWidth1 == nil then
        headerTextWidth1 = lcd.getTextSize(HEADER_TEXT_1)
        headerTextWidth2 = lcd.getTextSize(HEADER_TEXT_2)
        headerTextWidth3 = lcd.getTextSize(HEADER_TEXT_3)
    end

    lcd.color(rc.cyan)
    lcd.drawText(x + 5, y + 4, HEADER_TEXT_1)
    lcd.color(rc.amber)
    lcd.drawText(x + 5 + headerTextWidth1, y + 4, HEADER_TEXT_2)
    lcd.color(rc.white)
    lcd.drawText(x + 5 + headerTextWidth1 + headerTextWidth2, y + 4, HEADER_TEXT_3)

    -- Small permanent author mark in the common header. It is present on
    -- preflight, inflight, and postflight without covering telemetry.
    local watermarkX = x + 5 + headerTextWidth1 + headerTextWidth2 + headerTextWidth3 + 10
    lcd.color(rc.amber)
    lcd.drawLine(watermarkX - 5, y + 9, watermarkX - 5, y + 25)
    lcd.font(FONT_XS or FONT_XXS or 0)
    if headerWatermarkWidth == nil then headerWatermarkWidth = lcd.getTextSize(HEADER_WATERMARK) end
    lcd.color(rc.cyan)
    lcd.drawText(watermarkX, y + 8, HEADER_WATERMARK)
end

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        local headerBgColor = "transparent" 
        for _, box in ipairs(boxes) do
            box.bgcolor = headerBgColor
            box.offsety = (box.offsety or 0) + topbarShiftY
            
            if box.type == "image" then
                box.type = "func"
                box.subtype = "func"
                box.paint = paintHeaderLogo
            end
        end
        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function getStrobeColor(baseColor, isCritical)
    if isCritical then
        if floor(clock() * 6) % 2 == 0 then
            return rc.strobeBright 
        else
            return rc.strobeDark
        end
    end
    return baseColor
end


local ARC_START = 155
local ARC_SWEEP = 230
local ARC_TICK_COUNT = 18
local ARC_TICKS = {}
for i = 0, ARC_TICK_COUNT do
    local angle = rad(ARC_START + (ARC_SWEEP * i / ARC_TICK_COUNT))
    ARC_TICKS[i + 1] = {c = cos(angle), s = sin(angle)}
end

local function drawArcSweep(cx, cy, radius, thickness, startAngle, sweep, color)
    if sweep <= 0 or radius <= 0 or thickness <= 0 then return end
    if sweep > 360 then sweep = 360 end

    local finish = startAngle + sweep
    if finish <= 360 then
        utils.drawArc(cx, cy, radius, thickness, startAngle, finish, color)
    else
        utils.drawArc(cx, cy, radius, thickness, startAngle, 360, color)
        utils.drawArc(cx, cy, radius, thickness, 0, finish - 360, color)
    end
end

local function formatGaugeValue(value, decimals)
    if decimals == 1 then
        return format("%.1f", value)
    elseif decimals == 2 then
        return format("%.2f", value)
    end
    return tostring(floor(value + 0.5))
end

-- =========================================================================
-- MODERN SEGMENTED SMART FUEL GAUGE
-- No solid inactive background: empty cells are outlines only.
-- =========================================================================
local FUEL_SEGMENT_COUNT = 10

local function getFuelSegmentColor(value)
    if value <= 25 then return rc.red end
    if value <= 50 then return rc.amber end
    return rc.green
end

local function wakeSegmentedFuel(box, telemetry)
    local cache = box._cache
    if type(cache) ~= "table" or cache._mode ~= "segmented_fuel" then
        cache = {
            _mode = "segmented_fuel",
            source = box.source or "smartfuel",
            value = 0,
            valueKey = false,
            valueText = "--%",
            activeSegments = 0,
            color = rc.dim,
            hasValue = false
        }
        box._cache = cache
    end

    local raw = nil
    if telemetry and telemetry.getSensor then
        raw = telemetry.getSensor(cache.source)
    end

    if raw ~= nil then
        local value = max(0, min(100, tonumber(raw) or 0))
        local valueKey = floor(value + 0.5)

        if cache.valueKey ~= valueKey then
            cache.value = value
            cache.valueKey = valueKey
            cache.valueText = tostring(valueKey) .. "%"
            cache.activeSegments = valueKey > 0
                and max(1, min(FUEL_SEGMENT_COUNT, floor((valueKey / 100) * FUEL_SEGMENT_COUNT + 0.999)))
                or 0
            cache.color = getFuelSegmentColor(valueKey)
        end
        cache.hasValue = true
    elseif not cache.hasValue then
        cache.valueText = "--%"
        cache.activeSegments = 0
        cache.color = rc.dim
    end

    return cache
end

local function paintSegmentedFuel(x, y, w, h, box, cache)
    x, y = utils.applyOffset(x, y, box)
    cache = cache or box._cache
    if not cache then return end

    local segmentCount = box.segmentcount or FUEL_SEGMENT_COUNT
    local gap = box.segmentgap or 3
    local paddingX = box.gaugepaddingleft or 7
    local capGap = 3
    local capW = max(3, min(6, floor(w * 0.025)))

    local valueFont = utils.resolveFont(box.font or "FONT_L", nil)
    local titleFont = utils.resolveFont(box.titlefont or "FONT_XS", nil)

    local valueText = cache.valueText or "--%"
    local valueH = 0
    if type(valueFont) == "number" then
        lcd.font(valueFont)
        local valueW
        valueW, valueH = lcd.getTextSize(valueText)
        lcd.color(box.textcolor or rc.white)
        lcd.drawText(floor(x + (w - valueW) / 2), y + (box.valuepaddingtop or 0), valueText)
    end

    local titleH = 0
    local titleY = y + h
    if type(titleFont) == "number" and box.title then
        lcd.font(titleFont)
        local titleW
        titleW, titleH = lcd.getTextSize(box.title)
        titleY = y + h - titleH - (box.titlepaddingbottom or 1)
        lcd.color(box.titlecolor or rc.cyan)
        lcd.drawText(floor(x + (w - titleW) / 2), titleY, box.title)
    end

    local availableTop = y + valueH + (box.gaugepaddingtop or 5)
    local availableBottom = titleY - (box.gaugepaddingbottom or 5)
    local availableH = max(8, availableBottom - availableTop)
    local segmentH = min(box.segmentheight or 20, availableH)
    local segmentY = floor(availableTop + (availableH - segmentH) / 2)

    local bodyW = w - (paddingX * 2) - capW - capGap
    local segmentW = floor((bodyW - gap * (segmentCount - 1)) / segmentCount)
    if segmentW < 2 then return end

    local active = min(segmentCount, cache.activeSegments or 0)
    local activeColor = cache.color or rc.green
    local startX = x + paddingX

    for i = 1, segmentCount do
        local sx = floor(startX + (i - 1) * (segmentW + gap))
        if i <= active then
            lcd.color(activeColor)
            lcd.drawFilledRectangle(sx, segmentY, segmentW, segmentH)
        else
            lcd.color(box.emptycolor or rc.dim)
            lcd.drawRectangle(sx, segmentY, segmentW, segmentH, 1)
        end
    end

    -- Minimal battery terminal and two small technical end marks.
    local capX = floor(startX + bodyW + capGap)
    local capH = max(5, floor(segmentH * 0.42))
    lcd.color(active > 0 and activeColor or (box.emptycolor or rc.dim))
    lcd.drawFilledRectangle(capX, floor(segmentY + (segmentH - capH) / 2), capW, capH)

    lcd.drawLine(startX - 3, segmentY, startX + 1, segmentY)
    lcd.drawLine(startX - 3, segmentY, startX - 3, segmentY + 4)
    lcd.drawLine(capX + capW + 3, segmentY + segmentH, capX + capW - 1, segmentY + segmentH)
    lcd.drawLine(capX + capW + 3, segmentY + segmentH, capX + capW + 3, segmentY + segmentH - 4)
end

local function wakeAesGauge(box, telemetry)
    local cache = box._cache
    if type(cache) ~= "table" or cache._mode ~= "neon_arc" then
        cache = {
            _mode = "neon_arc",
            source = box.source,
            value = 0,
            valueKey = false,
            maxKey = false,
            valText = "0",
            maxText = "",
            rangeText = "",
            maxVal = -9999,
            color = box.accentcolor or colorMode.fillcolor,
            pct = 0,
            activeTicks = 0
        }
        local unit = box.unit or ""
        cache.rangeText = "RANGE " .. formatGaugeValue(box.min or 0, box.decimals or 0) .. "–" .. formatGaugeValue(box.max or 100, box.decimals or 0) .. unit
        box._cache = cache
    end

    local val = cache.value or 0
    if telemetry and telemetry.getSensor then
        local raw = telemetry.getSensor(cache.source)
        if raw ~= nil then
            if raw == 0 and (cache.value or 0) > 5 and box.holdzero ~= false then
                val = cache.value
            else
                val = raw
            end
        end
    end
    cache.value = val

    local decimals = box.decimals or 0
    local multiplier = decimals == 2 and 100 or (decimals == 1 and 10 or 1)
    local valueKey = floor(val * multiplier + 0.5)
    if cache.valueKey ~= valueKey then
        cache.valText = formatGaugeValue(val, decimals)
        cache.valueKey = valueKey
    end

    if box.arcmax then
        if val > cache.maxVal then cache.maxVal = val end
        local maxKey = floor(cache.maxVal * multiplier + 0.5)
        if cache.maxKey ~= maxKey then
            cache.maxText = "MAX " .. formatGaugeValue(cache.maxVal, decimals) .. (box.unit or "")
            cache.maxKey = maxKey
        end
    end

    local activeColor = box.accentcolor or colorMode.fillcolor
    if box.thresholds then
        for _, threshold in ipairs(box.thresholds) do
            activeColor = threshold.fillcolor or activeColor
            if val <= threshold.value then break end
        end
    end
    cache.color = activeColor

    local minValue = box.min or 0
    local maxValue = box.max or 100
    local span = maxValue - minValue
    local pct = span > 0 and ((val - minValue) / span) or 0
    cache.pct = max(0, min(1, pct))
    cache.activeTicks = floor(cache.pct * ARC_TICK_COUNT + 0.5)

    return cache
end

-- Multi-layer neon arc with glow rail, active ticks and a bright sweep marker.
local function paintAesGauge(x, y, w, h, box, cache)
    if not cache or cache._mode ~= "neon_arc" then return end
    x, y = utils.applyOffset(x, y, box)

    local radius = floor(min(w * 0.44, h * 0.39))
    if radius < 12 then return end

    local cx = floor(x + w * 0.5)
    local cy = floor(y + h * 0.50)
    local thickness = floor(max(5, min(box.thickness or 14, radius * 0.28)))
    local pct = cache.pct or 0
    local activeSweep = ARC_SWEEP * pct
    local activeColor = cache.color or box.accentcolor or colorMode.fillcolor
    local isCritical = activeColor == colorMode.fillcritcolor or activeColor == rc.red
    local drawColor = getStrobeColor(activeColor, isCritical) or activeColor
    local glowColor = box.glowcolor or rc.dim
    local trackColor = box.trackcolor or rc.panel
    local tickColor = box.tickcolor or rc.tick

    -- Soft outer glow, dark body and inner technical rail.
    drawArcSweep(cx, cy, radius, thickness + 7, ARC_START, ARC_SWEEP, glowColor)
    drawArcSweep(cx, cy, radius, thickness + 2, ARC_START, ARC_SWEEP, trackColor)
    drawArcSweep(cx, cy, radius - floor(thickness * 0.52) - 2, 2, ARC_START, ARC_SWEEP, tickColor)

    if pct > 0 then
        drawArcSweep(cx, cy, radius, thickness + 5, ARC_START, activeSweep, glowColor)
        drawArcSweep(cx, cy, radius, thickness, ARC_START, activeSweep, drawColor)
        drawArcSweep(cx, cy, radius + floor(thickness * 0.5) - 1, 2, ARC_START, activeSweep, drawColor)
    end

    -- Scale ticks. Major ticks are longer; completed ticks inherit the active color.
    local tickOuter = radius - floor(thickness * 0.55) - 4
    for i = 0, ARC_TICK_COUNT do
        local vector = ARC_TICKS[i + 1]
        local major = (i % 3) == 0
        local tickLength = major and 9 or 5
        local tickInner = tickOuter - tickLength
        lcd.color(i <= cache.activeTicks and drawColor or tickColor)
        lcd.drawLine(
            floor(cx + vector.c * tickInner),
            floor(cy + vector.s * tickInner),
            floor(cx + vector.c * tickOuter),
            floor(cy + vector.s * tickOuter)
        )
    end

    -- Bright endpoint marker gives the active sweep a precise instrument look.
    if pct > 0 then
        local endAngle = rad(ARC_START + activeSweep)
        local ec, es = cos(endAngle), sin(endAngle)
        local markerInner = radius - floor(thickness * 0.62)
        local markerOuter = radius + floor(thickness * 0.62)
        lcd.color(rc.white)
        lcd.drawLine(
            floor(cx + ec * markerInner),
            floor(cy + es * markerInner),
            floor(cx + ec * markerOuter),
            floor(cy + es * markerOuter)
        )
    end

    -- Small endpoint blocks and lower data rail.
    local startVector = ARC_TICKS[1]
    local endVector = ARC_TICKS[#ARC_TICKS]
    lcd.color(tickColor)
    lcd.drawFilledRectangle(floor(cx + startVector.c * radius) - 2, floor(cy + startVector.s * radius) - 2, 4, 4)
    lcd.drawFilledRectangle(floor(cx + endVector.c * radius) - 2, floor(cy + endVector.s * radius) - 2, 4, 4)
    local railY = floor(cy + radius * 0.58)
    lcd.drawLine(floor(cx - radius * 0.46), railY, floor(cx + radius * 0.46), railY)

    local titleFont = utils.resolveFont(box.titlefont or "FONT_S", nil)
    if type(titleFont) == "number" and box.title then
        lcd.font(titleFont)
        lcd.color(box.titlecolor or colorMode.titlecolor)
        local titleW, titleH = lcd.getTextSize(box.title)
        local titleX = floor(cx - titleW / 2)
        local titleY = y + 2
        lcd.drawText(titleX, titleY, box.title)
        lcd.color(drawColor)
        local underlineY = titleY + titleH + 2
        lcd.drawLine(titleX, underlineY, titleX + titleW, underlineY)
    end

    local valueFont = utils.resolveFont(box.font or "FONT_XL", nil)
    if type(valueFont) == "number" then
        lcd.font(valueFont)
        lcd.color(colorMode.textcolor)
        local valueW, valueH = lcd.getTextSize(cache.valText)
        local valueY = floor(cy - valueH * 0.55)
        lcd.drawText(floor(cx - valueW / 2), valueY, cache.valText)

        local unit = box.unit
        if unit and unit ~= "" then
            local unitFont = utils.resolveFont(box.unitfont or "FONT_XS", nil)
            if type(unitFont) == "number" then
                lcd.font(unitFont)
                lcd.color(drawColor)
                local unitW = lcd.getTextSize(unit)
                lcd.drawText(floor(cx - unitW / 2), valueY + valueH - 1, unit)
            end
        end
    end

    local footer = box.arcmax and cache.maxText or cache.rangeText
    if footer and footer ~= "" then
        local footerFont = utils.resolveFont(box.maxfont or "FONT_XS", nil)
        if type(footerFont) == "number" then
            lcd.font(footerFont)
            lcd.color(box.maxtextcolor or colorMode.fillwarncolor)
            local footerW, footerH = lcd.getTextSize(footer)
            lcd.drawText(floor(cx - footerW / 2), y + h - footerH - 3, footer)
        end
    end
end


local function buildBoxes(W)
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ls_full

    return {
        {
            col = 1, row = 1, colspan = 3, rowspan = 9,
            type = "image", subtype = "model", imagewidth = 280, imageheight = 300, imagealign = "center",
            bgcolor = "transparent"
        },
        {
            col = 4, row = 9, rowspan = 2, offsety = -15,
            type = "text", subtype = "telemetry", source = "rate_profile", title = "RATES", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, transform = "floor",
            thresholds = {{value = 1.5, textcolor = rc.cyan}, {value = 2.5, textcolor = rc.amber}, {value = 6, textcolor = rc.green}}
        },
        {
            col = 5, row = 9, rowspan = 2, offsety = -15,
            type = "text", subtype = "telemetry", source = "pid_profile", title = "PROFILE", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, transform = "floor",
            thresholds = {{value = 1.5, textcolor = rc.cyan}, {value = 2.5, textcolor = rc.amber}, {value = 6, textcolor = rc.green}}
        },
        {
            col = 6, row = 9, colspan = 2, rowspan = 2, offsetx = -5, offsety = -15,
            type = "time", subtype = "count", title = "FLIGHTS", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.flightvaluepaddingtop, valuepaddingbottom = opts.flightvaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor
        },
        
        -- Modern segmented Smart Fuel battery
        {
            col = 1, row = 10, colspan = 3, rowspan = 3, offsetx = 4, offsety = -1,
            type = "func", subtype = "func",
            source = "smartfuel",
            wakeup = wakeSegmentedFuel,
            paint = paintSegmentedFuel,
            title = "SMART FUEL",
            font = "FONT_XL",
            titlefont = opts.titlefont,
            titlecolor = rc.cyan,
            textcolor = rc.white,
            segmentcount = 10,
            segmentgap = 4,
            segmentheight = 20,
            gaugepaddingleft = 10,
            gaugepaddingtop = 4,
            gaugepaddingbottom = 4,
            bgcolor = "transparent"
        },

        {
            col = 4, colspan = 2, row = 1, rowspan = 7, offsetx = 0, offsety = 0,
            type = "func", subtype = "func", wakeup = wakeAesGauge, paint = paintAesGauge,
            bgcolor = "transparent",
            source = "bec_voltage", title = "BEC VOLT", titlepos = "bottom", decimals = 1, unit = "V", accentcolor = rc.cyan, glowcolor = rc.cyanDim,
            titlepaddingbottom = opts.titlepaddingbottom, valuepaddingtop = 30, font = "FONT_XL", titlefont = opts.arctitlefont, min = getThemeValue("bec_min"), max = getThemeValue("bec_max"),
            thickness = math.max(3, math.floor(opts.thickness * 0.4)),
            thresholds = {{value = getThemeValue("bec_min"), fillcolor = rc.red}, {value = getThemeValue("bec_warn"), fillcolor = rc.amber}, {value = getThemeValue("bec_max"), fillcolor = rc.cyan}, {value = 100, fillcolor = rc.red}}
        },
        {
            col = 4, row = 11, colspan = 2, rowspan = 2, offsety = -10,
            type = "text", subtype = "blackbox", title = "BLACKBOX", titlepos = "bottom",
            font = opts.tilefont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom, decimals = 0,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor, transform = "floor",
            thresholds = {{value = 80, textcolor = colorMode.textcolor}, {value = 90, textcolor = rc.amber}, {value = 100, textcolor = rc.red}}
        },
        {
            col = 6, colspan = 2, row = 1, rowspan = 7, offsetx = 0, offsety = 0,
            type = "func", subtype = "func", wakeup = wakeAesGauge, paint = paintAesGauge,
            bgcolor = "transparent",
            source = "temp_esc", title = "ESC TEMP", titlepos = "bottom", unit = "°C", accentcolor = rc.orange, glowcolor = rc.amberDim,
            font = "FONT_XL", titlefont = opts.arctitlefont, min = 0, max = getThemeValue("esctemp_max"),
            thickness = math.max(3, math.floor(opts.thickness * 0.4)),
            thresholds = {{value = getThemeValue("esctemp_warn"), fillcolor = rc.orange}, {value = getThemeValue("esctemp_max"), fillcolor = rc.amber}, {value = 10000, fillcolor = rc.red}}
        },
        {
            col = 6, row = 11, colspan = 2, rowspan = 2, offsetx = -5, offsety = -10,
            type = "text", subtype = "governor", title = "GOVERNOR", titlepos = "bottom",
            font = opts.govfont, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingbottom = opts.tiletitlepaddingbottom, valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = "DISARMED", textcolor = rc.green}, {value = "OFF", textcolor = rc.amber}, {value = "IDLE", textcolor = rc.amber}, {value = "SPOOLUP", textcolor = rc.red}, {value = "RECOVERY", textcolor = rc.amber}, {value = "ACTIVE", textcolor = rc.red},
                {value = "@i18n(widgets.governor.THR-OFF)@", textcolor = rc.green}
            }
        }
    }
end

local function boxes()
    local config = rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section]
    local W = lcd.getWindowSize()
    if boxes_cache == nil or themeconfig ~= config or lastScreenW ~= W then
        boxes_cache = buildBoxes(W)
        themeconfig = config
        lastScreenW = W
    end
    return boxes_cache
end

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, screenBorderStyle = screenBorderStyle, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.8}}
--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local floor = math.floor
local max = math.max
local min = math.min
local format = string.format
local tonumber = tonumber

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()
local pageBgColor = colorMode.bgcolor
local panelBgColor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor

local theme_section = "system/kevd"

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 5500, bec_min = 6.0, bec_warn = 7.0, bec_max = 12.0}

local function estimateCellCountFromVoltage(voltage)
    voltage = tonumber(voltage) or 0
    if voltage <= 0 then return 0 end

    local fullCell = 4.2
    local emptyCell = 3.5
    local minCells = 1
    local maxCells = 14

    for cells = maxCells, minCells, -1 do
        local perCell = voltage / cells
        if perCell >= emptyCell and perCell <= (fullCell + 0.15) then
            return cells
        end
    end

    local estimated = floor((voltage / fullCell) + 0.999)
    if estimated < minCells then estimated = minCells end
    if estimated > maxCells then estimated = maxCells end
    return estimated
end

local function formatPackVoltage(voltage)
    voltage = tonumber(voltage) or 0
    if voltage <= 0 then return "--.-V" end
    return format("%.1fV", voltage)
end

local function formatCellVoltageAndCount(voltage)
    voltage = tonumber(voltage) or 0
    local cells = estimateCellCountFromVoltage(voltage)
    if voltage <= 0 or cells <= 0 then return "--.--V (--S)" end
    return format("%.2fV (%dS)", voltage / cells, cells)
end

local function formatConsumedMah(consumed)
    consumed = tonumber(consumed) or 0
    return format("%d mAh", floor(consumed + 0.5))
end

local function drawVerticalBatteryBar(x, y, w, h, percent, fillbgcolor, fillcolor, accentcolor, frameThickness, cappaddingtop)
    frameThickness = frameThickness or 4
    cappaddingtop = cappaddingtop or 0

    local maxCapH = floor(h * 0.5)
    local capH = min(max(8, floor(h * 0.10)), maxCapH)
    local capW = min(max(4, floor(w * 0.40)), w)
    local capX = x + floor((w - capW) / 2 + 0.5)
    local capY = y + cappaddingtop
    local capHFinal = capH - cappaddingtop

    lcd.color(accentcolor)
    for i = 0, frameThickness - 1 do
        lcd.drawFilledRectangle(capX - i, capY + i, capW + 2 * i, capHFinal - i)
    end

    local bodyY = y + capH
    local bodyH = h - capH

    lcd.color(fillbgcolor)
    lcd.drawFilledRectangle(x, bodyY, w, bodyH)
    if percent > 0 then
        lcd.color(fillcolor)
        local fillH = floor(bodyH * percent)
        lcd.drawFilledRectangle(x, bodyY + bodyH - fillH, w, fillH)
    end

    lcd.color(accentcolor)
    lcd.drawRectangle(x, bodyY, w, bodyH, frameThickness)
end

local function rightStackWakeup(box, telemetry)
    local c = box._cache or {}

    local session = rfsuite.session
    local telemetryActive = session and session.telemetryState and session.isConnected
    if telemetryActive and session.timer then
        c._flightSeconds = session.timer.live or 0
    elseif c._flightSeconds == nil then
        c._flightSeconds = 0
    end

    if c._flightSeconds > 0 then
        c.flightTime = format("%02d:%02d", floor(c._flightSeconds / 60), floor(c._flightSeconds % 60))
    else
        c.flightTime = "00:00"
    end

    local getSensor = telemetry and telemetry.getSensor

    local fuelRaw = getSensor and getSensor("smartfuel")
    if fuelRaw ~= nil then
        c.fuelPercent = max(0, min(1, fuelRaw / 100))
        c.fuelDisplay = floor(fuelRaw)
        c.fuelUnit = "%"
        c._fuelHasValue = true
    elseif not c._fuelHasValue then
        c.fuelPercent = 0
        c.fuelDisplay = utils.getPulsingDots(box, "_fuelDots")
        c.fuelUnit = nil
    end
    c.fuelFillColor = utils.resolveThresholdColor(c.fuelDisplay, box, "fillcolor", "fillcolor", box.rs_fuelthresholds)

    local voltage = getSensor and getSensor("voltage") or 0
    local consumed = getSensor and getSensor("smartconsumption") or 0
    c.voltageStr = formatPackVoltage(voltage)
    c.cellStr = formatCellVoltageAndCount(voltage)
    c.consumedStr = formatConsumedMah(consumed)

    local govRaw = getSensor and getSensor("governor")
    if govRaw == nil then
        c.governorText = utils.getPulsingDots(box, "_govDots")
    else
        c.governorText = rfsuite.utils.getGovernorState(govRaw)
    end
    c.governorColor = utils.resolveThresholdColor(c.governorText, box, "textcolor", "textcolor", box.rs_govthresholds)

    return c
end

local function rightStackPaint(x, y, w, h, box, c)
    c = c or {}
    h = h + (box.rs_heightadjust or 0)
    utils.drawBoxBackground(x, y, w, h, box.rs_bgstyle)

    local rowH = h / 10

    utils.box(x, y + box.rs_flightoffsety, w, rowH * 2,
        "FLIGHT TIME", "bottom", "center", box.rs_flighttitlefont, box.rs_flighttitlespacing, box.rs_titlecolor,
        nil, nil, nil, nil, box.rs_flighttitlepaddingbottom,
        c.flightTime, nil, box.rs_flightfont, "center", box.rs_textcolor,
        nil, nil, nil, box.rs_flightvaluepaddingtop, box.rs_flightvaluepaddingbottom,
        nil)

    local fuelY = y + rowH * 2
    local fuelH = floor(rowH * 5.5 + 0.5)

    if box.rs_fuelbgcolor then
        lcd.color(box.rs_fuelbgcolor)
        lcd.drawFilledRectangle(x, fuelY, w, fuelH)
    end

    drawVerticalBatteryBar(x + box.rs_fuelgaugepaddingleft, fuelY + box.rs_fuelgaugepaddingtop, w - box.rs_fuelgaugepaddingleft, fuelH - box.rs_fuelgaugepaddingtop, c.fuelPercent or 0, box.rs_fuelfillbgcolor, c.fuelFillColor, box.rs_fuelaccentcolor, box.rs_fuelframethickness, box.rs_fuelcappaddingtop)

    utils.box(x, fuelY, w, fuelH,
        nil, nil, nil, nil, nil, nil,
        nil, nil, nil, nil, nil,
        c.fuelDisplay, c.fuelUnit, box.rs_fuelfont, "center", box.rs_textcolor,
        nil, box.rs_fuelvaluepaddingleft, nil, box.rs_fuelvaluepaddingtop, box.rs_fuelvaluepaddingbottom,
        nil)

    utils.box(x, fuelY + box.rs_voltageoffsety, w, rowH, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        c.voltageStr, nil, box.rs_overlayfont, "right", box.rs_textcolor, nil, nil, nil, nil, nil, nil)
    utils.box(x, fuelY + box.rs_celloffsety, w, rowH, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        c.cellStr, nil, box.rs_overlayfont, "right", box.rs_textcolor, nil, nil, nil, nil, nil, nil)
    utils.box(x, fuelY + box.rs_consumedoffsety, w, rowH, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        c.consumedStr, nil, box.rs_overlayfont, "right", box.rs_textcolor, nil, nil, nil, nil, nil, nil)

    local govY = fuelY + fuelH
    local govH = (y + h) - govY
    local govBgH = govH - 8
    local govBgY = govY + box.rs_govbgoffsety
    utils.drawBoxBackground(x, govBgY, w, govBgH, box.rs_govbgstyle)

    utils.box(x, govY + box.rs_govoffsety, w, govBgH,
        "GOVERNOR", "bottom", "center", box.rs_govfont, box.rs_govtitlespacing, box.rs_titlecolor,
        nil, nil, nil, nil, box.rs_govtitlepaddingbottom,
        c.governorText, nil, box.rs_govfont, "center", c.governorColor,
        nil, nil, nil, nil, box.rs_govvaluepaddingbottom,
        nil)
end

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

local function getEscTempThresholds()
    local warn = getThemeValue("esctemp_warn") or 90
    local maxTemp = getThemeValue("esctemp_max") or 140
    return {
        {value = warn - 1, fillcolor = colorMode.fillcolor},
        {value = maxTemp - 1, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)},
        {value = 10000, fillcolor = colorMode.fillcritcolor}
    }
end

local function pageBackgroundPaint()
    local W, H = lcd.getWindowSize()
    lcd.color(pageBgColor)
    lcd.drawFilledRectangle(0, 0, W, H)
end

local themeOptions = {
    ls_full = {font = "FONT_XL", valuefont = "FONT_L", titlefont = "FONT_STD", titlepaddingtop = 5, thickness = 24, tilefont = "FONT_XXL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 7, gaugepaddingbottom = 13},
    ls_std  = {font = "FONT_L", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 18, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 10},
    ms_full = {font = "FONT_L", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 16, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 9},
    ms_std  = {font = "FONT_S", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 0, thickness = 12, tilefont = "FONT_L", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 7},
    ss_full = {font = "FONT_L", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 16, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 9},
    ss_std  = {font = "FONT_S", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 0, thickness = 12, tilefont = "FONT_L", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 7}
}

local rightStackOptions = {
    ls_full = {tilefont = "FONT_XXL", govfont = "FONT_STD", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},
    ls_std  = {tilefont = "FONT_XL", govfont = "FONT_STD", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},
    ms_full = {tilefont = "FONT_XL", govfont = "FONT_STD", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},
    ms_std  = {tilefont = "FONT_L", govfont = "FONT_S", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0},
    ss_full = {tilefont = "FONT_XL", govfont = "FONT_STD", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},
    ss_std  = {tilefont = "FONT_L", govfont = "FONT_S", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local last_txbatt_type = nil

local layout = {cols = 12, rows = 12, padding = 0, bgcolor = pageBgColor}
local screenBorderStyle = {
    enabled = true,
    bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
    borderwidth = 5,
    inset = 0
}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 4
if header_layout and header_layout.height then
    header_layout.height = header_layout.height + topbarShiftY
end

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)

        local headerBgColor = colorMode.headerbgcolor or colorMode.fillbgcolor or colorMode.bgcolor
        for _, box in ipairs(boxes) do
            box.bgcolor = headerBgColor 
            box.offsety = (box.offsety or 0) + topbarShiftY 
        end

        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function buildBoxes(W)
    local themeKey = getThemeOptionKey(W)
    local opts = themeOptions[themeKey] or themeOptions.ls_full
    local stackOpts = rightStackOptions[themeKey] or rightStackOptions.ls_full
    local compactWindow = themeKey == nil or themeKey == "ls_std" or themeKey == "ms_std" or themeKey == "ss_std"
    local governorFont = compactWindow and "FONT_S" or stackOpts.govfont
    local governorTitleSpacing = compactWindow and 5 or stackOpts.tiletitlespacing
    local governorTitlePaddingBottom = compactWindow and 0 or 10
    local governorValuePaddingBottom = compactWindow and 0 or 6
    local gaugeGrow = 10
    local gaugeShiftUp = 10
    local gaugeShrinkTop = 5
    local gaugePaddingTop = opts.gaugepaddingtop
    local gaugePaddingBottom = opts.gaugepaddingbottom + 1
    local reduceGaugeBottom = min(gaugeGrow, gaugePaddingBottom)
    local reduceGaugeTop = min(gaugeGrow - reduceGaugeBottom, gaugePaddingTop)
    local reduceTitleTop = gaugeGrow - reduceGaugeBottom - reduceGaugeTop
    local barGaugePaddingTop = gaugePaddingTop - reduceGaugeTop - gaugeShiftUp + gaugeShrinkTop
    local barGaugePaddingBottom = gaugePaddingBottom - reduceGaugeBottom + gaugeShiftUp
    local barTitlePaddingTop = max(0, opts.titlepaddingtop + 11 - reduceTitleTop)

    local gaugeTileBg = {
        backfillcolor = pageBgColor,
        fillcolor = panelBgColor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 5,
        roundradius = 8,
        inset = 8,
        contentpadding = 1
    }

    local rightStackTileBg = {
        backfillcolor = pageBgColor,
        fillcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 4,
        roundradius = 6,
        inset = 4,
        insettop = 11,
        insetleft = -9,
        insetright = -5,
        insetbottom = 8,
        contentpadding = 1
    }

    local governorDisarmedTileBg = {
        backfillcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor,
        fillcolor = lcd.RGB(0x00, 0x00, 0x00),
        bordercolor = colorMode.fillcritcolor,
        borderwidth = 6,
        roundradius = 6,
        inset = 4,
        insettop = 4,
        insetbottom = 0,
        insetleft = -9,
        insetright = -5,
        contentpadding = 1
    }

    return {
        {
            col = 1, row = 1, colspan = 12, rowspan = 12,
            type = "func",
            subtype = "func",
            paint = pageBackgroundPaint
        },
        {col = 1, row = 7, colspan = 4, rowspan = 3, offsetx = 30, offsety = -7, type = "text", subtype = "telemetry", source = "altitude", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 5, row = 10, colspan = 4, rowspan = 3, offsetx = 60, offsety = -7, type = "text", subtype = "telemetry", source = "watts", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 5, row = 7, colspan = 4, rowspan = 3, offsetx = 60, offsety = -7, type = "text", subtype = "telemetry", source = "current", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 1, row = 4, colspan = 4, rowspan = 3, offsetx = 30, offsety = -7, type = "text", subtype = "telemetry", source = "rpm", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 1, row = 10, colspan = 4, rowspan = 3, offsetx = 30, offsety = -7, type = "text", subtype = "telemetry", source = "link", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 5, row = 4, colspan = 4, rowspan = 3, offsetx = 60, offsety = -7, type = "text", subtype = "telemetry", source = "temp_esc", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {
            col = 11, row = 1, colspan = 2, rowspan = 12,
            offsetx = -30,
            offsety = 0,
            type = "func",
            subtype = "func",
            wakeupinterval = 0.5,
            wakeup = rightStackWakeup,
            paint = rightStackPaint,

            rs_bgstyle = rightStackTileBg,
            rs_govbgstyle = governorDisarmedTileBg,
            rs_titlecolor = colorMode.titlecolor,
            rs_textcolor = colorMode.textcolor,
            fillcolor = colorMode.fillcolor,

            rs_flightoffsety = 10,
            rs_flighttitlefont = "FONT_S",
            rs_flighttitlespacing = stackOpts.tiletitlespacing,
            rs_flighttitlepaddingbottom = 6,
            rs_flightfont = stackOpts.tilefont,
            rs_flightvaluepaddingtop = stackOpts.tilevaluepaddingtop,
            rs_flightvaluepaddingbottom = stackOpts.tilevaluepaddingbottom,

            rs_fuelbgcolor = panelBgColor,
            rs_fuelfillbgcolor = colorMode.fillbgcolor,
            rs_fuelaccentcolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
            rs_fuelgaugepaddingleft = -4,
            rs_fuelgaugepaddingtop = -16,
            rs_fuelcappaddingtop = 22,
            rs_fuelframethickness = 3,
            rs_fuelfont = "FONT_XXL",
            rs_fuelvaluepaddingleft = 13,
            rs_fuelvaluepaddingtop = 31,
            rs_fuelvaluepaddingbottom = -40,
            rs_fuelthresholds = {
                {value = 25, fillcolor = colorMode.fillcritcolor},
                {value = 50, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}
            },

            rs_overlayfont = "FONT_STD",
            rs_voltageoffsety = 8,
            rs_celloffsety = 34,
            rs_consumedoffsety = 60,

            rs_govbgoffsety = 0,
            rs_govoffsety = -3,
            rs_heightadjust = -7,
            rs_govfont = governorFont,
            rs_govtitlespacing = governorTitleSpacing,
            rs_govtitlepaddingbottom = governorTitlePaddingBottom,
            rs_govvaluepaddingbottom = governorValuePaddingBottom,
            rs_govthresholds = {
                {value = "DISARMED", textcolor = colorMode.fillcritcolor},
                {value = "OFF", textcolor = colorMode.fillcritcolor},
                {value = "IDLE", textcolor = colorMode.accentcolor},
                {value = "SPOOLUP", textcolor = colorMode.accentcolor},
                {value = "RECOVERY", textcolor = colorMode.fillwarncolor},
                {value = "ACTIVE", textcolor = colorMode.fillcolor},
                {value = "@i18n(widgets.governor.THR-OFF)@", textcolor = colorMode.fillcritcolor}
            }
        },
        {
            col = 5, row = 1, colspan = 4, rowspan = 3,
            offsetx = 60,
            type = "time",
            subtype = "total",
            title = "Total Flight Time",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.tilefont,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop,
            valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor
        },
        {
            col = 1, row = 1, colspan = 4, rowspan = 3,
            offsetx = 30,
            type = "time",
            subtype = "count",
            title = "Flights",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.tilefont,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop,
            valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            transform = "floor"
        },
        {
            col = 1, row = 7, colspan = 4, rowspan = 3,
            offsetx = 30,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "altitude",
            stattype = "max",
            title = "Max Altitude",
            unit = "ft",
            min = 0,
            max = 450,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = barTitlePaddingTop,
            gaugepadding = 12,
            gaugepaddingtop = barGaugePaddingTop,
            gaugepaddingbottom = barGaugePaddingBottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = 199, fillcolor = colorMode.fillcolor},
                {value = 350, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)},
                {value = 10000, fillcolor = colorMode.fillcritcolor}
            },
            transform = "floor"
        },

        {
            col = 5, row = 10, colspan = 4, rowspan = 3,
            offsetx = 60,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "watts",
            stattype = "max",
            title = "Max Watts",
            unit = "W",
            min = 0,
            max = 15000,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = barTitlePaddingTop,
            gaugepadding = 12,
            gaugepaddingtop = barGaugePaddingTop,
            gaugepaddingbottom = barGaugePaddingBottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = 7000, fillcolor = colorMode.fillcolor},
                {value = 9000, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)},
                {value = 15000, fillcolor = colorMode.fillcritcolor}
            },
            transform = "floor"
        },
        {
            col = 5, row = 7, colspan = 4, rowspan = 3,
            offsetx = 60,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "current",
            stattype = "max",
            title = "Max Amps",
            unit = "A",
            min = 0,
            max = 300,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = barTitlePaddingTop,
            gaugepadding = 12,
            gaugepaddingtop = barGaugePaddingTop,
            gaugepaddingbottom = barGaugePaddingBottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = 160, fillcolor = colorMode.fillcolor},
                {value = 199, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)},
                {value = 10000, fillcolor = colorMode.fillcritcolor}
            },
            transform = "floor"
        },
        {
            col = 1, row = 4, colspan = 4, rowspan = 3,
            offsetx = 30,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "rpm",
            stattype = "max",
            title = "Max Rpm",
            unit = "rpm",
            min = 0,
            max = 5500,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = barTitlePaddingTop,
            gaugepadding = 12,
            gaugepaddingtop = barGaugePaddingTop,
            gaugepaddingbottom = barGaugePaddingBottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor"
        },
        {
            col = 1, row = 10, colspan = 4, rowspan = 3,
            offsetx = 30,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "link",
            stattype = "min",
            title = "Vfr Min",
            unit = "%",
            min = 0,
            max = 100,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = barTitlePaddingTop,
            gaugepadding = 12,
            gaugepaddingtop = barGaugePaddingTop,
            gaugepaddingbottom = barGaugePaddingBottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = 59, fillcolor = colorMode.fillcritcolor},
                {value = 74, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)},
                {value = 100, fillcolor = colorMode.fillcolor}
            },
            transform = "floor"
        },

        {
            col = 5, row = 4, colspan = 4, rowspan = 3,
            offsetx = 60,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "temp_esc",
            stattype = "max",
            title = "ESC Max Temp",
            unit = "°F",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = barTitlePaddingTop,
            gaugepadding = 12,
            gaugepaddingtop = barGaugePaddingTop,
            gaugepaddingbottom = barGaugePaddingBottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            min = 0,
            max = getThemeValue("esctemp_max") or 140,
            thresholds = getEscTempThresholds(),
            transform = "floor"
        },
    }
end

local function boxes()
    local W = lcd.getWindowSize()
    if boxes_cache == nil or lastScreenW ~= W then
        boxes_cache = buildBoxes(W)
        lastScreenW = W
    end
    return boxes_cache
end

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, screenBorderStyle = screenBorderStyle, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.5}}

--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


local rfsuite = require("rfsuite")
local lcd = lcd

local tonumber = tonumber
local floor = math.floor
local format = string.format

local utils = rfsuite.widgets.dashboard.utils
local maxVoltageToCellVoltage = utils.maxVoltageToCellVoltage

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local theme_section = "system/kevd"

local THEME_DEFAULTS = {throttle_max = 100, rpm_min = 0, rpm_max = 5500, bec_min = 6.0, bec_warn = 8.0, bec_max = 12.0, esctemp_warn = 120, esctemp_max = 300}

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
    local cells = utils.getBatteryCellCount(0)
    if cells <= 0 then cells = estimateCellCountFromVoltage(voltage) end
    if voltage <= 0 or cells <= 0 then return "--.--V (--S)" end
    return format("%.2fV (%dS)", voltage / cells, cells)
end

local function formatConsumedMah(consumed)
    consumed = tonumber(consumed) or 0
    return format("%d mAh", floor(consumed + 0.5))
end


-- Draws a vertical battery-style bar (cap + frame + fill) used by the
-- right-hand smart fuel gauge. Mirrors the vertical branch of
-- objects/gauge/bar.lua's drawBatteryBox with batteryframe=true, battery=false.
local function drawVerticalBatteryBar(x, y, w, h, percent, fillbgcolor, fillcolor, accentcolor, frameThickness, cappaddingtop)
    frameThickness = frameThickness or 4
    cappaddingtop = cappaddingtop or 0

    local maxCapH = floor(h * 0.5)
    local capH = math.min(math.max(8, floor(h * 0.10)), maxCapH)
    local capW = math.min(math.max(4, floor(w * 0.40)), w)
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


-- wakeup for the consolidated right-hand info stack: flight time, smart fuel
-- gauge + battery overlay text, and governor status. Replaces what used to
-- be 8 separately-offset overlapping boxes with one coordinated panel.
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
        c.fuelPercent = math.max(0, math.min(1, fuelRaw / 100))
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


-- paint for the consolidated right-hand info stack. All sub-elements are
-- positioned relative to the single panel rect (x,y,w,h) using a 10-row
-- grid (matching the dashboard's row count), so tuning happens via the
-- rs_* fields on one box instead of 8 separate offsetx/offsety values.
local function rightStackPaint(x, y, w, h, box, c)
    c = c or {}
    utils.drawBoxBackground(x, y, w, h, box.rs_bgstyle)

    local rowH = h / 10

    -- FLIGHT TIME (rows 1-2)
    utils.box(x, y + box.rs_flightoffsety, w, rowH * 2,
        "FLIGHT TIME", "bottom", "center", box.rs_flighttitlefont, box.rs_flighttitlespacing, box.rs_titlecolor,
        nil, nil, nil, nil, box.rs_flighttitlepaddingbottom,
        c.flightTime, nil, box.rs_flightfont, "center", box.rs_textcolor,
        nil, nil, nil, box.rs_flightvaluepaddingtop, box.rs_flightvaluepaddingbottom,
        nil)

    -- Smart fuel gauge (rows 3-7.5)
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

    -- Battery overlay text (voltage / per-cell voltage / consumed mAh)
    utils.box(x, fuelY + box.rs_voltageoffsety, w, rowH, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        c.voltageStr, nil, box.rs_overlayfont, "right", box.rs_textcolor, nil, nil, nil, nil, nil, nil)
    utils.box(x, fuelY + box.rs_celloffsety, w, rowH, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        c.cellStr, nil, box.rs_overlayfont, "right", box.rs_textcolor, nil, nil, nil, nil, nil, nil)
    utils.box(x, fuelY + box.rs_consumedoffsety, w, rowH, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        c.consumedStr, nil, box.rs_overlayfont, "right", box.rs_textcolor, nil, nil, nil, nil, nil, nil)

    -- GOVERNOR status (rows 7.5-10)
    -- govY/govH are derived from fuelY/fuelH and the panel's integer height
    -- (h) so that govY+govH lands exactly on y+h. This keeps govBgH's bottom
    -- edge pixel-aligned with rs_bgstyle's border, so both tiles' rounded
    -- corners coincide instead of leaving a gap that exposes the border
    -- underneath.
    local govY = fuelY + fuelH
    local govH = (y + h) - govY

    -- Bottom-align the tile with rs_bgstyle's insetbottom (8px) so the red
    -- border doesn't poke out past the panel's outer border.
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

local themeOptions = {

    ls_full = {font = "FONT_XXL", advfont = "FONT_L", thickness = 24, gaugepadding = 8, gaugepaddingbottom = 28, maxpaddingtop = 48, maxpaddingleft = 18, valuepaddingbottom = 18, fuelpaddingbottom = 8, maxfont = "FONT_L", tilefont = "FONT_XXL", govfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},

    ls_std = {font = "FONT_XL", advfont = "FONT_STD", thickness = 20, gaugepadding = 2, gaugepaddingbottom = 8, maxpaddingtop = 32, maxpaddingleft = 12, valuepaddingbottom = 6, fuelpaddingbottom = 8, maxfont = "FONT_STD", tilefont = "FONT_XL", govfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},

    ms_full = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 14, gaugepadding = 5, gaugepaddingbottom = 16, maxpaddingtop = 26, maxpaddingleft = 10, valuepaddingbottom = 12, fuelpaddingbottom = 5, maxfont = "FONT_S", tilefont = "FONT_XL", govfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},

    ms_std = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 12, gaugepadding = 2, gaugepaddingbottom = 6, maxpaddingtop = 18, maxpaddingleft = 10, valuepaddingbottom = 4, fuelpaddingbottom = 8, maxfont = "FONT_S", tilefont = "FONT_L", govfont = "FONT_S", tiletitlespacing = 3, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0},

    ss_full = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 17, gaugepadding = 5, gaugepaddingbottom = 16, maxpaddingtop = 26, maxpaddingleft = 10, valuepaddingbottom = 8, fuelpaddingbottom = 5, maxfont = "FONT_S", tilefont = "FONT_XL", govfont = "FONT_STD", tiletitlespacing = 4, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0},

    ss_std = {font = "FONT_XL", advfont = "FONT_STD", thickness = 15, gaugepadding = 2, gaugepaddingbottom = 6, maxpaddingtop = 22, maxpaddingleft = 8, valuepaddingbottom = 4, fuelpaddingbottom = 0, maxfont = "FONT_S", tilefont = "FONT_L", govfont = "FONT_S", tiletitlespacing = 3, tiletitlepaddingbottom = 1, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil


local pageBgColor = colorMode.bgcolor
local layout = {cols = 12, rows = 10, padding = 0, bgcolor = pageBgColor}
local screenBorderStyle = {
    enabled = true,
    bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
    borderwidth = 5,
    inset = 0
}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 4 -- increase to move topbar down, decrease to move it up
header_layout.height = header_layout.height + topbarShiftY -- keeps shifted topbar from clipping

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)

        local headerBgColor = colorMode.headerbgcolor or colorMode.fillbgcolor or colorMode.bgcolor
        for _, box in ipairs(boxes) do
            box.bgcolor = headerBgColor
            box.offsety = (box.offsety or 0) + topbarShiftY -- shifts topbar and internal details on Y axis
        end

        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function buildBoxes(W)

    local optionKey = getThemeOptionKey(W)
    local opts = themeOptions[optionKey] or themeOptions.ms_std
    local compactWindow = optionKey == nil or optionKey == "ls_std" or optionKey == "ms_std" or optionKey == "ss_std"
    local arcTitleFont = compactWindow and "FONT_S" or "FONT_STD"
    local arcMaxFont = compactWindow and opts.maxfont or "FONT_L"
    local governorFont = compactWindow and "FONT_S" or opts.govfont
    local governorTitleSpacing = compactWindow and 5 or opts.tiletitlespacing
    local governorTitlePaddingBottom = compactWindow and 0 or 3
    local governorValuePaddingBottom = compactWindow and 0 or -5


    local governorDisarmedTileBg = {
        backfillcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor,
        fillcolor = lcd.RGB(0x00, 0x00, 0x00),
        bordercolor = colorMode.fillcritcolor,
        borderwidth = 6,
        roundradius = 6,
        inset = 4,
        insettop = 4,
        insetbottom = 0,
        insetleft = -9, --(adjust governor tile border)
        insetright = -5,
        contentpadding = 1
    }


    local arcGroupTileBg = {
        backfillcolor = pageBgColor,
        fillcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 4,
        roundradius = 6,
        inset = 4,
        insettop = 11,
        insetleft = 24,
        insetright = -8,
        insetbottom = 8,
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


    return {


        {
            col = 1,
            row = 1,
            colspan = 12,
            rowspan = 10,
            type = "text",
            subtype = "telemetry",
            source = "__background_only__",
            title = "",
            unit = "",
            font = "FONT_XS",
            textcolor = pageBgColor,
            titlecolor = pageBgColor,
            bgcolor = pageBgColor
        },


        {
            col = 1,
            row = 1,
            colspan = 9,
            rowspan = 10,
            offsetx = 0,
            type = "text",
            subtype = "telemetry",
            source = "__background_only__",
            title = "",
            unit = "",
            font = "FONT_XS",
            textcolor = pageBgColor,
            titlecolor = pageBgColor,
            bgcolor = arcGroupTileBg
        },


        {
            col = 11,
            row = 1,
            colspan = 2,
            rowspan = 10,
            offsetx = -30,
            offsety = 0,
            type = "func",
            subtype = "func",
            wakeupinterval = 0.5,
            wakeup = rightStackWakeup,
            paint = rightStackPaint,

            -- shared styling
            rs_bgstyle = rightStackTileBg,
            rs_govbgstyle = governorDisarmedTileBg,
            rs_titlecolor = colorMode.titlecolor,
            rs_textcolor = colorMode.textcolor,
            fillcolor = colorMode.fillcolor, -- threshold fallback for the fuel gauge fill colour

            -- FLIGHT TIME row
            rs_flightoffsety = 10,
            rs_flighttitlefont = "FONT_S",
            rs_flighttitlespacing = opts.tiletitlespacing,
            rs_flighttitlepaddingbottom = 6,
            rs_flightfont = opts.tilefont,
            rs_flightvaluepaddingtop = opts.tilevaluepaddingtop,
            rs_flightvaluepaddingbottom = opts.tilevaluepaddingbottom,

            -- smart fuel gauge
            rs_fuelbgcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor,
            rs_fuelfillbgcolor = colorMode.fillbgcolor,
            rs_fuelaccentcolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
            rs_fuelgaugepaddingleft = -4,
            rs_fuelgaugepaddingtop = -16,
            rs_fuelcappaddingtop = 22,
            rs_fuelframethickness = 3,
            rs_fuelfont = "FONT_XXL",
            rs_fuelvaluepaddingleft = 13,
            rs_fuelvaluepaddingtop = 6,
            rs_fuelvaluepaddingbottom = -40,
            rs_fuelthresholds = {{value = 25, fillcolor = colorMode.fillcritcolor}, {value = 50, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}},

            -- battery overlay text (voltage / per-cell voltage / consumed mAh)
            rs_overlayfont = "FONT_STD",
            rs_voltageoffsety = 8,
            rs_celloffsety = 34,
            rs_consumedoffsety = 60,

            -- governor status
            rs_govbgoffsety = 0,
            rs_govoffsety = -3,
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
            col = 6,
            row = 2,
            colspan = 4,
            rowspan = 7,
            offsetx = 7,
            offsety = -38,
            type = "gauge",
            subtype = "arc",
            source = "rpm",
            arcmax = true,
            title = "HEADSPEED",
            titlepos = "bottom",
            titlefont = arcTitleFont,
            titlepaddingbottom = -15,
            titlepaddingleft = 10,
            min = 0,
            max = getThemeValue("rpm_max"),
            thickness = math.max(3, opts.thickness - - 3),
            unit = "",
            maxprefix = "Max: ",
            font = "FONT_XL",
            maxpaddingtop = opts.maxpaddingtop + 14,
            maxpaddingleft = opts.maxpaddingleft + -13,
            maxfont = arcMaxFont,
            gaugepadding = 13,
            gaugepaddingbottom = 14,
            valuepaddingbottom = math.max(0, opts.valuepaddingbottom - 23),
            bgcolor = "transparent",
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            maxtextcolor = "orange",
            transform = "floor",
            thresholds = {{value = getThemeValue("rpm_min"), fillcolor = "lightpurple"}, {value = getThemeValue("rpm_max"), fillcolor = "purple"}, {value = 10000, fillcolor = "magenta"}}
        },

        {
            col = 3,                         -- throttle tile grid column; lower = left, higher = right
            row = 6,                         -- throttle tile grid row; lower = up, higher = down
            colspan = 3,                     -- throttle tile width; larger = wider tile/container
            rowspan = 5,                     -- throttle tile height; larger = taller tile/container
            offsetx = 65,                    -- move entire throttle tile left/right; negative = left, positive = right
            offsety = -65,                   -- move entire throttle tile up/down; negative = up, positive = down
            type = "gauge",
            subtype = "arc",
            source = "throttle_percent",
            arcmax = true,
            title = "THROTTLE",
            titlepos = "bottom",
            titlefont = arcTitleFont,        -- throttle title font size
            titlepaddingbottom = -50,        -- throttle title vertical position; adjust to move title up/down
            titlepaddingleft = 8,            -- shift throttle title left/right
            min = 0,
            max = getThemeValue("throttle_max"),
            thickness = math.max(3, math.floor((opts.thickness - 10) )), -- throttle arc ring thickness
            font = "FONT_XL",                -- throttle main value font size
            maxfont = arcMaxFont,            -- throttle max value font size
            maxprefix = "Max: ",
            maxpaddingtop = math.max(8, opts.maxpaddingtop), -- throttle max value vertical position
            maxpaddingleft = opts.maxpaddingleft - 12, -- moves throttle max text right 10 px
            gaugepadding = 17,               -- throttle arc size; larger = smaller arc, smaller = larger arc. 17 is 15% shrink
            gaugepaddingbottom = 8,          -- throttle arc bottom; larger = moves bottom edge up, smaller = extends lower
            valuepaddingleft = 23,           -- throttle value horizontal position; negative = left, positive = right
            valuepaddingbottom = math.max(0, opts.valuepaddingbottom - 20), -- throttle value vertical position; increase/decrease to move value
            bgcolor = "transparent",
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            maxtextcolor = "orange",
            transform = "floor",
            thresholds = {{value = 70, fillcolor = "green"}, {value = 85, fillcolor = "red"}}
        },


        {
            col = 1,
            row = 1,
            colspan = 5,
            rowspan = 5,
            offsetx = -25,
            offsety = 10,
            type = "gauge",
            subtype = "arc",
            source = "temp_esc",
            arcmax = true,
            title = "ESC TEMP",
            titlepos = "bottom",
            titlefont = arcTitleFont,
            titlepaddingbottom = -60,
            min = 0,
            max = getThemeValue("esctemp_max"),
            thickness = math.max(3, math.floor((opts.thickness - 3) / 2) + 9),
            valuepaddingleft = 6,
            valuepaddingbottom = math.max(0, opts.valuepaddingbottom - 6),
            maxpaddingleft = opts.maxpaddingleft - 17,
            maxpaddingtop = math.max(8, opts.maxpaddingtop + 8),
            maxprefix = "Max: ",
            maxfont = arcMaxFont,
            font = "FONT_XL",
            gaugepadding = math.max(0, opts.gaugepadding + 3),
            gaugepaddingbottom = math.max(0, opts.gaugepaddingbottom + 3),
            bgcolor = "transparent",
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            maxtextcolor = "orange",
            transform = "floor",
            thresholds = {{value = getThemeValue("esctemp_warn"), fillcolor = colorMode.fillcolor}, {value = getThemeValue("esctemp_max"), fillcolor = colorMode.fillwarncolor}, {value = 155, fillcolor = colorMode.fillcritcolor}}
        },

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

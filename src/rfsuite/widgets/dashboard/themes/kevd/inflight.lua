--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 â€” https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd

local tonumber = tonumber
local floor = math.floor
local format = string.format
local clock = os.clock

local utils = rfsuite.widgets.dashboard.utils
local maxVoltageToCellVoltage = utils.maxVoltageToCellVoltage

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

-- Longest stretch this panel's fuel readout is allowed to keep showing a
-- number without a fresh getSensor("smartfuel") read behind it. This panel
-- reads the sensor directly (unlike every other theme's fuel gauge, which
-- goes through the shared, budget-paced gauge/bar.lua object) -- see the
-- wakeup() below. Under normal telemetry that read succeeds every tick, so
-- this never matters; it only kicks in if this box's own wakeup() itself
-- goes a long stretch without being called at all (dense-theme instruction-
-- budget starvation -- see widgets/dashboard/engine.lua's
-- WAKE_CURSOR_MAX_CONSECUTIVE_FAILS for the scheduler-side half of this
-- fix), where the old code would otherwise keep confidently displaying
-- whatever percentage it last managed to read, indefinitely, even after
-- it's badly out of date.
local FUEL_STALE_TIMEOUT = 5.0

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


-- Rectangular fuel frame shares the timer/governor column edges.
local function drawFuelBar(x, y, w, h, percent, fillbgcolor, fillcolor, accentcolor, thickness)
    lcd.color(accentcolor)
    local capW = floor(w * 0.4)
    local capX = x + floor((w - capW) / 2)
    lcd.drawFilledRectangle(capX + 2, y - 5, capW - 4, 5)
    lcd.drawFilledCircle(capX + 2, y - 3, 2)
    lcd.drawFilledCircle(capX + capW - 3, y - 3, 2)
    lcd.drawFilledRectangle(x, y, w, h)
    x, y, w, h = x + thickness, y + thickness, w - thickness * 2, h - thickness * 2
    lcd.color(fillbgcolor)
    lcd.drawFilledRectangle(x, y, w, h)
    if percent > 0 then
        lcd.color(fillcolor)
        local fillH = floor(h * percent)
        lcd.drawFilledRectangle(x, y + h - fillH, w, fillH)
    end
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
        c._fuelUpdatedAt = clock()
    elseif not c._fuelHasValue or (c._fuelUpdatedAt and (clock() - c._fuelUpdatedAt) > FUEL_STALE_TIMEOUT) then
        c.fuelPercent = 0
        c.fuelDisplay = utils.getPulsingDots(box, "_fuelDots")
        c.fuelUnit = nil
        c._fuelHasValue = false
    end
    c.fuelFillColor = utils.resolveThresholdColor(c.fuelDisplay, box, "fillcolor", "fillcolor", box.rs_fuelthresholds)

    local voltage = getSensor and getSensor("voltage") or 0
    local consumed = getSensor and getSensor("smartconsumption") or 0
    c.voltageStr = formatPackVoltage(voltage)
    c.cellStr = formatCellVoltageAndCount(voltage)
    c.consumedStr = formatConsumedMah(consumed)

    if box.rs_fullscreen and box._dashboardRectW and box._dashboardRectH then
        local _, _, w, h = utils.boxContentRect(0, 0, box._dashboardRectW, box._dashboardRectH, box.rs_bgstyle)
        if c._fontW ~= w or c._fontH ~= h or c._fontVoltage ~= c.voltageStr or c._fontCell ~= c.cellStr or c._fontConsumed ~= c.consumedStr then
            -- Fit all three rows together and reuse the result until inputs change.
            local font, _, _, height = utils.resolveAndFitValue(c.voltageStr, nil, w + 2, h / 10)
            local cellFont, _, _, cellHeight = utils.resolveAndFitValue(c.cellStr, nil, w + 2, h / 10)
            local mahFont, _, _, mahHeight = utils.resolveAndFitValue(c.consumedStr, nil, w + 2, h / 10)
            if cellHeight < height then font, height = cellFont, cellHeight end
            if mahHeight < height then font = mahFont end
            c.detailsFont = font
            c._fontVoltage, c._fontCell, c._fontConsumed = c.voltageStr, c.cellStr, c.consumedStr
            c._fontW, c._fontH = w, h
        end
    end

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
    x, y, w, h = utils.drawBoxBackground(x, y, w, h, box.rs_bgstyle)
    local rowH = h / 10
    local framePadding = box.rs_framepadding
    local frameX, frameW = x - framePadding, w + framePadding * 2
    local panelBottom = y + h + framePadding
    local timerBottom = y + floor(rowH * 2.5 + 0.5)
    local fuelY = timerBottom - 8
    local govY = y + floor(rowH * 8.3 + 0.5)
    local fuelH = govY - fuelY

    utils.box(x, y, w, timerBottom - y,
        "FLIGHT TIME", "bottom", "center", box.rs_flighttitlefont, box.rs_flighttitlespacing, box.rs_titlecolor,
        nil, nil, nil, nil, box.rs_flighttitlepaddingbottom,
        c.flightTime, nil, box.rs_flightfont, "center", box.rs_textcolor,
        0, 0, 0, 12, 0, nil)

    drawFuelBar(frameX, fuelY, frameW, fuelH, c.fuelPercent or 0,
        box.rs_fuelfillbgcolor, c.fuelFillColor, box.rs_fuelaccentcolor, box.rs_fuelframethickness)

    -- Three right-aligned rows above a separate percentage region prevent the
    -- advanced readings from colliding with the large remaining-fuel value.
    local detailX = x - (box.rs_fullscreen and 1 or 0)
    local detailW = w + (box.rs_fullscreen and 2 or -4)
    local detailPadding = box.rs_fullscreen and 0 or nil
    utils.box(detailX, fuelY + 4, detailW, rowH, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        c.voltageStr, nil, c.detailsFont or box.rs_overlayfont, "right", box.rs_textcolor, detailPadding, detailPadding, detailPadding, detailPadding, detailPadding, nil)
    utils.box(detailX, fuelY + rowH + 4, detailW, rowH, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        c.cellStr, nil, c.detailsFont or box.rs_overlayfont, "right", box.rs_textcolor, detailPadding, detailPadding, detailPadding, detailPadding, detailPadding, nil)
    utils.box(detailX, fuelY + rowH * 2 + 4, detailW, rowH, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        c.consumedStr, nil, c.detailsFont or box.rs_overlayfont, "right", box.rs_textcolor, detailPadding, detailPadding, detailPadding, detailPadding, detailPadding, nil)
    utils.box(x, fuelY + rowH * 3 + 4, w - 4, fuelH - rowH * 3 - 8,
        nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        c.fuelDisplay, c.fuelUnit, box.rs_fuelfont, "right", box.rs_textcolor,
        nil, nil, nil, 0, 0, nil)

    -- Use the same outer frame coordinates, including its bottom edge.
    local gx, gy, gw, gh = utils.drawBoxBackground(frameX, govY, frameW, panelBottom - govY, box.rs_govbgstyle)
    utils.box(gx, gy, gw, gh,
        "GOVERNOR", "bottom", "center", box.rs_govtitlefont, box.rs_govtitlespacing, box.rs_titlecolor,
        nil, nil, nil, nil, box.rs_govtitlepaddingbottom,
        c.governorText, nil, box.rs_govfont, "center", c.governorColor,
        nil, nil, nil, nil, box.rs_govvaluepaddingbottom, nil)
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
local lastScreenH = nil
local boxes_cache = nil
local themeconfig = nil


local pageBgColor = colorMode.bgcolor
local layout = {cols = 12, rows = 10, padding = 0, bgcolor = pageBgColor}
local screenBorderStyle = {
    enabled = true,
    bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
    borderwidth = 5,
    inset = 0
}

local createHeader = requireModule("widgets/dashboard/themes/kevd/header.lua")
local header_layout, header_boxes, _, pageBackground = createHeader(colorMode, headeropts)


-- Match the shared arc renderer's geometry once per layout build. The
-- normal font fitter then works inside the free centre of the inner arc,
-- rather than fitting a fixed font against the entire gauge tile.
local function fitArcValue(box, cellW, cellH)
    local w = floor(cellW * box.colspan)
    local h = floor(cellH * box.rowspan)
    lcd.font(utils.resolveFont(box.titlefont, FONT_S))
    local _, titleH = lcd.getTextSize(box.title)
    titleH = titleH + (box.titlepaddingtop or 0) + (box.titlepaddingbottom or 0) + (box.titlespacing or 0)
    local arcH = h - titleH - box.gaugepaddingbottom
    local radius = math.min(w / 2 - box.gaugepadding, arcH / 2 - box.thickness / 2 + 8)
    local freeRadius = math.max(1, radius * 0.74 - box.thickness * 0.4)
    local valueW = floor(freeRadius * 1.7)
    local valueH = floor(freeRadius * 1.15)
    box.font = "auto"
    box.valuealign = "center"
    box.valuepadding = 0
    box.valuepaddingleft = (w - valueW) / 2
    box.valuepaddingright = box.valuepaddingleft
    box.valuepaddingtop = arcH * 0.6 - valueH / 2
    box.valuepaddingbottom = h - titleH - box.valuepaddingtop - valueH
end

local function buildBoxes(W, H)

    local optionKey = getThemeOptionKey(W)
    local opts = themeOptions[optionKey] or themeOptions.ms_std
    local compactWindow = optionKey == nil or optionKey == "ls_std" or optionKey == "ms_std" or optionKey == "ss_std"
    local arcTitleFont = compactWindow and "FONT_S" or "FONT_STD"
    local arcMaxFont = compactWindow and opts.maxfont or "FONT_L"
    local smallGaugeBottom = compactWindow and 36 or 24
    local smallGaugeValueBottom = compactWindow and 52 or 28
    local smallGaugeMaxTop = compactWindow and 30 or 40
    local smallGaugeMaxFont = compactWindow and "FONT_XS" or "FONT_STD"
    local governorFont = compactWindow and "FONT_S" or "FONT_L"
    local governorTitleSpacing = compactWindow and 5 or opts.tiletitlespacing
    local governorTitlePaddingBottom = compactWindow and 0 or 3
    local governorValuePaddingBottom = 0


    local governorDisarmedTileBg = {
        backfillcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor,
        fillcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor, -- was a hardcoded black, which looked fine in dark themes but ignored the OS theme entirely (stood out as a jarring black box against a light theme); match the panel's own fill instead, same as every other tile
        bordercolor = colorMode.fillcritcolor,
        borderwidth = 4,
        roundradius = 6,
        inset = 0,
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
        insetright = 4,
        insetbottom = 8,
        contentpadding = 1
    }


    local rightStackTileBg = {
        fillcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 4,
        roundradius = 6,
        inset = 4,
        insettop = 11,
        insetleft = 15,
        insetright = 20, -- was -5 (which expanded the tile *past* its own box's right edge, right up against the screen edge with no margin); a positive value pulls the tile's right edge inward for real padding
        insetbottom = 8,
        contentpadding = 1
    }


    local result = {
        pageBackground,


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
            col = 10,
            row = 1,
            colspan = 3,
            rowspan = 10,
            type = "func",
            subtype = "func",
            wakeupinterval = 0.5,
            wakeup = rightStackWakeup,
            paint = rightStackPaint,

            -- shared styling
            rs_bgstyle = rightStackTileBg,
            rs_framepadding = 5,
            rs_govbgstyle = governorDisarmedTileBg,
            rs_titlecolor = colorMode.titlecolor,
            rs_textcolor = colorMode.textcolor,
            fillcolor = colorMode.fillcolor, -- threshold fallback for the fuel gauge fill colour

            -- FLIGHT TIME row
            rs_flighttitlefont = compactWindow and "FONT_S" or "FONT_STD",
            rs_flighttitlespacing = opts.tiletitlespacing,
            rs_flighttitlepaddingbottom = 15,
            rs_flightfont = compactWindow and "FONT_L" or "FONT_XXL",

            -- smart fuel gauge
            rs_fuelfillbgcolor = colorMode.fillbgcolor,
            rs_fuelaccentcolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
            rs_fuelframethickness = 4,
            rs_fuelfont = compactWindow and "FONT_XXL" or "FONT_XXXXL",
            rs_fuelthresholds = {{value = 25, fillcolor = colorMode.fillcritcolor}, {value = 50, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}},

            -- battery overlay text (voltage / per-cell voltage / consumed mAh)
            rs_fullscreen = utils.isFullScreen(W, H),
            rs_overlayfont = opts.advfont,

            -- governor status
            rs_govfont = governorFont,
            rs_govtitlefont = compactWindow and "FONT_XS" or "FONT_STD",
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
                {value = "@i18n(widgets.governor.THROFF)@", textcolor = colorMode.fillcritcolor}
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
            xoffset = math.floor(W / 24),    -- half a grid column to the right
            type = "gauge",
            subtype = "arc",
            source = "throttle_percent",
            arcmax = true,
            title = "THROTTLE",
            titlepos = "bottom",
            titlefont = arcTitleFont,        -- throttle title font size
            titlepaddingbottom = 8,
            titlepaddingleft = 0,
            min = 0,
            max = getThemeValue("throttle_max"),
            thickness = math.max(3, math.floor((opts.thickness - 10) )), -- throttle arc ring thickness
            font = "FONT_XL",                -- throttle main value font size
            maxfont = smallGaugeMaxFont,
            maxprefix = "Max: ",
            maxpaddingtop = smallGaugeMaxTop,
            maxpaddingleft = 0,
            gaugepadding = math.max(18, math.floor(W * 0.035)),
            gaugepaddingbottom = smallGaugeBottom,
            valuepaddingleft = 0,
            valuepaddingtop = 32,
            valuepaddingbottom = smallGaugeValueBottom,
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
            yoffset = 12,
            type = "gauge",
            subtype = "arc",
            source = "temp_esc",
            arcmax = true,
            title = "ESC TEMP",
            titlepos = "bottom",
            titlefont = arcTitleFont,
            titlepaddingbottom = 8,
            min = 0,
            max = getThemeValue("esctemp_max"),
            thickness = math.max(3, math.floor((opts.thickness - 3) / 2) + 9),
            valuepaddingleft = 0,
            valuepaddingtop = 32,
            valuepaddingbottom = smallGaugeValueBottom,
            maxpaddingleft = 0,
            maxpaddingtop = smallGaugeMaxTop,
            maxprefix = "Max: ",
            maxfont = smallGaugeMaxFont,
            font = "FONT_XL",
            gaugepadding = math.max(18, math.floor(W * 0.04)),
            gaugepaddingbottom = smallGaugeBottom,
            bgcolor = "transparent",
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            maxtextcolor = "orange",
            transform = "floor",
            thresholds = {{value = getThemeValue("esctemp_warn"), fillcolor = colorMode.fillcolor}, {value = getThemeValue("esctemp_max"), fillcolor = colorMode.fillwarncolor}, {value = 155, fillcolor = colorMode.fillcritcolor}}
        },

    }
    local headerH = utils.isFullScreen(W, H) and header_layout.height or 0
    local cellW, cellH = floor(W / layout.cols), floor((H - headerH) / layout.rows)
    for _, box in ipairs(result) do
        if box.source == "temp_esc" or box.source == "throttle_percent" then
            fitArcValue(box, cellW, cellH)
        end
    end
    return result
end

local function boxes()
    local config = rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section]
    local W, H = lcd.getWindowSize()
    if boxes_cache == nil or themeconfig ~= config or lastScreenW ~= W or lastScreenH ~= H then
        boxes_cache = buildBoxes(W, H)
        themeconfig = config
        lastScreenW = W
        lastScreenH = H
    end
    return boxes_cache
end

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, screenBorderStyle = screenBorderStyle, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.8}}

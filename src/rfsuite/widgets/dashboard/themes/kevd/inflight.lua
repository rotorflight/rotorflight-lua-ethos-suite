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

local THEME_DEFAULTS = {throttle_max = 100, rpm_min = 0, rpm_max = 5500, bec_min = 6.0, bec_warn = 8.0, bec_max = 12.0, esctemp_warn = 120, esctemp_max = 150}

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

    ls_full = {font = "FONT_XXL", advfont = "FONT_L", thickness = 24, gaugepadding = 8, gaugepaddingbottom = 28, maxpaddingtop = 48, maxpaddingleft = 18, valuepaddingbottom = 18, fuelpaddingbottom = 8, maxfont = "FONT_L"},

    ls_std = {font = "FONT_XL", advfont = "FONT_STD", thickness = 20, gaugepadding = 2, gaugepaddingbottom = 8, maxpaddingtop = 32, maxpaddingleft = 12, valuepaddingbottom = 6, fuelpaddingbottom = 8, maxfont = "FONT_STD"},

    ms_full = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 14, gaugepadding = 5, gaugepaddingbottom = 16, maxpaddingtop = 26, maxpaddingleft = 10, valuepaddingbottom = 12, fuelpaddingbottom = 5, maxfont = "FONT_S"},

    ms_std = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 12, gaugepadding = 2, gaugepaddingbottom = 6, maxpaddingtop = 18, maxpaddingleft = 10, valuepaddingbottom = 4, fuelpaddingbottom = 8, maxfont = "FONT_S"},

    ss_full = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 17, gaugepadding = 5, gaugepaddingbottom = 16, maxpaddingtop = 26, maxpaddingleft = 10, valuepaddingbottom = 8, fuelpaddingbottom = 5, maxfont = "FONT_S"},

    ss_std = {font = "FONT_XL", advfont = "FONT_STD", thickness = 15, gaugepadding = 2, gaugepaddingbottom = 6, maxpaddingtop = 22, maxpaddingleft = 8, valuepaddingbottom = 4, fuelpaddingbottom = 0, maxfont = "FONT_S"}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil


local pageBgColor = colorMode.bgcolor
local layout = {cols = 12, rows = 10, padding = 0, bgcolor = pageBgColor}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 4 -- increase to move topbar down, decrease to move it up
header_layout.height = header_layout.height + topbarShiftY -- keeps shifted topbar from clipping

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        header_boxes_cache = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        for _, box in ipairs(header_boxes_cache) do
            box.offsety = (box.offsety or 0) + topbarShiftY -- shifts topbar and internal details on Y axis
        end
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function buildBoxes(W)

    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.unknown


    local governorTileBg = {
        backfillcolor = pageBgColor,
        fillcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 4,
        roundradius = 6,
        inset = 4,
        contentpadding = 1
    }


    local governorDisarmedTileBg = {
        backfillcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor,
        fillcolor = lcd.RGB(0x00, 0x00, 0x00),
        bordercolor = colorMode.fillcritcolor,
        borderwidth = 6,
        roundradius = 6,
        inset = 4,
        insettop = 17,
        insetbottom = -4,
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
        insetbottom = -36,
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
            rowspan = 9,
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
            type = "text",
            subtype = "telemetry",
            source = "__background_only__",
            title = "",
            unit = "",
            font = "FONT_XS",
            textcolor = pageBgColor,
            titlecolor = pageBgColor,
            bgcolor = rightStackTileBg
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
            titlefont = "FONT_STD",
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
            maxfont = "FONT_L",
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
            offsetx = 53,                    -- move entire throttle tile left/right; negative = left, positive = right
            offsety = -65,                   -- move entire throttle tile up/down; negative = up, positive = down
            type = "gauge",
            subtype = "arc",
            source = "throttle_percent",
            arcmax = true,
            title = "THROTTLE",
            titlepos = "bottom",
            titlefont = "FONT_STD",          -- throttle title font size
            titlepaddingbottom = -50,        -- throttle title vertical position; adjust to move title up/down
            titlepaddingleft = 8,            -- shift throttle title left/right
            min = 0,
            max = getThemeValue("throttle_max"),
            thickness = math.max(3, math.floor((opts.thickness - 10) )), -- throttle arc ring thickness
            font = "FONT_XL",                -- throttle main value font size
            maxfont = "FONT_L",              -- throttle max value font size
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
            offsetx = -24,
            offsety = 10,
            type = "gauge",
            subtype = "arc",
            source = "temp_esc",
            arcmax = true,
            title = "ESC TEMP",
            titlepos = "bottom",
            titlefont = "FONT_STD",
            titlepaddingbottom = -45,
            min = 0,
            max = getThemeValue("esctemp_max"),
            thickness = math.max(3, math.floor((opts.thickness - 3) / 2) + 9),
            valuepaddingleft = 6,
            valuepaddingbottom = math.max(0, opts.valuepaddingbottom - 6),
            maxpaddingleft = opts.maxpaddingleft - 17,
            maxpaddingtop = math.max(8, opts.maxpaddingtop + 8),
            maxprefix = "Max: ",
            maxfont = "FONT_L",
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


        {
            col = 11,
            row = 1,
            colspan = 2,
            rowspan = 2,
            offsetx = -30,
            offsety = 10,
            type = "time",
            subtype = "flight",
            font = "FONT_XXL",
            titlefont = "FONT_S",
            title = "FLIGHT TIME",
            titlepos = "bottom",
            titlealign = "center",
            valuealign = "center",
            titlepaddingbottom = 6,
            bgcolor = "transparent",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor
        },






        {
            col = 11, -- (gov tile settings)
            row = 9,
            colspan = 2,
            rowspan = 2,
            offsetx = -30,
            offsety = -12,--(move gov tile border up/down)
            type = "text",
            subtype = "telemetry",
            source = "__background_only__",
            title = "",
            unit = "",
            font = "FONT_S",
            textcolor = pageBgColor,
            titlecolor = pageBgColor,
            bgcolor = governorDisarmedTileBg
        },


        {
            col = 11,
            row = 9,
            colspan = 2,
            rowspan = 2,
            offsetx = -30,
            offsety = -10,--(move gov title up or down)
            type = "text",
            subtype = "governor",
            title = "GOVERNOR",
            titlepos = "bottom",
            font = "FONT_STD",
            titlefont = "FONT_STD", --(gov font size)
            titlealign = "center",
            valuealign = "center",
            valuepaddingbottom = -5, -- shifts disame title up/down
            titlepaddingbottom = 1,
            bgcolor = "transparent",
            titlecolor = colorMode.titlecolor,
            thresholds = {
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
            col = 11,
            row = 3,
            colspan = 2,
            rowspan = 6,
            offsetx = -30,
            offsety = 0,
            type = "gauge",
            subtype = "bar",
            source = "smartfuel",
            gaugeorientation = "vertical",
            batteryframe = true,
            batteryframethickness = 3,
            cappaddingtop = 22,
            cappaddingbottom = 0,
            cappaddingleft = 0,
            cappaddingright = 0,

            battadv = false,
            battadvestimatecells = true,
            battadvfullcell = 4.2,
            battadvemptycell = 3.5,
            battadvmincells = 1,
            battadvmaxcells = 14,
            valuealign = "center",
            valuepaddingleft = 13,
            valuepaddingtop = 6,
            valuepaddingbottom = - 40,
            battadvfont = "FONT_STD",
            font = "FONT_XXL",
            battadvpaddingright = -0,
            battadvpaddingtop = -80,
            battadvvaluealign = "right",
            gaugepadding = 0,
            gaugepaddingleft = -4,
            gaugepaddingright = 0,
            gaugepaddingtop = - 16,
            gaugepaddingbottom = 0,
            transform = "floor",
            unit = "%",
            fillcolor = colorMode.fillcolor,
            fillbgcolor = colorMode.fillbgcolor,
            accentcolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
            bgcolor = colorMode.tbbgcolor or colorMode.headerbgcolor or pageBgColor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            thresholds = {{value = 25, fillcolor = colorMode.fillcritcolor}, {value = 50, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}}
        },


        {
            col = 11,
            row = 3,
            colspan = 2,
            rowspan = 1,
            offsetx = -30,
            offsety = 8,
            type = "text",
            subtype = "telemetry",
            source = "voltage",
            transform = formatPackVoltage,
            title = "",
            unit = "",
            font = "FONT_STD",
            valuealign = "right",
            bgcolor = "transparent",
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor
        },


        {
            col = 11,
            row = 3,
            colspan = 2,
            rowspan = 1,
            offsetx = -30,
            offsety = 34,
            type = "text",
            subtype = "telemetry",
            source = "voltage",
            transform = formatCellVoltageAndCount,
            title = "",
            unit = "",
            font = "FONT_STD",
            valuealign = "right",
            bgcolor = "transparent",
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor
        },


        {
            col = 11,
            row = 3,
            colspan = 2,
            rowspan = 1,
            offsetx = -30,
            offsety = 60,
            type = "text",
            subtype = "telemetry",
            source = "smartconsumption",
            transform = formatConsumedMah,
            title = "",
            unit = "",
            font = "FONT_STD",
            valuealign = "right",
            bgcolor = "transparent",
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor
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

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.8}}
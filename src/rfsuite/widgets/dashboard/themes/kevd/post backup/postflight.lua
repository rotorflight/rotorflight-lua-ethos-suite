--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local floor = math.floor
local max = math.max
local tonumber = tonumber

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local maxVoltageToCellVoltage = utils.maxVoltageToCellVoltage

local theme_section = "system/kevd"

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 5500, bec_min = 6.0, bec_warn = 8.0, bec_max = 12.0, esctemp_warn = 120, esctemp_max = 150}

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
    ls_full = {font = "FONT_XL", valuefont = "FONT_L", titlefont = "FONT_STD", titlepaddingtop = 5, thickness = 24, tilefont = "FONT_XXL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 7, gaugepaddingbottom = 13},
    ls_std  = {font = "FONT_L", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 18, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 10},
    ms_full = {font = "FONT_L", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 16, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 9},
    ms_std  = {font = "FONT_S", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 0, thickness = 12, tilefont = "FONT_L", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 7},
    ss_full = {font = "FONT_L", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 16, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 9},
    ss_std  = {font = "FONT_S", valuefont = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 0, thickness = 12, tilefont = "FONT_L", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 7}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local last_txbatt_type = nil

local layout = {cols = 12, rows = 12, padding = 0, bgcolor = colorMode.bgcolor}
local screenBorderStyle = {
    enabled = true,
    bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
    borderwidth = 5,
    inset = 0
}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 4 -- Topbar Y shift: increase to move topbar/header down, decrease to move it up.
if header_layout and header_layout.height then
    header_layout.height = header_layout.height + topbarShiftY -- Adds room so shifted topbar details do not clip.
end

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)

        local headerBgColor = colorMode.headerbgcolor or colorMode.fillbgcolor or colorMode.bgcolor
        for _, box in ipairs(boxes) do
            box.bgcolor = headerBgColor -- Matches latest preflight5 topbar background handling.
            box.offsety = (box.offsety or 0) + topbarShiftY -- Moves topbar item and internal details on the Y axis.
        end

        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function buildBoxes(W)
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ls_full

    local gaugeTileBg = {
        -- Same bordered-tile method used for the working preflight 5-tile borders.
        -- Border follows the SmartFuel / AdvBatt outline color path.
        backfillcolor = colorMode.bgcolor,
        fillcolor = colorMode.bgcolor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 5,
        roundradius = 8,
        inset = 8,
        contentpadding = 1
    }

    return {

        -- Border underlays for postflight time/status tiles. These use the same
        -- 5-tile border method and draw before the actual time widgets.

        -- Border underlays for all postflight telemetry gauges. These draw first,
        -- and the actual bar gauges are drawn on top with transparent backgrounds.
        {col = 1, row = 10, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "altitude", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 5, row = 10, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "watts", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 5, row = 7, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "current", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 1, row = 4, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "rpm", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 1, row = 7, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "link", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 9, row = 4, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "smartconsumption", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 5, row = 4, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "smartfuel", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 9, row = 10, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "voltage", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        {col = 9, row = 7, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "temp_esc", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = gaugeTileBg, titlecolor = colorMode.bgcolor, textcolor = colorMode.bgcolor},
        -- =========================================================================
        -- COLUMN 1: TIME AND ALTITUDE
        -- =========================================================================
        {
            col = 5, row = 1, colspan = 4, rowspan = 3,
            type = "time",
            subtype = "flight",
            title = "Flight Time",
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
            col = 9, row = 1, colspan = 4, rowspan = 3,
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
        -- MODIFIED: Altitude Max moved here (Col 1, Row 10)
        {
            col = 1, row = 10, colspan = 4, rowspan = 3,
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
            titlepaddingtop = opts.titlepaddingtop + 11,
            -- Keep the actual bar gauge inside the bordered tile underlay.
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor"
        },

        -- =========================================================================
        -- COLUMN 2: POWER, CURRENT, RPM, VFR/LINK
        -- =========================================================================
        {
            col = 5, row = 10, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "watts",
            stattype = "max",
            title = "Max Watts",
            unit = "W",
            min = 0,
            max = 10000,
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            -- Keep the actual bar gauge inside the bordered tile underlay.
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor"
        },
        {
            col = 5, row = 7, colspan = 4, rowspan = 3,
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
            titlepaddingtop = opts.titlepaddingtop + 11,
            -- Keep the actual bar gauge inside the bordered tile underlay.
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor"
        },
        -- MODIFIED: RPM Max moved here (Col 5, Row 7)
        {
            col = 1, row = 4, colspan = 4, rowspan = 3,
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
            titlepaddingtop = opts.titlepaddingtop + 11,
            -- Keep the actual bar gauge inside the bordered tile underlay.
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor"
        },
        {
            col = 1, row = 7, colspan = 4, rowspan = 3,
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
            titlepaddingtop = opts.titlepaddingtop + 11,
            -- Keep the actual bar gauge inside the bordered tile underlay.
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = 10, fillcolor = colorMode.fillcritcolor},
                {value = 45, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}
            },
            transform = "floor"
        },

        -- =========================================================================
        -- COLUMN 3: CONSUMPTION, FUEL, VOLTAGE, TEMP
        -- =========================================================================
        {
            col = 9, row = 4, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "smartconsumption",
            stattype = "max",
            title = "Consumed mAh",
            unit = "mAh",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            -- Keep the actual bar gauge inside the bordered tile underlay.
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            min = 0,
            max = 5000,
            thresholds = {
                {value = 2250, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)},
                {value = 4000, fillcolor = colorMode.fillcritcolor}
            },
            transform = "floor"
        },
        {
            col = 5, row = 4, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "smartfuel",
            stattype = "min",
            title = "Battery Remaining",
            unit = "%",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            -- Keep the actual bar gauge inside the bordered tile underlay.
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            min = 0,
            max = 100,
            thresholds = {
                {value = 25, fillcolor = colorMode.fillcritcolor},
                {value = 45, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}
            },
            transform = "floor"
        },
        {
            col = 9, row = 10, colspan = 4, rowspan = 3,
            offsety = -7,
            type = "gauge",
            subtype = "bar",
            source = "voltage",
            stattype = "min",
            title = "Volts per cell",
            unit = "V",
            min = 3.2,
            max = 4.35,
            gaugevalue = "display",
            titlepos = "top",
            titlealign = "center",
            valuealign = "center",
            font = opts.font,
            titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing,
            titlepaddingtop = opts.titlepaddingtop + 11,
            -- Keep the actual bar gauge inside the bordered tile underlay.
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = 3.70, fillcolor = colorMode.fillcritcolor},
                {value = 3.85, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}
            },
            transform = function(v) return maxVoltageToCellVoltage(v) end,
            decimals = 2
        },
        {
            col = 9, row = 7, colspan = 4, rowspan = 3,
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
            titlepaddingtop = opts.titlepaddingtop + 11,
            -- Keep the actual bar gauge inside the bordered tile underlay.
            thickness = max(4, opts.thickness - 4),
            gaugepadding = 12,
            gaugepaddingtop = opts.gaugepaddingtop,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            gaugepaddingleft = 13,
            gaugepaddingright = 13,
            bgcolor = "transparent",
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            min = 0,
            max = getThemeValue("esctemp_max"),
            thresholds = {
                {value = getThemeValue("esctemp_warn"), fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)},
                {value = getThemeValue("esctemp_max"), fillcolor = colorMode.fillcritcolor}
            },
            transform = "floor"
        },}
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

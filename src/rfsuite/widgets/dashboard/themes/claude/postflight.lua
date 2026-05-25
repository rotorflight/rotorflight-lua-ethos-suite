--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html

  claude — postflight layout
  Full flight review: time, speeds, voltage, current, power, consumption.
  Six-column stat grid — same proven approach as gismo's postflight.
]] --

local rfsuite = require("rfsuite")
local lcd     = lcd

local utils      = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
local colorMode  = utils.themeColors()

local maxVoltageToCellVoltage = utils.maxVoltageToCellVoltage

local function getThemeOptionKey(W)
    return utils.getDashboardThemeOptionKey(W)
end

local themeOptions = {
    ls_full = {font = "FONT_XXL", titlefont = "FONT_S",  valuepaddingtop = 15},
    ls_std  = {font = "FONT_XL",  titlefont = "FONT_XS", valuepaddingtop = 10},
    ms_full = {font = "FONT_XL",  titlefont = "FONT_XS", valuepaddingtop = 10},
    ms_std  = {font = "FONT_XL",  titlefont = "FONT_XS", valuepaddingtop = 6},
    ss_full = {font = "FONT_XL",  titlefont = "FONT_XS", valuepaddingtop = 5},
    ss_std  = {font = "FONT_L",   titlefont = "FONT_XS", valuepaddingtop = 3},
}

local lastScreenW        = nil
local boxes_cache        = nil
local header_boxes_cache = nil
local last_txbatt_type   = nil

-- 6-column × 12-row stat grid — readable on any screen size
local layout = {cols = 6, rows = 12, padding = 2, showstats = false}

local header_layout = utils.standardHeaderLayout(headeropts)

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end
    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        header_boxes_cache = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function buildBoxes(W)
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ms_std

    -- Helper: stat box shorthand
    local function stat(col, row, src, title, unit, opts2)
        local box = {
            col = col, row = row, colspan = 2, rowspan = 3,
            type = "text", subtype = "stats",
            source = src, unit = unit or "",
            title = title, titlepos = "bottom",
            transform = "floor",
            bgcolor    = (col == 1 or col == 5) and colorMode.panelbg or colorMode.paneldarkbg,
            textcolor  = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            valuepaddingtop = opts.valuepaddingtop,
            font = opts.font, titlefont = opts.titlefont,
        }
        if opts2 then for k, v in pairs(opts2) do box[k] = v end end
        return box
    end

    return {

        -- Column 1-2: time and RPM stats
        {
            col = 1, row = 1, colspan = 2, rowspan = 3,
            type = "time", subtype = "flight",
            title = "@i18n(widgets.dashboard.flight_duration)@", titlepos = "bottom",
            bgcolor = colorMode.panelbg, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor,
            valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont,
        },
        {
            col = 1, row = 4, colspan = 2, rowspan = 3,
            type = "time", subtype = "total",
            title = "@i18n(widgets.dashboard.total_flight_duration)@", titlepos = "bottom",
            bgcolor = colorMode.paneldarkbg, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor,
            valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont,
        },
        stat(1, 7,  "rpm", "@i18n(widgets.dashboard.rpm_max)@",     " rpm"),
        stat(1, 10, "rpm", "@i18n(widgets.dashboard.rpm_min)@",     " rpm", {stattype = "min", bgcolor = colorMode.panelbg}),

        -- Column 3-4: throttle, current, ESC temp, watts
        stat(3, 1,  "throttle_percent", "@i18n(widgets.dashboard.throttle_max)@",   "%"),
        stat(3, 4,  "current",          "@i18n(widgets.dashboard.current_max)@",    " A",  {bgcolor = colorMode.panelbg}),
        stat(3, 7,  "temp_esc",         "@i18n(widgets.dashboard.esc_max_temp)@",   "°C"),
        {
            col = 3, row = 10, colspan = 2, rowspan = 3,
            type = "text", subtype = "watts", source = "max",
            title = "@i18n(widgets.dashboard.watts_max)@", unit = " W", titlepos = "bottom",
            bgcolor = colorMode.panelbg, transform = "floor",
            textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor,
            valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont,
        },

        -- Column 5-6: voltage, fuel, consumption
        stat(5, 1,  "smartconsumption", "@i18n(widgets.dashboard.consumed_mah)@",   " mAh", {stattype = "max", bgcolor = colorMode.panelbg}),
        stat(5, 4,  "smartfuel",        "@i18n(widgets.dashboard.fuel_remaining)@", "%",   {stattype = "min"}),
        {
            col = 5, row = 7, colspan = 2, rowspan = 3,
            type = "text", subtype = "stats", stattype = "min", source = "voltage",
            title = "@i18n(widgets.dashboard.min_volts_cell)@", titlepos = "bottom",
            bgcolor = colorMode.panelbg, unit = " V",
            transform = function(v) return maxVoltageToCellVoltage(v) end,
            textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor,
            valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont,
        },
        {
            col = 5, row = 10, colspan = 2, rowspan = 3,
            type = "text", subtype = "stats", stattype = "min", source = "voltage",
            title = "@i18n(widgets.dashboard.min_voltage)@", titlepos = "bottom",
            bgcolor = colorMode.paneldarkbg, unit = " V",
            textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor,
            valuepaddingtop = opts.valuepaddingtop, font = opts.font, titlefont = opts.titlefont,
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

return {
    layout        = layout,
    boxes         = boxes,
    header_boxes  = header_boxes,
    header_layout = header_layout,
    scheduler     = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.5},
}

--[[
  Copyright (C) 2025 Rotorflight Project
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

local function maxVoltageToCellVoltage(value)
    local cells = 2

    if cells and value then
        value = max(0, value / cells)
        value = floor(value * 100 + 0.5) / 100
    end

    return value
end

local theme_section = "system/@aerc-n"

local THEME_DEFAULTS = {v_min = 7.0, v_max = 8.4, rpm_min = 0, rpm_max = 3000}

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
    if W == 800 then
        return "ls_full"
    elseif W == 784 then
        return "ls_std"
    elseif W == 640 then
        return "ss_full"
    elseif W == 630 then
        return "ss_std"
    elseif W == 480 then
        return "ms_full"
    elseif W == 472 then
        return "ms_std"
    end
end

local themeOptions = {ls_full = {font = "FONT_XXL", titlefont = "FONT_S", titlepaddingtop = 15}, ls_std = {font = "FONT_XL", titlefont = "FONT_XS", titlepaddingtop = 0}, ms_full = {font = "FONT_XL", titlefont = "FONT_XXS", titlepaddingtop = 5}, ms_std = {font = "FONT_XL", titlefont = "FONT_XXS", titlepaddingtop = 0}, ss_full = {font = "FONT_XL", titlefont = "FONT_XS", titlepaddingtop = 5}, ss_std = {font = "FONT_XL", titlefont = "FONT_XXS", titlepaddingtop = 0}}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local last_txbatt_type = nil

local layout = {cols = 6, rows = 12}

local header_layout = utils.standardHeaderLayout(headeropts)

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        header_boxes_cache = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function buildBoxes(W)

    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.unknown

    return {

        {col = 1, row = 1, colspan = 2, rowspan = 4, type = "time", subtype = "flight", title = "@i18n(widgets.dashboard.flight_duration)@", titlefont = opts.titlefont, titlepos = "top", titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, textcolor = "orange", titlecolor = colorMode.titlecolor},
        {col = 1, row = 5, colspan = 2, rowspan = 4, type = "time", subtype = "total", title = "@i18n(widgets.dashboard.total_flight_duration)@", titlefont = opts.titlefont, titlepos = "top", titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, textcolor = "orange", titlecolor = colorMode.titlecolor},
        {col = 1, row = 9, colspan = 2, rowspan = 4, type = "time", subtype = "count", title = "@i18n(widgets.dashboard.flights)@", titlefont = opts.titlefont, titlepos = "top", titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"},
        {col = 3, row = 1, colspan = 2, rowspan = 4, type = "text", subtype = "stats", stattype = "min", source = "rpm", title = "@i18n(widgets.dashboard.rpm_min)@", titlefont = opts.titlefont, unit = " rpm", titlepos = "top", titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},
        {col = 3, row = 5, colspan = 2, rowspan = 4, type = "text", subtype = "stats", source = "rpm", title = "@i18n(widgets.dashboard.rpm_max)@", unit = " rpm", titlefont = opts.titlefont, titlepos = "top", titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},
        {col = 3, row = 9, colspan = 2, rowspan = 4, type = "text", subtype = "stats", source = "throttle_percent", title = "@i18n(widgets.dashboard.throttle_max)@", titlefont = opts.titlefont, titlepos = "top", titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, transform = "floor", textcolor = "orange", titlecolor = colorMode.titlecolor},
        {col = 5, row = 1, colspan = 2, rowspan = 4, type = "text", subtype = "telemetry", source = "bec_voltage", title = "@i18n(widgets.dashboard.voltage)@", titlefont = opts.titlefont, titlepos = "top", titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, unit = "V", textcolor = "orange", titlecolor = colorMode.titlecolor},
        {col = 5, row = 5, colspan = 2, rowspan = 4, type = "text", subtype = "stats", stattype = "min", source = "bec_voltage", title = "@i18n(widgets.dashboard.min_voltage)@", titlefont = opts.titlefont, titlepos = "top", titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end, textcolor = "orange", titlecolor = colorMode.titlecolor},
        {col = 5, row = 9, colspan = 2, rowspan = 4, type = "text", subtype = "stats", source = "altitude", title = "@i18n(widgets.dashboard.altitude_max)@", titlefont = opts.titlefont, titlepos = "top", titlepaddingtop = opts.titlepaddingtop, font = opts.font, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = "orange", transform = "floor"}
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

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.5}}


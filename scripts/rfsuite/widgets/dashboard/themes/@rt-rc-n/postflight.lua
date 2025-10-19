--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local function maxVoltageToCellVoltage(value)
    local cfg = rfsuite.session.batteryConfig
    local cells = (cfg and cfg.batteryCellCount) or 3

    if cfg and cells and value then
        value = math.max(0, value / cells)
        value = math.floor(value * 100 + 0.5) / 100
    end

    return value
end

local theme_section = "system/@rt-rc-n"

local THEME_DEFAULTS = {v_min = 7.0, v_max = 8.4}

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

local themeOptions = {ls_full = {font = "FONT_XXL", valuepaddingtop = 0}, ls_std = {font = "FONT_XL", valuepaddingtop = 0}, ms_full = {font = "FONT_XL", valuepaddingtop = 10}, ms_std = {font = "FONT_XL", valuepaddingtop = 5}, ss_full = {font = "FONT_XL", valuepaddingtop = 10}, ss_std = {font = "FONT_XL", valuepaddingtop = 10}}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local last_txbatt_type = nil

local layout = {cols = 3, rows = 3, padding = 2}

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

        {col = 1, row = 1, type = "time", subtype = "flight", opts.font, title = "@i18n(widgets.dashboard.flight_duration)@", titlepos = "bottom", valuepaddingtop = opts.valuepaddingtop, bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
        {col = 1, row = 2, type = "time", subtype = "total", opts.font, title = "@i18n(widgets.dashboard.total_flight_duration)@", titlepos = "bottom", valuepaddingtop = opts.valuepaddingtop, bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
        {col = 1, row = 3, type = "text", subtype = "stats", opts.font, stattype = "min", source = "rpm", title = "@i18n(widgets.dashboard.rpm_min)@", valuepaddingtop = opts.valuepaddingtop, unit = " rpm", titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
        {col = 2, row = 1, type = "text", subtype = "stats", stattype = "min", source = "link", opts.font, title = "@i18n(widgets.dashboard.link_min)@", valuepaddingtop = opts.valuepaddingtop, titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
        {col = 2, row = 2, type = "text", subtype = "stats", stattype = "max", source = "link", opts.font, title = "@i18n(widgets.dashboard.link_max)@", valuepaddingtop = opts.valuepaddingtop, titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
        {col = 2, row = 3, type = "text", subtype = "stats", source = "rpm", opts.font, title = "@i18n(widgets.dashboard.rpm_max)@", unit = " rpm", valuepaddingtop = opts.valuepaddingtop, titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
        {col = 3, row = 1, type = "text", subtype = "telemetry", source = "bec_voltage", opts.font, title = "@i18n(widgets.dashboard.voltage)@", valuepaddingtop = opts.valuepaddingtop, titlepos = "bottom", bgcolor = colorMode.bgcolor, unit = "V", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
        {col = 3, row = 2, type = "text", subtype = "stats", stattype = "min", source = "bec_voltage", opts.font, title = "@i18n(widgets.dashboard.min_volts_cell)@", valuepaddingtop = opts.valuepaddingtop, titlepos = "bottom", bgcolor = colorMode.bgcolor, unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor},
        {col = 3, row = 3, type = "text", subtype = "stats", source = "throttle_percent", opts.font, title = "@i18n(widgets.dashboard.throttle_max)@", valuepaddingtop = opts.valuepaddingtop, titlepos = "bottom", bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor}

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

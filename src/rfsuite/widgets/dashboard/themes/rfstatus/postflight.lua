--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local tonumber = tonumber

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local theme_section = "system/@rfstatus"

local THEME_DEFAULTS = {v_min = 18.0, v_max = 25.2}

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

local themeOptions = {ls_full = {font = "FONT_XXL"}, ls_std = {font = "FONT_XXL"}, ms_full = {font = "FONT_XXL"}, ms_std = {font = "FONT_XXL"}, ss_full = {font = "FONT_XXL"}, ss_std = {font = "FONT_XXL"}}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local last_txbatt_type = nil

local layout = {cols = 2, rows = 3, padding = 4}

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

        {col = 1, row = 1, type = "text", subtype = "stats", source = "voltage", stattype = "min", font = opts.font, title = "@i18n(widgets.dashboard.min_voltage):upper()@", titlepos = "bottom", textcolor = colorMode.textcolor, titlecolor = colorMode.textcolor},
        {col = 2, row = 1, type = "text", subtype = "stats", source = "voltage", stattype = "max", font = opts.font, title = "@i18n(widgets.dashboard.max_voltage):upper()@", titlepos = "bottom", textcolor = colorMode.textcolor, titlecolor = colorMode.textcolor},
        {col = 1, row = 2, type = "text", subtype = "stats", source = "current", stattype = "min", font = opts.font, title = "@i18n(widgets.dashboard.min_current):upper()@", titlepos = "bottom", transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.textcolor},
        {col = 2, row = 2, type = "text", subtype = "stats", source = "current", stattype = "max", font = opts.font, title = "@i18n(widgets.dashboard.max_current):upper()@", titlepos = "bottom", transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.textcolor},
        {col = 1, row = 3, type = "text", subtype = "stats", source = "temp_mcu", stattype = "max", font = opts.font, title = "@i18n(widgets.dashboard.max_tmcu):upper()@", titlepos = "bottom", transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.textcolor},
        {col = 2, row = 3, type = "text", subtype = "stats", source = "temp_esc", stattype = "max", font = opts.font, title = "@i18n(widgets.dashboard.max_emcu):upper()@", titlepos = "bottom", transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.textcolor}

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

--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local theme_section = "system/@aerc"

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 3000, bec_min = 3.0, bec_warn = 6.0, bec_max = 13.0, esctemp_warn = 90, esctemp_max = 140}

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

local themeOptions = {

    ls_full = {font = "FONT_XXL", advfont = "FONT_L", thickness = 26, gaugepadding = 10, gaugepaddingbottom = 40, maxpaddingtop = 60, maxpaddingleft = 20, valuepaddingbottom = 25, fuelpaddingbottom = 10, maxfont = "FONT_L"},

    ls_std = {font = "FONT_XL", advfont = "FONT_STD", thickness = 22, gaugepadding = 0, gaugepaddingbottom = 0, maxpaddingtop = 35, maxpaddingleft = 15, valuepaddingbottom = 0, fuelpaddingbottom = 10, maxfont = "FONT_STD"},

    ms_full = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 15, gaugepadding = 5, gaugepaddingbottom = 20, maxpaddingtop = 30, maxpaddingleft = 10, valuepaddingbottom = 15, fuelpaddingbottom = 5, maxfont = "FONT_S"},

    ms_std = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 13, gaugepadding = 0, gaugepaddingbottom = 0, maxpaddingtop = 20, maxpaddingleft = 10, valuepaddingbottom = 0, fuelpaddingbottom = 10, maxfont = "FONT_S"},

    ss_full = {font = "FONT_XXL", advfont = "FONT_STD", thickness = 19, gaugepadding = 5, gaugepaddingbottom = 20, maxpaddingtop = 30, maxpaddingleft = 10, valuepaddingbottom = 10, fuelpaddingbottom = 5, maxfont = "FONT_S"},

    ss_std = {font = "FONT_XL", advfont = "FONT_STD", thickness = 17, gaugepadding = 0, gaugepaddingbottom = 0, maxpaddingtop = 25, maxpaddingleft = 10, valuepaddingbottom = 0, fuelpaddingbottom = 0, maxfont = "FONT_S"}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local layout = {cols = 3, rows = 10}

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

        {col = 1, row = 1, rowspan = 2, type = "time", subtype = "flight", font = opts.font, title = "@i18n(widgets.dashboard.flight_time):upper()@", titlepos = "bottom", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor}, {
            col = 2,
            row = 1,
            colspan = 2,
            rowspan = 2,
            type = "gauge",
            source = "smartfuel",
            battadv = true,
            valuealign = "left",
            valuepaddingleft = 85,
            valuepaddingbottom = opts.fuelpaddingbottom,
            battadvfont = "FONT_STD",
            font = opts.font,
            battadvpaddingright = 5,
            battadvvaluealign = "right",
            transform = "floor",
            fillcolor = colorMode.fillcolor,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            thresholds = {{value = 10, fillcolor = colorMode.fillcritcolor}, {value = 45, fillcolor = colorMode.fillwarncolor}}
        }, {
            col = 1,
            row = 3,
            rowspan = 8,
            type = "gauge",
            subtype = "arc",
            source = "throttle_percent",
            arcmax = true,
            title = "@i18n(widgets.dashboard.throttle):upper()@",
            titlepos = "bottom",
            thickness = opts.thickness,
            font = opts.font,
            maxfont = opts.maxfont,
            maxprefix = "Max: ",
            maxpaddingtop = opts.maxpaddingtop,
            gaugepadding = opts.gaugepadding,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            valuepaddingbottom = opts.valuepaddingbottom,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            maxtextcolor = "orange",
            transform = "floor",
            thresholds = {{value = 89, fillcolor = "blue"}, {value = 100, fillcolor = "darkblue"}}
        }, {
            col = 2,
            row = 3,
            rowspan = 8,
            type = "gauge",
            subtype = "arc",
            source = "rpm",
            arcmax = true,
            title = "@i18n(widgets.dashboard.headspeed):upper()@",
            titlepos = "bottom",
            min = 0,
            max = getThemeValue("rpm_max"),
            thickness = opts.thickness,
            unit = "",
            maxprefix = "Max: ",
            font = opts.font,
            maxpaddingtop = opts.maxpaddingtop,
            maxfont = opts.maxfont,
            gaugepadding = opts.gaugepadding,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            valuepaddingbottom = opts.valuepaddingbottom,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            maxtextcolor = "orange",
            transform = "floor",
            thresholds = {{value = getThemeValue("rpm_min"), fillcolor = "lightpurple"}, {value = getThemeValue("rpm_max"), fillcolor = "purple"}, {value = 10000, fillcolor = "darkpurple"}}
        }, {
            col = 3,
            row = 3,
            rowspan = 8,
            type = "gauge",
            subtype = "arc",
            source = "temp_esc",
            arcmax = true,
            title = "@i18n(widgets.dashboard.esc_temp):upper()@",
            titlepos = "bottom",
            min = 0,
            max = getThemeValue("esctemp_max"),
            thickness = opts.thickness,
            valuepaddingleft = 10,
            valuepaddingbottom = opts.valuepaddingbottom,
            maxpaddingleft = opts.maxpaddingleft,
            maxpaddingtop = opts.maxpaddingtop,
            maxprefix = "Max: ",
            maxfont = opts.maxfont,
            font = opts.font,
            gaugepadding = opts.gaugepadding,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            maxtextcolor = "orange",
            transform = "floor",
            thresholds = {{value = getThemeValue("esctemp_warn"), fillcolor = colorMode.fillcolor}, {value = getThemeValue("esctemp_max"), fillcolor = colorMode.fillwarncolor}, {value = 200, fillcolor = colorMode.fillcritcolor}}
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

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.8}}

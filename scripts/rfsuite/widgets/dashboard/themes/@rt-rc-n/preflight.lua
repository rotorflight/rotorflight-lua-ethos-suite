--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

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

local themeOptions = {

    ls_full = {font = "FONT_XXL", thickness = 35, gaugepadding = 5, valuepaddingtop = 40},

    ls_std = {font = "FONT_XXL", thickness = 25, gaugepadding = 5, valuepaddingtop = 25},

    ms_full = {font = "FONT_XL", thickness = 25, gaugepadding = 5, valuepaddingtop = 35},

    ms_std = {font = "FONT_XL", thickness = 20, gaugepadding = 5, valuepaddingtop = 25},

    ss_full = {font = "FONT_XXL", thickness = 25, gaugepadding = 5, valuepaddingtop = 35},

    ss_std = {font = "FONT_XXL", thickness = 18, gaugepadding = 5, valuepaddingtop = 25}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local layout = {cols = 20, rows = 8, padding = 2}

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
    local vmin = getThemeValue("v_min") or 7.0
    local vmax = getThemeValue("v_max") or 8.4

    return {

        {col = 1, row = 1, colspan = 8, rowspan = 3, type = "image", subtype = "model", bgcolor = colorMode.bgcolor}, {
            col = 1,
            row = 4,
            colspan = 4,
            rowspan = 3,
            type = "text",
            subtype = "governor",
            title = "@i18n(widgets.dashboard.governor):upper()@",
            titlepos = "bottom",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
            thresholds = {
                {value = "@i18n(widgets.governor.DISARMED)@", textcolor = colorMode.fillcritcolor}, {value = "@i18n(widgets.governor.OFF)@", textcolor = colorMode.fillcritcolor}, {value = "@i18n(widgets.governor.IDLE)@", textcolor = "blue"},
                {value = "@i18n(widgets.governor.SPOOLUP)@", textcolor = "blue"}, {value = "@i18n(widgets.governor.RECOVERY)@", textcolor = colorMode.fillwarncolor}, {value = "@i18n(widgets.governor.ACTIVE)@", textcolor = colorMode.fillcolor},
                {value = "@i18n(widgets.governor.THR-OFF)@", textcolor = colorMode.fillcritcolor}
            }
        }, {
            col = 5,
            row = 4,
            colspan = 4,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "rpm",
            unit = "",
            transform = "floor",
            title = "@i18n(widgets.dashboard.headspeed):upper()@",
            titlepos = "bottom",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
            bgcolor = colorMode.bgcolor
        },
        {
            col = 1,
            row = 7,
            colspan = 2,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "pid_profile",
            title = "@i18n(widgets.dashboard.profile):upper()@",
            titlepos = "bottom",
            transform = "floor",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
            bgcolor = colorMode.bgcolor
        },
        {
            col = 3,
            row = 7,
            colspan = 2,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "rate_profile",
            title = "@i18n(widgets.dashboard.rates):upper()@",
            titlepos = "bottom",
            transform = "floor",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
            bgcolor = colorMode.bgcolor
        }, {col = 5, row = 7, colspan = 2, rowspan = 2, type = "time", subtype = "count", title = "@i18n(widgets.dashboard.flights):upper()@", titlepos = "bottom", titlecolor = colorMode.titlecolor, textcolor = colorMode.titlecolor, bgcolor = colorMode.bgcolor}, {
            col = 7,
            row = 7,
            colspan = 2,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "link",
            unit = "dB",
            title = "@i18n(widgets.dashboard.lq):upper()@",
            titlepos = "bottom",
            transform = "floor",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
            bgcolor = colorMode.bgcolor
        }, {col = 9, row = 7, colspan = 6, rowspan = 2, type = "time", subtype = "flight", title = "@i18n(widgets.dashboard.time):upper()@", titlepos = "bottom", titlecolor = colorMode.titlecolor, textcolor = colorMode.titlecolor, bgcolor = colorMode.bgcolor},
        {col = 15, row = 7, colspan = 6, rowspan = 2, type = "text", subtype = "blackbox", title = "@i18n(widgets.dashboard.blackbox):upper()@", titlepos = "bottom", decimals = 0, titlecolor = colorMode.titlecolor, textcolor = colorMode.titlecolor, bgcolor = colorMode.bgcolor}, {
            type = "gauge",
            subtype = "arc",
            col = 9,
            row = 1,
            colspan = 6,
            rowspan = 6,
            gaugepadding = opts.gaugepadding,
            valuepaddingtop = opts.valuepaddingtop,
            thickness = opts.thickness,
            source = "throttle_percent",
            unit = "%",
            transform = "floor",
            min = 0,
            max = 100,
            font = opts.font,
            fillbgcolor = colorMode.fillbgcolor,
            title = "@i18n(widgets.dashboard.throttle):upper()@",
            titlepos = "bottom",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
            bgcolor = colorMode.bgcolor,
            thresholds = {{value = 30, fillcolor = colorMode.fillcritcolor, textcolor = colorMode.textcolor}, {value = 50, fillcolor = colorMode.fillwarncolor, textcolor = colorMode.textcolor}, {value = 140, fillcolor = colorMode.fillcolor, textcolor = colorMode.textcolor}}
        }, {
            col = 15,
            row = 1,
            colspan = 6,
            rowspan = 6,
            type = "gauge",
            subtype = "arc",
            source = "bec_voltage",
            fillbgcolor = colorMode.fillbgcolor,
            title = "@i18n(widgets.dashboard.voltage):upper()@",
            font = opts.font,
            gaugepadding = opts.gaugepadding,
            valuepaddingtop = opts.valuepaddingtop,
            thickness = opts.thickness,
            titlepos = "bottom",
            fillcolor = colorMode.fillcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
            bgcolor = colorMode.bgcolor,
            min = vmin,
            max = vmax,
            thresholds = {{value = vmin + 0.2 * (vmax - vmin), fillcolor = colorMode.fillcritcolor}, {value = vmin + 0.4 * (vmax - vmin), fillcolor = colorMode.fillwarncolor}, {value = vmax, fillcolor = colorMode.fillcolor}}
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

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.5}}

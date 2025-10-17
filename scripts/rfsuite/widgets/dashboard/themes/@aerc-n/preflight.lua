--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

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

local themeOptions = {

    ls_full = {font = "FONT_XXL", titlefont = "FONT_S", valuepaddingbottom = 20, titlepaddingtop = 15, vgaugepaddingbottom = 7},

    ls_std = {font = "FONT_XL", titlefont = "FONT_XS", valuepaddingbottom = 25, titlepaddingtop = 0, vgaugepaddingbottom = 5},

    ms_full = {font = "FONT_XL", titlefont = "FONT_XS", valuepaddingbottom = 15, titlepaddingtop = 5, vgaugepaddingbottom = 5},

    ms_std = {font = "FONT_XL", titlefont = "FONT_XXS", valuepaddingbottom = 0, titlepaddingtop = 0, vgaugepaddingbottom = 5},

    ss_full = {font = "FONT_XL", titlefont = "FONT_XS", valuepaddingbottom = 15, titlepaddingtop = 5, vgaugepaddingbottom = 7},

    ss_std = {font = "FONT_XL", titlefont = "FONT_XXS", valuepaddingbottom = 0, titlepaddingtop = 0, vgaugepaddingbottom = 5}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
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
    local vmin = getThemeValue("v_min") or 7.0
    local vmax = getThemeValue("v_max") or 8.4

    return {

        {
            col = 1,
            colspan = 2,
            row = 1,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "throttle_percent",
            title = "@i18n(widgets.dashboard.throttle):upper()@",
            titlepos = "bottom",
            font = opts.font,
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            thresholds = {{value = 20, textcolor = colorMode.textcolor}, {value = 80, textcolor = colorMode.fillwarncolor}, {value = 100, textcolor = colorMode.fillcritcolor}}
        }, {
            col = 1,
            colspan = 2,
            row = 4,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "rpm",
            title = "@i18n(widgets.dashboard.headspeed):upper()@",
            titlepos = "bottom",
            font = opts.font,
            unit = " rpm",
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor
        }, {
            col = 1,
            colspan = 2,
            row = 7,
            rowspan = 3,
            type = "text",
            subtype = "blackbox",
            title = "@i18n(widgets.dashboard.blackbox):upper()@",
            titlepos = "bottom",
            font = opts.font,
            decimals = 0,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            transform = "floor",
            thresholds = {{value = 80, textcolor = colorMode.textcolor}, {value = 90, textcolor = colorMode.fillwarncolor}, {value = 100, textcolor = colorMode.fillcritcolor}}
        }, {
            col = 1,
            colspan = 2,
            row = 10,
            rowspan = 3,
            type = "text",
            subtype = "governor",
            title = "@i18n(widgets.dashboard.governor):upper()@",
            titlepos = "bottom",
            font = opts.font,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = "@i18n(widgets.governor.DISARMED)@", textcolor = colorMode.fillcritcolor}, {value = "@i18n(widgets.governor.OFF)@", textcolor = colorMode.fillcritcolor}, {value = "@i18n(widgets.governor.IDLE)@", textcolor = "blue"},
                {value = "@i18n(widgets.governor.SPOOLUP)@", textcolor = "blue"}, {value = "@i18n(widgets.governor.RECOVERY)@", textcolor = colorMode.fillwarncolor}, {value = "@i18n(widgets.governor.ACTIVE)@", textcolor = colorMode.fillcolor},
                {value = "@i18n(widgets.governor.THR-OFF)@", textcolor = colorMode.fillcritcolor}
            }
        }, {col = 3, row = 1, colspan = 3, rowspan = 9, type = "image", subtype = "model", bgcolor = colorMode.bgcolor}, {
            col = 3,
            row = 10,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "rate_profile",
            title = "@i18n(widgets.dashboard.rates):upper()@",
            titlepos = "bottom",
            font = opts.font,
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {{value = 1.5, textcolor = "blue"}, {value = 2.5, textcolor = colorMode.fillwarncolor}, {value = 6, textcolor = colorMode.fillcolor}}
        }, {
            col = 4,
            row = 10,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "pid_profile",
            title = "@i18n(widgets.dashboard.profile):upper()@",
            titlepos = "bottom",
            font = opts.font,
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {{value = 1.5, textcolor = "blue"}, {value = 2.5, textcolor = colorMode.fillwarncolor}, {value = 6, textcolor = colorMode.fillcolor}}
        }, {col = 5, row = 10, rowspan = 3, type = "time", subtype = "count", title = "@i18n(widgets.dashboard.flights):upper()@", titlepos = "bottom", font = opts.font, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor}, {
            col = 6,
            colspan = 1,
            row = 1,
            rowspan = 12,
            type = "gauge",
            source = "bec_voltage",
            title = "@i18n(widgets.dashboard.voltage):upper()@",
            titlepos = "bottom",
            gaugeorientation = "vertical",
            gaugepaddingright = 10,
            gaugepaddingleft = 10,
            gaugepaddingtop = 5,
            gaugepaddingbottom = opts.vgaugepaddingbottom,
            decimals = 1,
            battery = true,
            batteryspacing = 1,
            valuepaddingbottom = 17,
            valuepaddingleft = 8,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
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

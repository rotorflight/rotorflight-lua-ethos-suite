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

    ls_full = {font = "FONT_XXL", advfont = "FONT_STD", titlefont = "FONT_XXS", brfont = "FONT_XL", thickness = 32, batteryframethickness = 4, titlepaddingbottom = 25, valuepaddingleft = 25, valuepaddingtop = 20, gvaluepaddingtop = 30, valuepaddingbottom = 25, brvaluepaddingbottom = 20, gaugepaddingtop = 20, battadvpaddingtop = 20, cappaddingright = 4},

    ls_std = {font = "FONT_XL", advfont = "FONT_STD", titlefont = "FONT_XXS", brfont = "FONT_XL", thickness = 18, batteryframethickness = 3, titlepaddingbottom = 25, valuepaddingleft = 55, valuepaddingtop = 5, gvaluepaddingtop = 20, valuepaddingbottom = 25, brvaluepaddingbottom = 15, gaugepaddingtop = 5, battadvpaddingtop = 8, cappaddingright = 5},

    ms_full = {font = "FONT_XXL", advfont = "FONT_STD", titlefont = "FONT_XXS", brfont = "FONT_L", thickness = 19, batteryframethickness = 3, titlepaddingbottom = 20, valuepaddingleft = 20, valuepaddingtop = 10, gvaluepaddingtop = 20, valuepaddingbottom = 25, brvaluepaddingbottom = 8, gaugepaddingtop = 5, battadvpaddingtop = 2, cappaddingright = 2},

    ms_std = {font = "FONT_XL", advfont = "FONT_S", titlefont = "FONT_XXS", brfont = "FONT_L", thickness = 14, batteryframethickness = 2, titlepaddingbottom = 10, valuepaddingleft = 20, valuepaddingtop = 10, gvaluepaddingtop = 20, valuepaddingbottom = 25, brvaluepaddingbottom = 8, gaugepaddingtop = 5, battadvpaddingtop = 3, cappaddingright = 3},

    ss_full = {font = "FONT_XL", advfont = "FONT_STD", titlefont = "FONT_XXS", brfont = "FONT_XL", thickness = 25, batteryframethickness = 3, titlepaddingbottom = 15, valuepaddingleft = 20, valuepaddingtop = 10, gvaluepaddingtop = 25, valuepaddingbottom = 15, brvaluepaddingbottom = 15, gaugepaddingtop = 5, battadvpaddingtop = 5, cappaddingright = 3},

    ss_std = {font = "FONT_XL", advfont = "FONT_S", titlefont = "FONT_XXS", brfont = "FONT_XL", thickness = 14, batteryframethickness = 2, titlepaddingbottom = 15, valuepaddingleft = 20, valuepaddingtop = 10, gvaluepaddingtop = 15, valuepaddingbottom = 25, brvaluepaddingbottom = 20, gaugepaddingtop = 5, battadvpaddingtop = 0, cappaddingright = 3}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local layout = {cols = 7, rows = 12}

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

        {col = 1, row = 1, colspan = 3, rowspan = 10, type = "image", subtype = "model", bgcolor = colorMode.bgcolor},
        {
            col = 1,
            row = 11,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "rate_profile",
            title = "@i18n(widgets.dashboard.rates):upper()@",
            titlepos = "bottom",
            font = opts.brfont,
            titlefont = opts.titlefont,
            valuepaddingbottom = opts.brvaluepaddingbottom,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor",
            thresholds = {{value = 1.5, textcolor = "blue"}, {value = 2.5, textcolor = colorMode.fillwarncolor}, {value = 6, textcolor = colorMode.fillcolor}}
        },
        {
            col = 2,
            row = 11,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "pid_profile",
            title = "@i18n(widgets.dashboard.profile):upper()@",
            titlepos = "bottom",
            font = opts.brfont,
            titlefont = opts.titlefont,
            valuepaddingbottom = opts.brvaluepaddingbottom,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor",
            thresholds = {{value = 1.5, textcolor = "blue"}, {value = 2.5, textcolor = colorMode.fillwarncolor}, {value = 6, textcolor = colorMode.fillcolor}}
        }, {col = 3, row = 11, rowspan = 2, type = "time", subtype = "count", title = "@i18n(widgets.dashboard.flights):upper()@", titlepos = "bottom", font = opts.brfont, titlefont = opts.titlefont, valuepaddingbottom = opts.brvaluepaddingbottom, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor}, {
            col = 4,
            row = 1,
            colspan = 4,
            rowspan = 3,
            type = "gauge",
            source = "smartfuel",
            batteryframe = true,
            battadv = true,
            battadvvaluealign = "right",
            battadvpaddingright = 25,
            gaugepaddingbottom = 3,
            gaugepaddingleft = 5,
            gaugepaddingright = 5,
            valuealign = "left",
            batteryframethickness = opts.batteryframethickness,
            font = opts.font,
            valuepaddingleft = opts.valuepaddingleft,
            valuepaddingtop = opts.valuepaddingtop,
            gaugepaddingtop = opts.gaugepaddingtop,
            battadvfont = opts.advfont,
            battadvpaddingtop = opts.battadvpaddingtop,
            cappaddingright = opts.cappaddingright,
            fillcolor = colorMode.fillcolor,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            accentcolor = colorMode.accentcolor,
            transform = "floor",
            thresholds = {{value = 10, fillcolor = colorMode.fillcritcolor}, {value = 45, fillcolor = colorMode.fillwarncolor}}
        }, {
            col = 4,
            colspan = 2,
            row = 4,
            rowspan = 7,
            type = "gauge",
            subtype = "arc",
            source = "bec_voltage",
            title = "@i18n(widgets.dashboard.bec_voltage):upper()@",
            titlepos = "bottom",
            decimals = 1,
            titlepaddingbottom = opts.titlepaddingbottom,
            valuepaddingtop = opts.gvaluepaddingtop,
            font = opts.font,
            min = getThemeValue("bec_min"),
            max = getThemeValue("bec_max"),
            thickness = opts.thickness,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            thresholds = {{value = getThemeValue("bec_warn"), fillcolor = colorMode.fillwarncolor}, {value = getThemeValue("bec_max"), fillcolor = colorMode.fillcolor}}
        }, {
            col = 4,
            row = 11,
            colspan = 2,
            rowspan = 2,
            type = "text",
            subtype = "blackbox",
            title = "@i18n(widgets.dashboard.blackbox):upper()@",
            titlepos = "bottom",
            font = opts.brfont,
            titlefont = opts.titlefont,
            valuepaddingbottom = opts.brvaluepaddingbottom,
            decimals = 0,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            transform = "floor",
            thresholds = {{value = 80, textcolor = colorMode.textcolor}, {value = 90, textcolor = colorMode.fillwarncolor}, {value = 100, textcolor = colorMode.fillcritcolor}}
        }, {
            col = 6,
            colspan = 2,
            row = 4,
            rowspan = 7,
            type = "gauge",
            subtype = "arc",
            source = "temp_esc",
            title = "@i18n(widgets.dashboard.esc_temp):upper()@",
            titlepos = "bottom",
            font = opts.font,
            min = 0,
            max = getThemeValue("esctemp_max"),
            thickness = opts.thickness,
            valuepaddingleft = 10,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            titlepaddingbottom = opts.titlepaddingbottom,
            valuepaddingtop = opts.gvaluepaddingtop,
            transform = "floor",
            thresholds = {{value = getThemeValue("esctemp_warn"), fillcolor = colorMode.fillcolor}, {value = getThemeValue("esctemp_max"), fillcolor = colorMode.fillwarncolor}, {value = 200, fillcolor = colorMode.fillcritcolor}}
        }, {
            col = 6,
            row = 11,
            colspan = 2,
            rowspan = 2,
            type = "text",
            subtype = "governor",
            title = "@i18n(widgets.dashboard.governor):upper()@",
            titlepos = "bottom",
            font = opts.brfont,
            titlefont = opts.titlefont,
            valuepaddingbottom = opts.brvaluepaddingbottom,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = "@i18n(widgets.governor.DISARMED)@", textcolor = colorMode.fillcritcolor}, {value = "@i18n(widgets.governor.OFF)@", textcolor = colorMode.fillcritcolor}, {value = "@i18n(widgets.governor.IDLE)@", textcolor = "blue"}, {value = "@i18n(widgets.governor.SPOOLUP)@", textcolor = "blue"}, {value = "@i18n(widgets.governor.RECOVERY)@", textcolor = colorMode.fillwarncolor}, {value = "@i18n(widgets.governor.ACTIVE)@", textcolor = colorMode.fillcolor},
                {value = "@i18n(widgets.governor.THR-OFF)@", textcolor = colorMode.fillcritcolor}
            }
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

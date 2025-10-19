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

    ls_full = {font = "FONT_XXL", thickness = 28, gaugepadding = 10, gaugepaddingbottom = 40, maxpaddingtop = 60, maxpaddingleft = 20, valuepaddingbottom = 25, vgaugepaddingbottom = 10, maxfont = "FONT_L", batteryspacing = 2},

    ls_std = {font = "FONT_XXL", thickness = 25, gaugepadding = 0, gaugepaddingbottom = 0, maxpaddingtop = 40, maxpaddingleft = 10, valuepaddingbottom = 0, vgaugepaddingbottom = 4, maxfont = "FONT_M", batteryspacing = 1},

    ms_full = {font = "FONT_XL", thickness = 17, gaugepadding = 5, gaugepaddingbottom = 20, maxpaddingtop = 30, maxpaddingleft = 10, valuepaddingbottom = 15, vgaugepaddingbottom = 6, maxfont = "FONT_M", batteryspacing = 1},

    ms_std = {font = "FONT_XL", thickness = 14, gaugepadding = 0, gaugepaddingbottom = 0, maxpaddingtop = 20, maxpaddingleft = 10, valuepaddingbottom = 0, vgaugepaddingbottom = 0, maxfont = "FONT_S", batteryspacing = 1},

    ss_full = {font = "FONT_XXL", thickness = 19, gaugepadding = 5, gaugepaddingbottom = 20, maxpaddingtop = 30, maxpaddingleft = 10, valuepaddingbottom = 15, vgaugepaddingbottom = 4, maxfont = "FONT_S", batteryspacing = 1},

    ss_std = {font = "FONT_XL", thickness = 18, gaugepadding = 5, gaugepaddingbottom = 0, maxpaddingtop = 30, maxpaddingleft = 10, valuepaddingbottom = 0, vgaugepaddingbottom = 3, maxfont = "FONT_S", batteryspacing = 1}
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
            rowspan = 12,
            type = "gauge",
            subtype = "arc",
            source = "rpm",
            arcmax = true,
            title = "@i18n(widgets.dashboard.headspeed):upper()@",
            titlepos = "bottom",
            min = 0,
            max = getThemeValue("rpm_max"),
            valuepaddingtop = opts.valuepaddingtop,
            gaugepadding = opts.gaugepadding,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            thickness = opts.thickness,
            unit = "",
            maxprefix = "Max: ",
            font = opts.font,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            fillbgcolor = colorMode.fillbgcolor,
            maxtextcolor = "orange",
            maxfont = opts.maxfont,
            maxpaddingtop = opts.maxpaddingtop,
            transform = "floor",
            thresholds = {{value = getThemeValue("rpm_min"), fillcolor = "lightpurple"}, {value = getThemeValue("rpm_max"), fillcolor = "purple"}, {value = 10000, fillcolor = "darkpurple"}}
        }, {col = 3, colspan = 2, row = 1, rowspan = 2, type = "time", subtype = "flight", font = opts.font, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor}, {
            col = 3,
            colspan = 2,
            row = 3,
            rowspan = 10,
            type = "gauge",
            source = "bec_voltage",
            title = "@i18n(widgets.dashboard.voltage):upper()@",
            titlepos = "bottom",
            font = "FONT_XL",
            gaugeorientation = "vertical",
            gaugepaddingright = 40,
            gaugepaddingleft = 40,
            gaugepaddingbottom = opts.vgaugepaddingbottom,
            decimals = 1,
            unit = "v",
            battery = true,
            batteryspacing = opts.batteryspacing,
            valuepaddingbottom = 17,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            min = vmin,
            max = vmax,
            thresholds = {{value = vmin + 0.2 * (vmax - vmin), fillcolor = colorMode.fillcritcolor}, {value = vmin + 0.4 * (vmax - vmin), fillcolor = colorMode.fillwarncolor}, {value = vmax, fillcolor = colorMode.fillcolor}}
        }, {
            col = 5,
            colspan = 2,
            row = 1,
            rowspan = 12,
            type = "gauge",
            subtype = "arc",
            source = "throttle_percent",
            arcmax = true,
            title = "@i18n(widgets.dashboard.throttle):upper()@",
            titlepos = "bottom",
            transform = "floor",
            thickness = opts.thickness,
            gaugepadding = opts.gaugepadding,
            gaugepaddingbottom = opts.gaugepaddingbottom,
            valuepaddingtop = opts.valuepaddingtop,
            font = opts.font,
            maxprefix = "Max: ",
            maxpaddingtop = opts.maxpaddingtop,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            fillbgcolor = colorMode.fillbgcolor,
            maxtextcolor = "orange",
            maxfont = opts.maxfont,
            thresholds = {{value = 89, fillcolor = "blue"}, {value = 100, fillcolor = "darkblue"}}
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

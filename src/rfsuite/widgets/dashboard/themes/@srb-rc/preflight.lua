--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local max = math.max
local abs = math.abs
local tonumber = tonumber

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local theme_section = "system/@srb-rc"

local THEME_DEFAULTS = {bec_warn = 6.5, esctemp_warn = 90, esctemp_max = 200}

local function getThemeValue(key)
    if key == "tx_min" or key == "tx_warn" or key == "tx_max" then
        if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
            local val = rfsuite.preferences.general[key]
            if val ~= nil then
                return tonumber(val)
            end
        end
    end
    
    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then
            return val
        end
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
    ls_full = {
        font = "FONT_XXL",
        fontl = "FONT_XL",
        fontm = "FONT_M",
        rpmtitlefont = "FONT_STD",
        titlefont = "FONT_S",
        rowbattval = 7.8,
        rowspanbattval = 3.2,
        battborder = 5,
        rpmvaluepadding = 20,
        rpmtitlepadding = 1,
        titlepaddingtop = 10,
        valuepaddingtop = 15,
        gaugevaluepadding = 30,
    },
    ls_std = {
        font = "FONT_XXL",
        fontl = "FONT_XL",
        fontm = "FONT_M",
        rpmtitlefont = "FONT_STD",
        titlefont = "FONT_S",
        rowbattval = 8,
        rowspanbattval = 3,
        battborder = 4,
        rpmvaluepadding = 10,
        rpmtitlepadding = 1,
        titlepaddingtop = 5,
        valuepaddingtop = 15,
        gaugevaluepadding = 30,
    },
    ms_full = {
        font = "FONT_XL",
        fontl = "FONT_XL",
        fontm = "FONT_M",
        rpmtitlefont = "FONT_STD",
        titlefont = "FONT_XS",
        rowbattval = 7.9,
        rowspanbattval = 3.2,
        battborder = 4,
        rpmvaluepadding = 10,
        rpmtitlepadding = 1,
        titlepaddingtop = 3,
        valuepaddingtop = 7,
        gaugevaluepadding = 20,
    },
    ms_std = {
        font = "FONT_XL",
        fontl = "FONT_L",
        fontm = "FONT_M",
        rpmtitlefont = "FONT_STD",
        titlefont = "FONT_XS",
        rowbattval = 8.2,
        rowspanbattval = 3,
        battborder = 4,
        rpmvaluepadding = 15,
        rpmtitlepadding = 1,
        titlepaddingtop = 3,
        valuepaddingtop = 7,
        gaugevaluepadding = 20,
    },
    ss_full = {
        font = "FONT_XL",
        fontl = "FONT_XL",
        fontm = "FONT_M",
        rpmtitlefont = "FONT_STD",
        titlefont = "FONT_XS",
        rowbattval = 8,
        rowspanbattval = 3,
        battborder = 4,
        rpmvaluepadding = 10,
        rpmtitlepadding = 5,
        titlepaddingtop = 5,
        valuepaddingtop = 15,
        gaugevaluepadding = 30,
    },
        ss_std = {
        font = "FONT_XL",
        fontl = "FONT_XL",
        fontm = "FONT_M",
        rpmtitlefont = "FONT_STD",
        titlefont = "FONT_XS",
        rowbattval = 8.2,
        rowspanbattval = 3,
        battborder = 4,
        rpmvaluepadding = 10,
        rpmtitlepadding = 5,
        titlepaddingtop = 5,
        valuepaddingtop = 15,
        gaugevaluepadding = 30,
    },
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local layout = {cols = 13, rows = 10, padding = 1, showstats = false}
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
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.unknown
    local rowbatt = opts.rowbattval
    local rowspanbatt = opts.rowspanbattval
    local battbpad = opts.battborder

    return {
        {
            col = 1,
            row = 1,
            colspan = 13,
            rowspan = 10,
            type = "text",
            subtype = "text",
            title = "",
            bgcolor = colorMode.panelbgline,
        },
        {
            col = 1,
            row = 1,
            colspan = 4,
            rowspan = 3,
            type = "text",
            subtype = "craftname",
            title = "CRAFT NAME",
            titlepos = "top",
            titlealign = "center",
            titlefont = opts.titlefont,
            font = opts.font,
            textcolor = "orange",
            titlecolor = colorMode.titlecolor,
            titlepaddingtop = opts.titlepaddingtop,
            bgcolor = colorMode.panelbg,
        },
        {
            col = 1,
            row = 4,
            colspan = 2,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "pid_profile",
            titlefont = opts.titlefont,
            font = opts.fontl,
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingtop = opts.valuepaddingtop,
            title = "PROFILE",
            titlepos = "top",
            transform = "floor",
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            bgcolor = colorMode.panelbg,
        },
        {
            col = 3,
            row = 4,
            colspan = 2,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "rate_profile",
            font = opts.fontl,
            titlefont = opts.titlefont,
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingtop = opts.valuepaddingtop,
            title = "RATE",
            titlepos = "top",
            transform = "floor",
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            bgcolor = colorMode.panelbg,
        },
        {
            col = 5,
            row = 1,
            colspan = 3,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "bec_voltage",
            font = opts.font,
            titlefont = opts.titlefont,
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingtop = opts.valuepaddingtop,
            title = "BEC",
            titlepos = "top",
            decimals = 1,
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            bgcolor = colorMode.paneldarkbg,
            thresholds = {{value = getThemeValue("bec_warn"), textcolor = colorMode.fillcritcolor}}

        },
        {
            col = 5,
            row = 4,
            colspan = 3,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "temp_esc",
            font = opts.font,
            titlefont = opts.titlefont,
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingtop = opts.valuepaddingtop,
            title = "ESC TEMP",
            titlepos = "top",
            textcolor = colorMode.fillcritcolor,
            titlecolor = colorMode.titlecolor,
            bgcolor = colorMode.paneldarkbg,
            thresholds = {{value = getThemeValue("esctemp_warn"), textcolor = colorMode.textcolor}}
        },
        {
            col = 8,
            row = 1,
            colspan = 3,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "link",
            font = opts.font,
            titlefont = opts.titlefont,
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingtop = opts.valuepaddingtop,
            title = "LQ",
            titlepos = "top",
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            bgcolor = colorMode.paneldarkbg,
        },
        {
            col = 8,
            row = 4,
            colspan = 3,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "current",
            font = opts.font,
            titlefont = opts.titlefont,
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingtop = opts.valuepaddingtop,
            title = "CURRENT",
            titlepos = "top",
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            bgcolor = colorMode.paneldarkbg,
        },
        {
            col = 11,
            row = 1,
            colspan = 3,
            rowspan = 3,
            type = "text",
            subtype = "telemetry",
            source = "rpm",
            title = "RPM",
            titlepos = "top",
            titlealign = "center",
            titlefont = opts.rpmtitlefont,
            titlepaddingtop = opts.rpmtitlepadding,
            valuepaddingbottom = opts.rpmvaluepadding,
            font = opts.font,
            unit = "",
            textcolor = "black",
            titlecolor = "black",
            bgcolor = colorMode.textcolor,
        },
        {
            col = 11,
            row = 4,
            colspan = 3,
            rowspan = 3,
            type = "time",
            subtype = "flight",
            font = opts.font,
            titlefont = opts.titlefont,
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingtop = opts.valuepaddingtop,
            title = "TIMER",
            titlepos = "top",
            transform = "floor",
            textcolor = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            bgcolor = colorMode.panelbg,
        },
        {
            col = 1,
            row = 7,
            colspan = 13,
            rowspan = 4,
            font = opts.font,
            title = "FLIGHT BATTERY",
            titlefont = opts.titlefont,
            titlespacing = 10,
            titlepaddingtop = opts.titlepaddingtop,
            type = "gauge",
            subtype = "bar",
            source = "smartfuel",
            valuepaddingtop = opts.gaugevaluepadding,
            battadv = false,
            battadvfont = opts.titlefont,
            valuealign = "center",
            battadvpaddingright = 320,
            battadvgap = 35,
            fillcolor = colorMode.fillcolor,
            bgcolor = colorMode.paneldarkbg,
            titlecolor = colorMode.titlecolor,
            batteryframe = false,
            textcolor = colorMode.textcolor,
            accentcolor = colorMode.accentcolor,
            transform = "floor",
            thresholds = {
                {value = 10, fillcolor = colorMode.fillcritcolor},
                {value = 45, fillcolor = colorMode.fillwarncolor},
            },
        },
        {
            col = 1,
            row = rowbatt,
            colspan = 13,
            rowspan = rowspanbatt,
            type = "func",
            subtype = "func",
            paint = function(x, y, w, h, box, cache, t)
                if lcd.darkMode() then
                    lcd.color(lcd.RGB(255, 255, 255))
                else
                    lcd.color(lcd.RGB(90, 90, 90))
                end
                lcd.drawRectangle(x, y, w, h, battbpad)
            end,
        },
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

return {
    layout = layout,
    boxes = boxes,
    header_boxes = header_boxes,
    header_layout = header_layout,
    scheduler = {
        spread_scheduling = true,
        spread_scheduling_paint = false,
        spread_ratio = 0.5,
    },
}

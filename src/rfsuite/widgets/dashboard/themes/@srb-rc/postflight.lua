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
    local cfg = rfsuite.session.batteryConfig
    local cells = (cfg and cfg.batteryCellCount) or 3

    if cfg and cells and value then
        value = max(0, value / cells)
        value = floor(value * 100 + 0.5) / 100
    end

    return value
end

local theme_section = "system/@srb-rc"

local THEME_DEFAULTS = {}

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
        titlefont = "FONT_S",
        titlepaddingtop = 20,
        valuepaddingbottom = -10,
     
    },
    ls_std = {
        font = "FONT_XXL",
        fontl = "FONT_XL",
        fontm = "FONT_M",
        titlefont = "FONT_S",
        titlepaddingtop = 5,
        valuepaddingbottom = -10,

    },
    ms_full = {
        font = "FONT_XL",
        fontl = "FONT_XL",
        fontm = "FONT_M",
        titlefont = "FONT_XS",
        titlepaddingtop = 20,
        valuepaddingbottom = -10,
    },
    ms_std = {
        font = "FONT_XL",
        fontl = "FONT_L",
        fontm = "FONT_M",
        titlefont = "FONT_XS",
        titlepaddingtop = 10,
        valuepaddingbottom = -5,
    },
    ss_full = {
        font = "FONT_XL",
        fontl = "FONT_XL",
        fontm = "FONT_M",
        titlefont = "FONT_XS",
        titlepaddingtop = 15,
        valuepaddingbottom = -10,
    },
    ss_std = {
        font = "FONT_XL",
        fontl = "FONT_XL",
        fontm = "FONT_M",
        titlefont = "FONT_XS",
        titlepaddingtop = 5,
        valuepaddingbottom = -10,
    },
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local last_txbatt_type = nil

local layout = {cols = 3, rows = 7}

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

    return {

        {
            col = 1,
            row = 1,
            rowspan = 2,
            type = "time",
            subtype = "flight",
            title = "Flight Duration",
            titlepos = "top",
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingbottom = opts.valuepaddingbottom,
            font = opts.font,
            titlefont = opts.titlefont,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.fillwarncolor,
        },
        {
            col = 1,
            row = 3,
            rowspan = 2,
            type = "text",
            subtype = "stats",
            stattype = "min",
            source = "smartfuel",
            title = "Fuel Remaining",
            titlepos = "top",
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingbottom = opts.valuepaddingbottom,
            font = opts.font,
            titlefont = opts.titlefont,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.fillwarncolor,
            transform = "floor",
        },
        {
            col = 1,
            row = 5,
            rowspan = 2,
            type = "time",
            subtype = "count",
            title = "Flights",
            titlepos = "top",
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingbottom = opts.valuepaddingbottom,
            font = opts.font,
            titlefont = opts.titlefont,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.fillwarncolor,
            transform = "floor",
        },
        {
            col = 3,
            row = 1,
            rowspan = 2,
            type = "text",
            subtype = "stats",
            stattype = "max",
            source = "smartconsumption",
            title = "Consumed mAh",
            titlepos = "top",
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingbottom = opts.valuepaddingbottom,
            font = opts.font,
            titlefont = opts.titlefont,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.fillwarncolor,
            transform = "floor",
        },
        {
            col = 3,
            row = 3,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "voltage",
            title = "Ending Voltage",
            titlepos = "top",
            decimals = 1,
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingbottom = opts.valuepaddingbottom,
            font = opts.font,
            titlefont = opts.titlefont,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.fillwarncolor,
        },
        {
            col = 3,
            row = 5,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "voltage",
            title = "Volts per cell",
            titlepos = "top",
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingbottom = opts.valuepaddingbottom,
            font = opts.font,
            titlefont = opts.titlefont,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.fillwarncolor,
            unit = "V",
            transform = function(v)
                return maxVoltageToCellVoltage(v)
            end,
        },
        {
            col = 2,
            row = 1,
            rowspan = 2,
            type = "text",
            subtype = "stats",
            source = "current",
            title = "Current (Max)",
            titlepos = "top",
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingbottom = opts.valuepaddingbottom,
            font = opts.font,
            titlefont = opts.titlefont,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.fillwarncolor,
            transform = "floor",
        },
        {
            col = 2,
            row = 3,
            rowspan = 2,
            type = "text",
            subtype = "stats",
            source = "temp_esc",
            title = "ESC Temp (Max)",
            titlepos = "top",
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingbottom = opts.valuepaddingbottom,
            font = opts.font,
            titlefont = opts.titlefont,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.fillwarncolor,
            transform = "floor",
        },
        {
            col = 2,
            row = 5,
            rowspan = 2,
            type = "text",
            subtype = "stats",
            stattype = "min",
            source = "link",
            title = "Link (Min)",
            titlepos = "top",
            titlepaddingtop = opts.titlepaddingtop,
            valuepaddingbottom = opts.valuepaddingbottom,
            font = opts.font,
            titlefont = opts.titlefont,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.fillwarncolor,
            transform = "floor",
        },
        {
            col = 1,
            row = 7,
            colspan = 3,
            rowspan = 1,
            type = "image",
            subtype = "model",
            bgcolor = colorMode.bgcolor,
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

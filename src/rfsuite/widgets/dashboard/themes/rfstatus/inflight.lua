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

local theme_section = "system/@rfstatus"

local THEME_DEFAULTS = {v_min = 18.0, v_max = 25.2}

local function getUserVoltageOverride(which)
    local prefs = rfsuite.session and rfsuite.session.modelPreferences
    if prefs and prefs["system/@default"] then
        local v = tonumber(prefs["system/@default"][which])

        if which == "v_min" and v and abs(v - 18.0) > 0.05 then return v end
        if which == "v_max" and v and abs(v - 25.2) > 0.05 then return v end
    end
    return nil
end

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

local themeOptions = {ls_full = {font = "FONT_XXL", valuepaddingtop = 35, thickness = 50}, ls_std = {font = "FONT_XXL", valuepaddingtop = 20, thickness = 28}, ms_full = {font = "FONT_XXL", valuepaddingtop = 30, thickness = 35}, ms_std = {font = "FONT_XXL", valuepaddingtop = 20, thickness = 20}, ss_full = {font = "FONT_XXL", valuepaddingtop = 25, thickness = 40}, ss_std = {font = "FONT_XXL", valuepaddingtop = 25, thickness = 24}}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local layout = {cols = 4, rows = 14, padding = 4}

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
        {
            type = "gauge",
            subtype = "arc",
            col = 1,
            row = 1,
            rowspan = 12,
            colspan = 2,
            source = "voltage",
            thickness = opts.thickness,
            font = "FONT_XXL",
            fillbgcolor = colorMode.fillbgcolor,
            valuepaddingtop = opts.valuepaddingtop,
            title = "@i18n(widgets.dashboard.voltage):upper()@",
            titlepos = "bottom",
            min = function()
                local override = getUserVoltageOverride("v_min")
                if override then return override end
                local cfg = rfsuite.session.batteryConfig
                local cells = (cfg and cfg.batteryCellCount) or 3
                local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                return max(0, cells * minV)
            end,
            max = function()
                local override = getUserVoltageOverride("v_max")
                if override then return override end
                local cfg = rfsuite.session.batteryConfig
                local cells = (cfg and cfg.batteryCellCount) or 3
                local maxV = (cfg and cfg.vbatfullcellvoltage) or 4.2
                return max(0, cells * maxV)
            end,

            thresholds = {
                {
                    value = function(box)
                        local raw_gm = utils.getParam(box, "min")
                        if type(raw_gm) == "function" then raw_gm = raw_gm(box) end
                        local raw_gM = utils.getParam(box, "max")
                        if type(raw_gM) == "function" then raw_gM = raw_gM(box) end
                        return raw_gm + 0.30 * (raw_gM - raw_gm)
                    end,
                    fillcolor = colorMode.fillcritcolor,
                    textcolor = colorMode.textcolor
                }, {
                    value = function(box)
                        local raw_gm = utils.getParam(box, "min")
                        if type(raw_gm) == "function" then raw_gm = raw_gm(box) end
                        local raw_gM = utils.getParam(box, "max")
                        if type(raw_gM) == "function" then raw_gM = raw_gM(box) end
                        return raw_gm + 0.50 * (raw_gM - raw_gm)
                    end,
                    fillcolor = colorMode.fillwarncolor,
                    textcolor = colorMode.textcolor
                }, {
                    value = function(box)
                        local raw_gM = utils.getParam(box, "max")
                        if type(raw_gM) == "function" then raw_gM = raw_gM(box) end
                        return raw_gM
                    end,
                    fillcolor = colorMode.fillcolor,
                    textcolor = colorMode.textcolor
                }
            }
        }, {
            type = "gauge",
            subtype = "arc",
            col = 3,
            row = 1,
            rowspan = 12,
            thickness = opts.thickness,
            valuepaddingtop = opts.valuepaddingtop,
            colspan = 2,
            source = "smartfuel",
            transform = "floor",
            min = 0,
            max = 100,
            font = "FONT_XXL",
            fillbgcolor = colorMode.fillbgcolor,
            title = "@i18n(widgets.dashboard.fuel):upper()@",
            titlepos = "bottom",
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,

            thresholds = {{value = 30, fillcolor = colorMode.fillcritcolor, textcolor = colorMode.textcolor}, {value = 50, fillcolor = colorMode.fillwarncolor, textcolor = colorMode.textcolor}, {value = 140, fillcolor = colorMode.fillcolor, textcolor = colorMode.textcolor}}
        }, {
            col = 1,
            row = 13,
            rowspan = 2,
            type = "text",
            subtype = "governor",
            nosource = "-",
            titlecolor = colorMode.textcolor,
            textcolor = colorMode.textcolor,
            thresholds = {
                {value = "@i18n(widgets.governor.DISARMED)@", textcolor = colorMode.fillcritcolor}, {value = "@i18n(widgets.governor.OFF)@", textcolor = colorMode.fillcritcolor}, {value = "@i18n(widgets.governor.IDLE)@", textcolor = "blue"}, {value = "@i18n(widgets.governor.SPOOLUP)@", textcolor = "blue"}, {value = "@i18n(widgets.governor.RECOVERY)@", textcolor = colorMode.fillwarncolor}, {value = "@i18n(widgets.governor.ACTIVE)@", textcolor = colorMode.fillcolor},
                {value = "@i18n(widgets.governor.THR-OFF)@", textcolor = colorMode.fillcritcolor}
            }
        }, {col = 4, row = 13, rowspan = 2, type = "time", subtype = "flight", titlecolor = colorMode.textcolor, textcolor = colorMode.textcolor}, {col = 3, row = 13, rowspan = 2, type = "text", subtype = "telemetry", source = "rpm", nosource = "-", unit = "rpm", transform = "floor", titlecolor = colorMode.textcolor, textcolor = colorMode.textcolor},
        {col = 2, row = 13, rowspan = 2, type = "text", subtype = "telemetry", source = "link", nosource = "-", unit = "dB", transform = "floor", titlecolor = colorMode.textcolor, textcolor = colorMode.textcolor}

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

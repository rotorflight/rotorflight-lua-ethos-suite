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
local maxVoltageToCellVoltage = utils.maxVoltageToCellVoltage

local theme_section = "system/gismo"

local THEME_DEFAULTS = {v_min = 18.0, v_max = 25.2}

local function getUserVoltageOverride(which)
    local prefs = rfsuite.session and rfsuite.session.modelPreferences
    if prefs and prefs[theme_section] then
        local v = tonumber(prefs[theme_section][which])
        if which == "v_min" and v and abs(v - 18.0) > 0.05 then return v end
        if which == "v_max" and v and abs(v - 25.2) > 0.05 then return v end
    end
    return nil
end

local function getThemeOptionKey(W)
    return utils.getDashboardThemeOptionKey(W)
end

local themeOptions = {
    ls_full = {font = "FONT_XXL", fontl = "FONT_XL",  titlefont = "FONT_S",   valuepaddingtop = 12, titlepaddingtop = 5},
    ls_std  = {font = "FONT_XL",  fontl = "FONT_L",   titlefont = "FONT_XS",  valuepaddingtop = 8,  titlepaddingtop = 3},
    ms_full = {font = "FONT_XL",  fontl = "FONT_L",   titlefont = "FONT_XS",  valuepaddingtop = 6,  titlepaddingtop = 3},
    ms_std  = {font = "FONT_L",   fontl = "FONT_M",   titlefont = "FONT_XS",  valuepaddingtop = 5,  titlepaddingtop = 2},
    ss_full = {font = "FONT_XL",  fontl = "FONT_L",   titlefont = "FONT_XS",  valuepaddingtop = 5,  titlepaddingtop = 3},
    ss_std  = {font = "FONT_L",   fontl = "FONT_M",   titlefont = "FONT_XS",  valuepaddingtop = 3,  titlepaddingtop = 2},
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

-- 3-panel layout: left list | centre battery | right info
local layout = {cols = 20, rows = 10, padding = 2, showstats = false}

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
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ms_std

    -- Dynamic cell count title for cell voltage
    local function cellVoltageTitle()
        local cells = select(1, utils.getBatteryVoltageBounds(3, 3.0, 4.2))
        if cells and cells > 0 then return string.format("CELL VOLTAGE (%dS)", cells) end
        return "CELL VOLTAGE"
    end

    return {

        -- ── LEFT PANEL (cols 1-7): 5 telemetry rows, 2 rows each ──

        {col = 1, row = 1,  colspan = 7, rowspan = 2, type = "text", subtype = "telemetry", source = "voltage",
         title = cellVoltageTitle, titlepos = "top", titlealign = "left", valuealign = "right",
         font = opts.font, titlefont = opts.titlefont, decimals = 2, unit = "V",
         titlepaddingtop = opts.titlepaddingtop, valuepaddingtop = opts.valuepaddingtop,
         transform = function(v) return maxVoltageToCellVoltage(v) end,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.panelbg},

        {col = 1, row = 3,  colspan = 7, rowspan = 2, type = "text", subtype = "telemetry", source = "rpm",
         title = "HEADSPEED", titlepos = "top", titlealign = "left", valuealign = "right",
         font = opts.font, titlefont = opts.titlefont, unit = "", transform = "floor",
         titlepaddingtop = opts.titlepaddingtop, valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.paneldarkbg},

        {col = 1, row = 5,  colspan = 7, rowspan = 2, type = "text", subtype = "telemetry", source = "current",
         title = "CURRENT", titlepos = "top", titlealign = "left", valuealign = "right",
         font = opts.font, titlefont = opts.titlefont, decimals = 1, unit = "A",
         titlepaddingtop = opts.titlepaddingtop, valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.panelbg},

        {col = 1, row = 7,  colspan = 7, rowspan = 2, type = "text", subtype = "telemetry", source = "voltage",
         title = "BATTERY VOLTAGE", titlepos = "top", titlealign = "left", valuealign = "right",
         font = opts.font, titlefont = opts.titlefont, decimals = 2, unit = "V",
         titlepaddingtop = opts.titlepaddingtop, valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.paneldarkbg},

        {col = 1, row = 9,  colspan = 7, rowspan = 2, type = "text", subtype = "telemetry", source = "bec_voltage",
         title = "BEC VOLTAGE", titlepos = "top", titlealign = "left", valuealign = "right",
         font = opts.font, titlefont = opts.titlefont, decimals = 2, unit = "V",
         titlepaddingtop = opts.titlepaddingtop, valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.panelbg},

        -- ── CENTRE PANEL (cols 8-13): vertical battery gauge ──

        {col = 8, row = 1, colspan = 6, rowspan = 10, type = "gauge", subtype = "bar",
         source = "smartfuel", transform = "floor", min = 0, max = 100, unit = "%",
         gaugeorientation = "vertical", batteryframe = true,
         font = opts.fontl,
         bgcolor = colorMode.bgcolor, fillbgcolor = colorMode.fillbgcolor,
         fillcolor = colorMode.fillcolor, accentcolor = colorMode.accentcolor,
         textcolor = colorMode.textcolor,
         title = function() return utils.isElectricEngine() and "BATTERY" or "FUEL" end,
         titlepos = "bottom", titlecolor = colorMode.titlecolor,
         thresholds = {
             {value = 30, fillcolor = colorMode.fillcritcolor, textcolor = colorMode.textcolor},
             {value = 50, fillcolor = colorMode.fillwarncolor, textcolor = colorMode.textcolor},
         }},

        -- ── RIGHT PANEL (cols 14-20): timer + 2×2 stats ──

        -- Flight timer (rows 1-4, full width)
        {col = 14, row = 1, colspan = 7, rowspan = 4, type = "time", subtype = "flight",
         title = "TIMER", titlepos = "top", titlealign = "center",
         font = opts.fontl, titlefont = opts.titlefont,
         titlepaddingtop = opts.titlepaddingtop, valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.panelbg},

        -- Profile (rows 5-7, left half)
        {col = 14, row = 5, colspan = 3, rowspan = 3, type = "text", subtype = "telemetry", source = "pid_profile",
         title = "PROFILE", titlepos = "top", titlealign = "center", valuealign = "center",
         font = opts.fontl, titlefont = opts.titlefont, transform = "floor",
         titlepaddingtop = opts.titlepaddingtop, valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.paneldarkbg},

        -- Governor State (rows 5-7, right half)
        {col = 17, row = 5, colspan = 4, rowspan = 3, type = "text", subtype = "governor",
         title = "GOVERNOR STATE", titlepos = "top", titlealign = "center", valuealign = "center",
         font = opts.titlefont, titlefont = opts.titlefont,
         titlepaddingtop = opts.titlepaddingtop, valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.paneldarkbg,
         thresholds = {
             {value = "@i18n(widgets.governor.DISARMED)@", textcolor = colorMode.fillcritcolor},
             {value = "@i18n(widgets.governor.OFF)@",      textcolor = colorMode.fillcritcolor},
             {value = "@i18n(widgets.governor.IDLE)@",     textcolor = "blue"},
             {value = "@i18n(widgets.governor.SPOOLUP)@",  textcolor = "blue"},
             {value = "@i18n(widgets.governor.RECOVERY)@", textcolor = colorMode.fillwarncolor},
             {value = "@i18n(widgets.governor.ACTIVE)@",   textcolor = colorMode.fillcolor},
             {value = "@i18n(widgets.governor.THR-OFF)@",  textcolor = colorMode.fillcritcolor},
         }},

        -- Rate (rows 8-10, left half)
        {col = 14, row = 8, colspan = 3, rowspan = 3, type = "text", subtype = "telemetry", source = "rate_profile",
         title = "RATE", titlepos = "top", titlealign = "center", valuealign = "center",
         font = opts.fontl, titlefont = opts.titlefont, transform = "floor",
         titlepaddingtop = opts.titlepaddingtop, valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.panelbg},

        -- Flight count (rows 8-10, right half)
        {col = 17, row = 8, colspan = 4, rowspan = 3, type = "text", subtype = "blackbox",
         title = "BLACKBOX", titlepos = "top", titlealign = "center", valuealign = "center",
         font = opts.titlefont, titlefont = opts.titlefont, decimals = 0,
         titlepaddingtop = opts.titlepaddingtop, valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.panelbg},
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

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

local theme_section = "system/@gismo"

local function getThemeOptionKey(W)
    return utils.getDashboardThemeOptionKey(W)
end

local themeOptions = {
    ls_full = {font = "FONT_XXL", titlefont = "FONT_S",  valuepaddingtop = 20, gaugepadding = 10, thickness = 50},
    ls_std  = {font = "FONT_XXL", titlefont = "FONT_XS", valuepaddingtop = 15, gaugepadding = 10, thickness = 30},
    ms_full = {font = "FONT_XL",  titlefont = "FONT_XS", valuepaddingtop = 15, gaugepadding = 5,  thickness = 35},
    ms_std  = {font = "FONT_XL",  titlefont = "FONT_XS", valuepaddingtop = 10, gaugepadding = 5,  thickness = 20},
    ss_full = {font = "FONT_XL",  titlefont = "FONT_XS", valuepaddingtop = 15, gaugepadding = 5,  thickness = 35},
    ss_std  = {font = "FONT_XL",  titlefont = "FONT_XS", valuepaddingtop = 10, gaugepadding = 5,  thickness = 25},
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

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

    local function cellVoltageTitle()
        local cells = select(1, utils.getBatteryVoltageBounds(3, 3.0, 4.2))
        if cells and cells > 0 then return string.format("CELL VOLTAGE (%dS)", cells) end
        return "CELL VOLTAGE"
    end

    return {

        -- ── LEFT: big headspeed, cell voltage below ──

        {col = 1, row = 1, colspan = 7, rowspan = 7, type = "text", subtype = "telemetry", source = "rpm",
         title = "HEADSPEED", titlepos = "bottom", titlealign = "center",
         font = opts.font, titlefont = opts.titlefont, unit = "", transform = "floor",
         valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.panelbg},

        {col = 1, row = 8, colspan = 7, rowspan = 3, type = "text", subtype = "telemetry", source = "voltage",
         title = cellVoltageTitle, titlepos = "bottom", titlealign = "center",
         font = opts.font, titlefont = opts.titlefont, decimals = 2, unit = "V",
         transform = function(v) return maxVoltageToCellVoltage(v) end,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.paneldarkbg},

        -- ── CENTRE: vertical battery / fuel gauge ──

        {col = 8, row = 1, colspan = 6, rowspan = 10, type = "gauge", subtype = "bar",
         source = "smartfuel", transform = "floor", min = 0, max = 100, unit = "%",
         gaugeorientation = "vertical", batteryframe = true,
         font = opts.font,
         bgcolor = colorMode.bgcolor, fillbgcolor = colorMode.fillbgcolor,
         fillcolor = colorMode.fillcolor, accentcolor = colorMode.accentcolor,
         textcolor = colorMode.textcolor,
         title = function() return utils.isElectricEngine() and "BATTERY" or "FUEL" end,
         titlepos = "bottom", titlecolor = colorMode.titlecolor,
         thresholds = {
             {value = 30, fillcolor = colorMode.fillcritcolor, textcolor = colorMode.textcolor},
             {value = 50, fillcolor = colorMode.fillwarncolor, textcolor = colorMode.textcolor},
         }},

        -- ── RIGHT: big flight timer, voltage below ──

        {col = 14, row = 1, colspan = 7, rowspan = 7, type = "time", subtype = "flight",
         title = "TIMER", titlepos = "bottom", titlealign = "center",
         font = opts.font, titlefont = opts.titlefont,
         valuepaddingtop = opts.valuepaddingtop,
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.panelbg},

        {col = 14, row = 8, colspan = 7, rowspan = 3, type = "text", subtype = "telemetry", source = "voltage",
         title = "BATTERY VOLTAGE", titlepos = "bottom", titlealign = "center",
         font = opts.font, titlefont = opts.titlefont, decimals = 2, unit = "V",
         textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, bgcolor = colorMode.paneldarkbg},
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

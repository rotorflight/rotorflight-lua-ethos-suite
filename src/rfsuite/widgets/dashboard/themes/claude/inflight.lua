--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html

  claude — inflight layout
  Voltage arc | headspeed rainbow dial (centrepiece) | fuel ring + timer + governor
]] --

local rfsuite = require("rfsuite")
local lcd     = lcd

local max      = math.max
local tonumber = tonumber

local utils      = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
local colorMode  = utils.themeColors()

local theme_section  = "system/claude"
local THEME_DEFAULTS = {rpm_max = 3000, v_min = 0, v_max = 0}

local function getThemeValue(key)
    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local v = tonumber(rfsuite.session.modelPreferences[theme_section][key])
        if v ~= nil and v > 0 then return v end
    end
    return THEME_DEFAULTS[key]
end

local function getThemeOptionKey(W)
    return utils.getDashboardThemeOptionKey(W)
end

local themeOptions = {
    ls_full = {font = "FONT_XXL", fontl = "FONT_XL", fonts = "FONT_L",  titlefont = "FONT_S",  valuepaddingtop = 20, thickness = 40, gaugepadding = 15},
    ls_std  = {font = "FONT_XXL", fontl = "FONT_XL", fonts = "FONT_L",  titlefont = "FONT_XS", valuepaddingtop = 15, thickness = 30, gaugepadding = 10},
    ms_full = {font = "FONT_XL",  fontl = "FONT_L",  fonts = "FONT_M",  titlefont = "FONT_XS", valuepaddingtop = 15, thickness = 25, gaugepadding = 10},
    ms_std  = {font = "FONT_XL",  fontl = "FONT_L",  fonts = "FONT_M",  titlefont = "FONT_XS", valuepaddingtop = 10, thickness = 20, gaugepadding = 8},
    ss_full = {font = "FONT_XL",  fontl = "FONT_L",  fonts = "FONT_M",  titlefont = "FONT_XS", valuepaddingtop = 10, thickness = 20, gaugepadding = 8},
    ss_std  = {font = "FONT_L",   fontl = "FONT_M",  fonts = "FONT_S",  titlefont = "FONT_XS", valuepaddingtop = 8,  thickness = 16, gaugepadding = 5},
}

local lastScreenW        = nil
local boxes_cache        = nil
local header_boxes_cache = nil
local themeconfig        = nil
local last_txbatt_type   = nil

-- Grid: 20 cols × 10 rows
--   Left  (1-5):   voltage arc, full height
--   Centre (6-14): fuel ring (ringbatt), full height — the centrepiece
--   Right (15-20): headspeed rainbow dial (rows 1-6) + timer (7-8) + governor (9-10)
local layout = {cols = 20, rows = 10, padding = 2, showstats = false}

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
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ms_std

    local function vmin()
        local ov = getThemeValue("v_min")
        if ov > 0 then return ov end
        local cells, minV = utils.getBatteryVoltageBounds(3, 3.0, 4.2)
        return max(0, cells * minV)
    end
    local function vmax()
        local ov = getThemeValue("v_max")
        if ov > 0 then return ov end
        local cells, _, maxV = utils.getBatteryVoltageBounds(3, 3.0, 4.2)
        return max(0, cells * maxV)
    end

    local function vthr_crit(box) return vmin() + (vmax() - vmin()) * 0.15 end
    local function vthr_warn(box) return vmin() + (vmax() - vmin()) * 0.35 end

    return {

        -- ── LEFT: Voltage arc ─────────────────────────────────────────
        {
            col = 1, row = 1, colspan = 5, rowspan = 10,
            type = "gauge", subtype = "arc",
            source = "voltage",
            title = "VOLTAGE", titlepos = "bottom", titlealign = "center",
            font = opts.fonts, titlefont = opts.titlefont,
            decimals = 2, unit = "V",
            thickness = opts.thickness,
            gaugepadding = opts.gaugepadding,
            valuepaddingtop = opts.valuepaddingtop,
            min = vmin, max = vmax,
            bgcolor     = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            fillcolor   = colorMode.fillcolor,
            textcolor   = colorMode.textcolor,
            titlecolor  = colorMode.titlecolor,
            thresholds  = {
                {value = vthr_crit, fillcolor = colorMode.fillcritcolor, textcolor = colorMode.textcolor},
                {value = vthr_warn, fillcolor = colorMode.fillwarncolor, textcolor = colorMode.textcolor},
            },
        },

        -- ── CENTRE: SmartFuel ring (ringbatt mode) ───────────────────
        -- 360° fill ring — the dominant centrepiece. mAh subtext confirms consumption.
        {
            col = 6, row = 1, colspan = 9, rowspan = 10,
            type = "gauge", subtype = "ring",
            source = "smartfuel",
            ringbatt = true,
            transform = "floor", unit = "%",
            font = opts.font, titlefont = opts.titlefont,
            title = function() return utils.isElectricEngine() and "BATTERY" or "FUEL" end,
            titlepos = "bottom", titlealign = "center", titlecolor = colorMode.titlecolor,
            bgcolor        = colorMode.bgcolor,
            fillbgcolor    = colorMode.fillbgcolor,
            fillcolor      = colorMode.fillcolor,
            innerringcolor = colorMode.accentcolor,
            textcolor      = colorMode.textcolor,
            thresholds = {
                {value = 25, fillcolor = colorMode.fillcritcolor, textcolor = colorMode.textcolor},
                {value = 45, fillcolor = colorMode.fillwarncolor, textcolor = colorMode.textcolor},
            },
        },

        -- ── RIGHT TOP: Headspeed rainbow dial ────────────────────────
        -- Three-band arc: muted idle / fill cruise / crit overspeed.
        -- Band labels suppressed (spaces) — colours tell the story.
        {
            col = 15, row = 1, colspan = 6, rowspan = 6,
            type = "dial", subtype = "rainbow",
            source = "rpm",
            title = "HEADSPEED",
            font = opts.fontl, titlefont = opts.titlefont,
            unit = "", transform = "floor",
            min = 0, max = getThemeValue("rpm_max"),
            bandlabels = {" ", " ", " "},
            bandcolors = {"lightgrey", colorMode.fillcolor, colorMode.fillcritcolor},
            accentcolor = colorMode.accentcolor,
            valuepaddingtop = opts.valuepaddingtop,
            bgcolor     = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            textcolor   = colorMode.textcolor,
            titlecolor  = colorMode.titlecolor,
        },

        -- ── RIGHT MID: Flight timer ────────────────────────────────────
        {
            col = 15, row = 7, colspan = 6, rowspan = 2,
            type = "time", subtype = "flight",
            title = "TIMER", titlepos = "top", titlealign = "center",
            font = opts.fontl, titlefont = opts.titlefont,
            valuepaddingtop = 0,
            textcolor  = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            bgcolor    = colorMode.panelbg,
        },

        -- ── RIGHT BOTTOM: Governor state ───────────────────────────────
        {
            col = 15, row = 9, colspan = 6, rowspan = 2,
            type = "text", subtype = "governor",
            title = "GOVERNOR", titlepos = "top", titlealign = "center",
            valuealign = "center",
            font = opts.titlefont, titlefont = opts.titlefont,
            textcolor  = colorMode.textcolor,
            titlecolor = colorMode.titlecolor,
            bgcolor    = colorMode.paneldarkbg,
            thresholds = {
                {value = "@i18n(widgets.governor.DISARMED)@", textcolor = colorMode.fillcritcolor},
                {value = "@i18n(widgets.governor.OFF)@",      textcolor = colorMode.fillcritcolor},
                {value = "@i18n(widgets.governor.IDLE)@",     textcolor = "lightblue"},
                {value = "@i18n(widgets.governor.SPOOLUP)@",  textcolor = "lightblue"},
                {value = "@i18n(widgets.governor.RECOVERY)@", textcolor = colorMode.fillwarncolor},
                {value = "@i18n(widgets.governor.ACTIVE)@",   textcolor = colorMode.fillcolor},
                {value = "@i18n(widgets.governor.THR-OFF)@",  textcolor = colorMode.fillcritcolor},
            },
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
    layout        = layout,
    boxes         = boxes,
    header_boxes  = header_boxes,
    header_layout = header_layout,
    scheduler     = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.8},
}

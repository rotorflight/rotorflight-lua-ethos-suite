--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html

  kse4 — layouts for all three phases.
  An information-dense tile dashboard after Kyle Stacy's KSE4 widget
  (github.com/kylestacy2/KSE-Dashboards). Every colour comes from the Ethos
  theme (utils.themeColors()), so KSE's own palettes are picked by changing
  the radio theme rather than by this script.

  Grid: 16 cols x 12 rows
  Preflight
    model (1-4, 1-5)     | headspeed (5-12, 1-5)               | timer (13-16, 1-5)
    flights (1-4, 6-8)   | current | voltage | BEC V | ESC temp (5-16, 6-8)
    governor (1-4, 9-12) | fuel bar (5-16, 9-12)
  Inflight
    headspeed (1-8, 1-5)  | timer (9-16, 1-5)
    current | cell V | ESC temp | throttle (rows 6-8)
    governor (1-4, 9-12) | fuel bar (5-16, 9-12)
  Postflight
    flight time (1-6, 1-4) | consumed (7-11) | fuel left (12-16)
    rpm max | current max | watts max | throttle max (rows 5-8)
    ESC max | cell V min  | BEC V min | link min     (rows 9-12)
]] --

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")

local utils = rfsuite.widgets.dashboard.utils
local maxVoltageToCellVoltage = utils.maxVoltageToCellVoltage
local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local common = {}

common.layout = {cols = 16, rows = 12, padding = 4, showstats = false}
common.headerLayout = utils.standardHeaderLayout(headeropts)

-- No configurable values; the phase files still key their cache on this.
function common.prefsVersion() return 0 end

local themeOptions = {
    ls_full = {hero = "FONT_XXL", font = "FONT_XL", sfont = "FONT_L",   cfont = "FONT_L",   titlefont = "FONT_XS",  radius = 6, barpad = 10},
    ls_std  = {hero = "FONT_XXL", font = "FONT_L",  sfont = "FONT_M",   cfont = "FONT_STD", titlefont = "FONT_XS",  radius = 6, barpad = 8},
    ss_full = {hero = "FONT_XL",  font = "FONT_L",  sfont = "FONT_M",   cfont = "FONT_STD", titlefont = "FONT_XS",  radius = 5, barpad = 8},
    ss_std  = {hero = "FONT_XL",  font = "FONT_M",  sfont = "FONT_STD", cfont = "FONT_S",   titlefont = "FONT_XXS", radius = 5, barpad = 6},
    ms_full = {hero = "FONT_XL",  font = "FONT_M",  sfont = "FONT_STD", cfont = "FONT_S",   titlefont = "FONT_XXS", radius = 4, barpad = 6},
    ms_std  = {hero = "FONT_XL",  font = "FONT_M",  sfont = "FONT_STD", cfont = "FONT_S",   titlefont = "FONT_XXS", radius = 4, barpad = 5},
}

local header_boxes_cache = nil
local last_txbatt_type = nil

function common.headerBoxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end
    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        header_boxes_cache = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function cellVoltage(v) return maxVoltageToCellVoltage(v) end

local function fuelTitle()
    return utils.isElectricEngine() and "@i18n(widgets.dashboard.battery):upper()@" or "@i18n(widgets.dashboard.fuel):upper()@"
end

local GOVERNOR_THRESHOLDS = {
    {value = "@i18n(widgets.governor.DISARMED)@", textcolor = colorMode.fillcritcolor},
    {value = "@i18n(widgets.governor.OFF)@",      textcolor = colorMode.fillcritcolor},
    {value = "@i18n(widgets.governor.IDLE)@",     textcolor = colorMode.accentcolor},
    {value = "@i18n(widgets.governor.SPOOLUP)@",  textcolor = colorMode.accentcolor},
    {value = "@i18n(widgets.governor.RECOVERY)@", textcolor = colorMode.fillwarncolor},
    {value = "@i18n(widgets.governor.ACTIVE)@",   textcolor = colorMode.fillcolor},
    {value = "@i18n(widgets.governor.THROFF)@",   textcolor = colorMode.fillcritcolor},
}

local FUEL_THRESHOLDS = {
    {value = 25, fillcolor = colorMode.fillcritcolor, textcolor = colorMode.fillcritcolor},
    {value = 45, fillcolor = colorMode.fillwarncolor, textcolor = colorMode.fillwarncolor},
}

-- phase: "preflight" | "inflight" | "postflight"
function common.buildBoxes(W, phase)
    local opts = themeOptions[utils.getDashboardThemeOptionKey(W)] or themeOptions.ls_full

    -- KSE tile: theme panel fill with a hairline border in the gauge-track tone.
    local panel = {fillcolor = colorMode.panelbg, bordercolor = colorMode.fillbgcolor, borderwidth = 1, roundradius = opts.radius}

    -- Shared look for every tile: small title top-left, value below.
    local function tile(box)
        box.bgcolor = box.bgcolor or panel
        box.titlepos = box.titlepos or "top"
        box.titlealign = box.titlealign or "left"
        box.titlepaddingleft = box.titlepaddingleft or 6
        box.titlepaddingtop = box.titlepaddingtop or 4
        box.titlefont = box.titlefont or opts.titlefont
        box.titlecolor = box.titlecolor or colorMode.titlecolor
        box.textcolor = box.textcolor or colorMode.textcolor
        box.font = box.font or opts.font
        box.valuealign = box.valuealign or "center"
        return box
    end

    local function at(col, row, colspan, rowspan, box)
        box.col, box.row, box.colspan, box.rowspan = col, row, colspan, rowspan
        return tile(box)
    end

    local function live(col, row, colspan, rowspan, box)
        box.type, box.subtype = "text", "telemetry"
        return at(col, row, colspan, rowspan, box)
    end

    local function stat(col, row, colspan, rowspan, stattype, box)
        box.type, box.subtype, box.stattype = "text", "stats", stattype
        return at(col, row, colspan, rowspan, box)
    end

    local function governor(col, row, colspan, rowspan)
        return at(col, row, colspan, rowspan, {
            type = "text", subtype = "governor",
            title = "@i18n(widgets.dashboard.governor):upper()@",
            font = opts.sfont, thresholds = GOVERNOR_THRESHOLDS,
        })
    end

    local function fuelBar(col, row, colspan, rowspan)
        return at(col, row, colspan, rowspan, {
            type = "gauge", subtype = "bar",
            source = "smartfuel", unit = "%", transform = "floor", min = 0, max = 100,
            title = fuelTitle,
            roundradius = opts.radius,
            gaugepaddingleft = opts.barpad, gaugepaddingright = opts.barpad,
            gaugepaddingtop = 2, gaugepaddingbottom = opts.barpad,
            fillbgcolor = colorMode.fillbgcolor,
            fillcolor = colorMode.fillcolor,
            thresholds = FUEL_THRESHOLDS,
        })
    end

    local function timer(col, row, colspan, rowspan, title, font)
        return at(col, row, colspan, rowspan, {
            type = "time", subtype = "flight",
            title = title, font = font,
        })
    end

    if phase == "inflight" then
        return {
            live(1, 1, 8, 5, {
                source = "rpm", unit = "", transform = "floor",
                title = "@i18n(widgets.dashboard.headspeed):upper()@",
                font = opts.hero,
            }),
            timer(9, 1, 8, 5, "@i18n(widgets.dashboard.timer):upper()@", opts.hero),

            live(1, 6, 4, 3, {source = "current", unit = "A", transform = "floor", title = "@i18n(widgets.dashboard.current):upper()@"}),
            live(5, 6, 4, 3, {source = "voltage", unit = "V", decimals = 2, transform = cellVoltage, title = "@i18n(widgets.dashboard.volts_per_cell):upper()@"}),
            live(9, 6, 4, 3, {source = "temp_esc", transform = "floor", title = "@i18n(widgets.dashboard.esc_temp):upper()@"}),
            live(13, 6, 4, 3, {source = "throttle_percent", unit = "%", transform = "floor", title = "@i18n(widgets.dashboard.throttle):upper()@"}),

            governor(1, 9, 4, 4),
            fuelBar(5, 9, 12, 4),
        }
    end

    if phase == "postflight" then
        return {
            timer(1, 1, 6, 4, "@i18n(widgets.dashboard.flight_duration):upper()@", opts.font),
            stat(7, 1, 5, 4, "max", {source = "smartconsumption", unit = "", transform = "floor", title = "@i18n(widgets.dashboard.consumed_mah):upper()@"}),
            stat(12, 1, 5, 4, "min", {source = "smartfuel", unit = "%", transform = "floor", title = "@i18n(widgets.dashboard.fuel_remaining):upper()@", thresholds = FUEL_THRESHOLDS}),

            stat(1, 5, 4, 4, "max", {source = "rpm", unit = "", transform = "floor", title = "@i18n(widgets.dashboard.rpm_max):upper()@", font = opts.sfont}),
            stat(5, 5, 4, 4, "max", {source = "current", unit = "A", transform = "floor", title = "@i18n(widgets.dashboard.current_max):upper()@", font = opts.sfont}),
            at(9, 5, 4, 4, {type = "text", subtype = "watts", source = "max", unit = "W", transform = "floor", title = "@i18n(widgets.dashboard.watts_max):upper()@", font = opts.sfont}),
            stat(13, 5, 4, 4, "max", {source = "throttle_percent", unit = "%", transform = "floor", title = "@i18n(widgets.dashboard.throttle_max):upper()@", font = opts.sfont}),

            stat(1, 9, 4, 4, "max", {source = "temp_esc", transform = "floor", title = "@i18n(widgets.dashboard.esc_max_temp):upper()@", font = opts.sfont}),
            stat(5, 9, 4, 4, "min", {source = "voltage", unit = "V", decimals = 2, transform = cellVoltage, title = "@i18n(widgets.dashboard.volts_per_cell):upper()@", font = opts.sfont}),
            stat(9, 9, 4, 4, "min", {source = "bec_voltage", unit = "V", decimals = 1, title = "@i18n(widgets.dashboard.bec_voltage):upper()@", font = opts.sfont}),
            stat(13, 9, 4, 4, "min", {source = "link", unit = "dB", transform = "floor", title = "@i18n(widgets.dashboard.link_min):upper()@", font = opts.sfont}),
        }
    end

    -- preflight
    return {
        {col = 1, row = 1, colspan = 4, rowspan = 5, type = "image", subtype = "model", bgcolor = panel},
        at(1, 6, 4, 3, {type = "time", subtype = "count", title = "@i18n(widgets.dashboard.flights):upper()@", font = opts.cfont}),

        live(5, 1, 8, 5, {
            source = "rpm", unit = "", transform = "floor",
            title = "@i18n(widgets.dashboard.headspeed):upper()@",
            font = opts.hero, valuealign = "left", valuepaddingleft = 10,
        }),
        timer(13, 1, 4, 5, "@i18n(widgets.dashboard.timer):upper()@", opts.font),

        live(5, 6, 3, 3, {source = "current", unit = "", transform = "floor", title = "@i18n(widgets.dashboard.current):upper()@"}),
        live(8, 6, 3, 3, {source = "voltage", unit = "", decimals = 1, title = "@i18n(widgets.dashboard.voltage):upper()@"}),
        live(11, 6, 3, 3, {source = "bec_voltage", unit = "", decimals = 1, title = "@i18n(widgets.dashboard.bec_voltage):upper()@"}),
        live(14, 6, 3, 3, {source = "temp_esc", unit = "", transform = "floor", title = "@i18n(widgets.dashboard.esc_temp):upper()@"}),

        governor(1, 9, 4, 4),
        fuelBar(5, 9, 12, 4),
    }
end

return common

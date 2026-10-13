--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html

  kse5 — layouts for all three phases.
  A ring dashboard after Kyle Stacy's KSE5 widget
  (github.com/kylestacy2/KSE-Dashboards). Every colour comes from the Ethos
  theme (utils.themeColors()), so KSE's own palettes are picked by changing
  the radio theme rather than by this script.

  Grid: 16 cols x 14 rows
  Preflight
    fuel ring | headspeed ring | current ring | ESC temp ring    (rows 1-8)
    model (1-8, 9-12)    | governor (9-12) | BEC V (13-16)      (rows 9-11)
    flights (1-8, 13-14) | cell V (9-12)   | used mAh (13-16)   (rows 12-14)
  Inflight
    fuel ring (1-6, 1-10) | headspeed ring (7-11, 1-6) | ESC temp ring (12-16, 1-6)
                          | timer (7-11, 7-10)         | governor (12-16, 7-10)
    current | cell V | BEC V | throttle                         (rows 11-14)
  Postflight
    fuel min | rpm max | current max | ESC max rings            (rows 1-8)
    flight time (1-8, 9-11) | cell V min (9-12) | BEC V min (13-16)
    consumed (1-8, 12-14)   | watts max (9-12) | link min (13-16)
]] --

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")

local pairs = pairs
local tonumber = tonumber

local utils = rfsuite.widgets.dashboard.utils
local maxVoltageToCellVoltage = utils.maxVoltageToCellVoltage
local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local common = {}

common.layout = {cols = 16, rows = 14, padding = 4, showstats = false}
common.headerLayout = utils.standardHeaderLayout(headeropts)

-- Keep in step with configure.lua.
common.DEFAULTS = {rpm_max = 3000, current_max = 150, temp_max = 100}

local function pref(key)
    local v = tonumber(rfsuite.widgets.dashboard.getPreference(key))
    if v ~= nil and v > 0 then return v end
    return common.DEFAULTS[key]
end

-- 1 when the pilot shows temperatures in Fahrenheit. temp_esc readings
-- arrive already converted, so the ring's Celsius max must follow.
local function fahrenheit()
    local general = rfsuite.preferences and rfsuite.preferences.general
    return tonumber(general and general.temperature_unit) == 1 and 1 or 0
end

-- Bumps whenever a configured max or the temperature unit changes, so the
-- phase files rebuild their cached boxes only then.
local seenRpm, seenCurrent, seenTemp, seenUnit
local prefsVersion = 0

function common.prefsVersion()
    local rpm, current, temp, unit = pref("rpm_max"), pref("current_max"), pref("temp_max"), fahrenheit()
    if rpm ~= seenRpm or current ~= seenCurrent or temp ~= seenTemp or unit ~= seenUnit then
        seenRpm, seenCurrent, seenTemp, seenUnit = rpm, current, temp, unit
        prefsVersion = prefsVersion + 1
    end
    return prefsVersion
end

local themeOptions = {
    ls_full = {bigring = "FONT_XXL", ring = "FONT_XL",  font = "FONT_XL",  sfont = "FONT_L",   titlefont = "FONT_XS",  bigthickness = 18, thickness = 12, radius = 6},
    ls_std  = {bigring = "FONT_XL",  ring = "FONT_L",   font = "FONT_L",   sfont = "FONT_STD", titlefont = "FONT_XS",  bigthickness = 14, thickness = 9,  radius = 6},
    ss_full = {bigring = "FONT_XL",  ring = "FONT_L",   font = "FONT_L",   sfont = "FONT_STD", titlefont = "FONT_XS",  bigthickness = 14, thickness = 10, radius = 5},
    ss_std  = {bigring = "FONT_L",   ring = "FONT_STD", font = "FONT_M",   sfont = "FONT_S",   titlefont = "FONT_XXS", bigthickness = 12, thickness = 8,  radius = 5},
    ms_full = {bigring = "FONT_L",   ring = "FONT_STD", font = "FONT_M",   sfont = "FONT_S",   titlefont = "FONT_XXS", bigthickness = 10, thickness = 6,  radius = 4},
    ms_std  = {bigring = "FONT_L",   ring = "FONT_STD", font = "FONT_M",   sfont = "FONT_S",   titlefont = "FONT_XXS", bigthickness = 10, thickness = 6,  radius = 4},
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
    {value = 25, fillcolor = colorMode.fillcritcolor},
    {value = 45, fillcolor = colorMode.fillwarncolor},
}

-- phase: "preflight" | "inflight" | "postflight"
function common.buildBoxes(W, phase)
    local opts = themeOptions[utils.getDashboardThemeOptionKey(W)] or themeOptions.ls_full

    local rpmMax = pref("rpm_max")
    local currentMax = pref("current_max")
    local tempMax = pref("temp_max")
    if fahrenheit() == 1 then tempMax = tempMax * 1.8 + 32 end

    -- KSE tile: theme panel fill with a hairline border in the gauge-track tone.
    local panel = {fillcolor = colorMode.panelbg, bordercolor = colorMode.fillbgcolor, borderwidth = 1, roundradius = opts.radius}

    local function tile(col, row, colspan, rowspan, box)
        box.col, box.row, box.colspan, box.rowspan = col, row, colspan, rowspan
        box.bgcolor = box.bgcolor or panel
        box.titlepos = box.titlepos or "top"
        box.titlealign = box.titlealign or "center"
        box.titlepaddingtop = box.titlepaddingtop or 4
        box.titlefont = box.titlefont or opts.titlefont
        box.titlecolor = box.titlecolor or colorMode.titlecolor
        box.textcolor = box.textcolor or colorMode.textcolor
        box.font = box.font or opts.font
        return box
    end

    -- Small readout: title top-left, value right-aligned, as on KSE5.
    local function readout(col, row, colspan, rowspan, box)
        box.titlealign = "left"
        box.titlepaddingleft = 6
        box.valuealign = box.valuealign or "right"
        box.valuepaddingright = 8
        box.font = box.font or opts.sfont
        if not box.type then
            box.type = "text"
            box.subtype = box.stattype and "stats" or "telemetry"
        end
        return tile(col, row, colspan, rowspan, box)
    end

    -- Green below 70% of max, warning to 90%, critical above.
    local function rising(maxValue)
        return {
            {value = maxValue * 0.7, fillcolor = colorMode.fillcolor},
            {value = maxValue * 0.9, fillcolor = colorMode.fillwarncolor},
        }
    end

    local function ring(col, row, colspan, rowspan, box)
        box.type, box.subtype = "gauge", "ring"
        box.font = box.font or opts.ring
        box.thickness = box.thickness or opts.thickness
        box.fillbgcolor = colorMode.fillbgcolor
        return tile(col, row, colspan, rowspan, box)
    end

    local function fuelRing(col, row, colspan, rowspan, extra)
        local box = {
            source = "smartfuel", unit = "%", transform = "floor", min = 0, max = 100,
            title = fuelTitle, fillcolor = colorMode.fillcolor, thresholds = FUEL_THRESHOLDS,
        }
        for k, v in pairs(extra or {}) do box[k] = v end
        return ring(col, row, colspan, rowspan, box)
    end

    local function rpmRing(col, row, colspan, rowspan, extra)
        local box = {
            source = "rpm", unit = "", transform = "floor", min = 0, max = rpmMax,
            title = "@i18n(widgets.dashboard.headspeed):upper()@", fillcolor = colorMode.accentcolor,
        }
        for k, v in pairs(extra or {}) do box[k] = v end
        return ring(col, row, colspan, rowspan, box)
    end

    local function currentRing(col, row, colspan, rowspan, extra)
        local box = {
            source = "current", unit = "A", transform = "floor", min = 0, max = currentMax,
            title = "@i18n(widgets.dashboard.current):upper()@",
            fillcolor = colorMode.fillcritcolor, thresholds = rising(currentMax),
        }
        for k, v in pairs(extra or {}) do box[k] = v end
        return ring(col, row, colspan, rowspan, box)
    end

    local function tempRing(col, row, colspan, rowspan, extra)
        local box = {
            source = "temp_esc", transform = "floor", min = 0, max = tempMax,
            title = "@i18n(widgets.dashboard.esc_temp):upper()@",
            fillcolor = colorMode.fillcritcolor, thresholds = rising(tempMax),
        }
        for k, v in pairs(extra or {}) do box[k] = v end
        return ring(col, row, colspan, rowspan, box)
    end

    local function governor(col, row, colspan, rowspan, font, valuealign)
        return readout(col, row, colspan, rowspan, {
            type = "text", subtype = "governor",
            title = "@i18n(widgets.dashboard.governor):upper()@",
            font = font, valuealign = valuealign, thresholds = GOVERNOR_THRESHOLDS,
        })
    end

    if phase == "inflight" then
        return {
            fuelRing(1, 1, 6, 10, {font = opts.bigring, thickness = opts.bigthickness}),
            rpmRing(7, 1, 5, 6, {font = opts.sfont}),
            tempRing(12, 1, 5, 6, {font = opts.sfont}),

            tile(7, 7, 5, 4, {type = "time", subtype = "flight", title = "@i18n(widgets.dashboard.timer):upper()@"}),
            governor(12, 7, 5, 4, opts.sfont, "center"),

            readout(1, 11, 4, 4, {source = "current", unit = "A", transform = "floor", title = "@i18n(widgets.dashboard.current):upper()@", font = opts.font}),
            readout(5, 11, 4, 4, {source = "voltage", unit = "V", decimals = 2, transform = cellVoltage, title = "@i18n(widgets.dashboard.volts_per_cell):upper()@", font = opts.font}),
            readout(9, 11, 4, 4, {source = "bec_voltage", unit = "V", decimals = 1, title = "@i18n(widgets.dashboard.bec_voltage):upper()@", font = opts.font}),
            readout(13, 11, 4, 4, {source = "throttle_percent", unit = "%", transform = "floor", title = "@i18n(widgets.dashboard.throttle):upper()@", font = opts.font}),
        }
    end

    if phase == "postflight" then
        return {
            fuelRing(1, 1, 4, 8, {stattype = "min", title = "@i18n(widgets.dashboard.fuel_remaining):upper()@"}),
            rpmRing(5, 1, 4, 8, {stattype = "max", title = "@i18n(widgets.dashboard.rpm_max):upper()@"}),
            currentRing(9, 1, 4, 8, {stattype = "max", title = "@i18n(widgets.dashboard.current_max):upper()@"}),
            tempRing(13, 1, 4, 8, {stattype = "max", title = "@i18n(widgets.dashboard.esc_max_temp):upper()@"}),

            readout(1, 9, 8, 3, {type = "time", subtype = "flight", title = "@i18n(widgets.dashboard.flight_duration):upper()@", font = opts.font}),
            readout(1, 12, 8, 3, {source = "smartconsumption", stattype = "max", unit = " mAh", transform = "floor", title = "@i18n(widgets.dashboard.consumed_mah):upper()@", font = opts.font}),

            readout(9, 9, 4, 3, {source = "voltage", stattype = "min", unit = "V", decimals = 2, transform = cellVoltage, title = "@i18n(widgets.dashboard.volts_per_cell):upper()@"}),
            readout(13, 9, 4, 3, {source = "bec_voltage", stattype = "min", unit = "V", decimals = 1, title = "@i18n(widgets.dashboard.bec_voltage):upper()@"}),
            readout(9, 12, 4, 3, {type = "text", subtype = "watts", source = "max", unit = "W", transform = "floor", title = "@i18n(widgets.dashboard.watts_max):upper()@"}),
            readout(13, 12, 4, 3, {source = "link", stattype = "min", unit = "dB", transform = "floor", title = "@i18n(widgets.dashboard.link_min):upper()@"}),
        }
    end

    -- preflight
    return {
        fuelRing(1, 1, 4, 8),
        rpmRing(5, 1, 4, 8),
        currentRing(9, 1, 4, 8),
        tempRing(13, 1, 4, 8),

        {col = 1, row = 9, colspan = 8, rowspan = 4, type = "image", subtype = "model", bgcolor = panel},
        tile(1, 13, 8, 2, {type = "time", subtype = "count", title = "@i18n(widgets.dashboard.flights):upper()@", font = opts.sfont}),

        governor(9, 9, 4, 3),
        readout(13, 9, 4, 3, {source = "bec_voltage", unit = "V", decimals = 1, title = "@i18n(widgets.dashboard.bec_voltage):upper()@"}),
        readout(9, 12, 4, 3, {source = "voltage", unit = "V", decimals = 2, transform = cellVoltage, title = "@i18n(widgets.dashboard.volts_per_cell):upper()@"}),
        readout(13, 12, 4, 3, {source = "smartconsumption", unit = "", transform = "floor", title = "@i18n(widgets.dashboard.consumed_mah):upper()@"}),
    }
end

return common

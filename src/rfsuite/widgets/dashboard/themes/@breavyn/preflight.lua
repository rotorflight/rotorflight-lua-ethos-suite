--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local theme_section = "system/@rt-rc"

local THEME_DEFAULTS = {v_min = 18.0, v_max = 25.2}

local function getUserVoltageOverride(which)
    local prefs = rfsuite.session and rfsuite.session.modelPreferences
    if prefs and prefs["system/@breavyn"] then
        local v = tonumber(prefs["system/@breavyn"][which])

        if which == "v_min" and v and math.abs(v - 18.0) > 0.05 then return v end
        if which == "v_max" and v and math.abs(v - 25.2) > 0.05 then return v end
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

local themeOptions = {

    ls_full = {font = "FONT_XXL", thickness = 30, valuepaddingtop = 40, gaugepadding = 10},

    ls_std = {font = "FONT_XXL", thickness = 25, valuepaddingtop = 25, gaugepadding = 10},

    ms_full = {font = "FONT_XL", thickness = 22, valuepaddingtop = 35, gaugepadding = 5},

    ms_std = {font = "FONT_XL", thickness = 20, valuepaddingtop = 25, gaugepadding = 5},

    ss_full = {font = "FONT_XL", thickness = 28, valuepaddingtop = 30, gaugepadding = 5},

    ss_std = {font = "FONT_XL", thickness = 23, valuepaddingtop = 20, gaugepadding = 5}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local layout = {cols = 12, rows = 12, padding = 2, showstats = false}

local header_layout = utils.standardHeaderLayout(headeropts)

local function liveVoltageToCellVoltage(value)
    local cfg = rfsuite.session.batteryConfig
    local cells = (cfg and cfg.batteryCellCount) or 3
    if not cells or not value then return nil end

    local vpc = math.max(0, value / cells)
    return math.floor(vpc * 100 + 0.5) / 100
end

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
        {col = 1, row = 1, rowspan = 12,
            type = "gauge",
            source = "smartfuel",
            gaugeorientation = "vertical",
            battery = true,
            hidevalue = true,
            novalue = "",
            gaugepaddingtop = 2,
            transform = "floor",
            fillcolor = "green",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
                thresholds = {
                    { value = 25,  fillcolor = "red"    },
                    { value = 50,  fillcolor = "orange" }
                }
            }, 
            
            -- Voltage
            {col = 2, row = 1, colspan = 3, rowspan = 3, 
            type = "text", subtype = "telemetry", source = "voltage",
            title = "@i18n(widgets.dashboard.voltage)@", titlepos = "top", titlealign = "left", titlefont = "FONT_S", titlepaddingleft = 4,
            font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            valuealign = "left", decimals = 1, transform = "floor",
            },

            -- BEC Voltage
            {col = 2, row = 4, colspan = 3, rowspan = 3,
            type = "text", subtype = "telemetry", source = "bec_voltage",
            title = "@i18n(widgets.dashboard.bec_voltage)@", titlepos = "top", titlealign = "left", titlefont = "FONT_S", titlepaddingleft = 4,
            font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            valuealign = "left", decimals = 1, transform = "floor",
            },

            -- ESC Temperature
            {col = 2, row = 7, colspan = 3, rowspan = 3,
            type = "text", subtype = "telemetry", source = "temp_esc",
            title = "@i18n(widgets.dashboard.esc_temp)@", titlepos = "top", titlealign = "left", titlefont = "FONT_S", titlepaddingleft = 4,
            font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            valuealign = "left", transform = "floor",
            },

            -- Cell Voltage
            {col = 2, row = 10, colspan = 3, rowspan = 3,
            type = "text", subtype = "telemetry", source = "voltage",
            title = "@i18n(widgets.dashboard.cell_voltage)@", titlepos = "top", titlealign = "left", titlefont = "FONT_S", titlepaddingleft = 4,
            font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            valuealign = "left",
            transform = liveVoltageToCellVoltage,
            },

            -- Power
            {col = 9, row = 1, colspan = 3, rowspan = 3, 
            type = "text", subtype = "telemetry", source = "smartconsumption", unit = "mAh",
            title = "@i18n(widgets.dashboard.consumed_mah)@", titlepos = "top", titlealign = "right", titlefont = "FONT_S", titlepaddingright = 4, 
            font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            valuealign = "right",
            },

            -- Current
            {col = 9, row = 4, colspan = 3, rowspan = 3,
            type = "text", "watts", source = "current",
            title = "@i18n(widgets.dashboard.current)@", titlepos = "top", titlealign = "right", titlefont = "FONT_S", titlepaddingright = 4, 
            font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            valuealign = "right",
            },

            -- Altitude
            {col = 9, row = 7, colspan = 3, rowspan = 3, 
            type = "text", subtype = "telemetry", source = "altitude",
            title = "@i18n(widgets.dashboard.altitude)@", titlepos = "top", titlealign = "right", titlefont = "FONT_S", titlepaddingright = 4, 
            font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            decimals = 1, valuealign = "right", transform = "floor",
            },

            -- Throttle
            {col = 9, row = 10, colspan = 3, rowspan = 3,
            type = "text", subtype = "telemetry", source = "throttle_percent",
            title = "@i18n(widgets.dashboard.throttle)@", titlepos = "top", titlealign = "right", titlefont = "FONT_S", titlepaddingright = 4, 
            font = "FONT_XL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            valuealign = "right", transform = "floor",
            },

            -- Rates
            {col = 5, row = 1, colspan = 4, rowspan = 3,
            type = "text", subtype = "pidrates", object = "rates",
            title = "", font = "FONT_XL", fillcolor = "cyan", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            rowspacing = 20, rowfont ="FONT_L", rowalign = "center", rowpaddingbottom = 20,
            highlightlarger = true, transform = "floor",
            },

            -- RPM
            {col = 5, row = 4, colspan = 4, rowspan = 2,
            type = "text", subtype = "telemetry", source = "rpm", unit = "  RPM",
            title = "", titlepos = "top", font = "FONT_L", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            valuealign = "bottom", valuepaddingtop = 10, transform = "floor",
            },

            -- Timer
            {col = 5, row = 6, colspan = 4, rowspan = 4,
            type = "time", subtype = "flight",
            title = "", font = "FONT_XXL", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            valuepaddingbottom = 0,
            },

            -- Governor
            {col = 5, row = 10, colspan = 4, rowspan = 3,
            type = "text", subtype = "governor",
            title = "", font = "FONT_XL",
            bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
            valuealign = "top", valuepaddingbottom = 20,
                thresholds = {
                    { value = "@i18n(widgets.governor.DISARMED)@", textcolor = "red"    },
                    { value = "@i18n(widgets.governor.OFF)@",      textcolor = "red"    },
                    { value = "@i18n(widgets.governor.IDLE)@",     textcolor = "blue"   },
                    { value = "@i18n(widgets.governor.SPOOLUP)@",  textcolor = "blue"   },
                    { value = "@i18n(widgets.governor.RECOVERY)@", textcolor = "orange" },
                    { value = "@i18n(widgets.governor.ACTIVE)@",   textcolor = "green"  },
                    { value = "@i18n(widgets.governor.THR-OFF)",  textcolor = "red"    },
                }
            },

            -- Battery Bar
            {col = 12, row = 1, rowspan = 12,
            type = "gauge",
            source = "smartfuel",
            gaugeorientation = "vertical",
            battery = true,
            hidevalue = true,
            novalue = "",
            gaugepaddingtop = 2,
            transform = "floor",
            fillcolor = "green",
            bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
                thresholds = {
                    { value = 25,  fillcolor = "red"    },
                    { value = 50,  fillcolor = "orange" }
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

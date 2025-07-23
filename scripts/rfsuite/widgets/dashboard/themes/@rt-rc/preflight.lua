--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local i18n = rfsuite.i18n.get
local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

-- Theme based configuration settings
local theme_section = "system/@rt-rc"

local THEME_DEFAULTS = {
    v_min      = 18.0,
    v_max      = 25.2,
}

-- User voltage min/max override support
local function getUserVoltageOverride(which)
  local prefs = rfsuite.session and rfsuite.session.modelPreferences
  if prefs and prefs["system/@rt-rc"] then
    local v = tonumber(prefs["system/@rt-rc"][which])
    -- Only use override if it is present and different from the default 6S values
    -- (Defaults: min=18.0, max=25.2)
    if which == "v_min" and v and math.abs(v - 18.0) > 0.05 then return v end
    if which == "v_max" and v and math.abs(v - 25.2) > 0.05 then return v end
  end
  return nil
end

local function getThemeValue(key)
    -- Use General preferences for TX values
    if key == "tx_min" or key == "tx_warn" or key == "tx_max" then
        if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
            local val = rfsuite.preferences.general[key]
            if val ~= nil then return tonumber(val) end
        end
    end
    -- Theme defaults for other values
    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then return val end
    end
    return THEME_DEFAULTS[key]
end

-- Theme Options based on screen width
local function getThemeOptionKey(W)
    if     W == 800 then return "ls_full"
    elseif W == 784 then return "ls_std"
    elseif W == 640 then return "ss_full"
    elseif W == 630 then return "ss_std"
    elseif W == 480 then return "ms_full"
    elseif W == 472 then return "ms_std"
    end
end

-- Theme Options based on screen width
local themeOptions = {
    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    ls_full = { 
        font = "FONT_XXL", 
        thickness = 30, 
        valuepaddingtop = 40, 
        gaugepadding = 10
    },

    ls_std  = { 
        font = "FONT_XXL", 
        thickness = 25, 
        valuepaddingtop = 25, 
        gaugepadding = 10
    },

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = { 
        font = "FONT_XL", 
        thickness = 22, 
        valuepaddingtop = 35, 
        gaugepadding = 5 
    },

    ms_std  = { 
        font = "FONT_XL", 
        thickness = 20, 
        valuepaddingtop = 25, 
        gaugepadding = 5 
    },

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = { 
        font = "FONT_XL", 
        thickness = 28,  
        valuepaddingtop = 30, 
        gaugepadding = 5
    },

    ss_std  = { 
        font = "FONT_XL", 
        thickness = 23,  
        valuepaddingtop = 20, 
        gaugepadding = 5 
    },
}

-- Caching for boxes
local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

-- Theme Layout
local layout = {
    cols    = 20,
    rows    = 8,
    padding = 2,
    --showgrid = lcd.RGB(100, 100, 100)  -- or any color you prefer
}

-- Header Layout
local header_layout = utils.standardHeaderLayout(headeropts)

-- Header Boxes
local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end

    -- Rebuild cache if type changed
    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        header_boxes_cache = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

-- Boxes
local function buildBoxes(W)
    
    -- Object based options determined by screensize
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.unknown

    return{

      {
        col     = 1,
        row     = 1,
        colspan = 8,
        rowspan = 3,
        type    = "image",
        subtype = "model",
        bgcolor = colorMode.bgcolor,
      },
      {
        col     = 1,
        row     = 4,
        colspan = 4,
        rowspan = 3,
        type    = "text",
        subtype = "governor",
        title   = i18n("widgets.dashboard.governor"):upper(),
        titlepos= "bottom",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        thresholds = {
            { value = i18n("widgets.governor.DISARMED"), textcolor = colorMode.fillcritcolor },
            { value = i18n("widgets.governor.OFF"), textcolor = colorMode.fillcritcolor },
            { value = i18n("widgets.governor.IDLE"), textcolor = "blue" },
            { value = i18n("widgets.governor.SPOOLUP"), textcolor = "blue" },
            { value = i18n("widgets.governor.RECOVERY"), textcolor = colorMode.fillwarncolor },
            { value = i18n("widgets.governor.ACTIVE"), textcolor = colorMode.fillcolor },
            { value = i18n("widgets.governor.THR-OFF"), textcolor = colorMode.fillcritcolor }
        }
      },
      {
        col     = 5,
        row     = 4,
        colspan = 4,
        rowspan = 3,
        type    = "text",
        subtype = "telemetry",
        source  = "rpm",
        unit    = "",
        transform = "floor",
        title   = i18n("widgets.dashboard.headspeed"):upper(),
        titlepos= "bottom",
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
      },
      {
        col     = 1,
        row     = 7,
        colspan = 2,
        rowspan = 2,
        type    = "text",
        subtype = "telemetry",
        source  = "pid_profile",
        title   = i18n("widgets.dashboard.profile"):upper(),
        titlepos= "bottom",
        transform = "floor",
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
      },
      {
        col     = 3,
        row     = 7,
        colspan = 2,
        rowspan = 2,
        type    = "text",
        subtype = "telemetry",
        source  = "rate_profile",
        title   = i18n("widgets.dashboard.rates"):upper(),
        titlepos= "bottom",
        transform = "floor",
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
      },
      {
        col     = 5,
        row     = 7,
        colspan = 2,
        rowspan = 2,
        type    = "time",
        subtype = "count",
        title   = i18n("widgets.dashboard.flights"):upper(),
        titlepos= "bottom",
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
      },
      {
        col     = 7,
        row     = 7,
        colspan = 2,
        rowspan = 2,
        type    = "text",
        subtype = "telemetry",
        source  = "link",
        unit    = "dB",
        title   = i18n("widgets.dashboard.lq"):upper(),
        titlepos= "bottom",
        transform = "floor",
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
      },
      {
        col     = 9,
        row     = 7,
        colspan = 6,
        rowspan = 2,
        type    = "time",
        subtype = "flight",
        title   = i18n("widgets.dashboard.time"):upper(),
        titlepos= "bottom",
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
      },
      {
        col     = 15,
        row     = 7,
        colspan = 6,
        rowspan = 2,
        type    = "text",
        subtype = "blackbox",
        title   = i18n("widgets.dashboard.blackbox"):upper(),
        titlepos= "bottom",
        decimals = 0,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
      },
      {
        type    = "gauge",
        subtype = "arc",
        col     = 9,
        row     = 1,
        colspan = 6,
        rowspan = 6,
        thickness= opts.thickness,
        source  = "smartfuel",
        unit    = "%",
        transform = "floor",
        min     = 0,
        max     = 100,
        font    = opts.font,
        gaugepadding = opts.gaugepadding,
        valuepaddingtop = opts.valuepaddingtop,
        fillbgcolor = colorMode.fillbgcolor,
        title   = i18n("widgets.dashboard.fuel"):upper(),
        titlepos= "bottom",
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
        thresholds = {
            { value = 30,  fillcolor = colorMode.fillcritcolor,     textcolor = colorMode.textcolor },
            { value = 50,  fillcolor = colorMode.fillwarncolor,     textcolor = colorMode.textcolor },
            { value = 140, fillcolor = colorMode.fillcolor,         textcolor = colorMode.textcolor }
        },
      },
      {
        col     = 15,
        row     = 1,
        colspan = 6,
        rowspan = 6,
        type    = "gauge",
        subtype = "arc",
        source  = "voltage",
        fillbgcolor = colorMode.fillbgcolor,
        title    = i18n("widgets.dashboard.voltage"):upper(),
        font     = opts.font,
        thickness= opts.thickness,
        titlepos = "bottom",
        fillcolor= colorMode.fillcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
        gaugepadding = opts.gaugepadding,
        valuepaddingtop = opts.valuepaddingtop,
        min = function()
            local override = getUserVoltageOverride("v_min")
            if override then return override end
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV  = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,

        max = function()
            local override = getUserVoltageOverride("v_max")
            if override then return override end
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV  = (cfg and cfg.vbatfullcellvoltage) or 4.2
            return math.max(0, cells * maxV)
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
            },
            {
                value = function(box)
                    local raw_gm = utils.getParam(box, "min")
                    if type(raw_gm) == "function" then raw_gm = raw_gm(box) end
                    local raw_gM = utils.getParam(box, "max")
                    if type(raw_gM) == "function" then raw_gM = raw_gM(box) end
                    return raw_gm + 0.50 * (raw_gM - raw_gm)
                end,
                fillcolor = colorMode.fillwarncolor,
                textcolor = colorMode.textcolor
            },
            {
                value = function(box)
                    local raw_gM = utils.getParam(box, "max")
                    if type(raw_gM) == "function" then raw_gM = raw_gM(box) end
                    return raw_gM
                end,
                fillcolor = colorMode.fillcolor,
                textcolor = colorMode.textcolor
            }
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

return {
  layout = layout,
  boxes = boxes,
  header_boxes = header_boxes,
  header_layout = header_layout,
  scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
  }    
}

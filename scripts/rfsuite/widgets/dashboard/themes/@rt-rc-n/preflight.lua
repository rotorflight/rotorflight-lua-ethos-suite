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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]] --

local telemetry = rfsuite.tasks.telemetry
local utils = rfsuite.widgets.dashboard.utils

local W, H = lcd.getWindowSize()
local VERSION = system.getVersion().board

local gaugeThickness = 30
if VERSION == "X18" or VERSION == "X18S" or VERSION == "X14" or VERSION == "X14S" then gaugeThickness = 15 end

local darkMode = {
    textcolor   = "white",
    titlecolor  = "white",
    bgcolor= "black",
    fillcolor   = "green",
    fillbgcolor = "grey",
    arcbgcolor  = "lightgrey",
}

local lightMode = {
    textcolor   = "black",
    titlecolor  = "black",
    bgcolor= "white",
    fillcolor   = "green",
    fillbgcolor = "lightgrey",
    arcbgcolor  = "darkgrey",
}

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

-- Theme config support
local theme_section = "system/@rt-rc-n"

local THEME_DEFAULTS = {
    v_min   = 7.0,
    v_max   = 8.4,
}

local function getThemeValue(key)
    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then return val end
    end
    return THEME_DEFAULTS[key]
end

local boxes_cache = nil
local themeconfig = nil

local layout = {
    cols    = 20,
    rows    = 8,
    padding = 1,
    bgcolor = colorMode.bgcolor,
    -- showgrid = lcd.RGB(100, 100, 100)
}

local function buildBoxes()
    local vmin = getThemeValue("v_min")
    local vmax = getThemeValue("v_max")
    return {
    
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
        title   = "GOVERNOR",
        titlepos= "bottom",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        thresholds = {
          { value = "DISARMED", textcolor = colorMode.fillcolor },
          { value = "OFF",      textcolor = colorMode.fillcolor },
          { value = "IDLE",     textcolor = colorMode.accent    },
          { value = "SPOOLUP",  textcolor = colorMode.primary   },
          { value = "RECOVERY", textcolor = colorMode.secondary },
          { value = "ACTIVE",   textcolor = colorMode.fillcolor },
          { value = "THR-OFF",  textcolor = colorMode.fillcolor },
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
        title   = "HEADSPEED",
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
        title   = "PROFILE",
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
        title   = "RATES",
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
        title   = "FLIGHTS",
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
        source  = "rssi",
        unit    = "dB",
        title   = "LQ",
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
        title   = "TIME",
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
        title   = "BLACKBOX",
        titlepos= "bottom",
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
        thickness= gaugeThickness,
        source  = "throttle_percent",
        unit    = "%",
        transform = "floor",
        min     = 0,
        max     = 100,
        font    = "FONT_XL",
        arcbgcolor = colorMode.arcbgcolor,
        title   = "THROTTLE",
        titlepos= "bottom",
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
        thresholds = {
            { value = 30,  fillcolor = "red",    textcolor = colorMode.textcolor },
            { value = 50,  fillcolor = "orange", textcolor = colorMode.textcolor },
            { value = 140, fillcolor = colorMode.fillcolor,  textcolor = colorMode.textcolor }
        },
      },
      {
        col     = 15,
        row     = 1,
        colspan = 6,
        rowspan = 6,
        type    = "gauge",
        subtype = "arc",
        source  = "bec_voltage",
        fillbgcolor = colorMode.fillbgcolor,
        title    = "VOLTAGE",
        font     = "FONT_XL",
        thickness= gaugeThickness,
        titlepos = "bottom",
        fillcolor= colorMode.fillcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
        min = vmin,
        max = vmax,
        thresholds = {
            { value = vmin + 0.2 * (vmax - vmin), fillcolor = "red"    },
            { value = vmin + 0.4 * (vmax - vmin), fillcolor = "orange" },
            { value = vmax,                       fillcolor = "green"  }
            }
      },
    }
end

local function boxes()
    local config =
        rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section]
    if boxes_cache == nil or themeconfig ~= config then
        boxes_cache = buildBoxes()
        themeconfig = config
    end
    return boxes_cache
end

return {
  layout    = layout,
  boxes     = boxes,
    scheduler = {
        spread_scheduling = true,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
        spread_ratio = 0.8              -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }    
}

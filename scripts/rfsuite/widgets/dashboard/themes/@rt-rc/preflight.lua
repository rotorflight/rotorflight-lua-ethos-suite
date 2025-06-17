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
local gaugeThickness = 30
if W < 500 then gaugeThickness = 15 end

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


local layout = {
    cols    = 20,
    rows    = 8,
    padding = 1,
    bgcolor = colorMode.bgcolor,
    -- showgrid = lcd.RGB(100, 100, 100)
}

-- define boxes, pulling colors from colorMode
local boxes = {
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
    nosource= "-",
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
    nosource= "-",
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
    nosource= "-",
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
    source  = "fuel",
    unit    = "%",
    transform = "floor",
    min     = 0,
    max     = 100,
    font    = "FONT_XL",
    arcbgcolor = colorMode.arcbgcolor,
    title   = "FUEL",
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
    source  = "voltage",
    fillbgcolor = colorMode.fillbgcolor,
    title    = "VOLTAGE",
    font     = "FONT_XL",
    thickness= gaugeThickness,
    titlepos = "bottom",
    fillcolor= colorMode.fillcolor,
    titlecolor = colorMode.titlecolor,
    textcolor = colorMode.titlecolor,
    bgcolor = colorMode.bgcolor,
    min = function()
        local cfg = rfsuite.session.batteryConfig
        local cells = (cfg and cfg.batteryCellCount) or 3
        local minV  = (cfg and cfg.vbatmincellvoltage) or 3.0
        return math.max(0, cells * minV)
    end,

    max = function()
        local cfg = rfsuite.session.batteryConfig
        local cells = (cfg and cfg.batteryCellCount) or 3
        local maxV  = (cfg and cfg.vbatmaxcellvoltage) or 4.2
        return math.max(0, cells * maxV)
    end,

    gaugemin = function()
        local cfg = rfsuite.session.batteryConfig
        local cells = (cfg and cfg.batteryCellCount) or 3
        local minV  = (cfg and cfg.vbatmincellvoltage) or 3.0
        return math.max(0, cells * minV)
    end,

    gaugemax = function()
        local cfg = rfsuite.session.batteryConfig
        local cells = (cfg and cfg.batteryCellCount) or 3
        local maxV  = (cfg and cfg.vbatmaxcellvoltage) or 4.2
        return math.max(0, cells * maxV)
    end,

    -- (b) The “dynamic” thresholds (using functions that no longer reference box._cache)
    thresholds = {
        {
            value = function(box)
                -- Fetch the raw gaugemin parameter (could itself be a function)
                local raw_gm = utils.getParam(box, "gaugemin")
                if type(raw_gm) == "function" then
                    raw_gm = raw_gm(box)
                end

                -- Fetch the raw gaugemax parameter (could itself be a function)
                local raw_gM = utils.getParam(box, "gaugemax")
                if type(raw_gM) == "function" then
                    raw_gM = raw_gM(box)
                end

                -- Return 30% above gaugemin
                return raw_gm + 0.30 * (raw_gM - raw_gm)
            end,
            fillcolor = "red",
            textcolor = colorMode.textcolor
        },
        {
            value = function(box)
                local raw_gm = utils.getParam(box, "gaugemin")
                if type(raw_gm) == "function" then
                    raw_gm = raw_gm(box)
                end

                local raw_gM = utils.getParam(box, "gaugemax")
                if type(raw_gM) == "function" then
                    raw_gM = raw_gM(box)
                end

                -- Return 50% above gaugemin
                return raw_gm + 0.50 * (raw_gM - raw_gm)
            end,
            fillcolor = "orange",
            textcolor = colorMode.textcolor
        },
        {
            value = function(box)
                local raw_gM = utils.getParam(box, "gaugemax")
                if type(raw_gM) == "function" then
                    raw_gM = raw_gM(box)
                end

                -- Top‐end threshold = gaugemax
                return raw_gM
            end,
            fillcolor = colorMode.fillcolor,
            textcolor = colorMode.textcolor
        }
    }
  },
}



return {
  wakeup    = wakeup,
  layout    = layout,
  boxes     = boxes,
  scheduler = {
    wakeup_interval    = 0.1,
    wakeup_interval_bg = 5,
    paint_interval     = 0.1,
    spread_scheduling = true,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
    spread_ratio = 1.0              -- optional: manually override default ratio logic (applies if spread_scheduling is true)
  }
}

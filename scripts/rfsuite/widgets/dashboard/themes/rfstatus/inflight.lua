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
local i18n = rfsuite.i18n.get

local darkMode = {
    textcolor   = "white",
    fillcolor   = "green",
}

local lightMode = {
    textcolor   = "black",
    fillcolor   = "green",
}

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode



local layout = {
    cols = 4,
    rows = 14,
    padding = 4
}

local boxes = {
     {
        type = "gauge",
        subtype = "arc",
        col = 1, row = 1,
        rowspan = 12,
        colspan = 2,
        source = "voltage",
        thickness = 25,
        font = "FONT_XXL",
        arcbgcolor = colorMode.arcbgcolor,
        title = i18n("widgets.dashboard.voltage"):upper(),
        titlepos = "bottom",
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
    {
        type = "gauge",
        subtype = "arc",
        col = 3, row = 1,
        rowspan = 12,
        thickness = 25,
        colspan = 2,
        source = "smartfuel",
        transform = "floor",
        min = 0,
        max = 140,
        font = "FONT_XXL",
        arcbgcolor = colorMode.arcbgcolor,
        title = i18n("widgets.dashboard.fuel"):upper(),
        titlepos = "bottom",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,

        thresholds = {
            { value = 30,  fillcolor = "red",    textcolor = colorMode.textcolor },
            { value = 50,  fillcolor = "orange", textcolor = colorMode.textcolor },
            { value = 140, fillcolor = colorMode.fillcolor,  textcolor = colorMode.textcolor }
        },
    },
    {
        col = 1,
        row = 13,
        rowspan = 2,
        type = "text",
        subtype = "governor",
        nosource = "-",
        titlecolor = colorMode.textcolor,
        textcolor = colorMode.textcolor,  
        thresholds = {
          { value = i18n("widgets.governor.DISARMED"), textcolor = "red"    },
          { value = i18n("widgets.governor.OFF"),      textcolor = "red"    },
          { value = i18n("widgets.governor.IDLE"),     textcolor = "yellow" },
          { value = i18n("widgets.governor.SPOOLUP"),  textcolor = "blue"   },
          { value = i18n("widgets.governor.RECOVERY"), textcolor = "orange" },
          { value = i18n("widgets.governor.ACTIVE"),   textcolor = "green"  },
          { value = i18n("widgets.governor.THR-OFF"),  textcolor = "red"    },
        }
    },
    {
        col = 4,
        row = 13,
        rowspan = 2,
        type = "time",
        subtype = "flight",
        titlecolor = colorMode.textcolor,
        textcolor = colorMode.textcolor,          
    }, 
    {
        col = 3,
        row = 13,
        rowspan = 2,
        type = "text",
        subtype = "telemetry",
        source = "rpm",
        nosource = "-",
        unit = "rpm",
        transform = "floor",
        titlecolor = colorMode.textcolor,
        textcolor = colorMode.textcolor,          
    },    
    {
        col = 2,
        row = 13,
        rowspan = 2,
        type = "text",
        subtype = "telemetry",
        source = "rssi",
        nosource = "-",
        unit = "dB",
        transform = "floor",
        titlecolor = colorMode.textcolor,
        textcolor = colorMode.textcolor,          
    },    
}



return {
    layout = layout,
    wakeup = wakeup,
    boxes = boxes,
    scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }      
}

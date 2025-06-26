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


local layout = {
    cols = 4,
    rows = 14,
    padding = 1,
    bgcolor = colorMode.bgcolor
}

local boxes = {
    {
        type = "gauge",
        subtype = "arc",
        col = 1, row = 1,
        rowspan = 12,
        colspan = 2,
        source = "voltage",
        thickness = gaugeThickness,
        font = "FONT_XXL",
        arcbgcolor = colorMode.arcbgcolor,
        title = "VOLTAGE",
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
            local maxV  = (cfg and cfg.vbatfullcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,

        -- (b) The “dynamic” thresholds (using functions that no longer reference box._cache)
        thresholds = {
            {
                value = function(box)
                    -- Fetch the raw gaugemin parameter (could itself be a function)
                    local raw_gm = utils.getParam(box, "min")
                    if type(raw_gm) == "function" then
                        raw_gm = raw_gm(box)
                    end

                    -- Fetch the raw gaugemax parameter (could itself be a function)
                    local raw_gM = utils.getParam(box, "max")
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
                    local raw_gm = utils.getParam(box, "min")
                    if type(raw_gm) == "function" then
                        raw_gm = raw_gm(box)
                    end

                    local raw_gM = utils.getParam(box, "max")
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
                    local raw_gM = utils.getParam(box, "max")
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
        thickness = gaugeThickness,
        colspan = 2,
        source = "smartfuel",
        transform = "floor",
        min = 0,
        max = 140,
        font = "FONT_XXL",
        arcbgcolor = colorMode.arcbgcolor,
        title = "FUEL",
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
        thresholds = {
            { value = "DISARMED", textcolor = "red"    },
            { value = "OFF",      textcolor = "red"    },
            { value = "IDLE",     textcolor = "yellow" },
            { value = "SPOOLUP",  textcolor = "blue"   },
            { value = "RECOVERY", textcolor = "orange" },
            { value = "ACTIVE",   textcolor = "green"  },
            { value = "THR-OFF",  textcolor = "red"    },
        },
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
    },
    {
        col = 4,
        row = 13,
        rowspan = 2,
        type = "time",
        subtype = "flight",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
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
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
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
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
    },    
}

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        spread_scheduling = true,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
        spread_ratio = 0.8              -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }     
}

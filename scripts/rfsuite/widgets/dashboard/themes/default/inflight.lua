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

local W, H = lcd.getWindowSize()
local VERSION = system.getVersion() and system.getVersion().board
local gaugeThickness = 30
if VERSION == "X18" or VERSION == "X18S" or VERSION == "X14" or VERSION == "X14S" then gaugeThickness = 15 end

local darkMode = {
    textcolor   = "white",
    titlecolor  = "white",
    bgcolor     = "black",
    fillcolor   = "green",
    fillbgcolor = "grey",
    arcbgcolor  = "lightgrey",
}

local lightMode = {
    textcolor   = "black",
    titlecolor  = "black",
    bgcolor     = "white",
    fillcolor   = "green",
    fillbgcolor = "lightgrey",
    arcbgcolor  = "darkgrey",
}

local colorMode = lcd.darkMode() and darkMode or lightMode

-- User voltage min/max override support
local function getUserVoltageOverride(which)
  local prefs = rfsuite.session and rfsuite.session.modelPreferences
  if prefs and prefs["system/@rt-rc"] then
    local v = tonumber(prefs["system/@rt-rc"][which])
    if which == "v_min" and v and math.abs(v - 18.0) > 0.05 then return v end
    if which == "v_max" and v and math.abs(v - 25.2) > 0.05 then return v end
  end
  return nil
end

local layout = {
    cols = 2,
    rows = 2,
    padding = 1,
    bgcolor = colorMode.bgcolor
}

-- BOXES CACHE
local boxes_cache = nil
local themeconfig = nil

local function buildBoxes()
    return {
        {
            col = 1,
            row = 1,
            type = "time",
            subtype = "flight",
            title = i18n("widgets.dashboard.flight_time"):upper(),
            titlepos = "bottom",
            font = "FONT_XXL",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
        },  
      {
        col     = 1,
        row     = 2,
        type    = "text",
        subtype = "telemetry",
        source  = "rssi",
        unit    = "dB",
        title   = i18n("widgets.dashboard.lq"):upper(),
        titlepos= "bottom",
        transform = "floor",
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.titlecolor,
        bgcolor = colorMode.bgcolor,
      },               
        {
            type = "gauge",
            subtype = "arc",
            col = 2, 
            row = 1,
            rowspan = 2,
            source = "voltage",
            thickness = gaugeThickness,
            font = "FONT_XXL",
            arcbgcolor = colorMode.arcbgcolor,
            title = i18n("widgets.dashboard.voltage"):upper(),
            titlepos = "bottom",
            bgcolor = colorMode.bgcolor,
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
                    fillcolor = "red",
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
                    fillcolor = "orange",
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
        },
    }
end

local function boxes()
    local config = rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences["system/@rt-rc"]
    if boxes_cache == nil or themeconfig ~= config then
        boxes_cache = buildBoxes()
        themeconfig = config
    end
    return boxes_cache
end

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        spread_scheduling = true,      -- (optional: spread scheduling over the interval to avoid spikes in CPU usage)  
        spread_ratio = 0.8              -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }     
}

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

================================================================================
                         CONFIGURATION INSTRUCTIONS
================================================================================

For a complete list of all available widget parameters and usage options,
SEE THE TOP OF EACH WIDGET OBJECT FILE.

(Scroll to the top of files like battery.lua, telemetry.lua etc, for the full reference.)

--------------------------------------------------------------------------------
-- ACTUAL DASHBOARD CONFIG BELOW (edit/add your widgets here!)
--------------------------------------------------------------------------------
]]
 local rfsuite = require("rfsuite")

local function themeColor(constName, fallback)
    if type(lcd.themeColor) == "function" then
        local key = _G[constName]
        if type(key) == "number" then return lcd.themeColor(key) end
    end
    return fallback
end

local function legacyDarkMode()
    return type(lcd.darkMode) == "function" and lcd.darkMode() == true
end

local primaryColor = themeColor("THEME_PRIMARY_COLOR", legacyDarkMode() and lcd.RGB(255, 255, 255) or lcd.RGB(90, 90, 90))
local secondaryBgColor = themeColor("THEME_SECONDARY_BGCOLOR", legacyDarkMode() and lcd.RGB(90, 90, 90) or lcd.RGB(211, 211, 211))
local activeColor = themeColor("THEME_ACTIVE_COLOR", lcd.RGB(0, 188, 4))
local warningColor = themeColor("THEME_WARNING_COLOR", lcd.RGB(255, 165, 0))
local inactiveColor = themeColor("THEME_INACTIVE_COLOR", lcd.RGB(255, 0, 0))

local layout = {
    cols = 3,
    rows = 3,
    padding = 4,
    showstats = true  -- or any color you prefer
    --showgrid = lcd.RGB(100, 100, 100)  -- or any color you prefer    
}

local boxes = {

    -- DIAL
    {
        col = 1, row = 1,
        type = "dial",
        title = "VOLTAGE",
        titlepos = "bottom",
        titlefont = "FONT_XXS",
        source = "voltage",
        decimals = 1,
        needlecolor = primaryColor,
        needlehubcolor = primaryColor,
        valuepaddingtop = 70,
        dial = 1,
        font = "FONT_S",
        min = 0,
        max = 100,
        transform = "floor",
    },

    -- HEATRING
    {
        col = 2, row = 1,
        type = "gauge",
        subtype = "ring",
        source = "rpm",
        title = "RPM",
        min = 0,
        max = 2000,
        thresholds = {
            { value = 1000,  fillcolor = activeColor },
            { value = 1500,  fillcolor = warningColor },
            { value = 2000,  fillcolor = inactiveColor },
        },
        titlepos = "bottom",
        unit = "",
        transform = "floor",
    },

    -- ARCGUAGE
    {
        type = "gauge",
        subtype = "arc",
        col = 1, row = 2,
        source = "temp_esc",
        title = "ESC TEMP",
        titlepos = "bottom",
        min = 0, 
        max = 140,
        transform = "floor", 
        fillbgcolor = secondaryBgColor,
        thickness = 10,
        thresholds = {
            { value = 70,  fillcolor = activeColor },
            { value = 90,  fillcolor = warningColor },
            { value = 140, fillcolor = inactiveColor }
        }
    },

    -- RAINBOW
    {
        type = "dial",
        subtype = "rainbow",
        col = 2, row = 2,
        title = "FUEL",
        showvalue = false,
        transform = "floor",
        titlepos = "bottom",
        source = "smartfuel",
    },

    -- FUEL GAUGE
    {
        col = 1, row = 3,
        type = "gauge",
        source = "smartfuel",
        batteryframe = true,
        title = "FUEL",
        titlepos = "bottom",
        textcolor = primaryColor,
        valuepaddingbottom = 20,
        transform = "floor",
        thresholds = {
            { value = 20,  fillcolor = inactiveColor},
            { value = 50,  fillcolor = warningColor},
            { value = 100,  fillcolor = activeColor},
        },
    },

    -- VOLTAGE GAUGE
    {
        col = 2, row = 3,
        type = "gauge",
        source = "voltage",
        min = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        max = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
        title = "VOLTAGE",
        textcolor = primaryColor,
        titlepos = "bottom",
        fillcolor = activeColor,
        roundradius = 8,
        valuepaddingbottom = 20,
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2
                end,
                fillbgcolor = "red",
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2
                end,
                fillbgcolor = warningColor,
            }
        }
    },

    -- BATTERY
    {
        col = 3, row = 1,
        type = "gauge",
        battery = true,
        batteryframe = true,
        source = "voltage",
        min = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        max = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
        title = "VOLTAGE",
        titlepos = "bottom",
        fillcolor = activeColor,
        textcolor = primaryColor,
        valuepaddingbottom = 20,
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2
                end,
                fillcolor = inactiveColor
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2
                end,
                fillcolor = warningColor
            }
        },        
    },

    -- HEATRING
    {
        col = 3, row = 2, rowspan = 2,
        type = "gauge",
        subtype = "ring",
        source = "smartfuel",
        title = "FUEL",
        font = "FONT_XL",
        thickness = 25,
        ringbatt = true,
        valuepaddingbottom = 20,
        ringbattsubpaddingbottom = 10,
        fillbgcolor = "lightgrey",
        titlepos = "bottom",
        transform = "floor",
        thresholds = {
            { value = 20,  fillcolor = "red"},
            { value = 50,  fillcolor = "orange"},
            { value = 100,  fillcolor = "green"},
        },
    },
}

return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }    
}

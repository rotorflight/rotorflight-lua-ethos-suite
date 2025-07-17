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
    titlecolor  = "white",
    bgcolor     = "black",
    fillcolor   = "green",
    fillbgcolor = "grey",
    accentcolor = "white",
    rssifillcolor = "darkwhite",
    txaccentcolor = "grey",
}

local lightMode = {
    textcolor   = "black",
    titlecolor  = "black",
    bgcolor     = "white",
    fillcolor   = "green",
    fillbgcolor = "grey",
    accentcolor = "black",
    rssifillcolor = "darkwhite",
    txaccentcolor = "grey",
}

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

-- Determine layout and screensize in use
local function getScreenSize(w, h)

    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    if (w == 800 and (h == 458 or h == 480)) then return "ls_full" end
    if (w == 784 and (h == 294 or h == 316)) then return "ls_std" end

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    if (w == 480 and (h == 301 or h == 320)) then return "ms_full" end
    if (w == 472 and (h == 191 or h == 210)) then return "ms_std" end

    -- Small screens - (X14 / X14S) Full/Standard
    if (w == 640 and (h == 338 or h == 360)) then return "ss_full" end
    if (w == 630 and (h == 236 or h == 258)) then return "ss_std" end

    return "unknown"
end

local W, H = lcd.getWindowSize()
local screenGroup = getScreenSize(W, H)

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

-- Theme Options based on screen size
local themeOptions = {

    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    ls_full = { cols = 8, rows = 16, font = "FONT_XXL", titlefont = "FONT_S", txgaugepaddingtop = 5, txgaugepaddingbottom = 20, txgaugepaddingleft = 25, txgaugepaddingright = 0, 
                rssivaluepaddingleft = 40, barpadding = 5, barpaddingbottom = 20, barpaddingleft = 60, barpaddingright = 60, gaugepadding = 10, thickness = 50, valuepaddingtop = 40},

    ls_std  = { cols = 8, rows = 14, font = "FONT_XL", titlefont = "FONT_XS", thickness = 30},

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = { cols = 8, rows = 16, font = "FONT_XL", titlefont = "FONT_XS", txgaugepaddingtop = 2, txgaugepaddingbottom = 5, txgaugepaddingleft = 0, txgaugepaddingright = 0, 
                rssivaluepaddingleft = 10, barpadding = 2, barpaddingbottom = 5, barpaddingleft = 30, barpaddingright = 30, thickness = 35, valuepaddingtop = 20},

    ms_std  = { cols = 8, rows = 14, font = "FONT_XL", titlefont = "FONT_XXS", thickness = 25},

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = { cols = 8, rows = 16, font = "FONT_XXL", titlefont = "FONT_S", txgaugepaddingtop = 5, txgaugepaddingbottom = 10, txgaugepaddingleft = 25, txgaugepaddingright = 0, 
                rssivaluepaddingleft = 40, barpadding = 5, barpaddingbottom = 10, barpaddingleft = 60, barpaddingright = 60, gaugepadding = 10, thickness = 40, valuepaddingtop = 30},
                
    ss_std  = { cols = 8, rows = 14, font = "FONT_XL", titlefont = "FONT_XXS", thickness = 25},

    -- Fallbacks
    unknown = { cols = 8, rows = 16, font = "FONT_XXL", titlefont = "FONT_S", txgaugepaddingtop = 5, txgaugepaddingbottom = 20, txgaugepaddingleft = 25, txgaugepaddingright = 0, 
                rssivaluepaddingleft = 40, barpadding = 5, barpaddingbottom = 20, barpaddingleft = 60, barpaddingright = 60, gaugepadding = 10, thickness = 50, valuepaddingtop = 40},
}

-- Theme Layout
local function getLayout()
    local opts = themeOptions[screenGroup] or themeOptions.unknown
    return { cols = opts.cols, rows = opts.rows }
end

-- BOXES CACHE
local boxes_cache = nil
local themeconfig = nil
local lastWindowWidth = nil
local lastWindowHeight = nil

local function buildBoxes()
    local opts = themeOptions[screenGroup] or themeOptions.unknown

    local boxes = {  

        { 
            col = 1, 
            row = 1,
            colspan = 2,
            rowspan = 2, 
            type = "text", 
            subtype = "craftname", 
            font = "FONT_L", 
            valuepaddingleft = 10, 
            bgcolor = colorMode.bgcolor, 
            titlecolor = colorMode.titlecolor, 
            textcolor = colorMode.textcolor
        },
        {
            col = 3, 
            row = 1,
            colspan = 3,
            rowspan = 2, 
            type = "image", 
            subtype = "image", 
            bgcolor = colorMode.bgcolor
        },
        {
            col = 6, 
            row = 1,
            rowspan = 2, 
            type = "gauge", 
            subtype = "bar", 
            source = "txbatt",
            font = "FONT_S", 
            battery = true, 
            batteryframe = true, 
            hidevalue = true,
            batteryframethickness = 2,
            gaugepaddingtop = opts.txgaugepaddingtop, 
            gaugepaddingbottom = opts.txgaugepaddingbottom, 
            gaugepaddingleft = opts.txgaugepaddingleft, 
            gaugepaddingright = opts.txgaugepaddingright,
            batterysegments = 4, 
            batterysegmentpaddingtop = 4, 
            batterysegmentpaddingbottom = 4, 
            batterysegmentpaddingleft = 4, 
            batterysegmentpaddingright = 3, 
            batteryspacing = 1,
            fillcolor = colorMode.fillcolor, 
            bgcolor = colorMode.bgcolor, 
            accentcolor = colorMode.txaccentcolor, 
            textcolor = colorMode.textcolor,
            min = 7.2, 
            max = 8.4, 
            thresholds = {
            { value = 7.4, fillcolor = "orange"   },
            { value = 8.4, fillcolor = "darkwhite"  }
            }                        
        },
        {
            col = 7, 
            row = 1,
            colspan = 2,
            rowspan = 2, 
            type = "gauge", 
            subtype = "step", 
            source = "rssi",            
            font = "FONT_XS", 
            barpadding = opts.barpadding, 
            stepgap = 3, 
            stepcount = 5, 
            decimals = 0,
            valuealign = "left", 
            valuepaddingbottom = 30, 
            valuepaddingleft = opts.rssivaluepaddingleft,
            barpaddingbottom = opts.barpaddingbottom,
            barpaddingleft = opts.barpaddingleft, 
            barpaddingright = opts.barpaddingright,
            bgcolor = colorMode.bgcolor, 
            textcolor = colorMode.textcolor, 
            fillcolor = colorMode.rssifillcolor, 
        },
        {
            type = "gauge",
            subtype = "arc",
            col = 1, row = 1,
            rowspan = 12,
            colspan = 4,
            source = "voltage",
            thickness = opts.thickness,
            valuepaddingtop = opts.valuepaddingtop,
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
        {
            type = "gauge",
            subtype = "arc",
            col = 5, row = 1,
            colspan = 4,
            rowspan = 12,
            thickness = opts.thickness,
            valuepaddingtop = opts.valuepaddingtop,
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
            textcolor = colorMode.textcolor,
            thresholds = {
                { value = 30,  fillcolor = "red",    textcolor = colorMode.textcolor },
                { value = 50,  fillcolor = "orange", textcolor = colorMode.textcolor },
                { value = 140, fillcolor = colorMode.fillcolor,  textcolor = colorMode.textcolor }
            },
        },
        {
            col = 1,
            row = 13,
            colspan = 2,
            rowspan = 2,
            type = "text",
            subtype = "governor",
            thresholds = {
                { value = i18n("widgets.governor.DISARMED"), textcolor = "red"    },
                { value = i18n("widgets.governor.OFF"),      textcolor = "red"    },
                { value = i18n("widgets.governor.IDLE"),     textcolor = "yellow" },
                { value = i18n("widgets.governor.SPOOLUP"),  textcolor = "blue"   },
                { value = i18n("widgets.governor.RECOVERY"), textcolor = "orange" },
                { value = i18n("widgets.governor.ACTIVE"),   textcolor = "green"  },
                { value = i18n("widgets.governor.THR-OFF"),  textcolor = "red"    },
            },
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
        },
        {
            col = 7,
            row = 13,
            colspan = 2,
            rowspan = 2,
            type = "time",
            subtype = "flight",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
        }, 
        {
            col = 5,
            row = 13,
            colspan = 2,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "rpm",
            unit = "rpm",
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
        },    
        {
            col = 3,
            row = 13,
            colspan = 2,
            rowspan = 2,
            type = "text",
            subtype = "telemetry",
            source = "rssi",
            unit = "dB",
            transform = "floor",
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.titlecolor,
        },    
    }
    if screenGroup and screenGroup:find("_full") then
        for _, box in ipairs(boxes) do
            -- Do not shift these four specific boxes
            local isTopRow =
                (box.type == "text"  and box.subtype == "craftname") or
                (box.type == "image" and box.subtype == "image") or
                (box.type == "gauge" and box.subtype == "bar" and box.source == "txbatt") or
                (box.type == "gauge" and box.subtype == "step" and box.source == "rssi")
            if not isTopRow then
                box.row = (box.row or 1) + 2
            end
        end
    end
    
    return boxes
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
    layout = getLayout,
    boxes = boxes,
    scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
    }     
}

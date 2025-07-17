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

-- Theme based configuration settings
local theme_section = "system/@aerc"

local THEME_DEFAULTS = {
    rpm_min      = 0,
    rpm_max      = 3000,
    bec_min      = 3.0,
    bec_max      = 13.0,
    esctemp_warn = 90,
    esctemp_max  = 140,
    tx_min       = 7.2,
    tx_warn      = 7.4,
    tx_max       = 8.4
}

-- Theme Options based on screen size
local themeOptions = {

    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    ls_full = { cols = 7, rows = 12, thickness = 30, font = "FONT_XXL", advfont = "FONT_M", batteryframethickness = 4, 
                titlepaddingbottom = 15, valuepaddingleft = 25, valuepaddingtop = 20, valuepaddingbottom = 25, 
                gaugepaddingtop = 20, battadvpaddingtop = 20, txgaugepaddingtop = 5, txgaugepaddingbottom = 5, txgaugepaddingleft = 26, txgaugepaddingright = 25, 
                rssivaluepaddingleft = 12, barpadding = 5, barpaddingleft = 15, barpaddingright = 15},

    ls_std  = { cols = 7, rows = 11, thickness = 11, font = "FONT_XL", advfont = "FONT_M", batteryframethickness = 4, 
                titlepaddingbottom = 0, valuepaddingleft = 75, valuepaddingtop = 5, valuepaddingbottom = 25, gaugepaddingtop = 5, battadvpaddingtop = 5},

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = { cols = 7, rows = 12, thickness = 20, font = "FONT_XL", advfont = "FONT_M", batteryframethickness = 4, 
                titlepaddingbottom = 0, valuepaddingleft = 20, valuepaddingtop = 5, valuepaddingbottom = 15, gaugepaddingtop = 5, battadvpaddingtop = 5, 
                txgaugepaddingtop = 2, txgaugepaddingbottom = 2, txgaugepaddingleft = 10, txgaugepaddingright = 9, 
                rssivaluepaddingleft = 7, barpadding = 2, barpaddingleft = 5, barpaddingright = 5},

    ms_std  = { cols = 7, rows = 11, thickness = 12, font = "FONT_L", advfont = "FONT_S", batteryframethickness = 2, 
                titlepaddingbottom = 0, valuepaddingleft = 20, valuepaddingtop = 10, valuepaddingbottom = 25, gaugepaddingtop = 5, battadvpaddingtop = 0},

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = { cols = 7, rows = 12, thickness = 20, font = "FONT_XL", advfont = "FONT_M", batteryframethickness = 4, 
                titlepaddingbottom = 0, valuepaddingleft = 20, valuepaddingtop = 5, valuepaddingbottom = 15, 
                gaugepaddingtop = 5, battadvpaddingtop = 5, txgaugepaddingtop = 2, txgaugepaddingbottom = 2, txgaugepaddingleft = 12, txgaugepaddingright = 12, 
                rssivaluepaddingleft = 9, barpadding = 2, barpaddingleft = 13, barpaddingright = 13},

    ss_std  = { cols = 7, rows = 11, thickness = 12, font = "FONT_L", advfont = "FONT_S", batteryframethickness = 2, 
                titlepaddingbottom = 0, valuepaddingleft = 20, valuepaddingtop = 10, valuepaddingbottom = 25, gaugepaddingtop = 5, battadvpaddingtop = 0},

    -- Fallbacks
    unknown = { cols = 7, rows = 11, thickness = 11, font = "FONT_XL", advfont = "FONT_M", batteryframethickness = 4, 
                titlepaddingbottom = 0, valuepaddingleft = 75, valuepaddingtop = 5, valuepaddingbottom = 25, gaugepaddingtop = 5, battadvpaddingtop = 5},
}

local function getThemeValue(key)
    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then return val end
    end
    return THEME_DEFAULTS[key]
end

-- Caching for boxes
local boxes_cache = nil
local themeconfig = nil
local lastWindowWidth = nil
local lastWindowHeight = nil

-- Theme Layout
local function getLayout()
    local opts = themeOptions[screenGroup] or themeOptions.unknown
    return { cols = opts.cols, rows = opts.rows }
end

-- Boxes
local function buildBoxes()
    local opts = themeOptions[screenGroup] or themeOptions.unknown

    local boxes = {

        -- Craftname
        { col = 1, row = 1, colspan = 2, type = "text", subtype = "craftname", font = "FONT_L", valuepaddingleft = 100, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor},
        
        -- RF Logo
        {col = 3, row = 1, colspan = 3, type = "image", subtype = "image", bgcolor = colorMode.bgcolor},

        -- TX Battery
        {col = 5, row = 1,
        type = "gauge", subtype = "bar", source = "txbatt",
        font = "FONT_S", battery = true, batteryframe = true, hidevalue = true,
        batteryframethickness = 2, decimals = 1, unit = "v", valuepaddingleft = 35, valuepaddingbottom = 10, valuealign = "left",
        gaugepaddingtop = opts.txgaugepaddingtop, gaugepaddingbottom = opts.txgaugepaddingbottom, gaugepaddingleft = opts.txgaugepaddingleft, gaugepaddingright = opts.txgaugepaddingright,
        batterysegments = 4, batterysegmentpaddingtop = 4, batterysegmentpaddingbottom = 4, batterysegmentpaddingleft = 4, batterysegmentpaddingright = 3, batteryspacing = 1,
        fillcolor = colorMode.fillcolor, bgcolor = colorMode.bgcolor, accentcolor = colorMode.txaccentcolor, textcolor = colorMode.textcolor,
        min = getThemeValue("tx_min"), max = getThemeValue("tx_max"), 
        thresholds = {
            { value = getThemeValue("tx_warn"), fillcolor = "orange"   },
            { value = getThemeValue("tx_max"), fillcolor = "darkwhite"  }
        }                        
        },

        -- RSSI
        {col = 7, row = 1,
        type = "gauge", subtype = "step", source = "rssi",            
        font = "FONT_XS", barpadding = opts.barpadding, stepgap = 3, stepcount = 5, decimals = 0,
        valuealign = "left", valuepaddingbottom = 20, valuepaddingleft = opts.rssivaluepaddingleft,
        barpaddingleft = opts.barpaddingleft, barpaddingright = opts.barpaddingright,
        bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, fillcolor = colorMode.rssifillcolor, 
        },

        -- Model Image
        {col = 1, row = 1, colspan = 3, rowspan = 8, type = "image", subtype = "model", bgcolor = colorMode.bgcolor},
        
        -- Rates
        {col = 1, row = 9, rowspan = 3,
        type = "text", subtype = "telemetry", source = "rate_profile",
        title = i18n("widgets.dashboard.rates"):upper(), titlepos = "bottom",
        font = "FONT_XL",
        bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor,
        transform = "floor",
        thresholds = {
            { value = 1.5, textcolor = "blue" },
            { value = 2.5, textcolor = "orange" },
            { value = 6,   textcolor = "green" }
        }
        },

        -- PID
        {col = 2, row = 9, rowspan = 3,
        type = "text", subtype = "telemetry", source = "pid_profile",
        title = i18n("widgets.dashboard.profile"):upper(), titlepos = "bottom",
        font = "FONT_XL",
        bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor,
        transform = "floor",
        thresholds = {
            { value = 1.5, textcolor = "blue" },
            { value = 2.5, textcolor = "orange" },
            { value = 6,   textcolor = "green" }
        }
        },
        
        -- Flights
        {col = 3, row = 9, rowspan = 3,
        type = "time", subtype = "count",
        title = i18n("widgets.dashboard.flights"):upper(), titlepos = "bottom",
        font = "FONT_XL",
        bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
        },

        -- Fuel Bar
        {col = 4, row = 1, colspan = 4, rowspan = 3,
        type = "gauge", source = "smartfuel", 
        batteryframe = true, battadv = true, batteryframethickness = opts.batteryframethickness,
        font = opts.font,
        valuealign = "left", valuepaddingleft = opts.valuepaddingleft, valuepaddingtop = opts.valuepaddingtop,
        gaugepaddingleft = 5, gaugepaddingright = 5, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = 3,
        battadvfont = opts.advfont, battadvpaddingright = 25, battadvpaddingtop = opts.battadvpaddingtop, battadvvaluealign = "right",
        fillcolor = "green", bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor, accentcolor = colorMode.accentcolor,
        transform = "floor",
        thresholds = {
            { value = 10, fillcolor = "red" },
            { value = 30, fillcolor = "orange" }
        }
        },

        -- BEC Voltage
        {col = 4, colspan = 2, row = 4, rowspan = 5,
        type = "gauge", subtype = "arc", source = "bec_voltage",
        title = i18n("widgets.dashboard.bec_voltage"):upper(), titlepos = "bottom", titlepaddingbottom = opts.titlepaddingbottom,
        font = opts.font,
        min = getThemeValue("bec_min"), max = getThemeValue("bec_max"),
        decimals = 1, thickness = opts.thickness,
        bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor, 
        thresholds = {
            { value = getThemeValue("bec_min"), fillcolor = "red" },
            { value = getThemeValue("bec_max"), fillcolor = "green" }
        }
        },

        -- Blackbox
        {col = 4, row = 9, colspan = 2, rowspan = 3,
        type = "text", subtype = "blackbox",
        title = i18n("widgets.dashboard.blackbox"):upper(), titlepos = "bottom",
        font = "FONT_XL", decimals = 0,
        bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor,
        transform = "floor", 
        thresholds = {
            { value = 80, textcolor = colorMode.textcolor },
            { value = 90, textcolor = "orange" },
            { value = 100, textcolor = "red" }
        }
        },

        -- ESC Temp
        {col = 6, colspan = 2, row = 4, rowspan = 5,
        type = "gauge", subtype = "arc", source = "temp_esc",
        title = i18n("widgets.dashboard.esc_temp"):upper(), titlepos = "bottom",
        font = opts.font,
        min = 0, max = getThemeValue("esctemp_max"), thickness = opts.thickness,
        valuepaddingleft = 10, 
        bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
        titlepaddingbottom = opts.titlepaddingbottom,
        transform = "floor",
        thresholds = {
            { value = getThemeValue("esctemp_warn"), fillcolor = "green" },
            { value = getThemeValue("esctemp_max"), fillcolor = "orange" },
            { value = 200, fillcolor = "red" }
        }
        },

        -- Governor
        {col = 6, row = 9, colspan = 2, rowspan = 3,
        type = "text", subtype = "governor",
        title = i18n("widgets.dashboard.governor"):upper(), titlepos = "bottom",
        font = "FONT_XL",
        bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor,
        thresholds = {
            { value = i18n("widgets.governor.DISARMED"), textcolor = "red" },
            { value = i18n("widgets.governor.OFF"), textcolor = "red" },
            { value = i18n("widgets.governor.IDLE"), textcolor = "blue" },
            { value = i18n("widgets.governor.SPOOLUP"), textcolor = "blue" },
            { value = i18n("widgets.governor.RECOVERY"), textcolor = "orange" },
            { value = i18n("widgets.governor.ACTIVE"), textcolor = "green" },
            { value = i18n("widgets.governor.THR-OFF"), textcolor = "red" }
        }
        }
    }

    if screenGroup and screenGroup:find("_full") then
        for _, box in ipairs(boxes) do
            -- Top row (logo, craftname, txbatt, rssi)
            if box.type == "text" and box.subtype == "craftname" then
                box.col = 1; box.row = 1; box.colspan = 2
            elseif box.type == "image" and box.subtype == "image" then
                box.col = 3; box.row = 1; box.colspan = 3
            elseif box.type == "gauge" and box.subtype == "bar" and box.source == "txbatt" then
                box.col = 6; box.row = 1
            elseif box.type == "gauge" and box.subtype == "step" and box.source == "rssi" then
                box.col = 7; box.row = 1

            -- Model Image, Throttle, BEC Voltage, ESC Temp: shift down by 1, increase rowspan
            elseif (box.type == "image" and box.subtype == "model")
                or (box.type == "text" and box.subtype == "telemetry" and box.source == "throttle_percent")
                or (box.type == "gauge" and box.subtype == "arc" and (box.source == "bec_voltage" or box.source == "temp_esc"))
            then
                box.row = (box.row or 1) + 1
                box.rowspan = (box.rowspan or 1) + 1

            -- Tally group: shift down by 2, reduce rowspan
            elseif (box.type == "text" and box.subtype == "blackbox") or
                (box.type == "text" and box.subtype == "governor") or
                (box.type == "text" and box.subtype == "telemetry" and (box.source == "rate_profile" or box.source == "pid_profile")) or
                (box.type == "time" and box.subtype == "count") then
                box.row = (box.row or 1) + 2
                box.rowspan = math.max(1, (box.rowspan or 1) - 1)
            -- Everything else: shift down by 1
            else
                box.row = (box.row or 1) + 1
            end
        end
    end

    return boxes
end

local function boxes()
    local config =
        rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section]
    local W, H = lcd.getWindowSize()
    -- Detect layout size change
    if boxes_cache == nil
        or themeconfig ~= config
        or lastWindowWidth ~= W
        or lastWindowHeight ~= H then
        -- Re-evaluate screen group and options
        screenGroup = getScreenSize(W, H)
        boxes_cache = buildBoxes()
        themeconfig = config
        lastWindowWidth = W
        lastWindowHeight = H
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

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

-- Theme config section for Nitro
local theme_section = "system/@aerc-n"

local THEME_DEFAULTS = {
    v_min      = 7.0,
    v_max      = 8.4,
    rpm_min    = 0,
    rpm_max    = 3000,
    tx_min     = 7.2,
    tx_warn    = 7.4,
    tx_max     = 8.4
}

-- Theme Options based on screen size
local themeOptions = {

    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    ls_full = { cols = 6, rows = 13, font = "FONT_XXL", titlefont = "FONT_S", valuepaddingbottom = 20, titlepaddingtop = 15, 
                txgaugepaddingtop = 5, txgaugepaddingbottom = 5, txgaugepaddingleft = 36, txgaugepaddingright = 34, 
                rssivaluepaddingleft = 22, barpadding = 5, barpaddingleft = 25, barpaddingright = 25},

    ls_std  = { cols = 6, rows = 12, font = "FONT_XL", titlefont = "FONT_XS", valuepaddingbottom = 25, titlepaddingtop = 0},

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = { cols = 6, rows = 13, font = "FONT_XL", titlefont = "FONT_XS", valuepaddingbottom = 15, titlepaddingtop = 5, 
                txgaugepaddingtop = 2, txgaugepaddingbottom = 0, txgaugepaddingleft = 18, txgaugepaddingright = 17, 
                rssivaluepaddingleft = 10, barpadding = 2, barpaddingleft = 5, barpaddingright = 5},

    ms_std  = { cols = 6, rows = 12, font = "FONT_XL", titlefont = "FONT_XXS", valuepaddingbottom = 0, titlepaddingtop = 0},

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = { cols = 6, rows = 13, font = "FONT_XL", titlefont = "FONT_XS", valuepaddingbottom = 15, titlepaddingtop = 5, 
                txgaugepaddingtop = 2, txgaugepaddingbottom = 2, txgaugepaddingleft = 25, txgaugepaddingright = 24, 
                rssivaluepaddingleft = 9, barpadding = 2, barpaddingleft = 13, barpaddingright = 13},
                
    ss_std  = { cols = 6, rows = 12, font = "FONT_XL", titlefont = "FONT_XXS", valuepaddingbottom = 0, titlepaddingtop = 0},

    -- Fallbacks
    unknown = { cols = 6, rows = 12, font = "FONT_XL", titlefont = "FONT_XS", valuepaddingbottom = 25, titlepaddingtop = 0},
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

local function buildBoxes()
    local vmin = getThemeValue("v_min")
    local vmax = getThemeValue("v_max")
    local opts = themeOptions[screenGroup] or themeOptions.unknown

    local boxes = {
        -- Craftname
        { col = 1, row = 1, colspan = 2, type = "text", subtype = "craftname", font = "FONT_L", valuepaddingleft = 10, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor},

        -- RF Logo
        {col = 3, row = 1, colspan = 2, type = "image", subtype = "image", bgcolor = colorMode.bgcolor},

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
        {col = 6, row = 1,
        type = "gauge", subtype = "step", source = "rssi",            
        font = "FONT_XS", barpadding = opts.barpadding, stepgap = 3, stepcount = 5, decimals = 0,
        valuealign = "left", valuepaddingbottom = 20, valuepaddingleft = opts.rssivaluepaddingleft,
        barpaddingleft = opts.barpaddingleft, barpaddingright = opts.barpaddingright,
        bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, fillcolor = colorMode.rssifillcolor, 
        },

        -- Throttle
        {col = 1, colspan = 2, row = 1, rowspan = 3,
        type = "text",
        subtype = "telemetry",
        source = "throttle_percent",
        title = i18n("widgets.dashboard.throttle"):upper(), 
        titlepos = "bottom", 
        font = opts.font,
        transform = "floor",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        thresholds = {
            { value = 20,  textcolor = colorMode.textcolor },
            { value = 80,  textcolor = "yellow" },
            { value = 100, textcolor = "red" }
            }
        },

        -- Headspeed
        {col = 1, colspan = 2, row = 4, rowspan = 3,
        type = "text",
        subtype = "telemetry",
        source = "rpm",
        title = i18n("widgets.dashboard.headspeed"):upper(),  
        titlepos = "bottom",
        font = opts.font,
        unit = " rpm", 
        transform = "floor",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        },

        -- Blackbox
        {col = 1, colspan = 2, row = 7, rowspan = 3, 
        type = "text", 
        subtype = "blackbox", 
        title = i18n("widgets.dashboard.blackbox"):upper(), 
        titlepos = "bottom",
        font = opts.font,
        decimals = 0, 
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        transform = "floor",
            thresholds = {
                { value = 80, textcolor = colorMode.textcolor },
                { value = 90, textcolor = "orange" },
                { value = 100, textcolor = "red" }
            }
        },

        -- Governor
        {col = 1, colspan = 2, row = 10, rowspan = 3,
        type = "text", 
        subtype = "governor", 
        title = i18n("widgets.dashboard.governor"):upper(), 
        titlepos = "bottom",
        font = opts.font,
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        thresholds = {
                { value = "DISARMED", textcolor = "red"    },
                { value = "OFF",      textcolor = "red"    },
                { value = "IDLE",     textcolor = "blue" },
                { value = "SPOOLUP",  textcolor = "blue"   },
                { value = "RECOVERY", textcolor = "orange" },
                { value = "ACTIVE",   textcolor = "green"  },
                { value = "THR-OFF",  textcolor = "red"    },
            }
        },

        -- Model Image
        {col = 3, row = 1, colspan = 3, rowspan = 9, type = "image", subtype = "model", bgcolor = colorMode.bgcolor},

        -- Rate Profile
        {col = 3, row = 10, rowspan = 3,
        type = "text",
        subtype = "telemetry",
        source = "rate_profile",    
        title = i18n("widgets.dashboard.rates"):upper(), 
        titlepos = "bottom",
        font = opts.font,
        transform = "floor",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
            thresholds = {
                { value = 1.5, textcolor = "blue" },
                { value = 2.5, textcolor = "orange" },
                { value = 6,   textcolor = "green"  }
            }
        },

        -- PID Profile
        {col = 4, row = 10, rowspan = 3,
        type = "text",
        subtype = "telemetry",
        source = "pid_profile",    
        title = i18n("widgets.dashboard.profile"):upper(),
        titlepos = "bottom",
        font = opts.font,
        transform = "floor",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
            thresholds = {
                { value = 1.5, textcolor = "blue" },
                { value = 2.5, textcolor = "orange" },
                { value = 6,   textcolor = "green"  }
            }
        },

        -- Flight Count
        {col = 5, row = 10, rowspan = 3, 
        type = "time", 
        subtype = "count", 
        title = i18n("widgets.dashboard.flights"):upper(), 
        titlepos = "bottom",
        font = opts.font,
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        },

        -- Voltage
        {col = 6, colspan = 1, row = 1, rowspan = 12,
        type = "gauge", 
        source = "bec_voltage", 
        title = i18n("widgets.dashboard.voltage"):upper(), 
        titlepos = "bottom", 
        gaugeorientation = "vertical",
        gaugepaddingright = 10,
        gaugepaddingleft = 10,
        gaugepaddingtop = 5,
        gaugepaddingbottom = 5,
        decimals = 1,
        battery = true,
        batteryspacing = 1,
        valuepaddingbottom = 17,
        valuepaddingleft = 8,
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        min = getThemeValue("v_min"),
        max = getThemeValue("v_max"),
        thresholds = {
            { value = vmin + 0.2 * (vmax - vmin), fillcolor = "red"    },
            { value = vmin + 0.4 * (vmax - vmin), fillcolor = "orange" },
            { value = vmax,                       fillcolor = "green"  }
            }
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

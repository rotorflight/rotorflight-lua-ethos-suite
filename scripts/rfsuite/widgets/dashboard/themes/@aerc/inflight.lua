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

-- Theme config support
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
    ls_full = { cols = 6, rows = 12, font = "FONT_XXL", advfont = "FONT_L", thickness = 28, gaugepadding = 10, gaugepaddingbottom = 40, 
                maxpaddingtop = 60, maxpaddingleft = 20, valuepaddingbottom = 25, maxfont = "FONT_L", 
                txgaugepaddingtop = 5, txgaugepaddingbottom = 5, txgaugepaddingleft = 36, txgaugepaddingright = 34, 
                rssivaluepaddingleft = 22, barpadding = 5, barpaddingleft = 25, barpaddingright = 25},

    ls_std  = { cols = 6, rows = 11, font = "FONT_XL", advfont = "FONT_M", thickness = 20, gaugepadding = 0, gaugepaddingbottom = 0, 
                maxpaddingtop = 30, maxpaddingleft = 10, valuepaddingbottom = 0, maxfont = "FONT_S"},

    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = { cols = 6, rows = 12, font = "FONT_XL", advfont = "FONT_M", thickness = 17, gaugepadding = 5, gaugepaddingbottom = 20, 
                maxpaddingtop = 30, maxpaddingleft = 10, valuepaddingbottom = 15, maxfont = "FONT_S", 
                txgaugepaddingtop = 2, txgaugepaddingbottom = 2, txgaugepaddingleft = 18, txgaugepaddingright = 17, 
                rssivaluepaddingleft = 10, barpadding = 2, barpaddingleft = 5, barpaddingright = 5},

    ms_std  = { cols = 6, rows = 11, font = "FONT_XL", advfont = "FONT_M", thickness = 14, gaugepadding = 0, gaugepaddingbottom = 0, 
                maxpaddingtop = 20, maxpaddingleft = 10, valuepaddingbottom = 0, maxfont = "FONT_S"},

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = { cols = 6, rows = 12, font = "FONT_XXL", advfont = "FONT_M", thickness = 19, gaugepadding = 5, gaugepaddingbottom = 20, 
                maxpaddingtop = 30, maxpaddingleft = 10, valuepaddingbottom = 15, maxfont = "FONT_S", 
                txgaugepaddingtop = 2, txgaugepaddingbottom = 2, txgaugepaddingleft = 22, txgaugepaddingright = 21, 
                rssivaluepaddingleft = 9, barpadding = 2, barpaddingleft = 13, barpaddingright = 13},

    ss_std  = { cols = 6, rows = 11, font = "FONT_XL", advfont = "FONT_M", thickness = 14, gaugepadding = 0, gaugepaddingbottom = 0, 
                maxpaddingtop = 20, maxpaddingleft = 10, valuepaddingbottom = 0, maxfont = "FONT_S"},

    -- Fallbacks
    unknown = { cols = 6, rows = 11, font = "FONT_XL", advfont = "FONT_M", thickness = 20, gaugepadding = 0, gaugepaddingbottom = 0, 
                maxpaddingtop = 30, maxpaddingleft = 10, valuepaddingbottom = 0, maxfont = "FONT_S"},
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
        {col = 1, row = 1, colspan = 2, type = "text", subtype = "craftname", font = "FONT_L", valuepaddingleft = 10, bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor},

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

        -- Timer
        {col = 1, colspan = 2, row = 1, rowspan = 3, 
        type = "time", subtype = "flight", 
        font = opts.font,
        title = i18n("widgets.dashboard.flight_time"):upper(),
        titlepos = "bottom",
        bgcolor = colorMode.bgcolor,
        titlecolor = colorMode.titlecolor,
        textcolor = colorMode.textcolor,
        },

        -- Battery Bar
        {col = 3, row = 1, colspan = 4, rowspan = 3,
        type = "gauge", source = "smartfuel", battadv = true,
        fillcolor = "green",
        valuealign = "left", valuepaddingleft = 85, valuepaddingbottom = 10,
        battadvfont = "FONT_M", font = opts.font,
        battadvpaddingright = 5, battadvvaluealign = "right",
        transform = "floor",
        titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor,
        thresholds = {
            { value = 10,  fillcolor = "red"    },
            { value = 30,  fillcolor = "orange" }
        }
        },

        -- Throttle
        {col = 1, colspan = 2, row = 4, rowspan = 8,
        type = "gauge", subtype = "arc", source = "throttle_percent", arcmax = true,
        title = i18n("widgets.dashboard.throttle"):upper(), titlepos = "bottom", 
        thickness = opts.thickness, font = opts.font, maxfont = opts.maxfont,
        maxprefix = "Max: ", maxpaddingtop = opts.maxpaddingtop,
        gaugepadding = opts.gaugepadding, gaugepaddingbottom = opts.gaugepaddingbottom, valuepaddingbottom = opts.valuepaddingbottom,
        bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor, maxtextcolor = "orange",
        transform = "floor",
        thresholds = {
            { value = 89,  fillcolor = "blue"       },
            { value = 100, fillcolor = "darkblue"   }
        }
        },

        -- Headspeed
        {col = 3, colspan = 2, row = 4, rowspan = 8,
        type = "gauge", subtype = "arc", source = "rpm", arcmax = true,
        title = i18n("widgets.dashboard.headspeed"):upper(), titlepos = "bottom", 
        min = 0, max = getThemeValue("rpm_max"),
        thickness = opts.thickness,
        unit = "",
        maxprefix = "Max: ", font = opts.font, maxpaddingtop = opts.maxpaddingtop, maxfont = opts.maxfont,
        gaugepadding = opts.gaugepadding, gaugepaddingbottom = opts.gaugepaddingbottom, valuepaddingbottom = opts.valuepaddingbottom,
        bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor, maxtextcolor = "orange",
        transform = "floor",
        thresholds = {
            { value = getThemeValue("rpm_min"),   fillcolor = "lightpurple"   },
            { value = getThemeValue("rpm_max"),   fillcolor = "purple"        },
            { value = 10000,                      fillcolor = "darkpurple"    }
        }
        },

        -- ESC Temp
        {col = 5, colspan = 2, row = 4, rowspan = 8,
        type = "gauge", subtype = "arc", source = "temp_esc", arcmax = true,
        title = i18n("widgets.dashboard.esc_temp"):upper(), titlepos = "bottom", 
        min = 0, max = getThemeValue("esctemp_max"), 
        thickness = opts.thickness,
        valuepaddingleft = 10, valuepaddingbottom = opts.valuepaddingbottom, maxpaddingleft = opts.maxpaddingleft, maxpaddingtop = opts.maxpaddingtop,
        maxprefix = "Max: ",maxfont = opts.maxfont, font = opts.font,
        gaugepadding = opts.gaugepadding, gaugepaddingbottom = opts.gaugepaddingbottom,
        bgcolor = colorMode.bgcolor, titlecolor = colorMode.titlecolor, textcolor = colorMode.textcolor, maxtextcolor = "orange",
        transform = "floor", 
        thresholds = {
            { value = getThemeValue("esctemp_warn"), fillcolor = "green"  },
            { value = getThemeValue("esctemp_max"),  fillcolor = "orange" },
            { value = 200,                           fillcolor = "red"    }
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

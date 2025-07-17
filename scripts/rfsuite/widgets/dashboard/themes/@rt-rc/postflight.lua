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

local function maxVoltageToCellVoltage(value)
    local cfg = rfsuite.session.batteryConfig
    local cells = (cfg and cfg.batteryCellCount) or 3

    if cfg and cells and value then
        value = math.max(0, value / cells)
        value = math.floor(value * 100 + 0.5) / 100  -- round to 2 decimal places
    end

    return value
end

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
                txgaugepaddingtop = 2, txgaugepaddingbottom = 2, txgaugepaddingleft = 22, txgaugepaddingright = 21, 
                rssivaluepaddingleft = 9, barpadding = 2, barpaddingleft = 13, barpaddingright = 13},

    ss_std  = { cols = 6, rows = 12, font = "FONT_XL", titlefont = "FONT_XXS", valuepaddingbottom = 0, titlepaddingtop = 0},

    -- Fallbacks
    unknown = { cols = 6, rows = 12, font = "FONT_XL", titlefont = "FONT_XS", valuepaddingbottom = 25, titlepaddingtop = 0},
}

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
        min = 7.2, max = 8.4, 
        thresholds = {
            { value = 7.4, fillcolor = "orange"   },
            { value = 8.4, fillcolor = "darkwhite"  }
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

        -- Flight info and RPM info
        {col = 1, row = 1, colspan = 2, rowspan = 3, type = "time", subtype = "flight", title = i18n("widgets.dashboard.flight_duration"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 1, row = 4, colspan = 2, rowspan = 3, type = "time", subtype = "total", title = i18n("widgets.dashboard.total_flight_duration"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 1, row = 7, colspan = 2, rowspan = 3, type = "text", subtype = "stats", stattype = "min", source = "rpm", title = i18n("widgets.dashboard.rpm_min"), unit = " rpm", titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 1, row = 10, colspan = 2, rowspan = 3, type = "text", subtype = "stats", source = "rpm", title = i18n("widgets.dashboard.rpm_max"), unit = " rpm", titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        -- Flight max/min stats 1
        {col = 3, row = 1, colspan = 2, rowspan = 3, type = "text", subtype = "stats", source = "throttle_percent", title = i18n("widgets.dashboard.throttle_max"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 3, row = 4, colspan = 2, rowspan = 3, type = "text", subtype = "stats", source = "current", title = i18n("widgets.dashboard.current_max"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 3, row = 7, colspan = 2, rowspan = 3, type = "text", subtype = "stats", source = "temp_esc", title = i18n("widgets.dashboard.esc_max_temp"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 3, row = 10, colspan = 2, rowspan = 3, type = "text", subtype = "watts", source = "max", title = i18n("widgets.dashboard.watts_max"), unit = "W", titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        -- Flight max/min stats 2
        {col = 5, row = 1, colspan = 2, rowspan = 3, type = "text", subtype = "stats", stattype = "max", source = "consumption", title = i18n("widgets.dashboard.consumed_mah"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 5, row = 4, colspan = 2, rowspan = 3, type = "text", subtype = "stats", stattype = "min", source = "smartfuel", title = i18n("widgets.dashboard.fuel_remaining"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 5, row = 7, colspan = 2, rowspan = 3, type = "text", subtype = "stats", stattype = "min", source = "voltage", title = i18n("widgets.dashboard.min_volts_cell"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, unit = "V", transform = function(v) return maxVoltageToCellVoltage(v) end, textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},

        {col = 5, row = 10, colspan = 2, rowspan = 3, type = "text", subtype = "stats", stattype = "min", source = "rssi", title = i18n("widgets.dashboard.link_min"), titlepos = "bottom", 
        bgcolor = colorMode.bgcolor, transform = "floor", textcolor = colorMode.textcolor, titlecolor = colorMode.titlecolor, titlepaddingtop = opts.titlepaddingtop, font = opts.font, titlefont = opts.titlefont},
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
    local W, H = lcd.getWindowSize()
    -- Detect layout size change
    if boxes_cache == nil
        or lastWindowWidth ~= W
        or lastWindowHeight ~= H then
        -- Re-evaluate screen group and options
        screenGroup = getScreenSize(W, H)
        boxes_cache = buildBoxes()
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

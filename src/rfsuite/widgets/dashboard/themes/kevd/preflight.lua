--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local tonumber = tonumber

local utils = rfsuite.widgets.dashboard.utils

local headeropts = utils.getHeaderOptions()
local colorMode = utils.themeColors()

local theme_section = "system/kevd"

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 5500, bec_min = 6.5, bec_warn = 7.4, bec_max = 11.0, esctemp_warn = 120, esctemp_max = 150}

local function getThemeValue(key)

    if key == "tx_min" or key == "tx_warn" or key == "tx_max" then
        if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
            local val = rfsuite.preferences.general[key]
            if val ~= nil then return tonumber(val) end
        end
    end

    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then return val end
    end
    return THEME_DEFAULTS[key]
end

local function getThemeOptionKey(W)
    return utils.getDashboardThemeOptionKey(W)
end

local themeOptions = {

    ls_full = {font = "FONT_XXL", advfont = "FONT_STD", titlefont = "FONT_XS", arctitlefont = "FONT_STD", brfont = "FONT_XL", tilefont = "FONT_XL", govfont = "FONT_XL", smartfont = "FONT_XXL", smartvaluefont = "FONT_XL", smartadvfont = "FONT_L", smartvaluepaddingtop = 36, smartbattadvpaddingright = 25, smartbattadvpaddingtop = -15, thickness = 32, batteryframethickness = 4, titlepaddingbottom = 25, valuepaddingleft = 25, valuepaddingtop = 20, gvaluepaddingtop = 30, valuepaddingbottom = 25, brvaluepaddingbottom = 20, gaugepaddingtop = 20, battadvpaddingtop = 20, cappaddingright = 4},

    ls_std = {font = "FONT_XL", advfont = "FONT_STD", titlefont = "FONT_XS", brfont = "FONT_XL", thickness = 18, batteryframethickness = 3, titlepaddingbottom = 25, valuepaddingleft = 55, valuepaddingtop = 5, gvaluepaddingtop = 20, valuepaddingbottom = 25, brvaluepaddingbottom = 15, gaugepaddingtop = 5, battadvpaddingtop = 8, cappaddingright = 5},

    ms_full = {font = "FONT_XXL", advfont = "FONT_STD", titlefont = "FONT_XS", arctitlefont = "FONT_S", brfont = "FONT_L", tilefont = "FONT_L", govfont = "FONT_L", smartfont = "FONT_XL", smartvaluefont = "FONT_L", smartadvfont = "FONT_STD", smartvaluepaddingtop = 12, smartbattadvpaddingright = 10, smartbattadvpaddingtop = -6, thickness = 19, batteryframethickness = 3, titlepaddingbottom = 16, valuepaddingleft = 20, valuepaddingtop = 10, gvaluepaddingtop = 20, valuepaddingbottom = 25, brvaluepaddingbottom = 8, gaugepaddingtop = 5, battadvpaddingtop = 2, cappaddingright = 2},

    ms_std = {font = "FONT_XL", advfont = "FONT_S", titlefont = "FONT_XS", arctitlefont = "FONT_S", brfont = "FONT_STD", tilefont = "FONT_STD", govfont = "FONT_STD", smartfont = "FONT_L", smartvaluefont = "FONT_STD", smartadvfont = "FONT_S", smartvaluepaddingtop = 8, smartbattadvpaddingright = 8, smartbattadvpaddingtop = -4, thickness = 14, batteryframethickness = 2, titlepaddingbottom = 10, valuepaddingleft = 20, valuepaddingtop = 10, gvaluepaddingtop = 20, valuepaddingbottom = 25, brvaluepaddingbottom = 8, gaugepaddingtop = 5, battadvpaddingtop = 3, cappaddingright = 3},

    ss_full = {font = "FONT_XL", advfont = "FONT_STD", titlefont = "FONT_XS", arctitlefont = "FONT_S", brfont = "FONT_XL", tilefont = "FONT_L", govfont = "FONT_L", smartfont = "FONT_XL", smartvaluefont = "FONT_L", smartadvfont = "FONT_STD", smartvaluepaddingtop = 12, smartbattadvpaddingright = 10, smartbattadvpaddingtop = -6, thickness = 25, batteryframethickness = 3, titlepaddingbottom = 15, valuepaddingleft = 20, valuepaddingtop = 10, gvaluepaddingtop = 25, valuepaddingbottom = 15, brvaluepaddingbottom = 15, gaugepaddingtop = 5, battadvpaddingtop = 5, cappaddingright = 3},

    ss_std = {font = "FONT_XL", advfont = "FONT_S", titlefont = "FONT_XS", arctitlefont = "FONT_S", brfont = "FONT_L", tilefont = "FONT_STD", govfont = "FONT_STD", smartfont = "FONT_L", smartvaluefont = "FONT_STD", smartadvfont = "FONT_S", smartvaluepaddingtop = 8, smartbattadvpaddingright = 8, smartbattadvpaddingtop = -4, thickness = 14, batteryframethickness = 2, titlepaddingbottom = 15, valuepaddingleft = 20, valuepaddingtop = 10, gvaluepaddingtop = 15, valuepaddingbottom = 25, brvaluepaddingbottom = 20, gaugepaddingtop = 5, battadvpaddingtop = 0, cappaddingright = 3}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local themeconfig = nil
local last_txbatt_type = nil

local layout = {cols = 7, rows = 12, padding = 0, bgcolor = colorMode.bgcolor}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 4
if header_layout and header_layout.height then
    header_layout.height = header_layout.height + topbarShiftY
end

local function applyScreenBorderStyle()
    local screenBorderStyle = {
        enabled = true,
        -- Match the SmartFuel / advanced battery outline color path.
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        -- Use the preflight screen background as the page fill so any exposed
        -- gaps from gauge offsets/resizing match the dashboard background.
        backgroundcolor = colorMode.bgcolor,
        borderwidth = 6,
        inset = -1
    }

    if utils.setScreenBorderStyle then
        utils.setScreenBorderStyle(screenBorderStyle)
    else
        utils._screenBorderStyle = screenBorderStyle
    end
end

applyScreenBorderStyle()

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)
        
        local headerBgColor = colorMode.headerbgcolor or colorMode.fillbgcolor or colorMode.bgcolor
        for _, box in ipairs(boxes) do
            box.bgcolor = headerBgColor
            box.offsety = (box.offsety or 0) + topbarShiftY
        end
        
        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function buildBoxes(W)

    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ls_full
    applyScreenBorderStyle()
    
    local footerBgColor = colorMode.headerbgcolor or colorMode.fillbgcolor or colorMode.bgcolor
    local screenBgColor = colorMode.bgcolor or footerBgColor
    local statusTileBg = {
        -- Outer/cell fill. This is the color visible around the rounded border
        -- so the area behind the tile matches the main preflight screen.
        backfillcolor = screenBgColor,
        fillcolor = colorMode.tbbgcolor or footerBgColor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 4,
        roundradius = 6,
        inset = 4,
        -- Lower tiles resized down by 4 px from the previous enlarged version.
        -- Left/right spacing stays at 4 px; top/bottom inset becomes 2 px each.
        insettop = 2,
        insetbottom = 2,
        contentpadding = 1
    }

    local statusTileRightEdgeBg = {
        -- Used with offsetx = -5 on right-edge tiles. The larger left inset
        -- keeps the left edge aligned while the right edge is pulled 5 px
        -- away from the screen border.
        backfillcolor = screenBgColor,
        fillcolor = colorMode.tbbgcolor or footerBgColor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 4,
        roundradius = 6,
        inset = 4,
        insetleft = 9,
        -- Lower tiles resized down by 4 px from the previous enlarged version.
        insettop = 2,
        insetbottom = 2,
        contentpadding = 1
    }

    local statusTileTopRowBg = {
        -- Rebuilt border style for Rates / Profile / Flights.
        -- Keep the top border fully inside the cell so it does not clip.
        backfillcolor = screenBgColor,
        fillcolor = colorMode.tbbgcolor or footerBgColor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 4,
        roundradius = 6,
        inset = 4,
        insettop = 4,
        insetbottom = 2,
        contentpadding = 1
    }

    local statusTileTopRowRightEdgeBg = {
        -- Top-row version for Flights.  Maintains the right-edge clearance.
        backfillcolor = screenBgColor,
        fillcolor = colorMode.tbbgcolor or footerBgColor,
        bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
        borderwidth = 4,
        roundradius = 6,
        inset = 4,
        insetleft = 9,
        insettop = 4,
        insetbottom = 2,
        contentpadding = 1
    }

    return {

        {
            col = 1,
            row = 1,
            colspan = 3,
            rowspan = 9,
            type = "image",
            subtype = "model",
            imagewidth = 280,
            imageheight = 300,
            imagealign = "center",
            bgcolor = colorMode.bgcolor
        },
        {
            col = 4,
            row = 9,
            rowspan = 2,
            offsety = -10,
            type = "text",
            subtype = "telemetry",
            source = "rate_profile",
            title = "RATES",
            titlepos = "bottom",
            font = opts.tilefont,
            titlefont = opts.titlefont,
            valuepaddingbottom = 6,
            bgcolor = statusTileTopRowBg,
            titlecolor = colorMode.titlecolor,
            transform = "floor",
            thresholds = {{value = 1.5, textcolor = colorMode.accentcolor}, {value = 2.5, textcolor = colorMode.fillwarncolor}, {value = 6, textcolor = colorMode.fillcolor}}
        },
        {
            col = 5,
            row = 9,
            rowspan = 2,
            offsety = -10,
            type = "text",
            subtype = "telemetry",
            source = "pid_profile",
            title = "PROFILE",
            titlepos = "bottom",
            font = opts.tilefont,
            titlefont = opts.titlefont,
            valuepaddingbottom = 6,
            bgcolor = statusTileTopRowBg,
            titlecolor = colorMode.titlecolor,
            transform = "floor",
            thresholds = {{value = 1.5, textcolor = colorMode.accentcolor}, {value = 2.5, textcolor = colorMode.fillwarncolor}, {value = 6, textcolor = colorMode.fillcolor}}
        }, 
        {
            col = 6, 
            row = 9, 
            colspan = 2,
            rowspan = 2, 
            offsetx = -5,
            offsety = -10,
            type = "time", 
            subtype = "count", 
            title = "FLIGHTS", 
            titlepos = "bottom", 
            font = opts.tilefont, 
            titlefont = opts.titlefont, 
            valuepaddingbottom = 10, 
            bgcolor = statusTileTopRowRightEdgeBg, 
            titlecolor = colorMode.titlecolor, 
            textcolor = colorMode.textcolor
        }, 
        {
            col = 1,
            row = 10,
            colspan = 3,
            rowspan = 3,
            offsetx = 4,
            offsety = -4,
            type = "gauge",
            source = "smartfuel",
            batteryframe = true,
            battadv = true,
            battadvvaluealign = "right",
            -- Shrink the SmartFuel gauge inside its box for border clearance and no internal collision.
            -- Detail stack remains on the right, but compact layouts tighten it
            -- so it does not collide with the percent value.
            gaugepaddingbottom = 8,
            gaugepaddingleft = 5,
            gaugepaddingright = 10,
            valuealign = "left",
            batteryframethickness = opts.batteryframethickness,
            font = opts.smartfont, --(smart fuel % size)
            valuefont = opts.smartvaluefont,
            valuepaddingleft = 10,
            valuepaddingtop = opts.smartvaluepaddingtop,
            valuepaddingbottom = 0,
            gaugepaddingtop = 6,
            battadvfont = opts.smartadvfont,
            battadvpaddingright = opts.smartbattadvpaddingright,
            battadvpaddingtop = opts.smartbattadvpaddingtop,
            cappaddingright = 4,
            fillcolor = colorMode.fillcolor,
            bgcolor = colorMode.bgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            accentcolor = colorMode.accentcolor,
            transform = "floor",
            -- Updated fillcolor for value = 45 using lcd.RGB
            thresholds = {{value = 25, fillcolor = colorMode.fillcritcolor}, {value = 45, fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}}
        }, 
        {
            col = 4,
            colspan = 2,
            row = 1,
            rowspan = 7,
            offsetx = 2,
            offsety = -7,
            type = "gauge",
            subtype = "arc",
            source = "bec_voltage",
            title = "BEC VOLTAGE",
            titlepos = "bottom",
            decimals = 1,
            titlepaddingbottom = opts.titlepaddingbottom,
            valuepaddingtop = 42,
            font = "FONT_XL",
            titlefont = opts.arctitlefont,
            min = getThemeValue("bec_min"),
            max = getThemeValue("bec_max"),
            thickness = opts.thickness + 1,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            thresholds = {{value = getThemeValue("bec_warn"), fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}, {value = getThemeValue("bec_max"), fillcolor = colorMode.fillcolor}}
        }, 
        {
            col = 4,
            row = 11,
            colspan = 2,
            rowspan = 2,
            offsety = -8,
            type = "text",
            subtype = "blackbox",
            title = "BLACKBOX",
            titlepos = "bottom",
            font = opts.tilefont,
            titlefont = opts.titlefont,
            valuepaddingbottom = 6,
            decimals = 0,
            bgcolor = statusTileBg,
            titlecolor = colorMode.titlecolor,
            transform = "floor",
            thresholds = {{value = 80, textcolor = colorMode.textcolor}, {value = 90, textcolor = colorMode.fillwarncolor}, {value = 100, textcolor = colorMode.fillcritcolor}}
        }, 
        {
            col = 6,
            colspan = 2,
            row = 1,
            rowspan = 7,
            offsetx = -8,
            offsety = -7,
            type = "gauge",
            subtype = "arc",
            source = "temp_esc",
            title = "ESC TEMP",
            titlepos = "bottom",
            font = "FONT_XL",
            titlefont = opts.arctitlefont,
            min = 0,
            max = getThemeValue("esctemp_max"),
            thickness = opts.thickness + 1,
            valuepaddingleft = 0,
            bgcolor = colorMode.bgcolor,
            fillbgcolor = colorMode.fillbgcolor,
            titlecolor = colorMode.titlecolor,
            textcolor = colorMode.textcolor,
            titlepaddingbottom = opts.titlepaddingbottom,
            valuepaddingtop = 42,
            transform = "floor",
            thresholds = {{value = getThemeValue("esctemp_warn"), fillcolor = colorMode.fillcolor}, {value = getThemeValue("esctemp_max"), fillcolor = lcd.RGB(0xE3, 0xA3, 0x00)}, {value = 155, fillcolor = colorMode.fillcritcolor}}
        }, 
        {
            col = 6,
            row = 11,
            colspan = 2,
            rowspan = 2,
            offsetx = -5,
            offsety = -8,
            type = "text",
            subtype = "governor",
            title = "GOVERNOR",
            titlepos = "bottom",
            font = opts.govfont,
            titlefont = opts.titlefont,
            valuepaddingbottom = 6,
            bgcolor = statusTileRightEdgeBg,
            titlecolor = colorMode.titlecolor,
            thresholds = {
                {value = "DISARMED", textcolor = colorMode.fillcritcolor}, {value = "OFF", textcolor = colorMode.fillcritcolor}, {value = "IDLE", textcolor = colorMode.accentcolor}, {value = "SPOOLUP", textcolor = colorMode.accentcolor}, {value = "RECOVERY", textcolor = colorMode.fillwarncolor}, {value = "ACTIVE", textcolor = colorMode.fillcolor},
                {value = "@i18n(widgets.governor.THR-OFF)@", textcolor = colorMode.fillcritcolor}
            }
        }
    }
end

local function boxes()
    local config = rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section]
    local W = lcd.getWindowSize()
    if boxes_cache == nil or themeconfig ~= config or lastScreenW ~= W then
        boxes_cache = buildBoxes(W)
        themeconfig = config
        lastScreenW = W
    end
    return boxes_cache
end

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.5}}

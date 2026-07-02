--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — [https://www.gnu.org/licenses/gpl-3.0.en.html](https://www.gnu.org/licenses/gpl-3.0.en.html)
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local floor = math.floor
local min = math.min
local max = math.max
local tonumber = tonumber
local ipairs = ipairs

local utils = rfsuite.widgets.dashboard.utils
local maxVoltageToCellVoltage = utils.maxVoltageToCellVoltage
local loadImage = rfsuite.utils and rfsuite.utils.loadImage

local headeropts = utils.getHeaderOptions()

-- Pre-cached Render Colors for Zero-Lag Performance
local rc = {
    bg = lcd.RGB(5, 8, 14),           
    panel = lcd.RGB(12, 18, 28),
    cyan = lcd.RGB(0, 240, 255),
    amber = lcd.RGB(255, 170, 0),
    red = lcd.RGB(255, 0, 60),
    green = lcd.RGB(57, 255, 20),
    orange = lcd.RGB(255, 105, 0),
    magenta = lcd.RGB(190, 30, 255),
    white = lcd.RGB(230, 240, 255),
    dim = lcd.RGB(30, 45, 60)
}

local colorMode = {
    bgcolor = rc.bg,           
    tbbgcolor = rc.panel,       
    headerbgcolor = "transparent",     
    titlecolor = rc.cyan,     
    textcolor = rc.white,    
    fillcolor = rc.green,      
    fillwarncolor = rc.amber,  
    fillcritcolor = rc.red,   
    accentcolor = rc.cyan,    
    rssifillbgcolor = rc.cyan,
    fillbgcolor = rc.dim      
}

local pageBgColor = colorMode.bgcolor


local EMPTY_CACHE = {}
local function wakeStatic()
    return EMPTY_CACHE
end

local ICON_NAMES = {
    "altitude", "rpm", "fuel", "current", "watts",
    "consumed", "link", "voltage", "temperature"
}
local ICON_BITMAPS = {}
local iconLoadAttempted = false
local iconThemeBase = nil

local function resolveThemeBasePath()
    local dashboard = rfsuite.widgets and rfsuite.widgets.dashboard
    local widgetPath = dashboard and dashboard.currentWidgetPath
    if type(widgetPath) ~= "string" or widgetPath == "" then return nil end

    local src, folder = widgetPath:match("([^/]+)/(.+)")
    if not src or not folder then return nil end

    if src == "user" then
        return "SCRIPTS:/" .. rfsuite.config.preferences .. "/dashboard/" .. folder .. "/"
    end
    return "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/themes/" .. folder .. "/"
end

local function loadMetricBitmaps()
    if iconLoadAttempted then return end
    if type(loadImage) ~= "function" then
        iconLoadAttempted = true
        return
    end

    iconThemeBase = resolveThemeBasePath()
    if not iconThemeBase then return end

    iconLoadAttempted = true
    local iconBase = iconThemeBase .. "gfx/icons/"
    for i = 1, #ICON_NAMES do
        local name = ICON_NAMES[i]
        ICON_BITMAPS[name] = loadImage(iconBase .. name .. ".bmp") or false
    end
end

-- State scripts are preloaded by the dashboard, so this normally loads the
-- bitmaps before the user switches to postflight. The paint function retries
-- if currentWidgetPath was not available yet.
loadMetricBitmaps()

local theme_section = "system/mwrc"

local THEME_DEFAULTS = {rpm_min = 0, rpm_max = 2500, bec_min = 6.5, bec_warn = 8.0, bec_max = 12.0, esctemp_warn = 110, esctemp_max = 150}

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
    ls_full = {font = "FONT_XL", titlefont = "FONT_STD", titlepaddingtop = 5, thickness = 24, tilefont = "FONT_XXL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 7, gaugepaddingbottom = 13, iconsize = 32, iconpadleft = 12, iconvalueshift = 38},
    ls_std = {font = "FONT_L", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 18, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 10, iconsize = 26, iconpadleft = 9, iconvalueshift = 31},
    ms_full = {font = "FONT_L", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 16, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 9, iconsize = 32, iconpadleft = 12, iconvalueshift = 38},
    ms_std = {font = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 0, thickness = 12, tilefont = "FONT_L", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 7, iconsize = 26, iconpadleft = 9, iconvalueshift = 31},
    ss_full = {font = "FONT_L", titlefont = "FONT_STD", titlepaddingtop = 2, thickness = 16, tilefont = "FONT_XL", tiletitlespacing = 4, tilevaluepaddingtop = 3, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 9, iconsize = 32, iconpadleft = 12, iconvalueshift = 38},
    ss_std = {font = "FONT_S", titlefont = "FONT_STD", titlepaddingtop = 0, thickness = 12, tilefont = "FONT_L", tiletitlespacing = 3, tilevaluepaddingtop = 2, tilevaluepaddingbottom = 0, gaugepaddingtop = 1, gaugepaddingbottom = 7, iconsize = 26, iconpadleft = 9, iconvalueshift = 31}
}

local lastScreenW = nil
local boxes_cache = nil
local header_boxes_cache = nil
local last_txbatt_type = nil
local themeconfig = nil

local layout = {cols = 12, rows = 12, padding = 0}
local screenBorderStyle = {
    enabled = false,
    bordercolor = colorMode.accentcolor or colorMode.rssifillbgcolor,
    borderwidth = 5,
    inset = 0
}

local header_layout = utils.standardHeaderLayout(headeropts)
local topbarShiftY = 4 
if header_layout and header_layout.height then
    header_layout.height = header_layout.height + topbarShiftY 
end

local HEADER_TEXT_1 = "ETHOS "
local HEADER_TEXT_2 = "// "
local HEADER_TEXT_3 = "ROTORFLIGHT"
local HEADER_WATERMARK = "MWRC"
local headerTextWidth1 = nil
local headerTextWidth2 = nil
local headerTextWidth3 = nil
local headerWatermarkWidth = nil

local function paintHeaderLogo(x, y)
    lcd.font(FONT_L or 0)

    if headerTextWidth1 == nil then
        headerTextWidth1 = lcd.getTextSize(HEADER_TEXT_1)
        headerTextWidth2 = lcd.getTextSize(HEADER_TEXT_2)
        headerTextWidth3 = lcd.getTextSize(HEADER_TEXT_3)
    end

    lcd.color(colorMode.accentcolor)
    lcd.drawText(x + 5, y + 4, HEADER_TEXT_1)
    lcd.color(rc.amber)
    lcd.drawText(x + 5 + headerTextWidth1, y + 4, HEADER_TEXT_2)
    lcd.color(colorMode.textcolor)
    lcd.drawText(x + 5 + headerTextWidth1 + headerTextWidth2, y + 4, HEADER_TEXT_3)

    -- Small permanent author mark in the common header. It is present on
    -- preflight, inflight, and postflight without covering telemetry.
    local watermarkX = x + 5 + headerTextWidth1 + headerTextWidth2 + headerTextWidth3 + 10
    lcd.color(rc.amber)
    lcd.drawLine(watermarkX - 5, y + 9, watermarkX - 5, y + 25)
    lcd.font(FONT_XS or FONT_XXS or 0)
    if headerWatermarkWidth == nil then headerWatermarkWidth = lcd.getTextSize(HEADER_WATERMARK) end
    lcd.color(colorMode.accentcolor)
    lcd.drawText(watermarkX, y + 8, HEADER_WATERMARK)
end

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then txbatt_type = rfsuite.preferences.general.txbatt_type or 0 end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, txbatt_type)

        local headerBgColor = "transparent"
        for _, box in ipairs(boxes) do
            box.bgcolor = headerBgColor 
            box.offsety = (box.offsety or 0) + topbarShiftY 
            
            if box.type == "image" then
                box.type = "func"
                box.subtype = "func"
                box.paint = paintHeaderLogo
            end
        end

        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end



-- =========================================================================
-- OPTIMIZED NATIVE LUA METRIC ICONS
-- One overlay object, no per-icon wakeups, and no duplicate shadow strokes.
-- =========================================================================
local function drawMountainIcon(x, y, size, color)
    local left = x + 2
    local bottom = y + size - 3
    local mid = x + floor(size * 0.42)
    local right = x + size - 2
    local shoulder = x + floor(size * 0.58)
    local peak2x = x + floor(size * 0.72)

    lcd.color(color)
    lcd.drawLine(left, bottom, mid, y + floor(size * 0.38))
    lcd.drawLine(mid, y + floor(size * 0.38), shoulder, y + floor(size * 0.55))
    lcd.drawLine(shoulder, y + floor(size * 0.55), peak2x, y + floor(size * 0.18))
    lcd.drawLine(peak2x, y + floor(size * 0.18), right, bottom)
    lcd.drawLine(left, bottom, right, bottom)
end

local function drawRotorIcon(x, y, size, color)
    local cx = x + floor(size / 2)
    local cy = y + floor(size / 2)
    local arm = floor(size * 0.40)
    local diagonal = floor(arm * 0.55)
    local hub = max(2, floor(size * 0.09))

    lcd.color(color)
    lcd.drawLine(cx, cy, cx + arm, cy - diagonal)
    lcd.drawLine(cx, cy, cx - arm, cy + diagonal)
    lcd.drawLine(cx, cy, cx + diagonal, cy + arm)
    lcd.drawLine(cx, cy, cx - diagonal, cy - arm)
    lcd.drawFilledRectangle(cx - hub, cy - hub, hub * 2 + 1, hub * 2 + 1)
end

local function drawBatteryIcon(x, y, size, color, withBolt)
    local bx = x + 3
    local by = y + floor(size * 0.24)
    local bw = size - 8
    local bh = floor(size * 0.52)
    local capW = max(2, floor(size * 0.10))
    local capH = max(5, floor(bh * 0.42))

    lcd.color(color)
    lcd.drawRectangle(bx, by, bw, bh, 2)
    lcd.drawFilledRectangle(bx + bw, by + floor((bh - capH) / 2), capW, capH)

    if withBolt then
        local cx = bx + floor(bw / 2)
        local midY = by + floor(bh * 0.53)
        lcd.drawLine(cx + 2, by + 3, cx - 2, midY)
        lcd.drawLine(cx - 2, midY, cx + 2, midY)
        lcd.drawLine(cx + 2, midY, cx - 2, by + bh - 3)
    else
        local gap = max(2, floor(bw * 0.06))
        local segW = floor((bw - 8 - gap * 2) / 3)
        local sx = bx + 4
        local sy = by + 4
        local sh = bh - 8
        lcd.drawFilledRectangle(sx, sy, segW, sh)
        lcd.drawFilledRectangle(sx + segW + gap, sy, segW, sh)
        lcd.drawFilledRectangle(sx + (segW + gap) * 2, sy, segW, sh)
    end
end

local function drawLightningIcon(x, y, size, color)
    local cx = x + floor(size / 2)
    local half = floor(size * 0.18)
    local midY = y + floor(size * 0.54)

    lcd.color(color)
    lcd.drawLine(cx + half, y + 2, cx - half, midY)
    lcd.drawLine(cx - half, midY, cx, midY)
    lcd.drawLine(cx, midY, cx - half, y + size - 2)
    lcd.drawLine(cx + half - 1, y + 2, cx - half - 1, midY)
end

local function drawWaveIcon(x, y, size, color)
    local left = x + 2
    local right = x + size - 2
    local cy = y + floor(size / 2)
    local step = max(3, floor(size / 8))

    lcd.color(color)
    lcd.drawRectangle(x, y, size - 2, size - 2, 1)
    lcd.drawLine(left, cy, left + step, cy)
    lcd.drawLine(left + step, cy, left + step * 2, cy - floor(size * 0.27))
    lcd.drawLine(left + step * 2, cy - floor(size * 0.27), left + step * 3, cy + floor(size * 0.27))
    lcd.drawLine(left + step * 3, cy + floor(size * 0.27), left + step * 4, cy - floor(size * 0.18))
    lcd.drawLine(left + step * 4, cy - floor(size * 0.18), left + step * 5, cy + floor(size * 0.10))
    lcd.drawLine(left + step * 5, cy + floor(size * 0.10), right, cy)
end

local function drawFuelCanIcon(x, y, size, color)
    local bx = x + floor(size * 0.18)
    local by = y + floor(size * 0.22)
    local bw = floor(size * 0.55)
    local bh = floor(size * 0.65)

    lcd.color(color)
    lcd.drawRectangle(bx, by, bw, bh, 2)
    lcd.drawRectangle(bx + floor(bw * 0.25), y + 3, floor(bw * 0.55), floor(size * 0.20), 1)
    lcd.drawLine(bx + bw, by + floor(bh * 0.18), x + size - 3, y + floor(size * 0.28))
    lcd.drawLine(x + size - 3, y + floor(size * 0.28), x + size - 3, y + floor(size * 0.63))
    lcd.drawLine(bx + 4, by + floor(bh * 0.45), bx + bw - 4, by + floor(bh * 0.45))
    lcd.drawLine(bx + 4, by + floor(bh * 0.62), bx + bw - 4, by + floor(bh * 0.62))
end

local function drawSignalIcon(x, y, size, color)
    local barW = max(2, floor(size * 0.10))
    local gap = max(2, floor(size * 0.08))
    local bottom = y + size - 3
    local startX = x + 3

    lcd.color(color)
    for i = 0, 3 do
        local h = floor(size * (0.22 + i * 0.17))
        lcd.drawFilledRectangle(startX + i * (barW + gap), bottom - h, barW, h)
    end

    local ax = x + size - 7
    lcd.drawLine(ax - 5, y + 8, ax, y + 3)
    lcd.drawLine(ax, y + 3, ax + 5, y + 8)
    lcd.drawLine(ax - 3, y + 12, ax, y + 9)
    lcd.drawLine(ax, y + 9, ax + 3, y + 12)
end

local function drawTemperatureIcon(x, y, size, color)
    local cx = x + floor(size * 0.42)
    local top = y + 3
    local bulb = max(4, floor(size * 0.16))
    local bottom = y + size - bulb - 3

    lcd.color(color)
    lcd.drawRectangle(cx - 3, top, 7, bottom - top, 2)
    lcd.drawRectangle(cx - bulb, bottom, bulb * 2, bulb * 2, 2)
    lcd.drawFilledRectangle(cx - 1, top + floor(size * 0.25), 3, bottom - top - floor(size * 0.18))

    local tx = x + floor(size * 0.68)
    lcd.drawLine(tx, y + floor(size * 0.28), x + size - 2, y + floor(size * 0.28))
    lcd.drawLine(tx, y + floor(size * 0.50), x + size - 5, y + floor(size * 0.50))
    lcd.drawLine(tx, y + floor(size * 0.72), x + size - 2, y + floor(size * 0.72))
end

local function paintAllMetricIcons(x, y, w, h, box, cache)
    loadMetricBitmaps()

    local size = box.iconsize or 30
    local pad = box.iconpadleft or 10
    local cellW = w / 12
    local cellH = h / 12
    local tileH = cellH * 3
    local offsetY = -7
    local iconOffsetY = 2

    local function iconPosition(col, row)
        local ix = x + (col - 1) * cellW + pad
        local iy = y + (row - 1) * cellH + offsetY + floor((tileH - size) / 2) + iconOffsetY
        return floor(ix), floor(iy)
    end

    local function paintIcon(name, col, row, fallback, color, extra)
        local ix, iy = iconPosition(col, row)
        local bitmap = ICON_BITMAPS[name]
        if bitmap then
            lcd.drawBitmap(ix, iy, bitmap, size, size)
        else
            fallback(ix, iy, size, color, extra)
        end
    end

    paintIcon("altitude", 1, 10, drawMountainIcon, rc.cyan)
    paintIcon("rpm", 1, 4, drawRotorIcon, rc.magenta)
    paintIcon("fuel", 5, 4, drawBatteryIcon, rc.green, false)
    paintIcon("current", 5, 7, drawLightningIcon, rc.cyan)
    paintIcon("watts", 5, 10, drawWaveIcon, rc.green)
    paintIcon("consumed", 9, 4, drawFuelCanIcon, rc.amber)
    paintIcon("link", 1, 7, drawSignalIcon, rc.cyan)
    paintIcon("voltage", 9, 10, drawBatteryIcon, rc.cyan, true)
    paintIcon("temperature", 9, 7, drawTemperatureIcon, rc.orange)
end

local function buildBoxes(W)
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.ls_full

    local function makeGaugeTileBg(bordercolor)
        return {
            color = rc.panel,
            bordercolor = bordercolor,
            borderwidth = 2,
            roundradius = 6,
            inset = 5,
            contentpadding = 1
        }
    end

    local cyanTileBg = makeGaugeTileBg(rc.cyan)
    local greenTileBg = makeGaugeTileBg(rc.green)
    local amberTileBg = makeGaugeTileBg(rc.amber)
    local orangeTileBg = makeGaugeTileBg(rc.orange)
    local magentaTileBg = makeGaugeTileBg(rc.magenta)


    return {
        
        -- Text Overlays for the Gauges
        {col = 1, row = 10, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "altitude", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = cyanTileBg, titlecolor = "transparent", textcolor = "transparent"},
        {col = 5, row = 10, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "watts", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = greenTileBg, titlecolor = "transparent", textcolor = "transparent"},
        {col = 5, row = 7, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "current", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = cyanTileBg, titlecolor = "transparent", textcolor = "transparent"},
        {col = 1, row = 4, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "rpm", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = magentaTileBg, titlecolor = "transparent", textcolor = "transparent"},
        {col = 1, row = 7, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "link", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = cyanTileBg, titlecolor = "transparent", textcolor = "transparent"},
        {col = 9, row = 4, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "smartconsumption", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = amberTileBg, titlecolor = "transparent", textcolor = "transparent"},
        {col = 5, row = 4, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "smartfuel", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = greenTileBg, titlecolor = "transparent", textcolor = "transparent"},
        {col = 9, row = 10, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "voltage", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = cyanTileBg, titlecolor = "transparent", textcolor = "transparent"},
        {col = 9, row = 7, colspan = 4, rowspan = 3, offsety = -7, type = "text", subtype = "telemetry", source = "temp_esc", font = "FONT_XXS", valuealign = "left", valuepaddingleft = -200, unit = "", bgcolor = orangeTileBg, titlecolor = "transparent", textcolor = "transparent"},
        
        -- Flight Timers
        {
            col = 5, row = 1, colspan = 4, rowspan = 3,
            type = "time", subtype = "flight", title = "Flight Time", titlepos = "top",
            titlealign = "center", valuealign = "center", font = opts.tilefont, titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = rc.cyan, textcolor = rc.white
        },
        {
            col = 9, row = 1, colspan = 4, rowspan = 3,
            type = "time", subtype = "total", title = "Total Flight Time", titlepos = "top",
            titlealign = "center", valuealign = "center", font = opts.tilefont, titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = rc.cyan, textcolor = rc.white
        },
        {
            col = 1, row = 1, colspan = 4, rowspan = 3,
            type = "time", subtype = "count", title = "Flights", titlepos = "top",
            titlealign = "center", valuealign = "center", font = opts.tilefont, titlefont = opts.titlefont,
            titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingtop = opts.tilevaluepaddingtop, valuepaddingbottom = opts.tilevaluepaddingbottom,
            bgcolor = "transparent", titlecolor = rc.cyan, textcolor = rc.white, transform = "floor"
        },
        
        -- Stat Gauges
        {
            col = 1, row = 10, colspan = 4, rowspan = 3, offsety = -7,
            type = "gauge", subtype = "bar", source = "altitude", stattype = "max", title = "Max Altitude", unit = "ft",
            min = 0, max = 450, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = "transparent", fillcolor = rc.cyan, textcolor = rc.white, titlecolor = rc.cyan, transform = "floor"
        },
        {
            col = 5, row = 10, colspan = 4, rowspan = 3, offsety = -7,
            type = "gauge", subtype = "bar", source = "watts", stattype = "max", title = "Max Watts", unit = "W",
            min = 0, max = 10000, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = "transparent", fillcolor = rc.green, textcolor = rc.white, titlecolor = rc.green, transform = "floor"
        },
        {
            col = 5, row = 7, colspan = 4, rowspan = 3, offsety = -7,
            type = "gauge", subtype = "bar", source = "current", stattype = "max", title = "Max Amps", unit = "A",
            min = 0, max = 300, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = "transparent", fillcolor = rc.cyan, textcolor = rc.white, titlecolor = rc.cyan, transform = "floor"
        },
        {
            col = 1, row = 4, colspan = 4, rowspan = 3, offsety = -7,
            type = "gauge", subtype = "bar", source = "rpm", stattype = "max", title = "Max Rpm", unit = "rpm",
            min = 0, max = 5500, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = "transparent", fillcolor = rc.magenta, textcolor = rc.white, titlecolor = rc.magenta, transform = "floor"
        },
        {
            col = 1, row = 7, colspan = 4, rowspan = 3, offsety = -7,
            type = "gauge", subtype = "bar", source = "link", stattype = "min", title = "Vfr Min", unit = "%",
            min = 0, max = 100, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = "transparent", fillcolor = rc.cyan, textcolor = rc.white, titlecolor = rc.cyan,
            thresholds = {
                {value = 45, fillcolor = rc.red},
                {value = 75, fillcolor = rc.amber},
                {value = 100, fillcolor = rc.cyan}
            },
            transform = "floor"
        },
        {
            col = 9, row = 4, colspan = 4, rowspan = 3, offsety = -7,
            type = "gauge", subtype = "bar", source = "smartconsumption", stattype = "max", title = "Consumed mAh", unit = "mAh",
            min = 0, max = 5000, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = "transparent", fillcolor = rc.amber, textcolor = rc.white, titlecolor = rc.amber,
            thresholds = {
                {value = 2250, fillcolor = rc.amber},
                {value = 4000, fillcolor = rc.red}
            },
            transform = "floor"
        },
        {
            col = 5, row = 4, colspan = 4, rowspan = 3, offsety = -7,
            type = "gauge", subtype = "bar", source = "smartfuel", stattype = "min", title = "Battery Remaining", unit = "%",
            min = 0, max = 100, titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = "transparent", fillcolor = rc.green, textcolor = rc.white, titlecolor = rc.green,
            thresholds = {
                {value = 25, fillcolor = rc.red},
                {value = 50, fillcolor = rc.amber},
                {value = 100, fillcolor = rc.green}
            },
            transform = "floor"
        },
        {
            col = 9, row = 10, colspan = 4, rowspan = 3, offsety = -7,
            type = "gauge", subtype = "bar", source = "voltage", stattype = "min", title = "Volts per cell", unit = "V",
            min = 3.2, max = 4.35, gaugevalue = "display", titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = "transparent", fillcolor = rc.cyan, textcolor = rc.white, titlecolor = rc.cyan,
            thresholds = {
                {value = 3.70, fillcolor = rc.red},
                {value = 3.85, fillcolor = rc.amber},
                {value = 4.35, fillcolor = rc.cyan}
            },
            transform = maxVoltageToCellVoltage,
            decimals = 2
        },
        {
            col = 9, row = 7, colspan = 4, rowspan = 3, offsety = -7,
            type = "gauge", subtype = "bar", source = "temp_esc", stattype = "max", title = "ESC Max Temp", unit = "°C",
            min = 0, max = getThemeValue("esctemp_max"), titlepos = "top", titlealign = "center", valuealign = "center",
            font = opts.font, titlefont = opts.titlefont, titlespacing = opts.tiletitlespacing, titlepaddingtop = opts.titlepaddingtop + 11,
            valuepaddingleft = opts.iconvalueshift,
            thickness = math.max(4, opts.thickness - 4), gaugepadding = 12, gaugepaddingtop = opts.gaugepaddingtop, gaugepaddingbottom = opts.gaugepaddingbottom, gaugepaddingleft = 13, gaugepaddingright = 13,
            bgcolor = "transparent", fillcolor = rc.orange, textcolor = rc.white, titlecolor = rc.orange,
            thresholds = {
                {value = getThemeValue("esctemp_warn"), fillcolor = rc.amber},
                {value = getThemeValue("esctemp_max"), fillcolor = rc.red}
            },
            transform = "floor"
        },

        -- One static overlay replaces nine separate icon widgets.
        {
            col = 1, row = 1, colspan = 12, rowspan = 12,
            type = "func", subtype = "func",
            wakeup = wakeStatic,
            paint = paintAllMetricIcons,
            iconsize = opts.iconsize,
            iconpadleft = opts.iconpadleft,
            bgcolor = "transparent"
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

return {layout = layout, boxes = boxes, header_boxes = header_boxes, header_layout = header_layout, screenBorderStyle = screenBorderStyle, scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.5}}
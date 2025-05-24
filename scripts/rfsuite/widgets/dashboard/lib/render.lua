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

local render = {}

local utils = assert(
    rfsuite.compiler.loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/lib/utils.lua")
)()

-- === Function-param support ===
local function getParam(box, key, ...)
    local v = box[key]
    if type(v) == "function" then
        return v(box, key, ...)
    else
        return v
    end
end

-- Telemetry data box
function render.telemetryBox(x, y, w, h, box, telemetry)
    local value = nil
    local source = getParam(box, "source")
    if source then
        local sensor = telemetry and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
        local transform = getParam(box, "transform")
        if type(transform) == "string" and math[transform] then
            value = value and math[transform](value)
        elseif type(transform) == "function" then
            value = value and transform(value)
        elseif type(transform) == "number" then
            value = value and transform(value)
        end
    end
    local displayValue = value
    local displayUnit = getParam(box, "unit")
    if value == nil then
        displayValue = getParam(box, "novalue") or "-"
        displayUnit = nil
    end

    -- Threshold color logic (borrowed from gaugeBox)
    local color = getParam(box, "color")
    local thresholds = getParam(box, "thresholds")
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            local t_color = type(t.color) == "function" and t.color(box, value) or t.color
            if value < t_val then
                color = t_color or color
                break
            end
        end
    end

    utils.telemetryBox(
        x, y, w, h,
        color, getParam(box, "title"), displayValue, displayUnit, getParam(box, "bgcolor"),
        getParam(box, "titlealign"), getParam(box, "valuealign"), getParam(box, "titlecolor"), getParam(box, "titlepos"),
        getParam(box, "titlepadding"), getParam(box, "titlepaddingleft"), getParam(box, "titlepaddingright"),
        getParam(box, "titlepaddingtop"), getParam(box, "titlepaddingbottom"),
        getParam(box, "valuepadding"), getParam(box, "valuepaddingleft"), getParam(box, "valuepaddingright"),
        getParam(box, "valuepaddingtop"), getParam(box, "valuepaddingbottom")
    )
end


-- Static text box
function render.textBox(x, y, w, h, box)
    local displayValue = getParam(box, "value")
    if displayValue == nil then
        displayValue = getParam(box, "novalue") or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        getParam(box, "color"), getParam(box, "title"), displayValue, getParam(box, "unit"), getParam(box, "bgcolor"),
        getParam(box, "titlealign"), getParam(box, "valuealign"), getParam(box, "titlecolor"), getParam(box, "titlepos"),
        getParam(box, "titlepadding"), getParam(box, "titlepaddingleft"), getParam(box, "titlepaddingright"),
        getParam(box, "titlepaddingtop"), getParam(box, "titlepaddingbottom"),
        getParam(box, "valuepadding"), getParam(box, "valuepaddingleft"), getParam(box, "valuepaddingright"),
        getParam(box, "valuepaddingtop"), getParam(box, "valuepaddingbottom")
    )
end

-- Image box
function render.imageBox(x, y, w, h, box)
    utils.imageBox(
        x, y, w, h,
        getParam(box, "color"), getParam(box, "title"),
        getParam(box, "value") or getParam(box, "source") or "widgets/dashboard/gfx/default_image.png",
        getParam(box, "imagewidth"), getParam(box, "imageheight"), getParam(box, "imagealign"),
        getParam(box, "bgcolor"), getParam(box, "titlealign"), getParam(box, "titlecolor"), getParam(box, "titlepos"),
        getParam(box, "imagepadding"), getParam(box, "imagepaddingleft"), getParam(box, "imagepaddingright"),
        getParam(box, "imagepaddingtop"), getParam(box, "imagepaddingbottom")
    )
end

-- Model image box
function render.modelImageBox(x, y, w, h, box)
    utils.modelImageBox(
        x, y, w, h,
        getParam(box, "color"), getParam(box, "title"),
        getParam(box, "imagewidth"), getParam(box, "imageheight"), getParam(box, "imagealign"),
        getParam(box, "bgcolor"), getParam(box, "titlealign"), getParam(box, "titlecolor"), getParam(box, "titlepos"),
        getParam(box, "imagepadding"), getParam(box, "imagepaddingleft"), getParam(box, "imagepaddingright"),
        getParam(box, "imagepaddingtop"), getParam(box, "imagepaddingbottom")
    )
end

-- Governor status box
function render.governorBox(x, y, w, h, box, telemetry)
    local value = nil
    local sensor = telemetry and telemetry.getSensorSource("governor")
    value = sensor and sensor:value()
    local displayValue = rfsuite.utils.getGovernorState(value)
    if displayValue == nil then
        displayValue = getParam(box, "novalue") or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        getParam(box, "color"), getParam(box, "title"), displayValue, getParam(box, "unit"), getParam(box, "bgcolor"),
        getParam(box, "titlealign"), getParam(box, "valuealign"), getParam(box, "titlecolor"), getParam(box, "titlepos"),
        getParam(box, "titlepadding"), getParam(box, "titlepaddingleft"), getParam(box, "titlepaddingright"),
        getParam(box, "titlepaddingtop"), getParam(box, "titlepaddingbottom"),
        getParam(box, "valuepadding"), getParam(box, "valuepaddingleft"), getParam(box, "valuepaddingright"),
        getParam(box, "valuepaddingtop"), getParam(box, "valuepaddingbottom")
    )
end

-- Craft name box
function render.craftnameBox(x, y, w, h, box)
    local displayValue = rfsuite.session.craftName
    if displayValue == nil or (type(displayValue) == "string" and displayValue:match("^%s*$")) then
        displayValue = getParam(box, "novalue") or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        getParam(box, "color"), getParam(box, "title"), displayValue, getParam(box, "unit"), getParam(box, "bgcolor"),
        getParam(box, "titlealign"), getParam(box, "valuealign"), getParam(box, "titlecolor"), getParam(box, "titlepos"),
        getParam(box, "titlepadding"), getParam(box, "titlepaddingleft"), getParam(box, "titlepaddingright"),
        getParam(box, "titlepaddingtop"), getParam(box, "titlepaddingbottom"),
        getParam(box, "valuepadding"), getParam(box, "valuepaddingleft"), getParam(box, "valuepaddingright"),
        getParam(box, "valuepaddingtop"), getParam(box, "valuepaddingbottom")
    )
end

-- API version box
function render.apiversionBox(x, y, w, h, box)
    local displayValue = rfsuite.session.apiVersion
    if displayValue == nil then
        displayValue = getParam(box, "novalue") or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        getParam(box, "color"), getParam(box, "title"), displayValue, getParam(box, "unit"), getParam(box, "bgcolor"),
        getParam(box, "titlealign"), getParam(box, "valuealign"), getParam(box, "titlecolor"), getParam(box, "titlepos"),
        getParam(box, "titlepadding"), getParam(box, "titlepaddingleft"), getParam(box, "titlepaddingright"),
        getParam(box, "titlepaddingtop"), getParam(box, "titlepaddingbottom"),
        getParam(box, "valuepadding"), getParam(box, "valuepaddingleft"), getParam(box, "valuepaddingright"),
        getParam(box, "valuepaddingtop"), getParam(box, "valuepaddingbottom")
    )
end

-- Session variable box
function render.sessionBox(x, y, w, h, box)
    local src = getParam(box, "source")
    local displayValue = rfsuite.session[src]
    if displayValue == nil then
        displayValue = getParam(box, "novalue") or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        getParam(box, "color"), getParam(box, "title"), displayValue, getParam(box, "unit"), getParam(box, "bgcolor"),
        getParam(box, "titlealign"), getParam(box, "valuealign"), getParam(box, "titlecolor"), getParam(box, "titlepos"),
        getParam(box, "titlepadding"), getParam(box, "titlepaddingleft"), getParam(box, "titlepaddingright"),
        getParam(box, "titlepaddingtop"), getParam(box, "titlepaddingbottom"),
        getParam(box, "valuepadding"), getParam(box, "valuepaddingleft"), getParam(box, "valuepaddingright"),
        getParam(box, "valuepaddingtop"), getParam(box, "valuepaddingbottom")
    )
end

-- Blackbox storage usage box
function render.blackboxBox(x, y, w, h, box)
    local displayValue = nil
    local totalSize = rfsuite.session.bblSize
    local usedSize = rfsuite.session.bblUsed
    if totalSize and usedSize then
        displayValue = string.format(
            "%.1f/%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"),
            usedSize / (1024 * 1024),
            totalSize / (1024 * 1024)
        )
    end
    if displayValue == nil then
        displayValue = getParam(box, "novalue") or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        getParam(box, "color"), getParam(box, "title"), displayValue, getParam(box, "unit"), getParam(box, "bgcolor"),
        getParam(box, "titlealign"), getParam(box, "valuealign"), getParam(box, "titlecolor"), getParam(box, "titlepos"),
        getParam(box, "titlepadding"), getParam(box, "titlepaddingleft"), getParam(box, "titlepaddingright"),
        getParam(box, "titlepaddingtop"), getParam(box, "titlepaddingbottom"),
        getParam(box, "valuepadding"), getParam(box, "valuepaddingleft"), getParam(box, "valuepaddingright"),
        getParam(box, "valuepaddingtop"), getParam(box, "valuepaddingbottom")
    )
end

-- Function box
function render.functionBox(x, y, w, h, box)
    local v = box.value
    if type(v) == "function" then
        -- In case someone set value = function() return actual_function end
        v = v(x, y, w, h) or v
        if type(v) == "function" then
            v(x, y, w, h)
        end
    end
end

-- Gauge box (fully function-param ready)
function render.gaugeBox(x, y, w, h, box, telemetry)
    -- Get value
    local value = nil
    local source = getParam(box, "source")
    if source then
        if type(source) == "function" then
            value = source(box, telemetry)
        else
            local sensor = telemetry and telemetry.getSensorSource(source)
            value = sensor and sensor:value()
            local transform = getParam(box, "transform")
            if type(transform) == "string" and math[transform] then
                value = value and math[transform](value)
            elseif type(transform) == "function" then
                value = value and transform(value)
            elseif type(transform) == "number" then
                value = value and transform(value)
            end
        end
    end

    local displayValue = value
    local displayUnit = getParam(box, "unit")
    if value == nil then
        displayValue = getParam(box, "novalue") or "-"
        displayUnit = nil
    end

    -- Padding for gauge area
    local gpad_left   = getParam(box, "gaugepaddingleft")   or getParam(box, "gaugepadding") or 0
    local gpad_right  = getParam(box, "gaugepaddingright")  or getParam(box, "gaugepadding") or 0
    local gpad_top    = getParam(box, "gaugepaddingtop")    or getParam(box, "gaugepadding") or 0
    local gpad_bottom = getParam(box, "gaugepaddingbottom") or getParam(box, "gaugepadding") or 0

    -- Figure out title area height (for gaugebelowtitle)
    local title_area_top = 0
    local title_area_bottom = 0
    if getParam(box, "gaugebelowtitle") and getParam(box, "title") then
        lcd.font(FONT_XS)
        local _, tsizeH = lcd.getTextSize(getParam(box, "title"))
        local titlepadding = getParam(box, "titlepadding") or 0
        local titlepaddingtop = getParam(box, "titlepaddingtop") or titlepadding
        local titlepaddingbottom = getParam(box, "titlepaddingbottom") or titlepadding
        if getParam(box, "titlepos") == "bottom" then
            title_area_bottom = tsizeH + titlepaddingtop + titlepaddingbottom
        else
            title_area_top = tsizeH + titlepaddingtop + titlepaddingbottom
        end
    end

    local gauge_x = x + gpad_left
    local gauge_y = y + gpad_top + title_area_top
    local gauge_w = w - gpad_left - gpad_right
    local gauge_h = h - gpad_top - gpad_bottom - title_area_top - title_area_bottom

    -- Draw overall box background
    local bgColor = utils.resolveColor(getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)


    -- Threshold gauge color logic (+ threshold value text color)
    local gaugeColor = utils.resolveColor(getParam(box, "gaugecolor")) or lcd.RGB(255, 204, 0)
    local valueTextColor = utils.resolveColor(getParam(box, "color")) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
    local matchingTextColor = nil
    local thresholds = getParam(box, "thresholds")
    if thresholds and value ~= nil then
            for _, t in ipairs(thresholds) do
                local t_val = type(t.value) == "function" and t.value(box, value) or t.value
                local t_color = type(t.color) == "function" and t.color(box, value) or t.color
                local t_textcolor = type(t.textcolor) == "function" and t.textcolor(box, value) or t.textcolor
                if value < t_val then
                    gaugeColor = utils.resolveColor(t_color) or gaugeColor
                    if t_textcolor then matchingTextColor = utils.resolveColor(t_textcolor) end
                    break
                end
            end
    end


    -- Draw gauge background & fill ONLY if gauge percent > 0
    local gaugeMin = getParam(box, "gaugemin") or 0
    local gaugeMax = getParam(box, "gaugemax") or 100
    local gaugeOrientation = getParam(box, "gaugeorientation") or "vertical"
    local percent = 0
    if value ~= nil and gaugeMax ~= gaugeMin then
        percent = (value - gaugeMin) / (gaugeMax - gaugeMin)
        if percent < 0 then percent = 0 end
        if percent > 1 then percent = 1 end
    end
    if percent > 0 then
        local gaugeBgColor = utils.resolveColor(getParam(box, "gaugebgcolor")) or bgColor
        lcd.color(gaugeBgColor)
        lcd.drawFilledRectangle(gauge_x, gauge_y, gauge_w, gauge_h)
        lcd.color(gaugeColor)
        if gaugeOrientation == "vertical" then
            local fillH = math.floor(gauge_h * percent)
            lcd.drawFilledRectangle(gauge_x, gauge_y + gauge_h - fillH, gauge_w, fillH)
        else
            local fillW = math.floor(gauge_w * percent)
            lcd.drawFilledRectangle(gauge_x, gauge_y, fillW, gauge_h)
        end
    end

    -- Overlay value text (with clever threshold coloring)
    local valuepadding = getParam(box, "valuepadding") or 0
    local valuepaddingleft = getParam(box, "valuepaddingleft") or valuepadding
    local valuepaddingright = getParam(box, "valuepaddingright") or valuepadding
    local valuepaddingtop = getParam(box, "valuepaddingtop") or valuepadding
    local valuepaddingbottom = getParam(box, "valuepaddingbottom") or valuepadding

    if displayValue ~= nil then
        local str = tostring(displayValue) .. (displayUnit or "")
        local unitIsDegree = (displayUnit == "°" or (displayUnit and tostring(displayUnit):find("°")))
        local strForWidth = unitIsDegree and (tostring(displayValue) .. "0") or str

        local availH = h - valuepaddingtop - valuepaddingbottom
        local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL, FONT_XXXXL}

        lcd.font(FONT_XL)
        local _, xlFontHeight = lcd.getTextSize("8")
        if xlFontHeight > availH * 0.5 then
            fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L}
        end

        local maxW, maxH = w - valuepaddingleft - valuepaddingright, availH
        local bestFont, bestW, bestH = FONT_XXS, 0, 0
        for _, font in ipairs(fonts) do
            lcd.font(font)
            local tW, tH = lcd.getTextSize(strForWidth)
            if tW <= maxW and tH <= maxH then
                bestFont, bestW, bestH = font, tW, tH
            else
                break
            end
        end
        lcd.font(bestFont)
        local region_x = x + valuepaddingleft
        local region_y = y + valuepaddingtop
        local region_w = w - valuepaddingleft - valuepaddingright
        local region_h = h - valuepaddingtop - valuepaddingbottom

        local sy = region_y + (region_h - bestH) / 2
        local align = (getParam(box, "valuealign") or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - bestW
        else
            sx = region_x + (region_w - bestW) / 2
        end

        -- Smart threshold text color based on gauge fill coverage
        local useThresholdTextColor = false
        if matchingTextColor and percent > 0 then
            local tW, tH = bestW, bestH
            if gaugeOrientation == "vertical" then
                local text_top = sy
                local text_bottom = sy + tH
                local fill_top = gauge_y + gauge_h * (1 - percent)
                local fill_bottom = gauge_y + gauge_h
                local overlap = math.min(text_bottom, fill_bottom) - math.max(text_top, fill_top)
                if overlap > tH / 2 then
                    useThresholdTextColor = true
                end
            else
                local text_left = sx
                local text_right = sx + tW
                local fill_left = gauge_x
                local fill_right = gauge_x + gauge_w * percent
                local overlap = math.min(text_right, fill_right) - math.max(text_left, fill_left)
                if overlap > tW / 2 then
                    useThresholdTextColor = true
                end
            end
        end
        if useThresholdTextColor then
            valueTextColor = matchingTextColor
        end

        lcd.color(valueTextColor)
        lcd.drawText(sx, sy, str)
    end

    -- Overlay title (top or bottom)
    if getParam(box, "title") then
        local titlepadding = getParam(box, "titlepadding") or 0
        local titlepaddingleft = getParam(box, "titlepaddingleft") or titlepadding
        local titlepaddingright = getParam(box, "titlepaddingright") or titlepadding
        local titlepaddingtop = getParam(box, "titlepaddingtop") or titlepadding
        local titlepaddingbottom = getParam(box, "titlepaddingbottom") or titlepadding

        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(getParam(box, "title"))
        local region_x = x + titlepaddingleft
        local region_w = w - titlepaddingleft - titlepaddingright
        local sy = (getParam(box, "titlepos") == "bottom")
            and (y + h - titlepaddingbottom - tsizeH)
            or (y + titlepaddingtop)
        local align = (getParam(box, "titlealign") or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - tsizeW
        else
            sx = region_x + (region_w - tsizeW) / 2
        end
        lcd.color(utils.resolveColor(getParam(box, "titlecolor")) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90)))
        lcd.drawText(sx, sy, getParam(box, "title"))
    end
end

-- Fuel Gauge Box: Easy, ready-to-use fuel gauge for end users.
function render.functionFuelGuage(x, y, w, h, box, telemetry)
    -- Default parameters for fuel gauge
    local defaults = {
        source = "fuel",  -- Telemetry source
        gaugemin = 0,
        gaugemax = 100,
        gaugeorientation = "vertical",
        gaugepadding = 4,
        gaugebelowtitle = true,
        title = "FUEL",
        unit = "%",
        color = "white",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        titlecolor = "white",
        gaugecolor = "green",
        thresholds = {
            { value = 20,  color = "red",    textcolor = "white" },
            { value = 50,  color = "orange", textcolor = "black" }
        }
    }

    -- Allow box to override defaults if user provided (for flexibility)
    local fuelBox = {}
    for k,v in pairs(defaults) do fuelBox[k] = v end
    for k,v in pairs(box or {}) do fuelBox[k] = v end

    -- Use the existing gaugeBox rendering logic (re-uses your existing styling)
    return render.gaugeBox(x, y, w, h, fuelBox, telemetry)
end

function render.functionVoltageGauge(x, y, w, h, box, telemetry)
    -- Default parameters for voltage gauge
    local defaults = {
        source = "voltage",  -- Telemetry source
        gaugemin = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        gaugemax = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
        gaugebgcolor = "gray",
        gaugeorientation = "horizontal",
        gaugepadding = 4,
        gaugebelowtitle = true,
        title = "VOLTAGE",
        unit = "V",
        color = "black",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        titlecolor = "white",
        gaugecolor = "green",
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2 -- 20% above minimum voltage
                end,
                color = "red", textcolor = "white"
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2
                end,
                color = "orange", textcolor = "black"
            }
        }
    }

    -- Allow box to override defaults if provided
    local voltBox = {}
    for k,v in pairs(defaults) do voltBox[k] = v end
    for k,v in pairs(box or {}) do voltBox[k] = v end

    return render.gaugeBox(x, y, w, h, voltBox, telemetry)
end

-- Extend render.lua with support for type = "dial"

local dialAssets = {
    [1] = { panel = "widgets/dashboard/gfx/panel1.png", pointer = "widgets/dashboard/gfx/pointer1.png" },
    [2] = { panel = "widgets/dashboard/gfx/panel2.png", pointer = "widgets/dashboard/gfx/pointer2.png" },
    [3] = { panel = "widgets/dashboard/gfx/panel3.png", pointer = "widgets/dashboard/gfx/pointer3.png" },
    [4] = { panel = "widgets/dashboard/gfx/panel4.png", pointer = "widgets/dashboard/gfx/pointer4.png" },
    [5] = { panel = "widgets/dashboard/gfx/panel5.png", pointer = "widgets/dashboard/gfx/pointer4.png" },
    [6] = { panel = "widgets/dashboard/gfx/panel6.png", pointer = "widgets/dashboard/gfx/pointer4.png" },
    [7] = { panel = "widgets/dashboard/gfx/panel7.png", pointer = "widgets/dashboard/gfx/pointer7.png" },
    [8] = { panel = "widgets/dashboard/gfx/panel8.png", pointer = "widgets/dashboard/gfx/pointer8.png" },
}

rfsuite.session.dialImageCachee = {}
local rotatedPointerCache = {}
local lastDialValue = {}
local lastRotatedKey = {}

local function loadDialAssets(style, customPanelPath, customPointerPath)
    local key = tostring(style or "default") .. ":" .. (customPanelPath or "") .. ":" .. (customPointerPath or "")
    if not rfsuite.session.dialImageCachee[key] then
        local assets = dialAssets[style or 1] or dialAssets[1]
        local panelPath = customPanelPath or assets.panel
        local pointerPath = customPointerPath or assets.pointer
        rfsuite.session.dialImageCachee[key] = {
            panel = rfsuite.utils.loadImage(panelPath),
            pointer = rfsuite.utils.loadImage(pointerPath)
        }
    end
    return rfsuite.session.dialImageCachee[key].panel, rfsuite.session.dialImageCachee[key].pointer
end

local function calDialAngle(percent)
    local angle = 315 + percent * 270 / 100
    while angle > 360 do angle = angle - 360 end
    return angle
end

local function computeDrawArea(img, x, y, w, h, aspect, align)
    local iw, ih = img:width(), img:height()
    local drawW, drawH = w, h

    if aspect == "fit" then
        local scale = math.min(w / iw, h / ih)
        drawW = iw * scale
        drawH = ih * scale
    elseif aspect == "fill" then
        local scale = math.max(w / iw, h / ih)
        drawW = iw * scale
        drawH = ih * scale
    elseif not aspect or aspect == "original" then
        drawW = iw
        drawH = ih
    end

    local drawX, drawY = x, y
    align = align or "center"
    if align:find("right") then
        drawX = x + w - drawW
    elseif align:find("center") or not align:find("left") then
        drawX = x + (w - drawW) / 2
    end
    if align:find("bottom") then
        drawY = y + h - drawH
    elseif align:find("center") or not align:find("top") then
        drawY = y + (h - drawH) / 2
    end

    return drawX, drawY, drawW, drawH
end

function render.dialBox(x, y, w, h, box, telemetry)
    local value = nil
    local source = getParam(box, "source")
    if source then
        local sensor = telemetry and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
        local transform = getParam(box, "transform")
        if type(transform) == "string" and math[transform] then
            value = value and math[transform](value)
        elseif type(transform) == "function" then
            value = value and transform(value)
        elseif type(transform) == "number" then
            value = value and transform(value)
        end
    end

    local displayValue = value or getParam(box, "novalue") or "-"
    local unit = getParam(box, "unit")
    local style = getParam(box, "style") or 1
    local customPanel = getParam(box, "panelpath")
    local customPointer = getParam(box, "pointerpath")
    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100
    local percent = 0

    if value and max ~= min then
        percent = ((value - min) / (max - min)) * 100
        percent = math.max(0, math.min(100, percent))
    end

    local aspect = getParam(box, "aspect")
    local align = getParam(box, "align") or "center"

    local panelImg, pointerImg = loadDialAssets(style, customPanel, customPointer)
    if panelImg and pointerImg then
        local drawX, drawY, drawW, drawH = computeDrawArea(panelImg, x, y, w, h, aspect, align)
        lcd.drawBitmap(drawX, drawY, panelImg, drawW, drawH)

        local angle = calDialAngle(percent)
        local boxId = tostring(box)
        local rotatedKey = tostring(style) .. ":" .. angle .. ":" .. (customPointer or "")

        if lastRotatedKey[boxId] ~= rotatedKey then
            if not rotatedPointerCache[rotatedKey] then
                rotatedPointerCache[rotatedKey] = pointerImg:rotate(angle)
            end
            lastRotatedKey[boxId] = rotatedKey
        end

        local rotated = rotatedPointerCache[rotatedKey]
        if rotated then
            lcd.drawBitmap(drawX, drawY, rotated, drawW, drawH)
        end
    end

    -- Optional title and value
    local title = getParam(box, "title")
    if title then
        lcd.font(FONT_XS)
        local tW, tH = lcd.getTextSize(title)
        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawText(x + (w - tW) / 2, y + h - tH, title)
    end

    if displayValue ~= nil then
        lcd.font(FONT_STD)
        local str = tostring(displayValue) .. (unit or "")
        local vW, vH = lcd.getTextSize(str)
        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawText(x + (w - vW) / 2, y + h - vH - 16, str)
    end
end



-- Dispatcher for rendering boxes by type.
function render.renderBox(boxType, x, y, w, h, box, telemetry)
    local funcMap = {
        telemetry = render.telemetryBox,
        text = render.textBox,
        image = render.imageBox,
        modelimage = render.modelImageBox,
        governor = render.governorBox,
        craftname = render.craftnameBox,
        apiversion = render.apiversionBox,
        session = render.sessionBox,
        blackbox = render.blackboxBox,
        gauge = render.gaugeBox,
        fuelgauge = render.functionFuelGuage,
        voltagegauge = render.functionVoltageGauge,
        dial = render.dialBox,
        ["function"] = render.functionBox,
    }
    local fn = funcMap[boxType]
    if fn then
        return fn(x, y, w, h, box, telemetry)
    end
end

return render

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

local function applyOffset(x, y, box)
    local ox = getParam(box, "offsetx") or 0
    local oy = getParam(box, "offsety") or 0
    return x + ox, y + oy
end

-- Telemetry data box
function render.telemetryBox(x, y, w, h, box, telemetry)

    x, y = applyOffset(x, y, box)

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

    x, y = applyOffset(x, y, box)

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

    x, y = applyOffset(x, y, box)

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

    x, y = applyOffset(x, y, box)

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

    x, y = applyOffset(x, y, box)

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

    x, y = applyOffset(x, y, box)

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

    x, y = applyOffset(x, y, box)

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

    x, y = applyOffset(x, y, box)

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

    x, y = applyOffset(x, y, box)

    local v = box.value
    if type(v) == "function" then
        -- In case someone set value = function() return actual_function end
        v = v(x, y, w, h) or v
        if type(v) == "function" then
            v(x, y, w, h)
        end
    end
end

function render.drawFilledRoundedRectangle(x, y, w, h, r)
    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    w = math.floor(w + 0.5)
    h = math.floor(h + 0.5)
    r = math.floor(r + 0.5)
    if r > 0 then
        lcd.drawFilledRectangle(x + r, y, w - 2*r, h)
        lcd.drawFilledRectangle(x, y + r, r, h - 2*r)
        lcd.drawFilledRectangle(x + w - r, y + r, r, h - 2*r)
        lcd.drawFilledCircle(x + r, y + r, r)
        lcd.drawFilledCircle(x + w - r - 1, y + r, r)
        lcd.drawFilledCircle(x + r, y + h - r - 1, r)
        lcd.drawFilledCircle(x + w - r - 1, y + h - r - 1, r)
    else
        lcd.drawFilledRectangle(x, y, w, h)
    end
end

function render.gaugeBox(x, y, w, h, box, telemetry)
    x, y = applyOffset(x, y, box)

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

    -- Title area height if needed
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

    local roundradius = getParam(box, "roundradius") or 0

    -- Colors
    local bgColor = utils.resolveColor(getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    local gaugeBgColor = utils.resolveColor(getParam(box, "gaugebgcolor")) or bgColor
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

    -- Draw overall box background (outer rectangle, always square)
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Draw rounded background for the gauge (full size)
    lcd.color(gaugeBgColor)
    render.drawFilledRoundedRectangle(gauge_x, gauge_y, gauge_w, gauge_h, roundradius)

    -- Draw the gauge fill as a rounded rectangle (or circle/capsule)
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
        lcd.color(gaugeColor)
        if gaugeOrientation == "vertical" then
            local fillH = math.floor(gauge_h * percent)
            local fillY = gauge_y + gauge_h - fillH
            if fillH > 2*roundradius then
                render.drawFilledRoundedRectangle(gauge_x, fillY, gauge_w, fillH, roundradius)
            elseif fillH > 0 then
                -- Capsule or circle
                local cx = gauge_x + gauge_w/2
                local cy = fillY + fillH/2
                local r = fillH/2
                lcd.drawFilledCircle(cx, cy, r)
            end
        else
            local fillW = math.floor(gauge_w * percent)
            if fillW > 2*roundradius then
                render.drawFilledRoundedRectangle(gauge_x, gauge_y, fillW, gauge_h, roundradius)
            elseif fillW > 0 then
                local cx = gauge_x + fillW/2
                local cy = gauge_y + gauge_h/2
                local r = fillW/2
                lcd.drawFilledCircle(cx, cy, r)
            end
        end
    end

    -- Overlay value text (same as before)
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

    x, y = applyOffset(x, y, box)

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

    x, y = applyOffset(x, y, box)

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

-- Advanced Battery Gauge Box
function render.batteryAdvancedBox(x, y, w, h, box, telemetry)
    x, y = applyOffset(x, y, box)

    -- default gauge rendering
    render.gaugeBox(x, y, w, h, box, telemetry)

    -- Retrieve battery telemetry
    local get = telemetry and telemetry.getSensorSource
    local voltageSensor = get and get("voltage")
    local cellCountSensor = get and get("cell_count")
    local consumptionSensor = get and get("consumption")
    local voltage = voltageSensor and voltageSensor:value()
    local cellCount = cellCountSensor and cellCountSensor:value()
    local consumption = consumptionSensor and consumptionSensor:value()

    local transform = getParam(box, "transform")
    if transform then
        if type(transform) == "string" and math[transform] then
            voltage = voltage and math[transform](voltage)
            cellCount = cellCount and math[transform](cellCount)
            consumed = consumed and math[transform](consumed)
        elseif type(transform) == "function" then
            voltage = voltage and transform(voltage)
            cellCount = cellCount and transform(cellCount)
            consumed = consumed and transform(consumed)
        end
    end

    local perCellVoltage = (voltage and cellCount and cellCount > 0)
        and (voltage / cellCount) or nil

    -- Format text lines
    local line1 = string.format("V: %.1f / C: %.2f", voltage or 0, perCellVoltage or 0)
    local line2 = string.format("Used: %d mAh (%dS)", consumed or 0, cellCount or 0)

    -- Draw text block to the right
    lcd.font(FONT_S)
    local textW1, textH1 = lcd.getTextSize(line1)
    local textW2, textH2 = lcd.getTextSize(line2)
    local totalH = textH1 + textH2 + 2

    local infoW = math.floor(w * 0.20)
    local paddingX = 8
    local yStart = y + (h - totalH) / 2
    local infoX = x + w - infoW + paddingX
    local maxRight = x + w - 2

    lcd.color(utils.resolveColor(getParam(box, "textColor")) or lcd.RGB(255, 255, 255))
    lcd.drawText(math.min(infoX, maxRight - textW1), yStart, line1)
    lcd.drawText(math.min(infoX, maxRight - textW2), yStart + textH1 + 2, line2)
end

-- Extend render.lua with support for type = "dial"


rfsuite.session.dialImageCachee = {}
local rotatedPointerCache = {}
local lastDialValue = {}
local lastRotatedKey = {}


-- New helper: resolves dial or pointer value to an image path
local function resolveDialAsset(value, basePath)
    if type(value) == "function" then
        value = value()
    end
    if type(value) == "number" then
        return string.format("%s/%d.png", basePath, value)
    elseif type(value) == "string" then
        if value:match("^%d+$") then
            -- If it's a numeric string, treat as number (for backward compat)
            return string.format("%s/%s.png", basePath, value)
        else
            return value
        end
    end
    return nil
end

local function loadDialAssets(panelPath, pointerPath)
    local key = (panelPath or "") .. ":" .. (pointerPath or "")
    if not rfsuite.session.dialImageCachee[key] then
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
    x, y = applyOffset(x, y, box)

    -- Draw box background (support bgColor)
    local bgColor = utils.resolveColor(getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

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
    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100
    local percent = 0
    if value and max ~= min then
        percent = ((value - min) / (max - min)) * 100
        percent = math.max(0, math.min(100, percent))
    end

    local aspect = getParam(box, "aspect")
    local align = getParam(box, "align") or "center"

    -- New flexible dial/pointer asset logic:
    local dial = getParam(box, "dial")
    local pointer = getParam(box, "pointer")
    local panelPath = resolveDialAsset(dial, "widgets/dashboard/gfx/dials") or "widgets/dashboard/gfx/panel1.png"
    local pointerPath = resolveDialAsset(pointer, "widgets/dashboard/gfx/pointers") or "widgets/dashboard/gfx/pointer1.png"

    local panelImg, pointerImg = loadDialAssets(panelPath, pointerPath)
    if panelImg and pointerImg then
        local drawX, drawY, drawW, drawH = computeDrawArea(panelImg, x, y, w, h, aspect, align)
        lcd.drawBitmap(drawX, drawY, panelImg, drawW, drawH)

        local angle = calDialAngle(percent)
        local boxId = tostring(box)
        local rotatedKey = (panelPath or "") .. ":" .. (pointerPath or "") .. ":" .. angle

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
        tW = tW or 0
        tH = tH or 0
        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawText(x + (w - tW) / 2, y + h - tH, title)
    end

    if displayValue ~= nil then
        lcd.font(FONT_STD)
        local str = tostring(displayValue or "") .. (unit or "")
        if str == "" then str = "-" end
        local vW, vH = lcd.getTextSize(str)
        vW = vW or 0
        vH = vH or 0
        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawText(x + (w - vW) / 2, y + h - vH - 16, str)
    end

end


function render.flightCountBox(x, y, w, h, box)
    x, y = applyOffset(x, y, box)

    local displayValue = rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "flightcount")
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

-- Draws an arc from angle1 to angle2 (degrees, counter-clockwise, 0°=right)
-- Draws a thick arc by stamping filled circles along the arc path.
function render.drawArc(cx, cy, radius, thickness, angleStart, angleEnd, color)
    local step = 4  -- degrees per circle; decrease for smoother, increase for speed
    local rad_thick = thickness / 2
    angleStart = math.rad(angleStart)
    angleEnd = math.rad(angleEnd)
    if angleEnd > angleStart then
        angleEnd = angleEnd - 2 * math.pi
    end
    lcd.color(color or lcd.RGB(255,128,0))
    for a = angleStart, angleEnd, -math.rad(step) do
        local x = cx + radius * math.cos(a)
        local y = cy - radius * math.sin(a)
        lcd.drawFilledCircle(x, y, rad_thick)
    end
    -- Ensure end cap is filled
    local x_end = cx + radius * math.cos(angleEnd)
    local y_end = cy - radius * math.sin(angleEnd)
    lcd.drawFilledCircle(x_end, y_end, rad_thick)
end


function render.arcGaugeBox(x, y, w, h, box, telemetry)
    local bgColor = utils.resolveColor(getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)
    local arcOffsetY = getParam(box, "arcOffsetY") or 0
    local cx = x + w/2
    local cy = y + h/2 - arcOffsetY
    local radius = math.min(w, h) * 0.42
    local thickness = math.max(6, radius * 0.22)

    -- Get values using getParam for function/constant support
    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100

    -- Value: support function for box.value or box.source
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
            value = value and transform
        end
    end

    local displayValue = value or getParam(box, "novalue") or "-"
    local displayUnit = getParam(box, "unit")
    local min = getParam(box, "gaugemin") or 0
    local max = getParam(box, "gaugemax") or 100

    local percent = 0
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end

    -- Arc angles
    local startAngle = getParam(box, "startAngle") or 135
    local sweep = getParam(box, "sweep") or 270
    local endAngle = startAngle - sweep * percent

    -- Draw base (background) arc
    render.drawArc(
        cx, cy, radius, thickness,
        startAngle, startAngle - sweep,
        utils.resolveColor(getParam(box, "arcBgColor")) or lcd.RGB(55,55,55)
    )

    -- Draw value arc (with thresholds, supporting function in thresholds)
    local arcColor = utils.resolveColor(getParam(box, "arcColor")) or lcd.RGB(255,128,0)
    local thresholds = getParam(box, "thresholds")
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            local t_color = type(t.color) == "function" and t.color(box, value) or t.color
            if value < t_val then
                arcColor = utils.resolveColor(t_color) or arcColor
                break
            end
        end
    end
    if percent > 0 then
        render.drawArc(cx, cy, radius, thickness, startAngle, endAngle, arcColor)
    end

    -- Value text (centered)
    local fontName = getParam(box, "font")
    lcd.font(fontName and _G[fontName] or FONT_XL)
    lcd.color(utils.resolveColor(getParam(box, "textColor")) or lcd.RGB(255,255,255))

    local valueFormat = getParam(box, "valueFormat")
    local unit = getParam(box, "unit") or ""
    local decimals = getParam(box, "decimals")
    local valStr

    if valueFormat then
        valStr = valueFormat(value)
    elseif type(value) == "number" then
        if decimals ~= nil then
            -- Always use fixed decimal formatting if explicitly requested
            if decimals == 0 then
                valStr = string.format("%d", value)
            else
                valStr = string.format("%." .. decimals .. "f", value)
            end
        else
            -- Default smart formatting: remove .0 if unnecessary
            if math.floor(value) == value then
                valStr = string.format("%d", value)
            else
                valStr = string.format("%.1f", value)
            end
        end
    else
        valStr = "-"
    end

    valStr = valStr .. unit

    local tw, th = lcd.getTextSize(valStr)
    local xOffset = getParam(box, "textoffsetx") or 0
    lcd.drawText(cx - tw/2 + xOffset, cy - th/2, valStr)

    -- Title above, subText below
    local title = getParam(box, "title")
    if title then
        local titlepadding = getParam(box, "titlepadding") or 0
        local titlepaddingleft = getParam(box, "titlepaddingleft") or titlepadding
        local titlepaddingright = getParam(box, "titlepaddingright") or titlepadding
        local titlepaddingtop = getParam(box, "titlepaddingtop") or titlepadding
        local titlepaddingbottom = getParam(box, "titlepaddingbottom") or titlepadding

        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(title)
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
        lcd.drawText(sx, sy, title)
    end
    local subText = getParam(box, "subText")
    if subText then
        lcd.font(FONT_XS)
        local tw, th = lcd.getTextSize(subText)
        lcd.drawText(cx - tw/2, cy + radius * 0.55, subText)
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
        flightcount = render.flightCountBox,
        dial = render.dialBox,
        arcgauge = render.arcGaugeBox,
        batteryadvanced = render.batteryAdvancedBox,
        ["function"] = render.functionBox,
    }
    local fn = funcMap[boxType]
    if fn then
        return fn(x, y, w, h, box, telemetry)
    end
end

return render

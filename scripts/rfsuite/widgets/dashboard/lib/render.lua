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

--[[
    Draws a telemetry data box.
    Applies any transformation to the value if specified.
    Args: x, y, w, h - box position and size
          box - box definition table (includes source, transform, color, etc.)
          telemetry - telemetry source accessor
]]
function render.telemetryBox(x, y, w, h, box, telemetry)
    local value = nil
    if box.source then
        local sensor = telemetry and telemetry.getSensorSource(box.source)
        value = sensor and sensor:value()
        if type(box.transform) == "string" and math[box.transform] then
            value = value and math[box.transform](value)
        elseif type(box.transform) == "function" then
            value = value and box.transform(value)
        elseif type(box.transform) == "number" then
            value = value and box.transform(value)
        end
    end
    local displayValue = value
    local displayUnit = box.unit
    if value == nil then
        displayValue = box.novalue or "-"
        displayUnit = nil
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, displayUnit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws a static text box.
    Args: x, y, w, h - box position and size
          box - box definition table (includes title, value, etc.)
]]
function render.textBox(x, y, w, h, box)
    if displayValue == nil then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, box.value, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws an image box.
    Uses box.value or box.source as the image, or defaults if missing.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.imageBox(x, y, w, h, box)
    utils.imageBox(
        x, y, w, h,
        box.color, box.title,
        box.value or box.source or "widgets/dashboard/default_image.png",
        box.imagewidth, box.imageheight, box.imagealign,
        box.bgcolor, box.titlealign, box.titlecolor, box.titlepos,
        box.imagepadding, box.imagepaddingleft, box.imagepaddingright, box.imagepaddingtop, box.imagepaddingbottom
    )
end

--[[
    Draws a model image box (usually shows the model's icon).
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.modelImageBox(x, y, w, h, box)
    utils.modelImageBox(
        x, y, w, h,
        box.color, box.title,
        box.imagewidth, box.imageheight, box.imagealign,
        box.bgcolor, box.titlealign, box.titlecolor, box.titlepos,
        box.imagepadding, box.imagepaddingleft, box.imagepaddingright, box.imagepaddingtop, box.imagepaddingbottom
    )
end

--[[
    Draws a governor status box.
    Converts sensor value to state string via rfsuite.utils.getGovernorState.
    Args: x, y, w, h - box position and size
          box - box definition table
          telemetry - telemetry source accessor
]]
function render.governorBox(x, y, w, h, box, telemetry)
    local value = nil
    local sensor = telemetry and telemetry.getSensorSource("governor")
    value = sensor and sensor:value()
    local displayValue = rfsuite.utils.getGovernorState(value)
    if displayValue == nil then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws the craft name box.
    Falls back to novalue if craft name is not set or empty.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.craftnameBox(x, y, w, h, box)
    local displayValue = rfsuite.session.craftName
    if displayValue == nil or (type(displayValue) == "string" and displayValue:match("^%s*$")) then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws an API version box.
    Shows the current API version or novalue if not available.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.apiversionBox(x, y, w, h, box)
    local displayValue = rfsuite.session.apiVersion
    if displayValue == nil then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws a session variable box.
    Looks up the value from rfsuite.session using box.source.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.sessionBox(x, y, w, h, box)
    local displayValue = rfsuite.session[box.source]
    if displayValue == nil then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws a blackbox storage usage box.
    Shows used/total space in MB if available, else novalue.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
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
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Calls a custom function stored in box.value (if it is a function).
    For advanced or custom box render logic.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.functionBox(x, y, w, h, box)
    if box.value and type(box.value) == "function" then
        box.value(x, y, w, h)
    end
end

--[[
    Draws a telemetry data box.
    Applies any transformation to the value if specified.
    Args: x, y, w, h - box position and size
          box - box definition table (includes source, transform, color, etc.)
          telemetry - telemetry source accessor
]]
function render.gaugeBox(x, y, w, h, box, telemetry)
    -- Get value
    local value = nil
    if box.source then
        local sensor = telemetry and telemetry.getSensorSource(box.source)
        value = sensor and sensor:value()
        if type(box.transform) == "string" and math[box.transform] then
            value = value and math[box.transform](value)
        elseif type(box.transform) == "function" then
            value = value and box.transform(value)
        elseif type(box.transform) == "number" then
            value = value and box.transform(value)
        end
    end

    local displayValue = value
    local displayUnit = box.unit
    if value == nil then
        displayValue = box.novalue or "-"
        displayUnit = nil
    end

    -- --- Padding for gauge area
    local gpad_left = box.gaugepaddingleft or box.gaugepadding or 0
    local gpad_right = box.gaugepaddingright or box.gaugepadding or 0
    local gpad_top = box.gaugepaddingtop or box.gaugepadding or 0
    local gpad_bottom = box.gaugepaddingbottom or box.gaugepadding or 0

    -- --- Figure out title area height (for gaugebelowtitle)
    local title_area_top = 0
    local title_area_bottom = 0
    if box.gaugebelowtitle and box.title then
        lcd.font(FONT_XS)
        local _, tsizeH = lcd.getTextSize(box.title)
        local titlepadding = box.titlepadding or 0
        local titlepaddingtop = box.titlepaddingtop or titlepadding
        local titlepaddingbottom = box.titlepaddingbottom or titlepadding
        if box.titlepos == "bottom" then
            title_area_bottom = tsizeH + titlepaddingtop + titlepaddingbottom
        else
            title_area_top = tsizeH + titlepaddingtop + titlepaddingbottom
        end
    end

    local gauge_x = x + gpad_left
    local gauge_y = y + gpad_top + title_area_top
    local gauge_w = w - gpad_left - gpad_right
    local gauge_h = h - gpad_top - gpad_bottom - title_area_top - title_area_bottom

    -- --- Draw overall box background
    local bgColor = utils.resolveColor(box.bgcolor) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- --- Threshold gauge color logic (+ threshold value text color)
    local gaugeColor = utils.resolveColor(box.gaugecolor) or lcd.RGB(255, 204, 0)
    local valueTextColor = utils.resolveColor(box.color) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
    local matchingTextColor = nil
    if box.thresholds and value ~= nil then
        for _, t in ipairs(box.thresholds) do
            if value < t.value then
                gaugeColor = utils.resolveColor(t.color) or gaugeColor
                if t.textcolor then matchingTextColor = utils.resolveColor(t.textcolor) end
                break
            end
            gaugeColor = utils.resolveColor(t.color) or gaugeColor
            if t.textcolor then matchingTextColor = utils.resolveColor(t.textcolor) end
        end
    end

    -- --- Draw gauge background & fill ONLY if gauge percent > 0
    local gaugeMin = box.gaugemin or 0
    local gaugeMax = box.gaugemax or 100
    local gaugeOrientation = box.gaugeorientation or "vertical"  -- or "horizontal"
    local percent = 0
    if value ~= nil and gaugeMax ~= gaugeMin then
        percent = (value - gaugeMin) / (gaugeMax - gaugeMin)
        if percent < 0 then percent = 0 end
        if percent > 1 then percent = 1 end
    end
    if percent > 0 then
        -- gauge area bg color
        local gaugeBgColor = utils.resolveColor(box.gaugebgcolor) or bgColor
        lcd.color(gaugeBgColor)
        lcd.drawFilledRectangle(gauge_x, gauge_y, gauge_w, gauge_h)
        -- gauge fill
        lcd.color(gaugeColor)
        if gaugeOrientation == "vertical" then
            local fillH = math.floor(gauge_h * percent)
            lcd.drawFilledRectangle(gauge_x, gauge_y + gauge_h - fillH, gauge_w, fillH)
        else -- horizontal
            local fillW = math.floor(gauge_w * percent)
            lcd.drawFilledRectangle(gauge_x, gauge_y, fillW, gauge_h)
        end
    end

    -- --- Overlay value text (with clever threshold coloring)
    local valuepadding = box.valuepadding or 0
    local valuepaddingleft = box.valuepaddingleft or valuepadding
    local valuepaddingright = box.valuepaddingright or valuepadding
    local valuepaddingtop = box.valuepaddingtop or valuepadding
    local valuepaddingbottom = box.valuepaddingbottom or valuepadding

    if displayValue ~= nil then
        local str = tostring(displayValue) .. (displayUnit or "")
        local unitIsDegree = (displayUnit == "°" or (displayUnit and displayUnit:find("°")))
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
        local align = (box.valuealign or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - bestW
        else
            sx = region_x + (region_w - bestW) / 2
        end

        -- -------- Smart threshold text color based on gauge fill coverage
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
            else -- horizontal
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

    -- --- Overlay title (top or bottom, mirrors utils.telemetryBox)
    if box.title then
        local titlepadding = box.titlepadding or 0
        local titlepaddingleft = box.titlepaddingleft or titlepadding
        local titlepaddingright = box.titlepaddingright or titlepadding
        local titlepaddingtop = box.titlepaddingtop or titlepadding
        local titlepaddingbottom = box.titlepaddingbottom or titlepadding

        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(box.title)
        local region_x = x + titlepaddingleft
        local region_w = w - titlepaddingleft - titlepaddingright
        local sy = (box.titlepos == "bottom")
            and (y + h - titlepaddingbottom - tsizeH)
            or (y + titlepaddingtop)
        local align = (box.titlealign or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - tsizeW
        else
            sx = region_x + (region_w - tsizeW) / 2
        end
        lcd.color(utils.resolveColor(box.titlecolor) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90)))
        lcd.drawText(sx, sy, box.title)
    end
end



--[[
    Dispatcher for rendering boxes by type.
    Looks up the render function from a map and calls it with box details.
    Args: boxType - the box type string (e.g., "telemetry", "text", etc.)
          x, y, w, h - box position and size
          box - box definition table
          telemetry - telemetry accessor (optional)
]]
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
        ["function"] = render.functionBox,
    }
    local fn = funcMap[boxType]
    if fn then
        return fn(x, y, w, h, box, telemetry)
    end
end

return render

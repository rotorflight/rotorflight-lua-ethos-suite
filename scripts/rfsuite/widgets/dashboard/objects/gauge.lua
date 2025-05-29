local render = {}

local function drawFilledRoundedRectangle(x, y, w, h, r)
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

function render.wakeup(box, telemetry)
    -- Get value
    local value = nil
    local source = rfsuite.widgets.dashboard.utils.getParam(box, "source")
    if source then
        if type(source) == "function" then
            value = source(box, telemetry)
        else
            local sensor = telemetry and telemetry.getSensorSource(source)
            value = sensor and sensor:value()
            local transform = rfsuite.widgets.dashboard.utils.getParam(box, "transform")
            if type(transform) == "string" and math[transform] then
                value = value and math[transform](value)
            elseif type(transform) == "function" then
                value = value and transform(value)
            elseif type(transform) == "number" then
                value = value and transform(value)
            end
        end
    end

    local displayUnit = rfsuite.widgets.dashboard.utils.getParam(box, "unit")
    local displayValue = value
    if value == nil then
        displayValue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
        displayUnit = nil
    end

    -- Padding for gauge area
    local gpad_left   = rfsuite.widgets.dashboard.utils.getParam(box, "gaugepaddingleft")   or rfsuite.widgets.dashboard.utils.getParam(box, "gaugepadding") or 0
    local gpad_right  = rfsuite.widgets.dashboard.utils.getParam(box, "gaugepaddingright")  or rfsuite.widgets.dashboard.utils.getParam(box, "gaugepadding") or 0
    local gpad_top    = rfsuite.widgets.dashboard.utils.getParam(box, "gaugepaddingtop")    or rfsuite.widgets.dashboard.utils.getParam(box, "gaugepadding") or 0
    local gpad_bottom = rfsuite.widgets.dashboard.utils.getParam(box, "gaugepaddingbottom") or rfsuite.widgets.dashboard.utils.getParam(box, "gaugepadding") or 0

    local roundradius = rfsuite.widgets.dashboard.utils.getParam(box, "roundradius") or 0

    -- Colors
    local bgColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    local gaugeBgColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "gaugebgcolor")) or bgColor
    local gaugeColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "gaugecolor")) or lcd.RGB(255, 204, 0)
    local valueTextColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "color")) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))

    local thresholds = rfsuite.widgets.dashboard.utils.getParam(box, "thresholds")
    local matchingTextColor = nil
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            local t_color = type(t.color) == "function" and t.color(box, value) or t.color
            local t_textcolor = type(t.textcolor) == "function" and t.textcolor(box, value) or t.textcolor
            if value < t_val then
                gaugeColor = rfsuite.widgets.dashboard.utils.resolveColor(t_color) or gaugeColor
                if t_textcolor then matchingTextColor = rfsuite.widgets.dashboard.utils.resolveColor(t_textcolor) end
                break
            end
        end
    end

    local gaugeMin = rfsuite.widgets.dashboard.utils.getParam(box, "gaugemin") or 0
    local gaugeMax = rfsuite.widgets.dashboard.utils.getParam(box, "gaugemax") or 100
    local gaugeOrientation = rfsuite.widgets.dashboard.utils.getParam(box, "gaugeorientation") or "vertical"
    local percent = 0
    if value ~= nil and gaugeMax ~= gaugeMin then
        percent = (value - gaugeMin) / (gaugeMax - gaugeMin)
        if percent < 0 then percent = 0 end
        if percent > 1 then percent = 1 end
    end

    -- Value text formatting and padding
    local valuepadding = rfsuite.widgets.dashboard.utils.getParam(box, "valuepadding") or 0
    local valuepaddingleft = rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingleft") or valuepadding
    local valuepaddingright = rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingright") or valuepadding
    local valuepaddingtop = rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingtop") or valuepadding
    local valuepaddingbottom = rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingbottom") or valuepadding

    -- Title parameters
    local title = rfsuite.widgets.dashboard.utils.getParam(box, "title")
    local titlepadding = rfsuite.widgets.dashboard.utils.getParam(box, "titlepadding") or 0
    local titlepaddingleft = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingleft") or titlepadding
    local titlepaddingright = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingright") or titlepadding
    local titlepaddingtop = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingtop") or titlepadding
    local titlepaddingbottom = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingbottom") or titlepadding
    local titlealign = rfsuite.widgets.dashboard.utils.getParam(box, "titlealign") or "center"
    local titlepos = rfsuite.widgets.dashboard.utils.getParam(box, "titlepos") or "top"
    local titlecolor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor")) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))

    local valuealign = rfsuite.widgets.dashboard.utils.getParam(box, "valuealign") or "center"

    -- Gauge below title?
    local gaugebelowtitle = rfsuite.widgets.dashboard.utils.getParam(box, "gaugebelowtitle")

    -- Title area height
    local title_area_top = 0
    local title_area_bottom = 0
    if gaugebelowtitle and title then
        lcd.font(FONT_XS)
        local _, tsizeH = lcd.getTextSize(title)
        if titlepos == "bottom" then
            title_area_bottom = tsizeH + titlepaddingtop + titlepaddingbottom
        else
            title_area_top = tsizeH + titlepaddingtop + titlepaddingbottom
        end
    end

    box._cache = {
        value = value,
        displayValue = displayValue,
        displayUnit = displayUnit,
        gpad_left = gpad_left,
        gpad_right = gpad_right,
        gpad_top = gpad_top,
        gpad_bottom = gpad_bottom,
        roundradius = roundradius,
        bgColor = bgColor,
        gaugeBgColor = gaugeBgColor,
        gaugeColor = gaugeColor,
        valueTextColor = valueTextColor,
        matchingTextColor = matchingTextColor,
        thresholds = thresholds,
        gaugeMin = gaugeMin,
        gaugeMax = gaugeMax,
        gaugeOrientation = gaugeOrientation,
        percent = percent,
        valuepadding = valuepadding,
        valuepaddingleft = valuepaddingleft,
        valuepaddingright = valuepaddingright,
        valuepaddingtop = valuepaddingtop,
        valuepaddingbottom = valuepaddingbottom,
        title = title,
        titlepadding = titlepadding,
        titlepaddingleft = titlepaddingleft,
        titlepaddingright = titlepaddingright,
        titlepaddingtop = titlepaddingtop,
        titlepaddingbottom = titlepaddingbottom,
        titlealign = titlealign,
        titlepos = titlepos,
        titlecolor = titlecolor,
        valuealign = valuealign,
        gaugebelowtitle = gaugebelowtitle,
        title_area_top = title_area_top,
        title_area_bottom = title_area_bottom,
    }
end

function render.paint(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Safe values
    local value = c.value
    local displayValue = c.displayValue or "-"
    local displayUnit = c.displayUnit
    local gpad_left = c.gpad_left or 0
    local gpad_right = c.gpad_right or 0
    local gpad_top = c.gpad_top or 0
    local gpad_bottom = c.gpad_bottom or 0
    local roundradius = c.roundradius or 0
    local bgColor = c.bgColor or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    local gaugeBgColor = c.gaugeBgColor or bgColor
    local gaugeColor = c.gaugeColor or lcd.RGB(255, 204, 0)
    local valueTextColor = c.valueTextColor or lcd.RGB(90,90,90)
    local matchingTextColor = c.matchingTextColor
    local gaugeMin = c.gaugeMin or 0
    local gaugeMax = c.gaugeMax or 100
    local gaugeOrientation = c.gaugeOrientation or "vertical"
    local percent = c.percent or 0
    local valuepaddingleft = c.valuepaddingleft or 0
    local valuepaddingright = c.valuepaddingright or 0
    local valuepaddingtop = c.valuepaddingtop or 0
    local valuepaddingbottom = c.valuepaddingbottom or 0
    local valuealign = c.valuealign or "center"
    local title = c.title
    local titlepadding = c.titlepadding or 0
    local titlepaddingleft = c.titlepaddingleft or 0
    local titlepaddingright = c.titlepaddingright or 0
    local titlepaddingtop = c.titlepaddingtop or 0
    local titlepaddingbottom = c.titlepaddingbottom or 0
    local titlealign = c.titlealign or "center"
    local titlepos = c.titlepos or "top"
    local titlecolor = c.titlecolor or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
    local gaugebelowtitle = c.gaugebelowtitle
    local title_area_top = c.title_area_top or 0
    local title_area_bottom = c.title_area_bottom or 0

    -- Draw overall box background
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Gauge rectangle (with padding and title space)
    local gauge_x = x + gpad_left
    local gauge_y = y + gpad_top + title_area_top
    local gauge_w = w - gpad_left - gpad_right
    local gauge_h = h - gpad_top - gpad_bottom - title_area_top - title_area_bottom

    -- Rounded background for the gauge
    lcd.color(gaugeBgColor)
    drawFilledRoundedRectangle(gauge_x, gauge_y, gauge_w, gauge_h, roundradius)

    -- Gauge fill
    if percent > 0 then
        lcd.color(gaugeColor)
        if gaugeOrientation == "vertical" then
            local fillH = math.floor(gauge_h * percent)
            local fillY = gauge_y + gauge_h - fillH
            if fillH > 2*roundradius then
                drawFilledRoundedRectangle(gauge_x, fillY, gauge_w, fillH, roundradius)
            elseif fillH > 0 then
                local cx = gauge_x + gauge_w/2
                local cy = fillY + fillH/2
                local r = fillH/2
                lcd.drawFilledCircle(cx, cy, r)
            end
        else
            local fillW = math.floor(gauge_w * percent)
            if fillW > 2*roundradius then
                drawFilledRoundedRectangle(gauge_x, gauge_y, fillW, gauge_h, roundradius)
            elseif fillW > 0 then
                local cx = gauge_x + fillW/2
                local cy = gauge_y + gauge_h/2
                local r = fillW/2
                lcd.drawFilledCircle(cx, cy, r)
            end
        end
    end

    -- Overlay value text (with smart threshold text color based on gauge fill coverage)
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

        -- Adjusted vertical alignment
        local verticalOffset = math.floor(bestH * 0.07 + 0.5)
        local sy = region_y + math.floor((region_h - bestH) / 2 + 0.5) - verticalOffset

        local align = valuealign:lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - bestW
        else
            sx = region_x + (region_w - bestW) / 2
        end

        -- Smart threshold text color
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
    if title then
        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(title)
        local region_x = x + titlepaddingleft
        local region_w = w - titlepaddingleft - titlepaddingright
        local sy = (titlepos == "bottom")
            and (y + h - titlepaddingbottom - tsizeH)
            or (y + titlepaddingtop)
        local align = titlealign:lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - tsizeW
        else
            sx = region_x + (region_w - tsizeW) / 2
        end
        lcd.color(titlecolor)
        lcd.drawText(sx, sy, title)
    end
end

return render

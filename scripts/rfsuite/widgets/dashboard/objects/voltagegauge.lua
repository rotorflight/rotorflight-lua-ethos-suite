local render = {}

-- Default parameters for voltage gauge (only declared once)
local defaults = {
    source = "voltage",
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
                return cells * minV * 1.2
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
    -- Merge defaults and box parameters (box overrides defaults)
    local params = {}
    for k, v in pairs(defaults) do params[k] = v end
    for k, v in pairs(box or {}) do params[k] = v end

    -- Evaluate gaugemin/gaugemax if functions
    if type(params.gaugemin) == "function" then
        params.gaugemin = params.gaugemin()
    end
    if type(params.gaugemax) == "function" then
        params.gaugemax = params.gaugemax()
    end

    -- Evaluate thresholds values if function
    if type(params.thresholds) == "table" then
        for i, t in ipairs(params.thresholds) do
            if type(t.value) == "function" then
                params.thresholds[i] = {}
                for key,v in pairs(t) do params.thresholds[i][key] = v end
                params.thresholds[i].value = t.value()
            end
        end
    end

    -- Get the telemetry value
    local value = nil
    if params.source then
        if type(params.source) == "function" then
            value = params.source(box, telemetry)
        else
            local sensor = telemetry and telemetry.getSensorSource(params.source)
            value = sensor and sensor:value()
            local transform = params.transform
            if type(transform) == "string" and math[transform] then
                value = value and math[transform](value)
            elseif type(transform) == "function" then
                value = value and transform(value)
            elseif type(transform) == "number" then
                value = value and transform
            end
        end
    end

    local displayUnit = params.unit
    local displayValue = value
    if value == nil then
        displayValue = params.novalue or "-"
        displayUnit = nil
    end

    -- Calculate gauge percent
    local percent = 0
    if value ~= nil and params.gaugemax ~= params.gaugemin then
        percent = (value - params.gaugemin) / (params.gaugemax - params.gaugemin)
        percent = math.max(0, math.min(1, percent))
    end

    -- Cache for paint
    box._cache = {
        value = value,
        displayValue = displayValue,
        displayUnit = displayUnit,
        gpad_left = params.gaugepaddingleft or params.gaugepadding or 0,
        gpad_right = params.gaugepaddingright or params.gaugepadding or 0,
        gpad_top = params.gaugepaddingtop or params.gaugepadding or 0,
        gpad_bottom = params.gaugepaddingbottom or params.gaugepadding or 0,
        roundradius = params.roundradius or 0,
        bgColor = rfsuite.widgets.dashboard.utils.resolveColor(params.bgcolor) or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240)),
        gaugeBgColor = rfsuite.widgets.dashboard.utils.resolveColor(params.gaugebgcolor) or (lcd.darkMode() and lcd.RGB(20,20,20) or lcd.RGB(220,220,220)),
        gaugeColor = rfsuite.widgets.dashboard.utils.resolveColor(params.gaugecolor) or lcd.RGB(255,204,0),
        valueTextColor = rfsuite.widgets.dashboard.utils.resolveColor(params.color) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90)),
        thresholds = params.thresholds,
        gaugeMin = params.gaugemin,
        gaugeMax = params.gaugemax,
        gaugeOrientation = params.gaugeorientation or "vertical",
        percent = percent,
        valuepadding = params.valuepadding or 0,
        valuepaddingleft = params.valuepaddingleft or params.valuepadding or 0,
        valuepaddingright = params.valuepaddingright or params.valuepadding or 0,
        valuepaddingtop = params.valuepaddingtop or params.valuepadding or 0,
        valuepaddingbottom = params.valuepaddingbottom or params.valuepadding or 0,
        title = params.title,
        titlepadding = params.titlepadding or 0,
        titlepaddingleft = params.titlepaddingleft or params.titlepadding or 0,
        titlepaddingright = params.titlepaddingright or params.titlepadding or 0,
        titlepaddingtop = params.titlepaddingtop or params.titlepadding or 0,
        titlepaddingbottom = params.titlepaddingbottom or params.titlepadding or 0,
        titlealign = params.titlealign or "center",
        titlepos = params.titlepos or "top",
        titlecolor = rfsuite.widgets.dashboard.utils.resolveColor(params.titlecolor) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90)),
        valuealign = params.valuealign or "center",
        gaugebelowtitle = params.gaugebelowtitle,
        title_area_top = 0,
        title_area_bottom = 0,
        font = params.font,
    }

    -- Calculate title area height for layout
    if box._cache.gaugebelowtitle and box._cache.title then
        lcd.font(FONT_XS)
        local _, th = lcd.getTextSize(box._cache.title)
        if box._cache.titlepos == "bottom" then
            box._cache.title_area_bottom = th + box._cache.titlepaddingtop + box._cache.titlepaddingbottom
        else
            box._cache.title_area_top = th + box._cache.titlepaddingtop + box._cache.titlepaddingbottom
        end
    end
end

function render.paint(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Draw background
    lcd.color(c.bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Calculate gauge drawing area
    local gauge_x = x + c.gpad_left
    local gauge_y = y + c.gpad_top + c.title_area_top
    local gauge_w = w - c.gpad_left - c.gpad_right
    local gauge_h = h - c.gpad_top - c.gpad_bottom - c.title_area_top - c.title_area_bottom

    -- Draw gauge background with rounded corners
    lcd.color(c.gaugeBgColor)
    drawFilledRoundedRectangle(gauge_x, gauge_y, gauge_w, gauge_h, c.roundradius)

    -- Draw filled gauge portion based on percent
    if c.percent > 0 then
        lcd.color(c.gaugeColor)
        if c.gaugeOrientation == "vertical" then
            local fillH = math.floor(gauge_h * c.percent)
            local fillY = gauge_y + gauge_h - fillH
            if fillH > 2 * c.roundradius then
                drawFilledRoundedRectangle(gauge_x, fillY, gauge_w, fillH, c.roundradius)
            elseif fillH > 0 then
                local cx = gauge_x + gauge_w / 2
                local cy = fillY + fillH / 2
                local r = fillH / 2
                lcd.drawFilledCircle(cx, cy, r)
            end
        else -- horizontal
            local fillW = math.floor(gauge_w * c.percent)
            if fillW > 2 * c.roundradius then
                drawFilledRoundedRectangle(gauge_x, gauge_y, fillW, gauge_h, c.roundradius)
            elseif fillW > 0 then
                local cx = gauge_x + fillW / 2
                local cy = gauge_y + gauge_h / 2
                local r = fillW / 2
                lcd.drawFilledCircle(cx, cy, r)
            end
        end
    end

    -- Draw gauge border if framecolor defined
    if c.framecolor then
        lcd.color(c.framecolor)
        lcd.drawRectangle(gauge_x, gauge_y, gauge_w, gauge_h)
    end

    -- Draw value text
    if c.displayValue ~= nil then
        local str = tostring(c.displayValue) .. (c.displayUnit or "")
        local font = c.font and _G[c.font] or FONT_XL
        lcd.font(font)

        local tw, th = lcd.getTextSize(str)
        local availW = w - (c.valuepaddingleft or 0) - (c.valuepaddingright or 0)
        local availH = h - (c.valuepaddingtop or 0) - (c.valuepaddingbottom or 0)

        local region_x = x + (c.valuepaddingleft or 0)
        local region_y = y + (c.valuepaddingtop or 0)
        local region_w = availW
        local region_h = availH

        local sy = region_y + (region_h - th) / 2
        local align = (c.valuealign or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - tw
        else
            sx = region_x + (region_w - tw) / 2
        end

        local valueTextColor = c.matchingTextColor or c.valueTextColor or lcd.RGB(90,90,90)
        lcd.color(valueTextColor)
        lcd.drawText(sx, sy, str)
    end

    -- Draw title text (top or bottom)
    if c.title then
        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(c.title)
        local region_x = x + (c.titlepaddingleft or 0)
        local region_w = w - (c.titlepaddingleft or 0) - (c.titlepaddingright or 0)

        local sy = (c.titlepos == "bottom") and (y + h - (c.titlepaddingbottom or 0) - tsizeH) or (y + (c.titlepaddingtop or 0))
        local align = (c.titlealign or "center"):lower()

        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - tsizeW
        else
            sx = region_x + (region_w - tsizeW) / 2
        end

        local titleColor = c.titlecolor or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
        lcd.color(titleColor)
        lcd.drawText(sx, sy, c.title)
    end
end

return render

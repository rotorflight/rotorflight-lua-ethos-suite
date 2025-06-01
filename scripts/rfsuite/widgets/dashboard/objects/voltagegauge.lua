local render = {}

-- Default parameters for voltage gauge
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
    gaugeorientation = "horizontal",
    gaugepadding = 4,
    gaugebelowtitle = true,
    title = "VOLTAGE",
    unit = "V",
    valuealign = "center",
    titlealign = "center",
    titlepos = "bottom",
    titlecolor = "white",
    fillcolor = "green",
    bgcolor = "black",
    textcolor = "white",
    thresholds = {
        {
            value = function()
                local cfg = rfsuite.session.batteryConfig
                local cells = (cfg and cfg.batteryCellCount) or 3
                local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                return cells * minV * 1.2
            end,
            fillcolor = "red", textcolor = "white"
        },
        {
            value = function()
                local cfg = rfsuite.session.batteryConfig
                local cells = (cfg and cfg.batteryCellCount) or 3
                local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                return cells * warnV * 1.2
            end,
            fillcolor = "orange", textcolor = "white"
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
    local utils = rfsuite.widgets.dashboard.utils
    local getParam, resolveColor = utils.getParam, utils.resolveColor

    -- Merge defaults and box (user values override defaults)
    local voltBox = {}
    for k, v in pairs(defaults) do voltBox[k] = v end
    for k, v in pairs(box or {}) do voltBox[k] = v end

    -- Evaluate gaugemin/gaugemax if functions
    if type(voltBox.gaugemin) == "function" then
        voltBox.gaugemin = voltBox.gaugemin()
    end
    if type(voltBox.gaugemax) == "function" then
        voltBox.gaugemax = voltBox.gaugemax()
    end

    -- Evaluate thresholds .value if function, so they're up to date each wakeup
    if type(voltBox.thresholds) == "table" then
        for i, t in ipairs(voltBox.thresholds) do
            if type(t.value) == "function" then
                voltBox.thresholds[i] = {}
                for k,v in pairs(t) do voltBox.thresholds[i][k] = v end
                voltBox.thresholds[i].value = t.value()
            end
        end
    end

    -- Get value from telemetry
    local value = nil
    local source = voltBox.source
    if source then
        if type(source) == "function" then
            value = source(box, telemetry)
        else
            local sensor = telemetry and telemetry.getSensorSource(source)
            value = sensor and sensor:value()
            local transform = voltBox.transform
            if type(transform) == "string" and math[transform] then
                value = value and math[transform](value)
            elseif type(transform) == "function" then
                value = value and transform(value)
            elseif type(transform) == "number" then
                value = value and transform(value)
            end
        end
    end

    local displayUnit = voltBox.unit
    local displayValue = value
    if value == nil then
        displayValue = voltBox.novalue or "-"
        displayUnit = nil
    end

    -- Padding for gauge area
    local gpad_left   = voltBox.gaugepaddingleft   or voltBox.gaugepadding or 0
    local gpad_right  = voltBox.gaugepaddingright  or voltBox.gaugepadding or 0
    local gpad_top    = voltBox.gaugepaddingtop    or voltBox.gaugepadding or 0
    local gpad_bottom = voltBox.gaugepaddingbottom or voltBox.gaugepadding or 0

    local roundradius = voltBox.roundradius or 0

    -- Standardized color keys (new style)
    local bgcolor     = resolveColor(voltBox.bgcolor) or or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
    local fillbgcolor = resolveColor(voltBox.fillbgcolor) or bgcolor or (lcd.darkMode() and lcd.RGB(40,40,40) or lcd.RGB(240,240,240))
    local fillcolor   = resolveColor(voltBox.fillcolor) or lcd.RGB(0, 255, 0)
    local framecolor  = resolveColor(voltBox.framecolor) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
    local textcolor   = resolveColor(voltBox.color) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))
    local titlecolor  = resolveColor(voltBox.titlecolor) or (lcd.darkMode() and lcd.RGB(255,255,255,1) or lcd.RGB(90,90,90))

    local thresholds = voltBox.thresholds
    local thresholdFillColor, thresholdTextColor
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            if value < t_val then
                if t.color then thresholdFillColor = resolveColor(t.color) end
                if t.textcolor then thresholdTextColor = resolveColor(t.textcolor) end
                break
            end
        end
    end

    local gaugeMin = voltBox.gaugemin or 0
    local gaugeMax = voltBox.gaugemax or 100
    local gaugeOrientation = voltBox.gaugeorientation or "vertical"
    local percent = 0
    if value ~= nil and gaugeMax ~= gaugeMin then
        percent = (value - gaugeMin) / (gaugeMax - gaugeMin)
        percent = math.max(0, math.min(1, percent))
    end

    -- Value text formatting and padding
    local valuepadding = voltBox.valuepadding or 0
    local valuepaddingleft = voltBox.valuepaddingleft or valuepadding
    local valuepaddingright = voltBox.valuepaddingright or valuepadding
    local valuepaddingtop = voltBox.valuepaddingtop or valuepadding
    local valuepaddingbottom = voltBox.valuepaddingbottom or valuepadding

    -- Title parameters
    local title = voltBox.title
    local titlepadding = voltBox.titlepadding or 0
    local titlepaddingleft = voltBox.titlepaddingleft or titlepadding
    local titlepaddingright = voltBox.titlepaddingright or titlepadding
    local titlepaddingtop = voltBox.titlepaddingtop or titlepadding
    local titlepaddingbottom = voltBox.titlepaddingbottom or titlepadding
    local titlealign = voltBox.titlealign or "center"
    local titlepos = voltBox.titlepos or "top"

    local valuealign = voltBox.valuealign or "center"
    local font = voltBox.font

    -- Gauge below title?
    local gaugebelowtitle = voltBox.gaugebelowtitle

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
        bgcolor = bgcolor,
        fillbgcolor = fillbgcolor,
        fillcolor = thresholdFillColor or fillcolor,
        framecolor = framecolor,
        textcolor = thresholdTextColor or textcolor,
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
        font = font,
    }
end

-- Use the *exact same* paint function as in gauge.lua
function render.paint(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local c = box._cache or {}

    lcd.color(c.bgcolor)
    lcd.drawFilledRectangle(x, y, w, h)

    local gauge_x = x + c.gpad_left
    local gauge_y = y + c.gpad_top + c.title_area_top
    local gauge_w = w - c.gpad_left - c.gpad_right
    local gauge_h = h - c.gpad_top - c.gpad_bottom - c.title_area_top - c.title_area_bottom

    lcd.color(c.fillbgcolor)
    drawFilledRoundedRectangle(gauge_x, gauge_y, gauge_w, gauge_h, c.roundradius)

    if c.percent > 0 then
        lcd.color(c.fillcolor)
        if c.gaugeOrientation == "vertical" then
            local fillH = math.floor(gauge_h * c.percent)
            local fillY = gauge_y + gauge_h - fillH
            drawFilledRoundedRectangle(gauge_x, fillY, gauge_w, fillH, c.roundradius)
        else
            local fillW = math.floor(gauge_w * c.percent)
            drawFilledRoundedRectangle(gauge_x, gauge_y, fillW, gauge_h, c.roundradius)
        end
    end

    if c.framecolor then
        lcd.color(c.framecolor)
        lcd.drawRectangle(gauge_x, gauge_y, gauge_w, gauge_h)
    end

    if c.displayValue ~= nil then
        local str = tostring(c.displayValue) .. (c.displayUnit or "")
        local font = c.font
        if font and _G[font] then
            lcd.font(_G[font])
        else
            lcd.font(FONT_XL)
        end
        local tw, th = lcd.getTextSize(str)
        local availW = w - c.valuepaddingleft - c.valuepaddingright
        local availH = h - c.valuepaddingtop - c.valuepaddingbottom
        local region_x = x + c.valuepaddingleft
        local region_y = y + c.valuepaddingtop
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

        lcd.color(c.textcolor)
        lcd.drawText(sx, sy, str)
    end

    if c.title then
        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(c.title)
        local region_x = x + c.titlepaddingleft
        local region_w = w - c.titlepaddingleft - c.titlepaddingright
        local sy = (c.titlepos == "bottom")
            and (y + h - c.titlepaddingbottom - tsizeH)
            or (y + c.titlepaddingtop)
        local align = (c.titlealign or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - tsizeW
        else
            sx = region_x + (region_w - tsizeW) / 2
        end
        lcd.color(c.titlecolor)
        lcd.drawText(sx, sy, c.title)
    end
end

return render

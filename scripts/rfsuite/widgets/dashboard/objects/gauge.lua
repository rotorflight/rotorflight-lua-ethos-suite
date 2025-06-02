--[[

    Generic Gauge Widget

    Configurable Arguments (box table keys):
    ----------------------------------------
    source              : string/function -- Telemetry sensor source name or function
    transform           : string/function/number -- Optional value transform (math function or custom function)
    gaugemin            : number/function -- Minimum value for gauge (default: 0)
    gaugemax            : number/function -- Maximum value for gauge (default: 100)
    gaugeorientation    : string          -- "horizontal" or "vertical" (default: "vertical")
    gaugepadding        : number          -- Base padding for gauge area (default: 0)
    gaugepaddingleft    : number          -- Left padding for gauge
    gaugepaddingright   : number          -- Right padding for gauge
    gaugepaddingtop     : number          -- Top padding for gauge
    gaugepaddingbottom  : number          -- Bottom padding for gauge
    roundradius         : number          -- Corner radius for filled rect (default: 0)
    fillcolor           : color           -- Bar fill color (default: theme fallback)
    fillbgcolor         : color           -- Bar background color (default: theme fallback)
    bgcolor             : color           -- Widget background color (default: theme fallback)
    textcolor           : color           -- Value and info text color (default: theme/text fallback)
    titlecolor          : color           -- Title text color (default: theme/text fallback)
    thresholds          : table           -- List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue             : string          -- Text shown if telemetry value is missing (default: "-")

    -- Title/Label:
    title               : string          -- Title text
    titlealign          : string          -- Title alignment ("center", "left", "right")
    valuealign          : string          -- Value alignment ("center", "left", "right")
    titlepos            : string          -- Title position ("top" or "bottom", default: "top")
    titlepadding        : number          -- Padding for title (all sides unless overridden)
    titlepaddingleft    : number          -- Left padding for title
    titlepaddingright   : number          -- Right padding for title
    titlepaddingtop     : number          -- Top padding for title
    titlepaddingbottom  : number          -- Bottom padding for title
    valuepadding        : number          -- Padding for value (all sides unless overridden)
    valuepaddingleft    : number          -- Left padding for value
    valuepaddingright   : number          -- Right padding for value
    valuepaddingtop     : number          -- Top padding for value
    valuepaddingbottom  : number          -- Bottom padding for value
    font                : font            -- Value font (default: FONT_XL)
    gaugebelowtitle     : bool            -- If true, positions the gauge below the title

]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

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

    local displayUnit = getParam(box, "unit")
    local displayValue = value
    if value == nil then
        displayValue = getParam(box, "novalue") or "-"
        displayUnit = nil
    end

    -- Padding for gauge area
    local gpad_left   = getParam(box, "gaugepaddingleft")   or getParam(box, "gaugepadding") or 0
    local gpad_right  = getParam(box, "gaugepaddingright")  or getParam(box, "gaugepadding") or 0
    local gpad_top    = getParam(box, "gaugepaddingtop")    or getParam(box, "gaugepadding") or 0
    local gpad_bottom = getParam(box, "gaugepaddingbottom") or getParam(box, "gaugepadding") or 0

    local roundradius = getParam(box, "roundradius") or 0

    -- Standardized color keys (new style)
    local bgcolor     = resolveThemeColor("fillbgcolor", getParam(box, "bgcolor"))
    local fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor"))
    local fillcolor   = resolveThemeColor("fillcolor",   getParam(box, "fillcolor"))
    local textcolor   = resolveThemeColor("textcolor",   getParam(box, "textcolor"))
    local titlecolor  = resolveThemeColor("titlecolor",  getParam(box, "titlecolor"))


    local thresholds = getParam(box, "thresholds")
    local thresholdFillColor, thresholdTextColor
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            if value < t_val then
                if t.fillcolor then thresholdFillColor = resolveThemeColor(t.fillcolor) end
                if t.textcolor then thresholdTextColor = resolveThemeColor(t.textcolor) end
                break
            end
        end
    end

    local gaugeMin = getParam(box, "gaugemin") or 0
    local gaugeMax = getParam(box, "gaugemax") or 100
    local gaugeOrientation = getParam(box, "gaugeorientation") or "vertical"
    local percent = 0
    if value ~= nil and gaugeMax ~= gaugeMin then
        percent = (value - gaugeMin) / (gaugeMax - gaugeMin)
        percent = math.max(0, math.min(1, percent))
    end

    -- Value text formatting and padding
    local valuepadding = getParam(box, "valuepadding") or 0
    local valuepaddingleft = getParam(box, "valuepaddingleft") or valuepadding
    local valuepaddingright = getParam(box, "valuepaddingright") or valuepadding
    local valuepaddingtop = getParam(box, "valuepaddingtop") or valuepadding
    local valuepaddingbottom = getParam(box, "valuepaddingbottom") or valuepadding

    -- Title parameters
    local title = getParam(box, "title")
    local titlepadding = getParam(box, "titlepadding") or 0
    local titlepaddingleft = getParam(box, "titlepaddingleft") or titlepadding
    local titlepaddingright = getParam(box, "titlepaddingright") or titlepadding
    local titlepaddingtop = getParam(box, "titlepaddingtop") or titlepadding
    local titlepaddingbottom = getParam(box, "titlepaddingbottom") or titlepadding
    local titlealign = getParam(box, "titlealign") or "center"
    local titlepos = getParam(box, "titlepos") or "top"

    local valuealign = getParam(box, "valuealign") or "center"
    local font = getParam(box, "font")

    -- Gauge below title?
    local gaugebelowtitle = getParam(box, "gaugebelowtitle")

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

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Draw overall box background
    lcd.color(c.bgcolor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Gauge rectangle (with padding and title space)
    local gauge_x = x + c.gpad_left
    local gauge_y = y + c.gpad_top + c.title_area_top
    local gauge_w = w - c.gpad_left - c.gpad_right
    local gauge_h = h - c.gpad_top - c.gpad_bottom - c.title_area_top - c.title_area_bottom

    -- Gauge background
    lcd.color(c.fillbgcolor)
    drawFilledRoundedRectangle(gauge_x, gauge_y, gauge_w, gauge_h, c.roundradius)

    -- Gauge fill
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

    -- Value text (with dynamic/static font)
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

    -- Title (top or bottom)
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

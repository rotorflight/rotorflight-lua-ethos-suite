--[[

    Battery Bar Widget

    Configurable Arguments (box table keys):
    ----------------------------------------
    source             : string   -- Telemetry sensor source name (e.g., "battery")
    transform          : string/function/number -- Optional value transform (math function or custom function)
    gaugemin           : number/function -- Minimum value for gauge (default: 0)
    gaugemax           : number/function -- Maximum value for gauge (default: 100)
    gaugeorientation   : string   -- "horizontal" or "vertical" (default: "horizontal")
    gaugepadding       : number   -- Padding inside battery bar (default: 2)
    gaugesegments      : number   -- Number of fill segments (default: 6)
    showvalue          : bool     -- Show value text (default: false)
    valueformat        : string   -- Lua format string for value display (e.g., "%.1f")
    unit               : string   -- Unit to append to value (e.g., "V")
    thresholds         : table    -- List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue            : string   -- Text shown if telemetry value is missing (default: "-")

    -- Appearance/Theming:
    bgcolor            : color    -- Widget background color (default: theme fallback)
    fillcolor          : color    -- Bar fill color (default: theme fallback)
    fillbgcolor        : color    -- Bar background color (default: theme fallback)
    textcolor          : color    -- Value text color (default: theme/text fallback)
    titlecolor         : color    -- Title text color (default: theme/text fallback)

    -- Title/Label:
    title              : string   -- Title text
    titlealign         : string   -- Title alignment ("center", "left", "right")
    valuealign         : string   -- Value alignment ("center", "left", "right")
    titlepos           : string   -- Title position ("top" or "bottom")
    titlepadding       : number   -- Padding for title (all sides unless overridden)
    titlepaddingleft   : number   -- Left padding for title
    titlepaddingright  : number   -- Right padding for title
    titlepaddingtop    : number   -- Top padding for title
    titlepaddingbottom : number   -- Bottom padding for title
    valuepadding       : number   -- Padding for value (all sides unless overridden)
    valuepaddingleft   : number   -- Left padding for value
    valuepaddingright  : number   -- Right padding for value
    valuepaddingtop    : number   -- Top padding for value
    valuepaddingbottom : number   -- Bottom padding for value
    font               : font     -- Font for value (default: nil / widget default)

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
    -- Value
    local value
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

    -- Display
    local displayUnit = getParam(box, "unit")
    local displayValue = value
    if value == nil then
        displayValue = getParam(box, "novalue") or "-"
        displayUnit = nil
    end

    -- Gauge params
    local gpad_left   = getParam(box, "gaugepaddingleft")   or getParam(box, "gaugepadding") or 0
    local gpad_right  = getParam(box, "gaugepaddingright")  or getParam(box, "gaugepadding") or 0
    local gpad_top    = getParam(box, "gaugepaddingtop")    or getParam(box, "gaugepadding") or 0
    local gpad_bottom = getParam(box, "gaugepaddingbottom") or getParam(box, "gaugepadding") or 0
    local roundradius = getParam(box, "roundradius") or 0

    -- Color resolution (all done here)
    local bgcolor     = resolveThemeColor("fillbgcolor", getParam(box, "bgcolor"))
    local fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor"))
    local fillcolor   = resolveThemeColor("fillcolor",   getParam(box, "fillcolor"))
    local textcolor   = resolveThemeColor("textcolor",   getParam(box, "textcolor"))
    local titlecolor  = resolveThemeColor("titlecolor",  getParam(box, "titlecolor"))

    -- Threshold logic: override colors if needed
    local thresholds = getParam(box, "thresholds")
    local thresholdTextColor = nil
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            if value < t_val then
                if t.fillcolor then fillcolor = resolveThemeColor("fillcolor", t.fillcolor) end
                if t.textcolor then thresholdTextColor = resolveThemeColor("textcolor", t.textcolor) end
                break
            end
        end
    end

    -- Gauge math
    local gaugeMin = getParam(box, "gaugemin") or 0
    local gaugeMax = getParam(box, "gaugemax") or 100
    local gaugeOrientation = getParam(box, "gaugeorientation") or "vertical"
    local percent = 0
    if value ~= nil and gaugeMax ~= gaugeMin then
        percent = (value - gaugeMin) / (gaugeMax - gaugeMin)
        percent = math.max(0, math.min(1, percent))
    end

        -- Title and value formatting
    local valuepadding = getParam(box, "valuepadding") or 0
    local valuepaddingleft = getParam(box, "valuepaddingleft") or valuepadding
    local valuepaddingright = getParam(box, "valuepaddingright") or valuepadding
    local valuepaddingtop = getParam(box, "valuepaddingtop") or valuepadding
    local valuepaddingbottom = getParam(box, "valuepaddingbottom") or valuepadding

    local title = getParam(box, "title")
    local titlepadding = getParam(box, "titlepadding") or 0
    local titlepaddingleft = getParam(box, "titlepaddingleft") or titlepadding
    local titlepaddingright = getParam(box, "titlepaddingright") or titlepadding
    local titlepaddingtop = getParam(box, "titlepaddingtop") or titlepadding
    local titlepaddingbottom = getParam(box, "titlepaddingbottom") or titlepadding
    local titlealign = getParam(box, "titlealign") or "center"
    local titlepos = getParam(box, "titlepos") or "top"
    local valuealign = getParam(box, "valuealign") or "center"
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

    -- All fields cached for paint
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
        fillcolor = fillcolor,
        textcolor = textcolor,
        thresholdTextColor = thresholdTextColor,
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
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Draw overall box background
    lcd.color(c.bgcolor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Gauge rectangle
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

    -- Value text
    if c.displayValue ~= nil then
        local str = tostring(c.displayValue) .. (c.displayUnit or "")
        local valueFont = box._cache.font or FONT_XL
        lcd.font(valueFont)
        local tw, th = lcd.getTextSize(str)
        local availW = w - c.valuepaddingleft - c.valuepaddingright
        local availH = h - c.valuepaddingtop - c.valuepaddingbottom
        local sx = x + c.valuepaddingleft + (availW - tw) / 2
        local sy = y + c.valuepaddingtop + (availH - th) / 2

        -- Use threshold text color if it overlaps with fill (optional, basic version)
        local useThresholdTextColor = c.thresholdTextColor and c.percent > 0
        local valueTextColor = useThresholdTextColor and c.thresholdTextColor or c.textcolor
        lcd.color(valueTextColor)
        lcd.drawText(sx, sy, str)
    end

    -- Title
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

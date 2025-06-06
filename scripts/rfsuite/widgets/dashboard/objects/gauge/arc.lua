--[[
    Arc Gauge Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
    -- Title parameters
    title               : string    -- (Optional) Title text
    titlepos            : string    -- (Optional) If `title` is present but `titlepos` is not set, title is placed at the top by default.
    titlealign          : string    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font      -- (Optional) Title font (e.g., FONT_L, FONT_XL)
    titlespacing        : number    -- (Optional) Vertical gap between title and value
    titlecolor          : color     -- (Optional) Title text color (theme/text fallback)
    titlepadding        : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number    -- (Optional) Left padding for title
    titlepaddingright   : number    -- (Optional) Right padding for title
    titlepaddingtop     : number    -- (Optional) Top padding for title
    titlepaddingbottom  : number    -- (Optional) Bottom padding for title

    -- Value/Source parameters
    value               : any       -- (Optional) Static value to display if telemetry is not present
    source              : string    -- Telemetry sensor source name (e.g., "voltage", "current")
    transform           : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number    -- (Optional) Number of decimal places for numeric display
    thresholds          : table     -- (Optional) List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue             : string    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string    -- (Optional) Unit label to append to value ("" hides, default resolves dynamically)
    font                : font      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color     -- (Optional) Value text color (theme/text fallback)
    valuepadding        : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number    -- (Optional) Left padding for value
    valuepaddingright   : number    -- (Optional) Right padding for value
    valuepaddingtop     : number    -- (Optional) Top padding for value
    valuepaddingbottom  : number    -- (Optional) Bottom padding for value

    -- Appearance/Theming
    bgcolor             : color     -- (Optional) Widget background color (theme fallback)
    fillbgcolor         : color     -- (Optional) Arc background color (theme fallback)
    fillcolor           : color     -- (Optional) Arc foreground color (theme fallback)

    -- Arc Geometry/Advanced
    min                 : number    -- (Optional) Minimum value of the arc (default: 0)
    max                 : number    -- (Optional) Maximum value of the arc (default: 100)
    arcoffsety          : number    -- (Optional) Y offset for arc center (default: 0)
    startangle          : number    -- (Optional) Arc start angle (deg, default: 225)
    sweep               : number    -- (Optional) Arc sweep angle (deg, default: 270)
    thickness           : number    -- (Optional) Arc thickness in pixels

    -- Subtext
    subtext             : string    -- (Optional) Sub-label below arc (e.g., "Max")
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

-- Arc drawing function
local function drawArc(cx, cy, radius, thickness, angleStart, angleEnd, color, cacheStepRad)
    local step = 1
    local rad_thick = thickness / 2
    angleStart = math.rad(angleStart)
    angleEnd = math.rad(angleEnd)
    if angleEnd > angleStart then
        angleEnd = angleEnd - 2 * math.pi
    end
    lcd.color(color)
    local stepRad = cacheStepRad or math.rad(step)
    for a = angleStart, angleEnd, -stepRad do
        local x = cx + radius * math.cos(a)
        local y = cy - radius * math.sin(a)
        lcd.drawFilledCircle(x, y, rad_thick)
    end
    local x_end = cx + radius * math.cos(angleEnd)
    local y_end = cy - radius * math.sin(angleEnd)
    lcd.drawFilledCircle(x_end, y_end, rad_thick)
end

function render.wakeup(box, telemetry)
    -- Value extraction
    local source = getParam(box, "source")
    local value
    if telemetry and source then
        value = telemetry.getSensor(source)
    end

    -- Transform and decimals (if required)
    local displayValue
    if value ~= nil then
        displayValue = utils.transformValue(value, box)
    end

    -- Resolve arc min/max and calculate percent fill for the gauge (clamped 0-1)
    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100
    local percent = 0
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end

    -- Threshold logic (if required)
    local textcolor = utils.resolveThresholdColor(value, box, "textcolor", "textcolor")
    local fillcolor = utils.resolveThresholdColor(value, box, "fillcolor", "fillcolor")

    -- Dynamic unit logic (User can force a unit or omit unit using "" to hide)
    local manualUnit = getParam(box, "unit")
    local unit

    if manualUnit ~= nil then
        unit = manualUnit
    else
        local displayValue, _, dynamicUnit = telemetry.getSensor(source)
        if dynamicUnit ~= nil then
            unit = dynamicUnit
        elseif source and telemetry and telemetry.sensorTable[source] then
            unit = telemetry.sensorTable[source].unit_string or ""
        else
            unit = ""
        end
    end

    -- Title logic to determine if a title is set
    local hasTitle = getParam(box, "title")
    local titlepos = getParam(box, "titlepos")
    if hasTitle then
        titlepos = titlepos or "top"
    end

    -- Fallback if no value
    if value == nil then
        displayValue = getParam(box, "novalue") or "-"
        unit = nil
    end

    box._cache = {
        arcoffsety         = getParam(box, "arcoffsety"),
        startangle         = getParam(box, "startangle") or 225,
        sweep              = getParam(box, "sweep") or 270,
        min                = min,
        max                = max,
        thickness          = getParam(box, "thickness"),
        percent            = percent,
        fillcolor          = fillcolor,
        fillbgcolor        = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor")),
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        value              = value,
        displayValue       = displayValue,
        unit               = unit,
        title              = getParam(box, "title"),
        titlepos           = titlepos,
        titlealign         = getParam(box, "titlealign"),
        titlefont          = getParam(box, "titlefont"),
        titlespacing       = getParam(box, "titlespacing") or 0,
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        font               = getParam(box, "font") or "FONT_STD",
        valuealign         = getParam(box, "valuealign"),
        textcolor          = textcolor,
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop") or 18,
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        subtext            = getParam(box, "subtext"),
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Title/Arc layout calculation
    local titleHeight = 0
    if c.title then
        lcd.font(_G[c.titlefont] or FONT_XS)
        local _, th = lcd.getTextSize(c.title)
        titleHeight = (th or 0) + (c.titlespacing or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0)
    end
   
    -- Arc region: based on titlepos (default is top)
    local titlepos = c.titlepos
    local arcRegionY, arcRegionH, cy, radius
    local arcMargin, thickness, maxRadius

    if c.titlepos == "top" then
        arcRegionY   = y + titleHeight
        arcRegionH   = h - titleHeight
        arcMargin    = 8
        thickness    = c.thickness or math.max(6, math.min(w, arcRegionH) * 0.07)
        maxRadius    = ((arcRegionH - arcMargin) / 2) - (thickness / 2)
        radius       = math.min(w * 0.50, maxRadius + 8)
        cy           = arcRegionY + arcRegionH * 0.5 + (c.arcoffsety or 0)
    elseif c.titlepos == "bottom" then
        arcRegionY   = y
        arcRegionH   = h - titleHeight
        arcMargin    = 8
        thickness    = c.thickness or math.max(6, math.min(w, arcRegionH) * 0.07)
        maxRadius    = ((arcRegionH - arcMargin) / 2) - (thickness / 2)
        radius       = math.min(w * 0.50, maxRadius + 8)
        cy           = arcRegionY + arcRegionH * 0.60 + (c.arcoffsety or 0)
    else
        arcRegionY   = y
        arcRegionH   = h
        arcMargin    = 8
        thickness    = c.thickness or math.max(6, math.min(w, arcRegionH) * 0.07)
        maxRadius    = ((arcRegionH - arcMargin) / 2) - (thickness / 2)
        radius       = math.min(w * 0.50, maxRadius + 8)
        cy           = arcRegionY + arcRegionH * 0.55 + (c.arcoffsety or 0)
    end

    local cx = x + w / 2
    local stepRad = math.rad(2)

    -- Widget background
    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end     

    -- Draw background arc
    if c.startangle and c.sweep then
        drawArc(cx, cy, radius, thickness, c.startangle, c.startangle - c.sweep, c.fillbgcolor, stepRad)
    end

    -- Draw value arc
    if c.percent > 0 then
        drawArc(cx, cy, radius, thickness, c.startangle, c.startangle - c.sweep * c.percent, c.fillcolor, stepRad)
    end

    -- Draw title and value
    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.displayValue, c.unit, c.font, c.valuealign, c.textcolor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        nil
    )

    -- Draw subtext if present
    if c.subtext then
        lcd.font(FONT_XS)
        local tw, _ = lcd.getTextSize(c.subtext)
        lcd.color(c.textcolor)
        lcd.drawText(cx - tw / 2, cy + radius * 0.55, c.subtext)
    end
end

return render

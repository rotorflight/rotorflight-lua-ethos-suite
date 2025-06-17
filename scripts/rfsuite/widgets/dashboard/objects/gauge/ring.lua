--[[
    Rainbow Gauge Widget
    Configurable Parameters (box table fields):
    -------------------------------------------

    -- Timing
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)

    -- Title parameters
    title               : string    -- (Optional) Title text
    titlepos            : string    -- (Optional) If `title` is present but `titlepos` is not set, title is placed at the top by default
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
    source              : string    -- Telemetry sensor source name (e.g., "temp_esc")
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
    fillbgcolor         : color     -- (Optional) Ring background color (theme fallback)
    fillcolor           : color     -- (Optional) Ring foreground color (theme fallback)

    -- Geometry
    thickness           : number    -- (Optional) Ring thickness in pixels (default is proportional to radius)

]]


local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local lastDisplayValue = nil

function render.dirty(box)
    -- Always dirty on first run
    if box._lastDisplayValue == nil then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end

    if box._lastDisplayValue ~= box._currentDisplayValue then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end

    return false
end

local function drawArc(cx, cy, radius, thickness, startAngle, endAngle, color)
    lcd.color(color)
    local outer = radius
    local inner = math.max(1, radius - (thickness or 6))

    -- Normalize angles
    startAngle = startAngle % 360
    endAngle = endAngle % 360
    if endAngle <= startAngle then
        endAngle = endAngle + 360
    end

    local sweep = endAngle - startAngle
    if sweep <= 180 then
        lcd.drawAnnulusSector(cx, cy, inner, outer, startAngle, endAngle)
    else
        local mid = startAngle + sweep / 2
        lcd.drawAnnulusSector(cx, cy, inner, outer, startAngle, mid)
        lcd.drawAnnulusSector(cx, cy, inner, outer, mid, endAngle)
    end
end

function render.wakeup(box, telemetry)
    -- Value extraction
    local source = getParam(box, "source")
    local value, _, dynamicUnit
    if telemetry and source then
        value, _, dynamicUnit = telemetry.getSensor(source)
    end

    -- Dynamic unit logic (User can force a unit or omit unit using "" to hide)
    local manualUnit = getParam(box, "unit")
    local unit

    if manualUnit ~= nil then
        unit = manualUnit  -- use user value, even if ""
    elseif dynamicUnit ~= nil then
        unit = dynamicUnit
    elseif source and telemetry and telemetry.sensorTable[source] then
        unit = telemetry.sensorTable[source].unit_string or ""
    else
        unit = ""
    end

    -- Transform and decimals (if required)
    local displayValue
    if value ~= nil then
        displayValue = utils.transformValue(value, box)
    end

    -- Fallback if no value
    if value == nil then
        displayValue = getParam(box, "novalue") or "-"
        unit = nil
    end

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = value

    box._cache = {
        value              = value,
        displayValue       = displayValue,
        unit               = unit,
        novalue            = getParam(box, "novalue") or "-",
        fillcolor          = utils.resolveThresholdColor(value, box, "fillcolor", "fillcolor", thresholds),
        textcolor          = utils.resolveThresholdColor(value, box, "textcolor", "textcolor", thresholds),
        fillbgcolor        = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor")),
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        thresholds         = getParam(box, "thresholds"),
        title              = getParam(box, "title"),
        titlepos           = getParam(box, "titlepos") or (getParam(box, "title") and "top"),
        titlealign         = getParam(box, "titlealign"),
        titlefont          = getParam(box, "titlefont"),
        titlespacing       = getParam(box, "titlespacing"),
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        font               = getParam(box, "font") or "FONT_STD",
        decimals           = getParam(box, "decimals"),
        valuealign         = getParam(box, "valuealign"),
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        thickness          = getParam(box, "thickness"),
    }

end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Widget background
    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    -- Arc layout
    local cx = x + w / 2

    -- Calculate total height used by the title (if present)
    local titleHeight = 0
    if c.title then
        lcd.font(_G[c.titlefont] or FONT_XS)
        local _, th = lcd.getTextSize(c.title)
        titleHeight = (th or 0) + (c.titlespacing or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0)
    end

    -- Compute vertical center of the arc based on title position
    local cy
    if c.titlepos == "top" then
        cy = y + titleHeight + (h - titleHeight) * 0.45
    elseif c.titlepos == "bottom" then
        cy = y + (h - titleHeight) * 0.5
    else
        cy = y + h * 0.5
    end

    -- Compute radius and thickness, slightly enlarging the ring when no title is present
    local ringPadding = 2
    local baseSize = math.min(w, h - (c.title and ringPadding * 2 or 0))
    local ringSize = math.min(0.88 * (c.title and 1 or 1.05), 1.0)
    local radius    = baseSize * 0.5 * ringSize
    local thickness = c.thickness or math.max(8, radius * 0.18)

    -- Full ring: draw background first, then filled foreground
    drawArc(cx, cy, radius, thickness, 0, 360, c.fillbgcolor)
    drawArc(cx, cy, radius, thickness, 0, 360, c.fillcolor)

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
end

return render

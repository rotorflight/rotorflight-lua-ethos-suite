--[[

    Heat Ring Widget

    Configurable Arguments (box table keys):
    ----------------------------------------
    source              : string/function -- Telemetry sensor source name or function
    transform           : string/function/number -- Optional value transform (math function or custom function)
    min                 : number/function -- Minimum value for gauge (default: 0)
    max                 : number/function -- Maximum value for gauge (default: 100)
    ringsize            : number          -- Size of ring as fraction of widget (default: 0.88)
    fillcolor           : color           -- Ring fill color (default: theme fallback)
    fillbgcolor         : color           -- Ring background color (default: theme fallback)
    thresholds          : table           -- List of threshold tables: {value=..., fillcolor=...}
    novalue             : string          -- Text shown if telemetry value is missing (default: "-")
    unit                : string          -- Unit label for value
    textcolor           : color           -- Value text color (default: theme/text fallback)
    textalign           : string          -- Value text alignment ("center", "left", "right")
    textoffset          : number          -- Offset for value text position (default: 0)
    title               : string          -- Title text
    titlealign          : string          -- Title alignment ("center", "left", "right")
    titlepos            : string          -- Title position ("above" or "below")
    titleoffset         : number          -- Offset for title position (default: 0)
    bgcolor             : color           -- Widget background color (default: theme fallback)

]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

local function drawSolidRing(cx, cy, radius, thickness, fillcolor, fillbgcolor)
    lcd.color(fillbgcolor)
    lcd.drawFilledCircle(cx, cy, radius)
    lcd.color(fillcolor)
    lcd.drawFilledCircle(cx, cy, radius - thickness)
end

function render.wakeup(box, telemetry)
    -- Calculate the value from telemetry, transform, min/max, etc
    local value, source = nil, getParam(box, "source")
    if source and telemetry and telemetry.getSensorSource then
        local sensor = telemetry.getSensorSource(source)
        value = sensor and sensor.value and sensor:value()
    end

    -- Apply transform
    local transform = getParam(box, "transform")
    if value ~= nil and transform ~= nil then
        if type(transform) == "function" then value = transform(value)
        elseif transform == "floor" then value = math.floor(value)
        elseif transform == "ceil" then value = math.ceil(value)
        elseif transform == "round" then value = math.floor(value + 0.5)
        end
    end

    -- Clamp
    local min = getParam(box, "min")
    local max = getParam(box, "max")
    if type(min) == "function" then min = min() end
    if type(max) == "function" then max = max() end
    if min ~= nil and max ~= nil and value ~= nil then
        value = math.max(min, math.min(max, value))
    end

    -- Prepare display string
    local novalue = getParam(box, "novalue") or "-"
    local displayValue = value or novalue
    local unit = (value ~= nil) and getParam(box, "unit") or nil

    -- Resolve fillcolor and textcolor with theme and thresholds
    local fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor"))
    local fillcolor   = resolveThemeColor("fillcolor", getParam(box, "fillcolor"))
    local textcolor   = resolveThemeColor("textcolor", getParam(box, "textcolor"))
    local thresholds  = getParam(box, "thresholds")
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            if value < t_val then
                if t.fillcolor then fillcolor = resolveThemeColor("fillcolor", t.fillcolor) end
                if t.textcolor then textcolor = resolveThemeColor("textcolor", t.textcolor) end
                break
            end
        end
    end

    -- Cache only essentials
    box._cache = {
        value        = value,
        displayValue = displayValue,
        unit         = unit,
        novalue      = novalue,
        fillcolor    = fillcolor,
        fillbgcolor  = fillbgcolor,
        textcolor    = textcolor,
        title        = getParam(box, "title"),
        titlecolor   = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        bgcolor      = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        ringsize     = getParam(box, "ringsize") or 0.88,
        textalign    = getParam(box, "textalign") or "center",
        titlealign   = getParam(box, "titlealign") or "center",
        titlepos     = getParam(box, "titlepos") or "above",
        textoffset   = getParam(box, "textoffset") or 0,
        titleoffset  = getParam(box, "titleoffset") or 0,
    }
end

function render.paint(x, y, w, h, box)
    local c = box._cache or {}

    -- Widget background
    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end
    -- Ring geometry
    local ringsize  = math.max(0.1, math.min(c.ringsize or 0.88, 1.0))
    local cx, cy    = x + w / 2, y + h / 2
    local radius    = math.min(w, h) * 0.5 * ringsize
    local thickness = math.max(8, radius * 0.18)

    -- Draw ring
    drawSolidRing(cx, cy, radius, thickness, c.fillbgcolor, c.fillcolor)

    -- Prepare display text
    local valStr = tostring(c.displayValue) .. (c.unit or "")
    -- Auto font sizing
    local fontSizes = {"FONT_XXL", "FONT_XL", "FONT_L", "FONT_M", "FONT_S"}
    local maxWidth, maxHeight = radius * 1.6, radius * 0.7
    local bestFont, vw, vh
    for _, fname in ipairs(fontSizes) do
        lcd.font(_G[fname])
        local tw, th = lcd.getTextSize(valStr)
        if tw <= maxWidth and th <= maxHeight then
            bestFont = _G[fname]; vw, vh = tw, th; break
        end
    end
    if not vw then
        lcd.font(_G[fontSizes[#fontSizes]])
        vw, vh = lcd.getTextSize(valStr)
        bestFont = _G[fontSizes[#fontSizes]]
    end

    -- Value alignment
    lcd.font(bestFont)
    lcd.color(c.textcolor)
    local text_x
    if c.textalign == "left" then
        text_x = cx - radius + 8
    elseif c.textalign == "right" then
        text_x = cx + radius - vw - 8
    else
        text_x = cx - vw / 2
    end
    lcd.drawText(text_x, cy - vh / 2 + (c.textoffset or 0), valStr)

    -- Title
    if c.title then
        lcd.font(FONT_XS)
        lcd.color(c.titlecolor)
        local tw, th = lcd.getTextSize(c.title)
        local title_x
        if c.titlealign == "left" then
            title_x = cx - radius + 4
        elseif c.titlealign == "right" then
            title_x = cx + radius - tw - 4
        else
            title_x = cx - tw / 2
        end
        local title_y
        if c.titlepos == "below" then
            title_y = cy + vh / 2 + 2 + (c.titleoffset or 0)
        else
            title_y = cy - vh / 2 - th - 2 + (c.titleoffset or 0)
        end
        lcd.drawText(title_x, title_y, c.title)
    end
end

return render

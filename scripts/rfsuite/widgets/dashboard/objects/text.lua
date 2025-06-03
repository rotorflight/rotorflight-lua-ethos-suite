--[[
    Text Display Widget

    Configurable Parameters (box table fields):
    -------------------------------------------
    value               : any                       -- (Optional) Static value to display if telemetry is not present
    transform           : string|function|number    -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number                    -- (Optional) Number of decimal places for numeric display
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value or configure as "" to omit the unit from being displayed. If not specified, the widget attempts to resolve a dynamic unit
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    title               : string                    -- (Optional) Title text
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

function render.wakeup(box)
    -- Value extraction
    local value = getParam(box, "value")

    -- Transform and decimals
    local displayValue
    if value ~= nil then
        displayValue = utils.transformValue(value, box)
    end

    -- Threshold logic (if required)
    local textcolor = utils.resolveThresholdTextColor(value, box)

    -- Dynamic unit logic (User can force a unit or omit unit using "" to hide)
    local manualUnit = getParam(box, "unit")
    local unit

    if manualUnit ~= nil then
        unit = manualUnit  -- use user value, even if ""
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

    -- Fallback if no value
    if value == nil then
        displayValue = getParam(box, "novalue") or "-"
        unit = nil
    end

    box._cache = {
        displayValue       = displayValue,
        title              = getParam(box, "title"),
        unit               = unit,
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        textcolor          = resolveThemeColor("textcolor", getParam(box, "textcolor")),
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        titlealign         = getParam(box, "titlealign"),
        valuealign         = getParam(box, "valuealign"),
        titlepos           = getParam(box, "titlepos"),
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        font               = getParam(box, "font"),
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    utils.box(
        x, y, w, h,
        c.title, c.displayValue, c.unit, c.bgcolor,
        c.titlealign, c.valuealign, c.titlecolor, c.titlepos, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom, c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom, c.font, c.textcolor
    )
end

return render

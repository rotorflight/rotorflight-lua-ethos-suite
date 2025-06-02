--[[
    Text Display Widget

    Configurable Parameters (box table fields):
    -------------------------------------------
    value               : any            -- Value to display (can be number or string)
    transform           : string|function -- (Optional) Value transformation ("floor", "ceil", "round", or custom function)
    decimals            : number         -- (Optional) Number of decimal places for numeric display
    thresholds          : table          -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string         -- (Optional) Text shown if value is missing (default: "-")
    unit                : string         -- (Optional) Unit label to append to value
    font                : font           -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    bgcolor             : color          -- (Optional) Widget background color (theme fallback if nil)
    textcolor           : color          -- (Optional) Value text color (theme/text fallback if nil)
    titlecolor          : color          -- (Optional) Title text color (theme/text fallback if nil)
    title               : string         -- (Optional) Title text
    titlealign          : string         -- (Optional) Title alignment ("center", "left", "right")
    valuealign          : string         -- (Optional) Value alignment ("center", "left", "right")
    titlepos            : string         -- (Optional) Title position ("top" or "bottom")
    titlepadding        : number         -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number         -- (Optional) Left padding for title
    titlepaddingright   : number         -- (Optional) Right padding for title
    titlepaddingtop     : number         -- (Optional) Top padding for title
    titlepaddingbottom  : number         -- (Optional) Bottom padding for title
    valuepadding        : number         -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number         -- (Optional) Left padding for value
    valuepaddingright   : number         -- (Optional) Right padding for value
    valuepaddingtop     : number         -- (Optional) Top padding for value
    valuepaddingbottom  : number         -- (Optional) Bottom padding for value

]]


local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

function render.wakeup(box)
    -- Extract value to display
    local value = getParam(box, "value")

    -- Apply transform/decimals (gold template logic)
    local displayValue
    if value ~= nil then
        displayValue = utils.transformValue(value, box)
        local unit = getParam(box, "unit") or ""
        if unit ~= "" then
            displayValue = displayValue .. unit
        end
    else
        displayValue = getParam(box, "novalue") or "-"
    end

    -- Threshold logic for textcolor
    local textcolor = resolveThemeColor(getParam(box, "textcolor"))
    local thresholds = getParam(box, "thresholds")
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            if value < t_val and t.textcolor then
                textcolor = resolveThemeColor(t.textcolor)
                break
            end
        end
    end

    box._cache = {
        displayValue       = displayValue,
        title              = getParam(box, "title"),
        unit               = nil,
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
    c.title, c.displayValue, nil, c.bgcolor,
    c.titlealign, c.valuealign, c.titlecolor, c.titlepos,
    c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
    c.titlepaddingtop, c.titlepaddingbottom,
    c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
    c.valuepaddingtop, c.valuepaddingbottom,
    c.font, c.textcolor
    )
end

return render

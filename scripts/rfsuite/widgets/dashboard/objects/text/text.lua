--[[
    Text Display Widget (Static/Label)

    Configurable Parameters (box table fields):
    -------------------------------------------
    title               : string    -- (Optional) Title text displayed above or below the value
    titlepos            : string    -- (Optional) Title position: "top" or "bottom"
    titlealign          : string    -- (Optional) Title alignment: "center", "left", or "right"
    titlefont           : font      -- (Optional) Font for title (e.g., FONT_L, FONT_XL). Uses theme or default if unset.
    titlespacing        : number    -- (Optional) Vertical gap between title and value (pixels)
    titlecolor          : color     -- (Optional) Title text color (theme fallback if nil)
    titlepadding        : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number    -- (Optional) Left padding for title
    titlepaddingright   : number    -- (Optional) Right padding for title
    titlepaddingtop     : number    -- (Optional) Top padding for title
    titlepaddingbottom  : number    -- (Optional) Bottom padding for title
    value               : string|number   -- (Optional) **Static** value to display (required for this widget)
    font                : font            -- (Optional) Font for value (e.g., FONT_L, FONT_XL). Uses theme or default if unset.
    valuealign          : string          -- (Optional) Value alignment: "center", "left", or "right"
    textcolor           : color           -- (Optional) Value text color (theme fallback if nil)
    valuepadding        : number          -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number          -- (Optional) Left padding for value
    valuepaddingright   : number          -- (Optional) Right padding for value
    valuepaddingtop     : number          -- (Optional) Top padding for value
    valuepaddingbottom  : number          -- (Optional) Bottom padding for value
    bgcolor             : color           -- (Optional) Widget background color (theme fallback if nil)
    novalue             : string          -- (Optional) Text to show if value is nil (default: "-")

    -- Note:
    -- This widget is for **static or label text only**. It does not support live telemetry or stats.
    -- If you need dynamic stats or telemetry (min/max/live), use `stats.lua` or other appropriate widgets.
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

function render.wakeup(box, telemetry)
    -- Value extraction
    local value = getParam(box, "value")
    local displayValue = value
    if value == nil then
        displayValue = getParam(box, "novalue") or "-"
    end

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = displayValue

    box._cache = {
        displayValue       = displayValue,
        unit               = nil,
        title              = getParam(box, "title"),
        titlepos           = getParam(box, "titlepos"),
        titlealign         = getParam(box, "titlealign"),
        titlefont          = getParam(box, "titlefont"),
        titlespacing       = getParam(box, "titlespacing"),
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        font               = getParam(box, "font"),
        valuealign         = getParam(box, "valuealign"),
        textcolor          = resolveThemeColor("textcolor", getParam(box, "textcolor")),
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    utils.box(
    x, y, w, h,
    c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
    c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
    c.titlepaddingtop, c.titlepaddingbottom,
    c.displayValue, c.unit, c.font, c.valuealign, c.textcolor,
    c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
    c.valuepaddingtop, c.valuepaddingbottom,
    c.bgcolor
)
end

return render

--[[
    Total Flight Time Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    value               : any                       -- (Optional) Static value to display if telemetry is not present
    unit                : string                    -- (Optional) Unit label to append to value or configure as "" to omit the unit from being displayed. If not specified, the widget attempts to resolve a dynamic unit
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
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

function render.wakeup(box)
    local value = rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "totalflighttime")
    local unit = getParam(box, "unit")
    local displayValue

    -- Format to HH:MM:SS
    if type(value) == "number" and value > 0 then
        local hours = math.floor(value / 3600)
        local minutes = math.floor((value % 3600) / 60)
        local seconds = math.floor(value % 60)
        displayValue = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    else
        displayValue = getParam(box, "novalue") or "00:00:00"
        unit = nil
    end

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = displayValue

    box._cache = {
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
        displayValue       = displayValue,
        unit               = unit,
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

-- set rate at which objects wakeup must be called
-- using this value will short circut the spread scheduling in
-- dashboard.lua to ensure object gets a heartbeat when required.
-- its mostly only used for objects that need to be updated like the
-- flight time objects
render.scheduler = 0.5

return render

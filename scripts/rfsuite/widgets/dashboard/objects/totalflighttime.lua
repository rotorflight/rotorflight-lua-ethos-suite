--[[
    Total Flight Time Widget

    Configurable Parameters (box table fields):
    -------------------------------------------
    unit                : string                    -- (Optional) Unit label to append to value
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

    box._cache = {
        displayValue       = displayValue,
        unit               = unit,
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        textcolor          = resolveThemeColor("textcolor", getParam(box, "textcolor")),
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        title              = getParam(box, "title"),
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

-- set rate at which objects wakeup must be called
-- using this value will short circut the spread scheduling in
-- dashboard.lua to ensure object gets a heartbeat when required.
-- its mostly only used for objects that need to be updated like the
-- flight time objects
render.scheduler = 0.5

return render

--[[

    Session Value Widget

    Configurable Arguments (box table keys):
    ----------------------------------------
    source              : string   -- rfsuite.session key to display (e.g., "totalflighttime")
    title               : string   -- Title text
    novalue             : string   -- Text shown if session value is missing (default: "-")
    unit                : string   -- Unit label to append to value
    font                : font     -- Value font (e.g., FONT_L, FONT_XL)
    bgcolor             : color    -- Widget background color (default: theme fallback)
    textcolor           : color    -- Value text color (default: theme/text fallback)
    titlecolor          : color    -- Title text color (default: theme/text fallback)
    titlealign          : string   -- Title alignment ("center", "left", "right")
    valuealign          : string   -- Value alignment ("center", "left", "right")
    titlepos            : string   -- Title position ("top" or "bottom")
    titlepadding        : number   -- Padding for title (all sides unless overridden)
    titlepaddingleft    : number   -- Left padding for title
    titlepaddingright   : number   -- Right padding for title
    titlepaddingtop     : number   -- Top padding for title
    titlepaddingbottom  : number   -- Bottom padding for title
    valuepadding        : number   -- Padding for value (all sides unless overridden)
    valuepaddingleft    : number   -- Left padding for value
    valuepaddingright   : number   -- Right padding for value
    valuepaddingtop     : number   -- Top padding for value
    valuepaddingbottom  : number   -- Bottom padding for value

]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

function render.wakeup(box)
    local src = getParam(box, "source")
    local displayValue = rfsuite.session[src]
    local unit = getParam(box, "unit")
    if displayValue == nil then
        displayValue = getParam(box, "novalue") or "-"
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
        c.titlealign, c.valuealign, c.titlecolor, c.titlepos,
        c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.font, c.textcolor
    )
end

return render

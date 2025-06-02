--[[

    Arm Flags Widget

    Configurable Arguments (box table keys):
    ----------------------------------------
    title              : string   -- Title text
    novalue            : string   -- Text shown if telemetry value is missing (default: "-")
    font               : font     -- Value font (e.g., FONT_L, FONT_XL)
    textcolor          : color    -- Value text color (default: theme/text fallback)
    bgcolor            : color    -- Background color (default: theme fallback)
    titlecolor         : color    -- Title text color (default: theme/text fallback)
    armedcolor         : color    -- Value text color when armed (overrides textcolor)
    disarmedcolor      : color    -- Value text color when disarmed (overrides textcolor)
    armedbgcolor       : color    -- Background color when armed (overrides bgcolor)
    disarmedbgcolor    : color    -- Background color when disarmed (overrides bgcolor)
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

]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

function render.wakeup(box, telemetry)
    local value = nil
    local sensor = telemetry and telemetry.getSensorSource("armflags")
    value = sensor and sensor:value()

    local displayValue = "-"
    if value ~= nil then
        if value >= 3 then
            displayValue = rfsuite.i18n.get("ARMED")
        else
            displayValue = rfsuite.i18n.get("DISARMED")
        end
    else
        displayValue = getParam(box, "novalue") or "-"
    end

   -- Dynamic background color
    local bgcolor
    if value ~= nil and value >= 3 then
        bgcolor = resolveThemeColor("fillbgcolor", getParam(box, "armedbgcolor"))
    elseif value ~= nil then
        bgcolor = resolveThemeColor("fillbgcolor", getParam(box, "disarmedbgcolor"))
    end
    if not bgcolor then
        bgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor")) or resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
    end

    -- Dynamic text color
    local textcolor
    if value ~= nil and value >= 3 then
        textcolor = resolveThemeColor("textcolor", getParam(box, "armedcolor"))
    elseif value ~= nil then
        textcolor = resolveThemeColor("textcolor", getParam(box, "disarmedcolor"))
    end
    if not textcolor then
        textcolor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
    end

    -- Title color (will default to white via resolver if unset)
    local titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))

    box._cache = {
        displayValue       = displayValue,
        bgcolor            = bgcolor,
        textcolor          = textcolor,
        titlecolor         = titlecolor,
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

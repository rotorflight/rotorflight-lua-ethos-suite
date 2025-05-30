local render = {}

function render.wakeup(box, telemetry)
    local utils = rfsuite.widgets.dashboard.utils
    local getParam = utils.getParam
    local resolveColor = utils.resolveColor

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

    -- Remove dynamic background color, always static from config
    local bgcolor = resolveColor(getParam(box, "bgcolor"))

    -- Dynamic text color depending on arm state
    local armedColor    = getParam(box, "armedcolor")
    local disarmedColor = getParam(box, "disarmedcolor")
    local textcolor
    if value ~= nil then
        textcolor = value >= 3 and resolveColor(armedColor) or resolveColor(disarmedColor)
    end
    if not textcolor then
        textcolor = resolveColor(getParam(box, "textcolor"))
    end

    -- Title color
    local titlecolor = resolveColor(getParam(box, "titlecolor"))

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
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Use only pre-resolved color values
    rfsuite.widgets.dashboard.utils.box(
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

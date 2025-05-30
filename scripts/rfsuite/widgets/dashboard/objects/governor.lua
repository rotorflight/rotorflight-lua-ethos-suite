local render = {}

function render.wakeup(box, telemetry)
    local utils = rfsuite.widgets.dashboard.utils
    local getParam = utils.getParam
    local resolveColor = utils.resolveColor

    local value = nil
    if telemetry and telemetry.getSensorSource then
        local sensor = telemetry.getSensorSource("governor")
        value = sensor and sensor:value()
    end

    local displayValue = rfsuite.utils.getGovernorState and rfsuite.utils.getGovernorState(value) or nil
    local unit = getParam(box, "unit")
    if displayValue == nil then
        displayValue = getParam(box, "novalue") or "-"
        unit = nil  -- Suppress unit if no valid governor state
    end

    box._cache = {
        displayValue       = displayValue,
        unit               = unit,
        bgcolor            = resolveColor(getParam(box, "bgcolor")),
        textcolor          = resolveColor(getParam(box, "textcolor")),
        titlecolor         = resolveColor(getParam(box, "titlecolor")),
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

    rfsuite.widgets.dashboard.utils.box(
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

local render = {}

function render.wakeup(box, telemetry)
    -- Get governor value and decoded display value at wakeup time
    local value
    if telemetry and telemetry.getSensorSource then
        local sensor = telemetry.getSensorSource("governor")
        value = sensor and sensor:value()
    end
    local displayValue = rfsuite.utils.getGovernorState(value)
    if displayValue == nil then
        displayValue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
    end

    box._cache = {
        color             = rfsuite.widgets.dashboard.utils.getParam(box, "color"),
        title             = rfsuite.widgets.dashboard.utils.getParam(box, "title"),
        displayValue      = displayValue,
        unit              = rfsuite.widgets.dashboard.utils.getParam(box, "unit"),
        bgcolor           = rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor"),
        titlealign        = rfsuite.widgets.dashboard.utils.getParam(box, "titlealign"),
        valuealign        = rfsuite.widgets.dashboard.utils.getParam(box, "valuealign"),
        titlecolor        = rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor"),
        titlepos          = rfsuite.widgets.dashboard.utils.getParam(box, "titlepos"),
        titlepadding      = rfsuite.widgets.dashboard.utils.getParam(box, "titlepadding"),
        titlepaddingleft  = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingleft"),
        titlepaddingright = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingright"),
        titlepaddingtop   = rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingtop"),
        titlepaddingbottom= rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingbottom"),
        valuepadding      = rfsuite.widgets.dashboard.utils.getParam(box, "valuepadding"),
        valuepaddingleft  = rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingleft"),
        valuepaddingright = rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingright"),
        valuepaddingtop   = rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingtop"),
        valuepaddingbottom= rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingbottom"),
    }
end

function render.paint(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local c = box._cache or {}

    rfsuite.widgets.dashboard.utils.box(
        x, y, w, h,
        c.color, c.title, c.displayValue, c.unit, c.bgcolor,
        c.titlealign, c.valuealign, c.titlecolor, c.titlepos,
        c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom
    )
end

return render

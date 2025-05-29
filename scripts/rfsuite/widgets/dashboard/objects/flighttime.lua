local render = {}

function render.wakeup(box)
    -- Always show the session time (accumulated time since last disconnect)
    local rawValue = rfsuite.session.timer and rfsuite.session.timer.live
    local unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit")
    local displayValue

    if type(rawValue) == "number" and rawValue > 0 then
        local minutes = math.floor(rawValue / 60)
        local seconds = math.floor(rawValue % 60)
        displayValue = string.format("%02d:%02d", minutes, seconds)
    else
        displayValue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
        unit = nil  -- suppress unit if no time to display
    end

    box._cache = {
        displayValue = displayValue,
        unit = unit,
        color = rfsuite.widgets.dashboard.utils.getParam(box, "color"),
        bgcolor = rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor"),
    }
end

function render.paint(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local cache = box._cache or {}

    rfsuite.widgets.dashboard.utils.box(
        x, y, w, h,
        cache.color, rfsuite.widgets.dashboard.utils.getParam(box, "title"), cache.displayValue, cache.unit, cache.bgcolor,
        rfsuite.widgets.dashboard.utils.getParam(box, "titlealign"), rfsuite.widgets.dashboard.utils.getParam(box, "valuealign"), rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepos"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingbottom"),
        rfsuite.widgets.dashboard.utils.getParam(box, "valuepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingbottom")
    )
end

return render

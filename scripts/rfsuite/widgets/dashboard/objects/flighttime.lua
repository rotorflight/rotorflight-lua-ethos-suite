local render = {}

function render.wakeup(box)
    -- Always show the session time (accumulated time since last disconnect)
    local displayValue = rfsuite.session.timer and rfsuite.session.timer.live or 0

    if type(displayValue) == "number" then
        local minutes = math.floor(displayValue / 60)
        local seconds = math.floor(displayValue % 60)
        displayValue = string.format("%02d:%02d", minutes, seconds)
    end

    box._cache = {
        displayValue = displayValue,
        color = rfsuite.widgets.dashboard.utils.getParam(box, "color"),
        unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit"),
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

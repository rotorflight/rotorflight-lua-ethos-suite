local render = {}

function render.wakeup(box)
    local value = rfsuite.widgets.dashboard.utils.getParam(box, "value")

    -- Apply transform if defined
    local transform = rfsuite.widgets.dashboard.utils.getParam(box, "transform")
    if type(transform) == "string" and math[transform] then
        value = value and math[transform](value)
    elseif type(transform) == "function" then
        value = value and transform(value)
    elseif type(transform) == "number" then
        value = value and transform(value)
    end

    box._cache = {
        value = value,
        unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit"),
        novalue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue"),
        color = rfsuite.widgets.dashboard.utils.getParam(box, "color"),
        bgcolor = rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor"),
        -- Add other frequently used params if you like
    }
end

function render.paint(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local cache = box._cache or {}
    local displayValue = cache.value
    if displayValue == nil then
        displayValue = cache.novalue or "-"
    end

    rfsuite.widgets.dashboard.utils.box(
        x, y, w, h,
        cache.color, rfsuite.widgets.dashboard.utils.getParam(box, "title"), displayValue, cache.unit, cache.bgcolor,
        rfsuite.widgets.dashboard.utils.getParam(box, "titlealign"), rfsuite.widgets.dashboard.utils.getParam(box, "valuealign"), rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepos"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingbottom"),
        rfsuite.widgets.dashboard.utils.getParam(box, "valuepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingbottom")
    )
end

return render

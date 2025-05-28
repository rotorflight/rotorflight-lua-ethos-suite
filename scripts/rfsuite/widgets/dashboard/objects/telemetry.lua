local render = {}

function render.wakeup(box, telemetry)
    local value = nil
    local source = rfsuite.widgets.dashboard.utils.getParam(box, "source")
    if source then
        local sensor = telemetry and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
        local transform = rfsuite.widgets.dashboard.utils.getParam(box, "transform")
        if type(transform) == "string" and math[transform] then
            value = value and math[transform](value)
        elseif type(transform) == "function" then
            value = value and transform(value)
        elseif type(transform) == "number" then
            value = value and transform(value)
        end
    end
    -- Threshold color logic
    local color = rfsuite.widgets.dashboard.utils.getParam(box, "color")
    local thresholds = rfsuite.widgets.dashboard.utils.getParam(box, "thresholds")
    if thresholds and value ~= nil then
        for _, t in ipairs(thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, value) or t.value
            local t_color = type(t.color) == "function" and t.color(box, value) or t.color
            if value < t_val then
                color = t_color or color
                break
            end
        end
    end
    -- Cache results for paint
    box._cache = {
        value = value,
        color = color,
        unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit"),
        novalue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue"),
        -- add more if needed
    }
end

function render.paint(x, y, w, h, box, telemetry)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local cache = box._cache or {}
    local displayValue = cache.value
    local displayUnit = cache.unit
    if displayValue == nil then
        displayValue = cache.novalue or "-"
        displayUnit = nil
    end
    rfsuite.widgets.dashboard.utils.box(
        x, y, w, h,
        cache.color, rfsuite.widgets.dashboard.utils.getParam(box, "title"), displayValue, displayUnit, rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlealign"), rfsuite.widgets.dashboard.utils.getParam(box, "valuealign"), rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepos"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingbottom"),
        rfsuite.widgets.dashboard.utils.getParam(box, "valuepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingbottom")
    )
end

return render

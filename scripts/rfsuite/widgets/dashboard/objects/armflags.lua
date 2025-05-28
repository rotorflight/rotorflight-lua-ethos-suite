local render = {}

-- Armflags status box
function render.armflags(x, y, w, h, box, telemetry)

    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

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
        displayValue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
    end

    local color = "white"
    local armedColor = rfsuite.widgets.dashboard.utils.getParam(box, "armedcolor") or "white"
    local disarmedColor = rfsuite.widgets.dashboard.utils.getParam(box, "disarmedcolor") or "white"

    if value ~= nil then
        if value >= 3 then
            color = armedColor
        else
            color = disarmedColor
        end
    end

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

    rfsuite.widgets.dashboard.utils.box(
        x, y, w, h,
        color, rfsuite.widgets.dashboard.utils.getParam(box, "title"), displayValue, nil, rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlealign"), rfsuite.widgets.dashboard.utils.getParam(box, "valuealign"), rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepos"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingbottom"),
        rfsuite.widgets.dashboard.utils.getParam(box, "valuepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingbottom")
    )
end

return render

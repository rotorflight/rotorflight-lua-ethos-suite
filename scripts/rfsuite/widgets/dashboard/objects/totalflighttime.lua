local render = {}

function render.totalflighttime(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

    local displayValue = rfsuite.ini.getvalue(rfsuite.session.modelPreferences, "general", "totalflighttime")
    if displayValue == nil then
        displayValue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
    else

        if rfsuite.session.timer and rfsuite.session.timer.live then
            displayValue = rfsuite.session.timer.live + (displayValue or 0)
        end

        -- Convert to hours, minutes, seconds
        local hours = math.floor(displayValue / 3600)
        local minutes = math.floor((displayValue % 3600) / 60)
        local seconds = math.floor(displayValue % 60)

        -- Format to HH:MM:SS with leading zeros
        displayValue = string.format("%02d:%02d:%02d", hours, minutes, seconds)          
    end
    rfsuite.widgets.dashboard.utils.box(
        x, y, w, h,
        rfsuite.widgets.dashboard.utils.getParam(box, "color"), rfsuite.widgets.dashboard.utils.getParam(box, "title"), displayValue, rfsuite.widgets.dashboard.utils.getParam(box, "unit"), rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlealign"), rfsuite.widgets.dashboard.utils.getParam(box, "valuealign"), rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepos"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepaddingbottom"),
        rfsuite.widgets.dashboard.utils.getParam(box, "valuepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "valuepaddingbottom")
    )
end

return render
local render = {}


-- Craft name box
function render.craftname(x, y, w, h, box)

    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

    local displayValue = rfsuite.session.craftName
    if displayValue == nil or (type(displayValue) == "string" and displayValue:match("^%s*$")) then
        displayValue = rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
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
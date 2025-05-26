local render = {}


-- Model image box
function render.modelimage(x, y, w, h, box)
    rfsuite.widgets.dashboard.utils.modelImageBox(
        x, y, w, h,
        rfsuite.widgets.dashboard.utils.getParam(box, "color"), rfsuite.widgets.dashboard.utils.getParam(box, "title"),
        rfsuite.widgets.dashboard.utils.getParam(box, "imagewidth"), rfsuite.widgets.dashboard.utils.getParam(box, "imageheight"), rfsuite.widgets.dashboard.utils.getParam(box, "imagealign"),
        rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor"), rfsuite.widgets.dashboard.utils.getParam(box, "titlealign"), rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepos"),
        rfsuite.widgets.dashboard.utils.getParam(box, "imagepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingbottom")
    )
end

return render
local render = {}

-- Image box
function render.image(x, y, w, h, box)

    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

    rfsuite.widgets.dashboard.utils.imageBox(
        x, y, w, h,
        rfsuite.widgets.dashboard.utils.getParam(box, "color"), rfsuite.widgets.dashboard.utils.getParam(box, "title"),
        rfsuite.widgets.dashboard.utils.getParam(box, "value") or rfsuite.widgets.dashboard.utils.getParam(box, "source") or "widgets/dashboard/gfx/default_image.png",
        rfsuite.widgets.dashboard.utils.getParam(box, "imagewidth"), rfsuite.widgets.dashboard.utils.getParam(box, "imageheight"), rfsuite.widgets.dashboard.utils.getParam(box, "imagealign"),
        rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor"), rfsuite.widgets.dashboard.utils.getParam(box, "titlealign"), rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor"), rfsuite.widgets.dashboard.utils.getParam(box, "titlepos"),
        rfsuite.widgets.dashboard.utils.getParam(box, "imagepadding"), rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingleft"), rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingright"),
        rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingtop"), rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingbottom")
    )
end

return render
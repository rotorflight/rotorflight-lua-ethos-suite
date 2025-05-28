local render = {}

function render.wakeup(box)
    local value = rfsuite.widgets.dashboard.utils.getParam(box, "value")
    local source = rfsuite.widgets.dashboard.utils.getParam(box, "source")
    box._cache = {
        color             = rfsuite.widgets.dashboard.utils.getParam(box, "color"),
        title             = rfsuite.widgets.dashboard.utils.getParam(box, "title"),
        image             = value or source or "widgets/dashboard/gfx/default_image.png",
        imagewidth        = rfsuite.widgets.dashboard.utils.getParam(box, "imagewidth"),
        imageheight       = rfsuite.widgets.dashboard.utils.getParam(box, "imageheight"),
        imagealign        = rfsuite.widgets.dashboard.utils.getParam(box, "imagealign"),
        bgcolor           = rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor"),
        titlealign        = rfsuite.widgets.dashboard.utils.getParam(box, "titlealign"),
        titlecolor        = rfsuite.widgets.dashboard.utils.getParam(box, "titlecolor"),
        titlepos          = rfsuite.widgets.dashboard.utils.getParam(box, "titlepos"),
        imagepadding      = rfsuite.widgets.dashboard.utils.getParam(box, "imagepadding"),
        imagepaddingleft  = rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingleft"),
        imagepaddingright = rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingright"),
        imagepaddingtop   = rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingtop"),
        imagepaddingbottom= rfsuite.widgets.dashboard.utils.getParam(box, "imagepaddingbottom"),
    }
end

function render.paint(x, y, w, h, box)
    local c = box._cache or {}
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    rfsuite.widgets.dashboard.utils.imageBox(
        x, y, w, h,
        c.color, c.title,
        c.image,
        c.imagewidth, c.imageheight, c.imagealign,
        c.bgcolor, c.titlealign, c.titlecolor, c.titlepos,
        c.imagepadding, c.imagepaddingleft, c.imagepaddingright,
        c.imagepaddingtop, c.imagepaddingbottom
    )
end

return render

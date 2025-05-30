local render = {}

function render.wakeup(box)
    local utils = rfsuite.widgets.dashboard.utils
    local getParam = utils.getParam
    local resolveColor = utils.resolveColor

    local value = getParam(box, "value")
    local source = getParam(box, "source")
    box._cache = {
        title             = getParam(box, "title"),
        image             = value or source or "widgets/dashboard/gfx/default_image.png",
        imagewidth        = getParam(box, "imagewidth"),
        imageheight       = getParam(box, "imageheight"),
        imagealign        = getParam(box, "imagealign"),
        bgcolor           = resolveColor(getParam(box, "bgcolor")),
        titlealign        = getParam(box, "titlealign"),
        titlecolor        = resolveColor(getParam(box, "titlecolor")),
        titlepos          = getParam(box, "titlepos"),
        imagepadding      = getParam(box, "imagepadding"),
        imagepaddingleft  = getParam(box, "imagepaddingleft"),
        imagepaddingright = getParam(box, "imagepaddingright"),
        imagepaddingtop   = getParam(box, "imagepaddingtop"),
        imagepaddingbottom= getParam(box, "imagepaddingbottom"),
    }
end

function render.paint(x, y, w, h, box)
    local c = box._cache or {}
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    rfsuite.widgets.dashboard.utils.imageBox(
        x, y, w, h,
        c.title,
        c.image,
        c.imagewidth, c.imageheight, c.imagealign,
        c.bgcolor, c.titlealign, c.titlecolor, c.titlepos,
        c.imagepadding, c.imagepaddingleft, c.imagepaddingright,
        c.imagepaddingtop, c.imagepaddingbottom
    )
end

return render

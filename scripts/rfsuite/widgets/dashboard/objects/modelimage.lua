--[[

    Model Image Box Widget

    Configurable Arguments (box table keys):
    ----------------------------------------
    title              : string   -- Title text
    imagewidth         : number   -- Image width (pixels; default: auto)
    imageheight        : number   -- Image height (pixels; default: auto)
    imagealign         : string   -- Image alignment ("center", "left", "right", "top", "bottom")
    bgcolor            : color    -- Widget background color (default: theme fallback)
    titlealign         : string   -- Title alignment ("center", "left", "right")
    titlecolor         : color    -- Title text color (default: theme/text fallback)
    titlepos           : string   -- Title position ("top" or "bottom")
    imagepadding       : number   -- Padding around the image (all sides unless overridden)
    imagepaddingleft   : number   -- Left padding for image
    imagepaddingright  : number   -- Right padding for image
    imagepaddingtop    : number   -- Top padding for image
    imagepaddingbottom : number   -- Bottom padding for image

]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

function render.wakeup(box)
    box._cache = {
        title             = getParam(box, "title"),
        imagewidth        = getParam(box, "imagewidth"),
        imageheight       = getParam(box, "imageheight"),
        imagealign        = getParam(box, "imagealign"),
        bgcolor           = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        titlealign        = getParam(box, "titlealign"),
        titlecolor        = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
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
    x, y = utils.applyOffset(x, y, box)

    utils.modelImageBox(
        x, y, w, h,
        c.title,
        c.imagewidth, c.imageheight, c.imagealign,
        c.bgcolor, c.titlealign, c.titlecolor, c.titlepos,
        c.imagepadding, c.imagepaddingleft, c.imagepaddingright,
        c.imagepaddingtop, c.imagepaddingbottom
    )
end

return render

--[[
    Model Image Box Widget

    Configurable Parameters (box table keys):
    ----------------------------------------
    title              : string   -- (Optional) Title text
    imagewidth         : number   -- (Optional) Image width (pixels; default: auto)
    imageheight        : number   -- (Optional) Image height (pixels; default: auto)
    imagealign         : string   -- (Optional) Image alignment ("center", "left", "right", "top", "bottom")
    bgcolor            : color    -- (Optional) Widget background color (theme fallback if nil)
    titlealign         : string   -- (Optional) Title alignment ("center", "left", "right")
    titlecolor         : color    -- (Optional) Title text color (theme/text fallback if nil)
    titlepos           : string   -- (Optional) Title position ("top" or "bottom")
    imagepadding       : number   -- (Optional) Padding around the image (all sides unless overridden)
    imagepaddingleft   : number   -- (Optional) Left padding for image
    imagepaddingright  : number   -- (Optional) Right padding for image
    imagepaddingtop    : number   -- (Optional) Top padding for image
    imagepaddingbottom : number   -- (Optional) Bottom padding for image
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local loadImage = rfsuite.utils.loadImage

function render.wakeup(box)
    local craftName = rfsuite and rfsuite.session and rfsuite.session.craftName
    local modelID   = rfsuite and rfsuite.session and rfsuite.session.modelID
    local imagePath

    if craftName then
        local pngPath = "/bitmaps/models/" .. craftName .. ".png"
        local bmpPath = "/bitmaps/models/" .. craftName .. ".bmp"
        if loadImage and loadImage(pngPath) then
            imagePath = pngPath
        elseif loadImage and loadImage(bmpPath) then
            imagePath = bmpPath
        end
    end
    if not imagePath and modelID then
        local pngPath = "/bitmaps/models/" .. modelID .. ".png"
        local bmpPath = "/bitmaps/models/" .. modelID .. ".bmp"
        if loadImage and loadImage(pngPath) then
            imagePath = pngPath
        elseif loadImage and loadImage(bmpPath) then
            imagePath = bmpPath
        end
    end
    if not imagePath then
        imagePath = "widgets/dashboard/gfx/logo.png"
    end

    box._cache = {
        title             = getParam(box, "title"),
        image             = imagePath,
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

    utils.imageBox(
        x, y, w, h,
        c.title,
        c.image, c.imagewidth, c.imageheight, c.imagealign,
        c.bgcolor, c.titlealign, c.titlecolor, c.titlepos,
        c.imagepadding, c.imagepaddingleft, c.imagepaddingright, c.imagepaddingtop, c.imagepaddingbottom
    )
end

return render

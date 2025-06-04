--[[
    Image Box Widget

    Configurable Parameters (box table keys):
    ----------------------------------------
    image              : string   -- (Optional) Path to image file (no extension needed; .png is tried first, then .bmp)
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
    local imageParam = getParam(box, "image")
    local imagePath

    if imageParam and imageParam ~= "" then
        -- Strip extension if present
        local baseNoExt = imageParam:gsub("%.png$",""):gsub("%.bmp$","")
        local pngPath = baseNoExt .. ".png"
        local bmpPath = baseNoExt .. ".bmp"
        if loadImage and loadImage(pngPath) then
            imagePath = pngPath
        elseif loadImage and loadImage(bmpPath) then
            imagePath = bmpPath
        end
    end

    if not imagePath then
        imagePath = "widgets/dashboard/gfx/default_image.png"
    end

    box._cache = box._cache or {}
    box._cache.title             = getParam(box, "title")
    box._cache.image             = imagePath
    box._cache.imagewidth        = getParam(box, "imagewidth")
    box._cache.imageheight       = getParam(box, "imageheight")
    box._cache.imagealign        = getParam(box, "imagealign")
    box._cache.bgcolor           = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
    box._cache.titlealign        = getParam(box, "titlealign")
    box._cache.titlecolor        = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
    box._cache.titlepos          = getParam(box, "titlepos")
    box._cache.imagepadding      = getParam(box, "imagepadding")
    box._cache.imagepaddingleft  = getParam(box, "imagepaddingleft")
    box._cache.imagepaddingright = getParam(box, "imagepaddingright")
    box._cache.imagepaddingtop   = getParam(box, "imagepaddingtop")
    box._cache.imagepaddingbottom= getParam(box, "imagepaddingbottom")
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

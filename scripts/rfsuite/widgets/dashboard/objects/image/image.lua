--[[
    Image Box Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
    image               : string   -- (Optional) Path to image file (no extension needed; .png is tried first, then .bmp)
    title               : string   -- (Optional) Title text
    titlepos            : string   -- (Optional) Title position ("top" or "bottom")
    titlealign          : string   -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font     -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number   -- (Optional) Gap between title and image
    titlecolor          : color    -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number   -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number   -- (Optional) Left padding for title
    titlepaddingright   : number   -- (Optional) Right padding for title
    titlepaddingtop     : number   -- (Optional) Top padding for title
    titlepaddingbottom  : number   -- (Optional) Bottom padding for title
    valuepadding        : number   -- (Optional) Padding for image (all sides unless overridden)
    valuepaddingleft    : number   -- (Optional) Left padding for image
    valuepaddingright   : number   -- (Optional) Right padding for image
    valuepaddingtop     : number   -- (Optional) Top padding for image
    valuepaddingbottom  : number   -- (Optional) Bottom padding for image
    bgcolor             : color    -- (Optional) Widget background color (theme fallback if nil)
    imagewidth          : number   -- (Optional) Image width (px)
    imageheight         : number   -- (Optional) Image height (px)
    imagealign          : string   -- (Optional) Image alignment ("center", "left", "right", "top", "bottom")
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local loadImage = rfsuite.utils.loadImage
local lastImagePath = nil

function render.dirty(box)
    if box._lastImagePath ~= box.imagePath then
        box._lastImagePath = box._imagePath
        return true
    end
    return false
end


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
        imagePath = "widgets/dashboard/gfx/logo.png"
    end

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = imagePath   

    box._cache = {
        title              = getParam(box, "title"),
        titlepos           = getParam(box, "titlepos"),
        titlealign         = getParam(box, "titlealign"),
        titlefont          = getParam(box, "titlefont"),
        titlespacing       = getParam(box, "titlespacing"),
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        displayValue       = nil,
        unit               = nil,
        font               = nil,
        valuealign         = nil,
        textcolor          = nil,
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        image              = imagePath,
        imagewidth         = getParam(box, "imagewidth"),
        imageheight        = getParam(box, "imageheight"),
        imagealign         = getParam(box, "imagealign")
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.displayValue, c.unit, c.font, c.valuealign, c.textcolor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.bgcolor,
        c.image, c.imagewidth, c.imageheight, c.imagealign
    )
end

return render

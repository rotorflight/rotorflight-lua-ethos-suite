--[[
    Model Image Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Gap between title and image
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    font                : font                      -- (Unused, for consistency)
    valuealign          : string                    -- (Unused, for consistency)
    textcolor           : color                     -- (Unused, for consistency)
    valuepadding        : number                    -- (Optional) Padding for image (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for image
    valuepaddingright   : number                    -- (Optional) Right padding for image
    valuepaddingtop     : number                    -- (Optional) Top padding for image
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for image
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
    image               : string                    -- (Auto) Image path, auto-resolved from model name or ID
    imagewidth          : number                    -- (Optional) Image width (px)
    imageheight         : number                    -- (Optional) Image height (px)
    imagealign          : string                    -- (Optional) Image alignment ("center", "left", "right", "top", "bottom")
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
    local craftName = rfsuite and rfsuite.session and rfsuite.session.craftName
    --local modelID   = rfsuite and rfsuite.session and rfsuite.session.modelID
    local imagePath

    if craftName then
        local pngPath = "/bitmaps/models/" .. craftName .. ".png"
        local bmpPath = "/bitmaps/models/" .. craftName .. ".bmp"
        imagePath = loadImage(pngPath, bmpPath)
    end

    --if not imagePath and modelID then
    --    local pngPath = "/bitmaps/models/" .. modelID .. ".png"
    --    local bmpPath = "/bitmaps/models/" .. modelID .. ".bmp"
    --    imagePath = loadImage(pngPath, bmpPath)
    --end

    if not imagePath and model and model.bitmap then
        local bm = model.bitmap()
        if bm and type(bm) == "string" and not string.find(bm, "default_") then
            imagePath = bm
        end
    end

    if not imagePath then
        imagePath = loadImage("widgets/dashboard/gfx/logo.png")
    end

    box._currentDisplayValue = imagePath

    box._cache = {
        title              = utils.getParam(box, "title"),
        titlepos           = utils.getParam(box, "titlepos"),
        titlealign         = utils.getParam(box, "titlealign"),
        titlefont          = utils.getParam(box, "titlefont"),
        titlespacing       = utils.getParam(box, "titlespacing"),
        titlecolor         = utils.resolveThemeColor("titlecolor", utils.getParam(box, "titlecolor")),
        titlepadding       = utils.getParam(box, "titlepadding"),
        titlepaddingleft   = utils.getParam(box, "titlepaddingleft"),
        titlepaddingright  = utils.getParam(box, "titlepaddingright"),
        titlepaddingtop    = utils.getParam(box, "titlepaddingtop"),
        titlepaddingbottom = utils.getParam(box, "titlepaddingbottom"),
        displayValue       = nil,
        unit               = nil,
        font               = nil,
        valuealign         = nil,
        textcolor          = nil,
        valuepadding       = utils.getParam(box, "valuepadding"),
        valuepaddingleft   = utils.getParam(box, "valuepaddingleft"),
        valuepaddingright  = utils.getParam(box, "valuepaddingright"),
        valuepaddingtop    = utils.getParam(box, "valuepaddingtop"),
        valuepaddingbottom = utils.getParam(box, "valuepaddingbottom"),
        bgcolor            = utils.resolveThemeColor("bgcolor", utils.getParam(box, "bgcolor")),
        image              = imagePath,
        imagewidth         = utils.getParam(box, "imagewidth"),
        imageheight        = utils.getParam(box, "imageheight"),
        imagealign         = utils.getParam(box, "imagealign")
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

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
local lastCraftName = nil
local imagePath

function render.dirty(box)
    if box._lastImagePath ~= box.imagePath then
        box._lastImagePath = box._imagePath
        return true
    end
    return false
end

-- Cache to reduce loadImage calls
local _imgCache = {}

function render.wakeup(box)
    -- Reuse cache table
    local c = box._cache or {}
    box._cache = c

   -- Build static config once
    local cfg = box._cfg
    if not cfg then
        cfg = {}
        cfg.title              = getParam(box, "title")
        cfg.titlepos           = getParam(box, "titlepos")
        cfg.titlealign         = getParam(box, "titlealign")
        cfg.titlefont          = getParam(box, "titlefont")
        cfg.titlespacing       = getParam(box, "titlespacing")
        cfg.titlepadding       = getParam(box, "titlepadding")
        cfg.titlepaddingleft   = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright  = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop    = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")
        cfg.titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.valuepadding       = getParam(box, "valuepadding")
        cfg.valuepaddingleft   = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright  = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop    = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.imagewidth         = getParam(box, "imagewidth")
        cfg.imageheight        = getParam(box, "imageheight")
        cfg.imagealign         = getParam(box, "imagealign")
        cfg._lastCraftName     = nil

        box._cfg = cfg
    end

    -- Resolve image path (prefer craftName, then model bitmap, then default)
    local craftName = rfsuite and rfsuite.session and rfsuite.session.craftName
    local path = c.image

    if craftName and craftName ~= cfg._lastCraftName then
        local cached = _imgCache[craftName]
        if cached == nil then
            local pngPath = "/bitmaps/models/" .. craftName .. ".png"
            local bmpPath = "/bitmaps/models/" .. craftName .. ".bmp"
            cached = loadImage(pngPath, bmpPath)
            _imgCache[craftName] = cached
        end
        path = cached
        cfg._lastCraftName = craftName
    end

    if not path and model and model.bitmap then
        local bm = model.bitmap()
        if bm and type(bm) == "string" and not string.find(bm, "default_") then
            path = bm
        end
    end

    if not path then
        path = loadImage("widgets/dashboard/gfx/logo.png")
    end

    c.image = path

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = path

    -- Mutate cache
    c.title              = cfg.title
    c.titlepos           = cfg.titlepos
    c.titlealign         = cfg.titlealign
    c.titlefont          = cfg.titlefont
    c.titlespacing       = cfg.titlespacing
    c.titlepadding       = cfg.titlepadding
    c.titlepaddingleft   = cfg.titlepaddingleft
    c.titlepaddingright  = cfg.titlepaddingright
    c.titlepaddingtop    = cfg.titlepaddingtop
    c.titlepaddingbottom = cfg.titlepaddingbottom
    c.titlecolor         = cfg.titlecolor
    c.valuepadding       = cfg.valuepadding
    c.valuepaddingleft   = cfg.valuepaddingleft
    c.valuepaddingright  = cfg.valuepaddingright
    c.valuepaddingtop    = cfg.valuepaddingtop
    c.valuepaddingbottom = cfg.valuepaddingbottom
    c.bgcolor            = cfg.bgcolor
    c.imagewidth         = cfg.imagewidth
    c.imageheight        = cfg.imageheight
    c.imagealign         = cfg.imagealign
    c.displayValue       = nil
    c.unit               = nil
    c.font               = nil
    c.valuealign         = nil
    c.textcolor          = nil
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

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

-- External invalidation when runtime params/theme change
function render.invalidate(box) box._cfg = nil end

-- Only repaint when displayed image path changes
function render.dirty(box)
    if box._lastDisplayValue == nil then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end
    if box._lastDisplayValue ~= box._currentDisplayValue then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end
    return false
end

-- Resolve image path once, trying .png then .bmp; return fallback if none
local function resolveImagePath(imageParam)
    if imageParam and imageParam ~= "" then
        local baseNoExt = imageParam:gsub("%.png$",""):gsub("%.bmp$","")
        local pngPath = baseNoExt .. ".png"
        local bmpPath = baseNoExt .. ".bmp"
        if loadImage and loadImage(pngPath) then
            return pngPath
        elseif loadImage and loadImage(bmpPath) then
            return bmpPath
        end
    end
    return "widgets/dashboard/gfx/logo.png"
end

-- Build/refresh static config (theme/params aware)
local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0 -- bump externally when params change
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version     = theme_version
        cfg._param_version     = param_version

        cfg.title              = getParam(box, "title")
        cfg.titlepos           = getParam(box, "titlepos")
        cfg.titlealign         = getParam(box, "titlealign")
        cfg.titlefont          = getParam(box, "titlefont")
        cfg.titlespacing       = getParam(box, "titlespacing")
        cfg.titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.titlepadding       = getParam(box, "titlepadding")
        cfg.titlepaddingleft   = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright  = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop    = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")

        cfg.valuepadding       = getParam(box, "valuepadding")
        cfg.valuepaddingleft   = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright  = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop    = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")

        cfg.bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))

        cfg.imagewidth         = getParam(box, "imagewidth")
        cfg.imageheight        = getParam(box, "imageheight")
        cfg.imagealign         = getParam(box, "imagealign")

        -- Resolve image path once per param/theme change
        cfg.image              = resolveImagePath(getParam(box, "image"))

        box._cfg = cfg
    end
    return box._cfg
end

function render.wakeup(box)
    local cfg = ensureCfg(box)
    -- Dynamic part is just the path; keep it here for consistency
    box._currentDisplayValue = cfg.image
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        nil, nil, nil, nil, nil, -- value text not used in image widget
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.bgcolor,
        c.image, c.imagewidth, c.imageheight, c.imagealign
    )
end

-- No need for frequent wakeups; only changes when params/theme change
render.scheduler = 2.0

return render
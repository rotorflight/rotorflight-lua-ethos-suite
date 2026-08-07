--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
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

local rfsuite = assert(loadfile("widgets/dashboard/context.lua"))()

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local loadImage = rfsuite.utils.loadImage
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout

function render.invalidate(box)
    box._cfg = nil
    box._textLayout = nil
end

function render.dirty(box)
    return utils.dirtyOnDisplayValueChange(box)
end

local function resolveLogoFallback(bgcolor)
    if utils.getLogoFallbackForBackground then
        return utils.getLogoFallbackForBackground(bgcolor)
    end
    return "widgets/dashboard/gfx/logo-dark.png"
end

local function resolveImagePath(imageParam, bgcolor)
    if imageParam and imageParam ~= "" then
        local baseNoExt = imageParam:gsub("%.png$", ""):gsub("%.bmp$", "")
        local pngPath = baseNoExt .. ".png"
        local bmpPath = baseNoExt .. ".bmp"
        if loadImage and loadImage(pngPath) then
            return pngPath
        elseif loadImage and loadImage(bmpPath) then
            return bmpPath
        end
    end
    return resolveLogoFallback(bgcolor)
end

local function ensureCfg(box)
    return utils.ensureCfg(box, function(cfg, box)
        cfg.title = getParam(box, "title")
        cfg.titlepos = getParam(box, "titlepos")
        cfg.titlealign = getParam(box, "titlealign")
        cfg.titlefont = getParam(box, "titlefont")
        cfg.titlespacing = getParam(box, "titlespacing")
        cfg.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.titlepadding = getParam(box, "titlepadding")
        cfg.titlepaddingleft = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")

        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")

        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))

        cfg.imagewidth = getParam(box, "imagewidth")
        cfg.imageheight = getParam(box, "imageheight")
        cfg.imagealign = getParam(box, "imagealign")

        cfg.image = resolveImagePath(getParam(box, "image"), cfg.bgcolor)
    end)
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    box._currentDisplayValue = cfg.image

    if box._dashboardRectW and box._dashboardRectH then
        local x, y = utils.applyOffset(box._dashboardRectX or 0, box._dashboardRectY or 0, box)
        local w, h
        x, y, w, h = utils.boxContentRect(x, y, box._dashboardRectW, box._dashboardRectH, cfg.bgcolor)
        prepareTextLayout(box, x, y, w, h, cfg.title, cfg.titlepos, cfg.titlealign, cfg.titlefont, cfg.titlespacing, cfg.titlepadding, cfg.titlepaddingleft, cfg.titlepaddingright, cfg.titlepaddingtop, cfg.titlepaddingbottom, nil, nil, nil, nil, cfg.valuepadding, cfg.valuepaddingleft, cfg.valuepaddingright, cfg.valuepaddingtop, cfg.valuepaddingbottom)
    end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)
    -- displayValue/unit are always nil here -- this widget draws an image,
    -- not value text -- so this call only ever measures/caches the title
    -- (the expensive part utils.box() used to redo every paint()); the
    -- returned layout.region* is the same title-adjusted content rect
    -- utils.box()'s own image branch would have used.
    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, nil, nil, nil, nil, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, nil, c.titlecolor)
    utils.drawImageInRect(layout.regionX, layout.regionY, layout.regionW, layout.regionH, c.image, c.imagewidth, c.imageheight, c.imagealign, c.bgcolor)
end

render.scheduler = 2.0

return render

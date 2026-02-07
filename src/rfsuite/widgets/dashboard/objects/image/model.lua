--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
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

local rfsuite = require("rfsuite")
local model = model

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local loadImage = rfsuite.utils.loadImage

function render.invalidate(box) box._cfg = nil end

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

local _imgCache = {}

local function resolveModelImage(cfg)

    local craftName = rfsuite and rfsuite.session and rfsuite.session.craftName
    if craftName and craftName ~= "" then
        local cached = _imgCache[craftName]
        if cached == nil then
            local base = "/bitmaps/models/" .. craftName
            local pngPath = base .. ".png"
            local bmpPath = base .. ".bmp"
            cached = loadImage and (loadImage(pngPath) or loadImage(bmpPath))
            _imgCache[craftName] = cached or false
        end
        if cached then return cached end
    end

    if model and model.bitmap then
        local bm = model.bitmap()
        if bm and type(bm) == "string" and bm ~= "" and not string.find(bm, "default_") then
            local loaded = loadImage(bm)
            if loaded then return loaded end
        end
    end

    local paramImage = getParam(cfg.box, "image")
    if paramImage and paramImage ~= "" then
        local base = paramImage:gsub("%.png$", ""):gsub("%.bmp$", "")
        local pngPath = base .. ".png"
        local bmpPath = base .. ".bmp"
        return (loadImage and (loadImage(pngPath) or loadImage(bmpPath))) or paramImage
    end

    return "widgets/dashboard/gfx/logo.png"
end

local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version = theme_version
        cfg._param_version = param_version
        cfg.box = box

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

        cfg.image = resolveModelImage(cfg)

        box._cfg = cfg
    end
    return box._cfg
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local craftName = rfsuite and rfsuite.session and rfsuite.session.craftName
    if cfg._lastCraftName ~= craftName then
        cfg.image = resolveModelImage(cfg)
        cfg._lastCraftName = craftName
    end

    box._currentDisplayValue = cfg.image
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, nil, nil, nil, nil, nil, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, c.bgcolor, c.image, c.imagewidth, c.imageheight, c.imagealign)
end

render.scheduler = 2.0

return render

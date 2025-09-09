--[[
    Flight Time Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    unit                : string                    -- (Optional) Unit label to append to value
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

-- Optional helper so outside code can force a rebuild of static cfg
function render.invalidate(box)
    box._cfg = nil
end

-- Dirty checking mirrors image/model widgets: wakeup only sets _currentDisplayValue;
-- dirty() compares against the last painted value and updates the cache.
function render.dirty(box)
    if not rfsuite.session.telemetryState then return false end

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

-- Build/refresh static config if needed
local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0  -- let callers bump this if runtime params change
    local cfg = box._cfg
    if (not cfg)
        or (cfg._theme_version ~= theme_version)
        or (cfg._param_version ~= param_version)
    then
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
        cfg.unit               = getParam(box, "unit")
        cfg.font               = getParam(box, "font")
        cfg.valuealign         = getParam(box, "valuealign")
        cfg.textcolor          = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.valuepadding       = getParam(box, "valuepadding")
        cfg.valuepaddingleft   = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright  = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop    = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        box._cfg = cfg
    end
    return box._cfg
end

function render.wakeup(box)
    -- Compute dynamic value once per tick
    local value = rfsuite.session.timer and rfsuite.session.timer.live
    local displayValue

    if type(value) == "number" and value > 0 then
        local minutes = math.floor(value / 60)
        local seconds = math.floor(value % 60)
        displayValue = string.format("%02d:%02d", minutes, seconds)
    else
        displayValue = getParam(box, "novalue") or "00:00"
    end

    if displayValue == "00:00" and box._lastDisplayValue ~= nil then
        displayValue = box._lastDisplayValue
    end

    box._currentDisplayValue = displayValue

    -- Ensure static cfg exists (theme/param aware)
    ensureCfg(box)
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        box._currentDisplayValue, c.unit, c.font, c.valuealign, c.textcolor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.bgcolor
    )
end

-- Frequent updates like the flight time objects require
render.scheduler = 0.5

return render

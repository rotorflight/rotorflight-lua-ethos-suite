--[[
    Text Display Widget (Static/Label)

    Configurable Parameters (box table fields):
    -------------------------------------------
    wakeupinterval      : number          -- Optional wakeup interval in seconds (set in wrapper)
    title               : string          -- (Optional) Title text displayed above or below the value
    titlepos            : string          -- (Optional) Title position: "top" or "bottom"
    titlealign          : string          -- (Optional) Title alignment: "center", "left", or "right"
    titlefont           : font            -- (Optional) Font for title (e.g., FONT_L, FONT_XL). Uses theme or default if unset.
    titlespacing        : number          -- (Optional) Vertical gap between title and value (pixels)
    titlecolor          : color           -- (Optional) Title text color (theme fallback if nil)
    titlepadding        : number          -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number          -- (Optional) Left padding for title
    titlepaddingright   : number          -- (Optional) Right padding for title
    titlepaddingtop     : number          -- (Optional) Top padding for title
    titlepaddingbottom  : number          -- (Optional) Bottom padding for title
    value               : string|number   -- (Optional) **Static** value to display (required for this widget)
    font                : font            -- (Optional) Font for value (e.g., FONT_L, FONT_XL). Uses theme or default if unset.
    valuealign          : string          -- (Optional) Value alignment: "center", "left", or "right"
    textcolor           : color           -- (Optional) Value text color (theme fallback if nil)
    valuepadding        : number          -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number          -- (Optional) Left padding for value
    valuepaddingright   : number          -- (Optional) Right padding for value
    valuepaddingtop     : number          -- (Optional) Top padding for value
    valuepaddingbottom  : number          -- (Optional) Bottom padding for value
    bgcolor             : color           -- (Optional) Widget background color (theme fallback if nil)
    novalue             : string          -- (Optional) Text to show if value is nil (default: "-")

    -- Note:
    -- This widget is for **static or label text only**. It does not support live telemetry or stats.
    -- If you need dynamic stats or telemetry (min/max/live), use `stats.lua` or other appropriate widgets.
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

-- External invalidation if runtime params change at runtime
function render.invalidate(box) box._cfg = nil end

-- Only repaint when the displayed value changes
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

-- Build/refresh static config (theme/params aware)
local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0 -- bump externally when params change
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version     = theme_version
        cfg._param_version     = param_version

        -- title + layout
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

        -- value style
        cfg.font               = getParam(box, "font")
        cfg.valuealign         = getParam(box, "valuealign")
        cfg.valuepadding       = getParam(box, "valuepadding")
        cfg.valuepaddingleft   = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright  = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop    = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")

        -- colours
        cfg.titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.textcolor          = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))

        -- static value + fallbacks
        cfg.novalue            = getParam(box, "novalue") or "-"
        cfg.unit               = nil -- explicit: no unit for plain text widget

        box._cfg = cfg
    end
    return box._cfg
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    -- Compute display value from params; this is static unless params change
    local value = getParam(box, "value")
    local displayValue = (value ~= nil) and tostring(value) or cfg.novalue

    box._currentDisplayValue = displayValue
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

-- Static label: no need for frequent wakeups; keep it slow
render.scheduler = 2.0

return render
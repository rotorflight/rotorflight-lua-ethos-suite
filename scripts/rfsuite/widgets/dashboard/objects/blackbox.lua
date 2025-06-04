--[[
    Blackbox Widget

    Configurable Parameters (box table fields):
    ----------------------------------------
    transform           : string|function|number    -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function) on used MB
    decimals            : number                    -- (Optional) Number of decimal places for numeric display
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    title               : string                    -- (Optional) Title text
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value

]]


local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

function render.wakeup(box)
    -- Value extraction
    local totalSize = rfsuite.session.bblSize
    local usedSize  = rfsuite.session.bblUsed

    -- Set displayValue, Fallback if no value
    local displayValue
    local percentUsed
    if totalSize and usedSize then
        local usedMB  = usedSize  / (1024 * 1024)
        local totalMB = totalSize / (1024 * 1024)
        percentUsed = totalSize > 0 and (usedSize / totalSize) * 100 or 0

        local decimals = getParam(box, "decimals") or 1
        local transformedUsed  = utils.transformValue(usedMB, box)
        local transformedTotal = utils.transformValue(totalMB, box)
        displayValue = string.format("%." .. decimals .. "f/%." .. decimals .. "f %s",
            transformedUsed, transformedTotal, rfsuite.i18n.get("app.modules.status.megabyte"))
    else
        displayValue = getParam(box, "novalue") or "-"
        percentUsed = nil
    end

    -- Use percent used with threshold color helper ()
    local textcolor = utils.resolveThresholdTextColor and percentUsed
        and utils.resolveThresholdTextColor(percentUsed, box)
        or resolveThemeColor("textcolor", getParam(box, "textcolor"))

    box._cache = {
        displayValue       = displayValue,
        unit               = nil,
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        textcolor          = textcolor,
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        title              = getParam(box, "title"),
        titlealign         = getParam(box, "titlealign"),
        valuealign         = getParam(box, "valuealign"),
        titlepos           = getParam(box, "titlepos"),
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        font               = getParam(box, "font"),
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    utils.box(
        x, y, w, h,
        c.title, c.displayValue, c.unit, c.bgcolor,
        c.titlealign, c.valuealign, c.titlecolor, c.titlepos, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom, c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom, c.font, c.textcolor
    )
end

return render

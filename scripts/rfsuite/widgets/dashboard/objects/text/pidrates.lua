--[[ 
    PID/Rates Profile Display Object

    Configurable Parameters (box table fields):
    -------------------------------------------

    -- Profile Source Selection
    object                  : string                    -- Required: must be "pid" or "rates"; maps to telemetry source "pid_profile" or "rate_profile"
    profilecount            : number                    -- (Optional) How many profile numbers to draw (1 to 6, default 6)

    -- Telemetry and Value Handling
    value                   : number                    -- (Optional) Static fallback value if telemetry is unavailable
    transform               : string|function|number    -- (Optional) Value transform logic (e.g., "floor", multiplier, or custom function)
    decimals                : number                    -- (Optional) Decimal precision for transformed value
    thresholds              : table                     -- (Optional) Value threshold list: { value=..., textcolor=... }
    novalue                 : string                    -- (Optional) Fallback text if no telemetry or static value is available
    unit                    : string                    -- (Optional) Placeholder only; not used in this object

    -- Value Styling and Alignment
    font                    : font                      -- (Optional) Font for profile number text
    textcolor               : color                     -- (Optional) Text color for inactive profile / rates
    fillcolor               : color                     -- (Optional) Text color for active profile / rates
    valuealign              : string                    -- (Optional) Ignored; profile numbers are always centered
    valuepadding            : number                    -- (Optional) General padding around value area (overridden by sides)
    valuepaddingleft        : number
    valuepaddingright       : number
    valuepaddingtop         : number
    valuepaddingbottom      : number

    -- Title Styling
    title                   : string                    -- (Optional) Title label (e.g., "Active Profile")
    titlepos                : string                    -- (Optional) "top" or "bottom"
    titlealign              : string                    -- (Optional) Title alignment: "center", "left", or "right"
    titlefont               : font                      -- (Optional) Title font (e.g., FONT_L)
    titlespacing            : number                    -- (Optional) Gap between title and profile number row
    titlecolor              : color                     -- (Optional) Title text color
    titlepadding            : number                    -- (Optional) General padding around title (overridden by sides)
    titlepaddingleft        : number
    titlepaddingright       : number
    titlepaddingtop         : number
    titlepaddingbottom      : number

    -- Row Layout and Font Options
    rowalign                : string                    -- (Optional) Alignment for number row: "left", "center", or "right"
    rowspacing              : number                    -- (Optional) Spacing between profile numbers (default: width / profilecount)
    rowfont                 : font                      -- (Optional) Font for profile numbers (fallbacks to `font`)
    rowpadding              : number                    -- (Optional) General padding for number row (overridden by sides)
    rowpaddingleft          : number
    rowpaddingright         : number
    rowpaddingtop           : number
    rowpaddingbottom        : number
    highlightlarger         : boolean                   -- (Optional) If true, enlarges the active index using the next font in the list

    -- Background
    bgcolor                 : color                     -- (Optional) Widget background color
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

-- External invalidation: call when runtime params change
function render.invalidate(box) box._cfg = nil end

-- Only repaint when displayed value changes
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

-- Build/refresh static config (theme & params aware)
local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0 -- bump externally when params change
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version     = theme_version
        cfg._param_version     = param_version

        -- Source/object selection (static)
        cfg.object             = getParam(box, "object")
        if cfg.object == "pid" then
            cfg.source = "pid_profile"
        elseif cfg.object == "rates" then
            cfg.source = "rate_profile"
        else
            cfg.source = nil
        end

        -- Title styling
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

        -- Value styling/static params
        cfg.font               = getParam(box, "font") or FONT_L
        cfg.valuealign         = getParam(box, "valuealign")
        cfg.defaultTextColor   = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.fillcolor          = utils.resolveThemeColor("fillcolor", getParam(box, "fillcolor"))
        cfg.valuepadding       = getParam(box, "valuepadding")
        cfg.valuepaddingleft   = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright  = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop    = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")

        -- Row layout/static
        cfg.rowalign           = getParam(box, "rowalign")
        cfg.rowpadding         = getParam(box, "rowpadding")
        cfg.rowpaddingleft     = getParam(box, "rowpaddingleft")
        cfg.rowpaddingright    = getParam(box, "rowpaddingright")
        cfg.rowpaddingtop      = getParam(box, "rowpaddingtop")
        cfg.rowpaddingbottom   = getParam(box, "rowpaddingbottom")
        cfg.rowspacing         = getParam(box, "rowspacing")
        cfg.rowfont            = getParam(box, "rowfont")
        cfg.highlightlarger    = getParam(box, "highlightlarger")
        cfg.profilecount       = math.max(1, math.min(6, tonumber(getParam(box, "profilecount")) or 6))

        -- Misc
        cfg.novalue            = getParam(box, "novalue") or "-"
        cfg.bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.fontList           = (utils.getFontListsForResolution().value_default) or {}

        box._cfg = cfg
    end
    return box._cfg
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local telemetry = rfsuite.tasks.telemetry
    local value
    if telemetry and cfg.source then
        value = select(1, telemetry.getSensor(cfg.source))
    end
    if value == nil then
        value = getParam(box, "value")
    end

    local displayValue
    if value == nil then
        -- loading dots
        local maxDots = 3
        box._dotCount = ((box._dotCount or 0) + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then displayValue = "." end
    else
        displayValue = utils.transformValue(value, box)
    end

    local index = tonumber(displayValue)
    if index == nil or index < 1 or index > 6 then
        if value ~= nil then
            displayValue = cfg.novalue
        end
    end

    -- Dynamic text color based on thresholds and *numeric* value when present
    local dynColor = utils.resolveThresholdColor(value, box, "textcolor", "textcolor") or cfg.defaultTextColor

    -- Set for dirty()/paint()
    box._currentDisplayValue = displayValue
    box._dynamicTextColor = dynColor
    box._isLoadingDots = (value == nil)
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        nil, nil, c.font, c.valuealign, box._dynamicTextColor or c.defaultTextColor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.bgcolor
    )

    -- Draw row of numbers 1..profilecount, highlighting the active index
    local fontList = c.fontList or {}
    local baseFont = _G[c.rowfont] or _G[c.font] or FONT_L

    local baseIndex
    for i, f in ipairs(fontList) do if f == baseFont then baseIndex = i; break end end
    local largerFont = baseFont
    if c.highlightlarger and baseIndex and baseIndex < #fontList then
        largerFont = fontList[baseIndex + 1]
    end

    lcd.font(baseFont)
    local _, baseHeight = lcd.getTextSize("8")

    local rowpadding = c.rowpadding or 0
    local padLeft    = c.rowpaddingleft or rowpadding
    local padRight   = c.rowpaddingright or rowpadding
    local padTop     = c.rowpaddingtop or rowpadding
    local padBottom  = c.rowpaddingbottom or rowpadding

    local rowY = y + padTop
    if c.title then
        rowY = y + h - baseHeight - padBottom
    end

    local totalWidth = w - padLeft - padRight
    local count = c.profilecount or 6
    local spacing = c.rowspacing or (totalWidth / count)
    local align = c.rowalign or "center"

    local totalContentWidth = spacing * count
    local startX
    if align == "left" then
        startX = x + padLeft
    elseif align == "right" then
        startX = x + w - padRight - totalContentWidth
    else
        startX = x + padLeft + (totalWidth - totalContentWidth) / 2
    end

    -- Active index from displayValue
    local activeIndex = tonumber(box._currentDisplayValue)

    for i = 1, count do
        local cx = startX + (i - 1) * spacing
        local text = tostring(i)
        local isActive = (activeIndex ~= nil) and (activeIndex == i)
        local currentFont = (isActive and c.highlightlarger and largerFont) or baseFont

        lcd.font(currentFont)
        local tw, th = lcd.getTextSize(text)
        local yOffset = (isActive and c.highlightlarger and largerFont ~= baseFont) and (baseHeight - th) / 2 or 0

        if isActive then
            lcd.color(c.fillcolor or c.defaultTextColor or WHITE)
        else
            lcd.color(c.defaultTextColor or WHITE)
        end

        lcd.drawText(cx + (spacing - tw) / 2, rowY + yOffset, text)
    end
end

return render


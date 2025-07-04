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
local lastDisplayValue = nil

function render.dirty(box)
    if box._lastDisplayValue ~= box._currentDisplayValue then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end
    return false
end

function render.wakeup(box)

    local telemetry = rfsuite.tasks.telemetry
    
    -- Value extraction
    local object = (getParam(box, "object"))
    local source

    if object == "pid" then
        source = "pid_profile"
    elseif object == "rates" then
        source = "rate_profile"
    end

    -- Try telemetry first, fallback to static value
    local value
    if telemetry and source then
        value = select(1, telemetry.getSensor(source))
    end

    if value == nil then
        value = getParam(box, "value")
    end

    -- Transform and fallback display
    local fallbackText = getParam(box, "novalue") or "-"
    local displayValue

    if value == nil then
        -- Show animated dots if no value (telemetry/data not ready)
        local maxDots = 3
        if box._dotCount == nil then box._dotCount = 0 end
        box._dotCount = (box._dotCount + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then displayValue = "." end
    else
        displayValue = utils.transformValue(value, box)
    end

    local index = tonumber(displayValue)
    if index == nil or index < 1 or index > 6 then
        index = nil
        -- Only use fallback if the value is NOT loading dots
        if value ~= nil then
            displayValue = fallbackText
        end
    end


    -- Text color and fontlist caching
    local textcolor = utils.resolveThresholdColor(value, box, "textcolor", "textcolor")
    local fontLists = utils.getFontListsForResolution()

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = displayValue

    box._cache = {
        displayValue        = displayValue,
        activeIndex         = index,
        font                = getParam(box, "font") or FONT_L,
        textcolor           = textcolor or resolveThemeColor("textcolor", getParam(box, "textcolor")),
        fillcolor           = utils.resolveThemeColor("fillcolor", getParam(box, "fillcolor")),
        bgcolor             = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        title               = getParam(box, "title"),
        titlepos            = getParam(box, "titlepos"),
        titlealign          = getParam(box, "titlealign"),
        titlefont           = getParam(box, "titlefont"),
        titlespacing        = getParam(box, "titlespacing"),
        titlecolor          = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        titlepadding        = getParam(box, "titlepadding"),
        titlepaddingleft    = getParam(box, "titlepaddingleft"),
        titlepaddingright   = getParam(box, "titlepaddingright"),
        titlepaddingtop     = getParam(box, "titlepaddingtop"),
        titlepaddingbottom  = getParam(box, "titlepaddingbottom"),
        valuealign          = getParam(box, "valuealign"),
        valuepadding        = getParam(box, "valuepadding"),
        valuepaddingleft    = getParam(box, "valuepaddingleft"),
        valuepaddingright   = getParam(box, "valuepaddingright"),
        valuepaddingtop     = getParam(box, "valuepaddingtop"),
        valuepaddingbottom  = getParam(box, "valuepaddingbottom"),
        rowalign            = getParam(box, "rowalign"),
        rowpadding          = getParam(box, "rowpadding"),
        rowpaddingleft      = getParam(box, "rowpaddingleft"),
        rowpaddingright     = getParam(box, "rowpaddingright"),
        rowpaddingtop       = getParam(box, "rowpaddingtop"),
        rowpaddingbottom    = getParam(box, "rowpaddingbottom"),
        rowspacing          = getParam(box, "rowspacing"),
        rowfont             = getParam(box, "rowfont"),
        fontList            = fontLists.value_default or {},
        highlightlarger     = getParam(box, "highlightlarger"),
        profilecount        = math.max(1, math.min(6, tonumber(getParam(box, "profilecount")) or 6)),
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
        nil, nil, c.font, c.valuealign, c.textcolor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.bgcolor
    )

    -- Get base and stepped font using resolution-aware font list
    local fontList = c.fontList or {}
    local baseFont = _G[c.rowfont] or _G[c.font] or FONT_L

    local baseIndex
    for i, f in ipairs(fontList) do
        if f == baseFont then
            baseIndex = i
            break
        end
    end
    local largerFont = baseFont
    if c.highlightlarger and baseIndex and baseIndex < #fontList then
        largerFont = fontList[baseIndex + 1]
    end

    -- Spacing and alignment setup
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

    -- Draw numbers 1–profilecount
    for i = 1, count do
        local cx = startX + (i - 1) * spacing
        local text = tostring(i)
        local isActive = (c.displayValue ~= nil) and (tonumber(c.displayValue) == i)
        local currentFont = (isActive and c.highlightlarger and largerFont) or baseFont

        lcd.font(currentFont)
        local tw, th = lcd.getTextSize(text)
        local yOffset = (isActive and c.highlightlarger and largerFont ~= baseFont) and (baseHeight - th) / 2 or 0

        if isActive then
            lcd.color(c.fillcolor or c.textcolor or WHITE)
        else
            lcd.color(c.textcolor or WHITE)
        end

        lcd.drawText(cx + (spacing - tw) / 2, rowY + yOffset, text)
    end
end

return render

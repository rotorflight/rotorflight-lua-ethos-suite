--[[

    Dial Image Widget

    Configurable Arguments (box table keys):
    ----------------------------------------
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
    source              : string   -- Telemetry sensor source name
    transform           : string/function/number -- Optional value transform (math function or custom function)
    min                 : number   -- Minimum value (default: 0)
    max                 : number   -- Maximum value (default: 100)
    novalue             : string   -- Text shown if telemetry value is missing (default: "-")
    unit                : string   -- Unit to append to value (display only if value is present)
    dial                : string/number/function -- Dial image selector (used for asset path)
    aspect              : string   -- Image aspect handling ("fit", "fill", "original")
    align               : string   -- Image alignment ("left", "center", "right", "top", "bottom")
    needlecolor         : color    -- Needle color (default: red)
    needlehubcolor      : color    -- Hub color (default: black)
    accentcolor         : color    -- Accent color (optional, used for hub highlight)
    needlethickness     : number   -- Needle width in pixels (default: 3)
    needlehubsize       : number   -- Hub circle radius in pixels (default: needle thickness + 2)
    needlestartangle    : number   -- Needle starting angle in degrees (default: 135)
    needleendangle      : number   -- Needle ending angle in degrees (if set, determines sweep)
    needlesweepangle    : number   -- Needle sweep angle in degrees (default: 270)
    bgcolor             : color    -- Widget background color (default: theme fallback)
    textcolor           : color    -- Value text color (default: theme/text fallback)
    titlecolor          : color    -- Title text color (default: theme/text fallback)
    title               : string   -- Title text
    titlealign          : string   -- Title alignment ("center", "left", "right")
    valuealign          : string   -- Value alignment ("center", "left", "right")
    titlepos            : string   -- Title position ("top" or "bottom")
    titlepadding        : number   -- Padding for title (all sides unless overridden)
    titlepaddingleft    : number   -- Left padding for title
    titlepaddingright   : number   -- Right padding for title
    titlepaddingtop     : number   -- Top padding for title
    titlepaddingbottom  : number   -- Bottom padding for title
    valuepadding        : number   -- Padding for value (all sides unless overridden)
    valuepaddingleft    : number   -- Left padding for value
    valuepaddingright   : number   -- Right padding for value
    valuepaddingtop     : number   -- Top padding for value
    valuepaddingbottom  : number   -- Bottom padding for value
    font                : font     -- Value font (default: FONT_STD)

]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local lastDisplayValue = nil

function render.dirty(box)
    -- Always dirty on first run
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


rfsuite.session.dialImageCache = rfsuite.session.dialImageCache or {}

-- Resolves dial or pointer value to an image path
local function resolveDialAsset(value, basePath)
    if type(value) == "function" then value = value() end
    if type(value) == "number" then
        return string.format("%s/%d.png", basePath, value)
    elseif type(value) == "string" then
        if value:match("^%d+$") then
            return string.format("%s/%s.png", basePath, value)
        else
            return value
        end
    end
    return nil
end

local function loadDialPanelCached(dialId)
    local key = tostring(dialId or "panel1")
    if not rfsuite.session.dialImageCache[key] then
        local panelPath = resolveDialAsset(dialId, "widgets/dashboard/gfx/dials") or "widgets/dashboard/gfx/dials/panel1.png"
        rfsuite.session.dialImageCache[key] = rfsuite.utils.loadImage(panelPath)
    end
    return rfsuite.session.dialImageCache[key]
end

local function calDialAngle(percent, startAngle, sweepAngle)
    return (startAngle or 315) + (sweepAngle or 270) * (percent or 0) / 100
end

local function computeDrawArea(img, x, y, w, h, aspect, align)
    local iw, ih = img:width(), img:height()
    local drawW, drawH = w, h
    if aspect == "fit" then
        local scale = math.min(w / iw, h / ih)
        drawW = iw * scale
        drawH = ih * scale
    elseif aspect == "fill" then
        local scale = math.max(w / iw, h / ih)
        drawW = iw * scale
        drawH = ih * scale
    elseif not aspect or aspect == "original" then
        drawW = iw
        drawH = ih
    end
    local drawX, drawY = x, y
    align = align or "center"
    if align:find("right") then
        drawX = x + w - drawW
    elseif align:find("center") or not align:find("left") then
        drawX = x + (w - drawW) / 2
    end
    if align:find("bottom") then
        drawY = y + h - drawH
    elseif align:find("center") or not align:find("top") then
        drawY = y + (h - drawH) / 2
    end
    return drawX, drawY, drawW, drawH
end

function render.wakeup(box, telemetry)
    -- Value/percent logic
    local value = nil
    local source = getParam(box, "source")
    if source then
        local sensor = telemetry and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
        local transform = getParam(box, "transform")
        if type(transform) == "string" and math[transform] then
            value = value and math[transform](value)
        elseif type(transform) == "function" then
            value = value and transform(value)
        elseif type(transform) == "number" then
            value = value and transform(value)
        end
    end

    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100
    local percent = 0
    if value and max ~= min then
        percent = ((value - min) / (max - min)) * 100
        percent = math.max(0, math.min(100, percent))
    end

    local displayValue = value ~= nil and value or (getParam(box, "novalue") or "-")
    local unit = value ~= nil and getParam(box, "unit") or nil

    -- Image/needle/hub
    local dialId   = getParam(box, "dial")
    local panelImg = loadDialPanelCached(dialId)
    local aspect   = getParam(box, "aspect")
    local align    = getParam(box, "align") or "center"

    local needleColor = resolveThemeColor(getParam(box, "needlecolor"))
    local hubColor    = resolveThemeColor(getParam(box, "needlehubcolor"))
    local accentcolor = resolveThemeColor(getParam(box, "accentcolor"))
    local framecolor  = resolveThemeColor(getParam(box, "framecolor"))
    local needleThickness = tonumber(getParam(box, "needlethickness")) or 3
    local hubRadius   = tonumber(getParam(box, "needlehubsize")) or (math.max(2, needleThickness + 2))

    local needleStartAngle = tonumber(getParam(box, "needlestartangle")) or 135
    local needleEndAngle   = getParam(box, "needleendangle")
    if needleEndAngle then needleEndAngle = tonumber(needleEndAngle) end
    local sweep = needleEndAngle and (needleEndAngle - needleStartAngle) or (tonumber(getParam(box, "needlesweepangle")) or 270)
    if needleEndAngle and math.abs(sweep) > 180 then
        if sweep > 0 then sweep = sweep - 360 else sweep = sweep + 360 end
    end

    -- Standard color fields
    local bgcolor    = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
    local textcolor  = resolveThemeColor("textcolor", getParam(box, "textcolor"))
    local titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
    local accentcolor = resolveThemeColor("accentcolor", getParam(box, "accentcolor"))
    local framecolor = resolveThemeColor("framecolor", getParam(box, "framecolor"))

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = value

    -- All display geometry/padding/font values
    box._cache = {
        value           = value,
        displayValue    = displayValue,
        unit            = unit,
        percent         = percent,
        min             = min,
        max             = max,
        dialId          = dialId,
        panelImg        = panelImg,
        aspect          = aspect,
        align           = align,
        needleColor     = needleColor,
        hubColor        = hubColor,
        accentcolor     = accentcolor,
        framecolor      = framecolor,
        needleThickness = needleThickness,
        hubRadius       = hubRadius,
        needleStartAngle= needleStartAngle,
        sweep           = sweep,
        bgcolor         = bgcolor,
        textcolor       = textcolor,
        titlecolor      = titlecolor,
        title           = getParam(box, "title"),
        titlealign      = getParam(box, "titlealign"),
        valuealign      = getParam(box, "valuealign"),
        titlepos        = getParam(box, "titlepos"),
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
        font            = getParam(box, "font"),
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Draw background
    lcd.color(c.bgcolor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Optional dial frame
    if c.framecolor then
        lcd.color(c.framecolor)
        lcd.drawRectangle(x, y, w, h)
    end

    -- Draw dial panel image
    local drawX, drawY, drawW, drawH = x, y, w, h
    if c.panelImg then
        drawX, drawY, drawW, drawH = computeDrawArea(c.panelImg, x, y, w, h, c.aspect, c.align)
        lcd.drawBitmap(drawX, drawY, c.panelImg, drawW, drawH)
    end

    -- Draw needle/hub/accent
    if c.value ~= nil then
        local angle = calDialAngle(c.percent, c.needleStartAngle, c.sweep)
        local cx = drawX + drawW / 2
        local cy = drawY + drawH / 2
        local radius = math.min(drawW, drawH) * 0.40
        local needleLength = radius - 6

        if c.percent and type(c.percent) == "number" and not (c.percent ~= c.percent) then
            rfsuite.widgets.dashboard.utils.drawBarNeedle(cx, cy, needleLength, c.needleThickness, angle, c.needleColor)
        end

        lcd.color(c.accentcolor or c.hubColor)
        lcd.drawFilledCircle(cx, cy, c.hubRadius)
    end

    -- Title
    if c.title then
        lcd.font(FONT_XS)
        local tW, tH = lcd.getTextSize(c.title)
        tW = tW or 0
        tH = tH or 0
        lcd.color(c.titlecolor or lcd.RGB(255, 255, 255))
        lcd.drawText(x + (w - tW) / 2, y + h - tH, c.title)
    end

    -- Value display (with dynamic/static text sizing)
    if c.displayValue ~= nil then
        local str = tostring(c.displayValue or "") .. (c.unit or "")
        if str == "" then str = "-" end
        local font = c.font -- may be nil for dynamic
        if font and _G[font] then
            lcd.font(_G[font])
        else
            lcd.font(FONT_STD)
        end
        local vW, vH = lcd.getTextSize(str)
        vW = vW or 0
        vH = vH or 0
        lcd.color(c.textcolor or lcd.RGB(255, 255, 255))
        lcd.drawText(x + (w - vW) / 2, y + h - vH - 16, str)
    end
end

return render

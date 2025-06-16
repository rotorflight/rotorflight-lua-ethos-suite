--[[
    Rainbow Gauge Widget

    Configurable Parameters (box table fields):
    -------------------------------------------

    wakeupinterval          : number   -- Optional wakeup interval in seconds (set in wrapper)

    -- title parameters
    title                   : string    -- (Optional) Title text
    titlepos                : string    -- (Optional) "top" or "bottom" (defaults to "top" if omitted)
    titlealign              : string    -- (Optional) "center", "left", "right"
    titlefont               : font      -- (Optional) Title font (e.g., font_l, font_xl)
    titlespacing            : number    -- (Optional) Gap below title
    titlecolor              : color     -- (Optional) Title text color
    titlepadding            : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft        : number    -- (Optional)
    titlepaddingright       : number    -- (Optional)
    titlepaddingtop         : number    -- (Optional)
    titlepaddingbottom      : number    -- (Optional)

    -- value / source parameters
    value                   : any       -- (Optional) Static value to display if telemetry is not present
    showvalue               : bool      -- (Optional) If false, hides the main value text (default true)
    source                  : string    -- Telemetry sensor name
    transform               : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", etc.)
    decimals                : number    -- (Optional) Decimal precision
    novalue                 : string    -- (Optional) Text if telemetry is missing (default: "-")
    unit                    : string    -- (Optional) Unit label ("" hides unit)
    font                    : font      -- (Optional) Value font (e.g., font_l)
    valuealign              : string    -- (Optional) "center", "left", "right"
    textcolor               : color     -- (Optional) Text color
    valuepadding            : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft        : number    -- (Optional)
    valuepaddingright       : number    -- (Optional)
    valuepaddingtop         : number    -- (Optional)
    valuepaddingbottom      : number    -- (Optional)

    -- arc band parameters
    bandlabels              : table     -- List of labels for each band (e.g. {"Low", "Med", "High"})
    bandcolors              : table     -- List of band colors (e.g. {lcd.RGB(180,50,50), lcd.RGB(...)})
    bandlabeloffset         : number    -- (Optional) Outward for left/right labels (default 18)
    bandlabeloffsettop      : number    -- (Optional) Down from the arc edge for the top label (default 8)
    bandlabelfont           : font      -- (Optional) Font for band labels (e.g. FONT_XS, FONT_S). Defaults to FONT_XS

    -- appearance / theming
    bgcolor                 : color     -- (Optional) Widget background color
    fillbgcolor             : color     -- (Optional) Arc background color (optional)
    titlecolor              : color     -- (Optional) Title text color fallback

    -- needle styling
    accentcolor             : color     -- (Optional) Needle and hub color
    needlethickness         : number    -- (Optional) Needle width (default: 5)
    needlehubsize           : number    -- (Optional) Needle hub circle radius (default: 7)

]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThresholdColor = utils.resolveThresholdColor
local resolveThemeColor = utils.resolveThemeColor
local resolveThemeColorArray = utils.resolveThemeColorArray
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

-- Arc drawing helper
local function drawArc(cx, cy, radius, thickness, angleStart, angleEnd, fillcolor, cachedStepRad)
    local step = 1
    local rad_thick = thickness / 2
    local aStart = math.rad(angleStart)
    local aEnd = math.rad(angleEnd)
    if aEnd > aStart then
        aEnd = aEnd - 2 * math.pi
    end
    lcd.color(fillcolor or lcd.RGB(255,128,0))
    local stepRad = cachedStepRad or math.rad(step)
    for a = aStart, aEnd, -stepRad do
        local x = cx + radius * math.cos(a)
        local y = cy - radius * math.sin(a)
        lcd.drawFilledCircle(x, y, rad_thick)
    end
    local x_end = cx + radius * math.cos(aEnd)
    local y_end = cy - radius * math.sin(aEnd)
    lcd.drawFilledCircle(x_end, y_end, rad_thick)
end

function render.wakeup(box, telemetry)
    -- Value extraction
    local source = getParam(box, "source")
    local value = nil
    if telemetry and source then
        value = telemetry.getSensor(source)
    end

    -- Dynamic unit logic (User can force a unit or omit unit using "" to hide)
    local manualUnit = getParam(box, "unit")
    local unit

    if manualUnit ~= nil then
        unit = manualUnit
    else
        local displayValue, _, dynamicUnit = telemetry.getSensor(source)
        if dynamicUnit ~= nil then
            unit = dynamicUnit
        elseif source and telemetry and telemetry.sensorTable[source] then
            unit = telemetry.sensorTable[source].unit_string or ""
        else
            unit = ""
        end
    end

    -- Calculate percent fill for the gauge (clamped 0-1)
    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100
    local percent = 0
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end

    -- Transform and decimals (if required)
    local displayValue
    if value ~= nil then
        displayValue = utils.transformValue(value, box)
    end

    -- Fallback if no value
    if value == nil then
        displayValue = getParam(box, "novalue") or "-"
        unit = nil
    end

    -- Optional: local showvalue
    local showvalue = getParam(box, "showvalue")
    if showvalue == nil then showvalue = true end

    -- Caching values
    box._currentDisplayValue = value

    box._cache = {
        value               = value,
        displayValue        = displayValue,
        percent             = percent,
        unit                = unit,
        min                 = min,
        max                 = max,
        showvalue           = showvalue,
        font                = getParam(box, "font") or "FONT_STD",
        textcolor           = resolveThemeColor("textcolor", getParam(box, "textcolor")),
        fillbgcolor         = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor")),
        bgcolor             = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        title               = getParam(box, "title"),
        titlepos            = getParam(box, "titlepos") or (getParam(box, "title") and "top"),
        titlefont           = getParam(box, "titlefont"),
        titlealign          = getParam(box, "titlealign"),
        titlespacing        = getParam(box, "titlespacing") or 0,
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
        bandlabeloffset     = getParam(box, "bandlabeloffset") or 18,
        bandlabeloffsettop  = getParam(box, "bandlabeloffsettop") or 8,
        bandlabelfont         = getParam(box, "bandlabelfont") or "FONT_XS",
        bandlabels          = getParam(box, "bandlabels") or { "Low", "Med", "High" },
        bandcolors          = resolveThemeColorArray("fillcolor", getParam(box, "bandcolors") or {"red", "orange", "green"}),
        needlethickness     = getParam(box, "needlethickness") or 5,
        needlehubsize       = getParam(box, "needlehubsize") or 7,
        accentcolor         = resolveThemeColor("accentcolor", getParam(box, "accentcolor")),
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Calculate space above for band label subtext (single line, e.g. "Low/OK/High")
    lcd.font(_G[c.bandlabelfont] or FONT_XS)
    local subtextHeight = select(2, lcd.getTextSize("OK")) + 2

    -- Calculate title height and allocate vertical regions for title, subtext, and arc
    local titleHeight = 0
    if c.title then
        lcd.font(_G[c.titlefont] or FONT_XS)
        local _, th = lcd.getTextSize(c.title)
        titleHeight = (th or 0) + (c.titlespacing or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0)
    end

    local arcRegionY, arcRegionH
    if c.titlepos == "bottom" then
        arcRegionY = y + subtextHeight
        arcRegionH = h - subtextHeight - titleHeight
    elseif c.titlepos == "top" then
        arcRegionY = y + titleHeight + subtextHeight
        arcRegionH = h - titleHeight - subtextHeight
    else
        arcRegionY = y + subtextHeight
        arcRegionH = h - subtextHeight
    end

    -- Calculate available arc geometry to maximize arc size within widget region
    local arcMargin = 2
    local usableW = w - arcMargin * 2
    local usableH = arcRegionH - arcMargin
    local thickness = c.thickness or math.max(6, math.min(usableW, usableH) * 0.20)
    local radius = math.min(usableW / 2, usableH) - (thickness / 2)
    if radius < 8 then radius = 8 end
    local cx = x + w / 2
    local cy = arcRegionY + usableH + arcMargin / 2

    -- Draw widget background
    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    -- Draw colored arc bands
    local bandCount = #c.bandlabels
    local startAngle = 180
    local sweep = 180
    for i = 1, bandCount do
        local segStart = startAngle - (i - 1) * (sweep / bandCount)
        local segEnd   = startAngle - i * (sweep / bandCount)
        drawArc(cx, cy, radius, thickness, segStart, segEnd, c.bandcolors[i])
    end

    -- Needle hub vertical offset
    local needleHubYOffset = -6

    -- Draw needle
    if c.percent then
        local angleDeg = startAngle - sweep * c.percent
        local step = 1
        local rad_thick = c.needlethickness / 2
        local needleLen = radius
        local cy_needle = cy + needleHubYOffset

        lcd.color(c.accentcolor)
        for i = 0, needleLen, step do
            local px = cx + i * math.cos(math.rad(angleDeg))
            local py = cy_needle - i * math.sin(math.rad(angleDeg))
            lcd.drawFilledCircle(px, py, rad_thick)
        end
        lcd.drawFilledCircle(cx, cy_needle, c.needlehubsize)
    end

    -- Draw band labels at the top of the arc
    local bandlabeloffsettop = c.bandlabeloffsettop or 8
    local bandlabeloffset    = c.bandlabeloffset or 18
    lcd.font(_G[c.bandlabelfont] or FONT_XS)

    for i = 1, bandCount do
        local midAngle = startAngle - (i - 0.5) * (sweep / bandCount)
        local degNorm = (midAngle + 360) % 360
        local labelRadius
        
        if degNorm > (90 - 10) and degNorm < (90 + 10) then
            labelRadius = radius + thickness/2 + bandlabeloffsettop
        else
            labelRadius = radius + thickness/2 + bandlabeloffset
        end

        local tx = cx + labelRadius * math.cos(math.rad(midAngle))
        local ty = cy - labelRadius * math.sin(math.rad(midAngle))
        local label = c.bandlabels[i]
        if label then
            local tw, th = lcd.getTextSize(label)
            lcd.color(c.textcolor)
            lcd.drawText(tx - tw / 2, ty - th / 2, label)
        end
    end

    -- Draw value and title using standard layout helper
    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.showvalue ~= false and c.displayValue or nil,
        c.showvalue ~= false and c.unit or nil,
        c.font, c.valuealign, c.textcolor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        nil
    )
end

return render

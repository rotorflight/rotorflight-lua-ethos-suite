--[[
    Arc Gauge Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
    -- Title parameters
    title               : string    -- (Optional) Title text
    titlepos            : string    -- (Optional) If `title` is present but `titlepos` is not set, title is placed at the top by default.
    titlealign          : string    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font      -- (Optional) Title font (e.g., FONT_L, FONT_XL)
    titlespacing        : number    -- (Optional) Vertical gap between title and value
    titlecolor          : color     -- (Optional) Title text color (theme/text fallback)
    titlepadding        : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number    -- (Optional) Left padding for title
    titlepaddingright   : number    -- (Optional) Right padding for title
    titlepaddingtop     : number    -- (Optional) Top padding for title
    titlepaddingbottom  : number    -- (Optional) Bottom padding for title

    -- Value/Source parameters
    value               : any       -- (Optional) Static value to display if telemetry is not present
    source              : string    -- Telemetry sensor source name (e.g., "voltage", "current")
    transform           : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number    -- (Optional) Number of decimal places for numeric display
    thresholds          : table     -- (Optional) List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue             : string    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string    -- (Optional) Unit label to append to value ("" hides, default resolves dynamically)
    font                : font      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color     -- (Optional) Value text color (theme/text fallback)
    valuepadding        : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number    -- (Optional) Left padding for value
    valuepaddingright   : number    -- (Optional) Right padding for value
    valuepaddingtop     : number    -- (Optional) Top padding for value
    valuepaddingbottom  : number    -- (Optional) Bottom padding for value

    -- Maxval parameters
    maxfont             : font      -- (Optional) Font for max value label (e.g., FONT_XS, FONT_S, FONT_M, default: FONT_S)
    maxtextcolor        : color     -- (Optional) Max text color (theme/text fallback)
    maxpadding          : number    -- (Optional) Padding (Y-offset) below arc center for max value label (default: 0)
    maxpaddingleft      : number    -- (Optional) Additional X-offset for max label (default: 0)
    maxpaddingtop       : number    -- (Optional) Additional Y-offset for max label (default: 0)

    -- Appearance/Theming
    bgcolor             : color     -- (Optional) Widget background color (theme fallback)
    fillbgcolor         : color     -- (Optional) Arc background color (theme fallback)
    fillcolor           : color     -- (Optional) Arc foreground color (theme fallback)
    maxprefix           : string    -- (Optional) Prefix for max value label (default: "+")

    -- Arc Geometry/Advanced
    min                 : number    -- (Optional) Minimum value of the arc (default: 0)
    max                 : number    -- (Optional) Maximum value of the arc (default: 100)
    thickness           : number    -- (Optional) Arc thickness in pixels
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local resolveThresholdColor = utils.resolveThresholdColor

-- Arc drawing function
local function drawArc(cx, cy, radius, thickness, angleStart, angleEnd, color, cacheStepRad)
    local step = 1
    local rad_thick = thickness / 2
    angleStart = math.rad(angleStart)
    angleEnd = math.rad(angleEnd)
    if angleEnd > angleStart then
        angleEnd = angleEnd - 2 * math.pi
    end
    lcd.color(color)
    local stepRad = cacheStepRad or math.rad(step)
    for a = angleStart, angleEnd, -stepRad do
        local x = cx + radius * math.cos(a)
        local y = cy - radius * math.sin(a)
        lcd.drawFilledCircle(x, y, rad_thick)
    end
    local x_end = cx + radius * math.cos(angleEnd)
    local y_end = cy - radius * math.sin(angleEnd)
    lcd.drawFilledCircle(x_end, y_end, rad_thick)
end

function render.wakeup(box, telemetry)
    -- Value extraction
    local source = getParam(box, "source")
    local value
    if telemetry and source then
        value = telemetry.getSensor(source)
    end

    -- Optionally cache and calculate max value for max arc
    local arcmax = getParam(box, "arcmax") == true
    local maxval = nil
    if arcmax and source then
        local stats = rfsuite.tasks.telemetry.getSensorStats(source)
        local currentMax = stats and stats.max or nil
        local prevMax = box._cache and box._cache.maxval or nil
        maxval = currentMax or prevMax
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

    -- Resolve arc min/max
    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100

    -- Only convert to Fahrenheit or Ft if localization is changed
    local isFahrenheit = unit and unit:match("F$") ~= nil
    local isFeet = unit and unit:lower():match("ft$") ~= nil

    if isFahrenheit then
        min = min * 9 / 5 + 32
        max = max * 9 / 5 + 32
        if arcmax and maxval then
            maxval = maxval * 9 / 5 + 32
        end
    elseif isFeet then
        min = min * 3.28084
        max = max * 3.28084
        if arcmax and maxval then
            maxval = maxval * 3.28084
        end
    end
    
    -- Clone and convert threshold values to match display units if using Fahrenheit or feet
    local thresholds = getParam(box, "thresholds")
    local adjustedThresholds = thresholds

    if thresholds and (isFahrenheit or isFeet) then
        adjustedThresholds = {}
        for i, t in ipairs(thresholds) do
            local newT = {}
            for k, v in pairs(t) do newT[k] = v end
            if type(newT.value) == "number" then
                if isFahrenheit then
                    newT.value = newT.value * 9 / 5 + 32
                elseif isFeet then
                    newT.value = newT.value * 3.28084
                end
            end
            table.insert(adjustedThresholds, newT)
        end
    end

    -- Calculate percent fill for the gauge (clamped 0-1)
    local percent = 0
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end
    local maxPercent = 0
    if arcmax and maxval and max ~= min then
        maxPercent = (maxval - min) / (max - min)
        maxPercent = math.max(0, math.min(1, maxPercent))
    end

    -- Transform and decimals (if required)
    local displayValue
    if value ~= nil then
        displayValue = utils.transformValue(value, box)
    end

    -- Transform and decimals (if required - for arcmax)
    local displayMaxValue = nil
    if arcmax and maxval ~= nil then
        displayMaxValue = utils.transformValue(maxval, box)
    end

    -- Fallback if no value
    if value == nil then
        displayValue = getParam(box, "novalue") or "-"
        unit = nil
    end

    box._cache = {
        value              = value,
        maxval             = maxval,
        displayValue       = displayValue,
        displayMaxValue    = displayMaxValue,
        arcmax             = arcmax,
        min                = min,
        max                = max,
        percent            = percent,
        maxPercent         = maxPercent,
        unit               = unit,
        textcolor          = resolveThresholdColor(value,   box, "textcolor",   "textcolor",   adjustedThresholds),
        maxtextcolor       = resolveThresholdColor(maxval,  box, "maxtextcolor","textcolor",   adjustedThresholds),
        fillcolor          = resolveThresholdColor(value,   box, "fillcolor",   "fillcolor",   adjustedThresholds),
        maxfillcolor       = resolveThresholdColor(maxval,  box, "fillcolor",   "fillcolor",   adjustedThresholds),
        fillbgcolor        = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor")),
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        title              = getParam(box, "title"),
        titlepos           = getParam(box, "titlepos") or (getParam(box, "title") and "top"),
        titlealign         = getParam(box, "titlealign"),
        titlefont          = getParam(box, "titlefont"),
        titlespacing       = getParam(box, "titlespacing") or 0,
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        font               = getParam(box, "font") or "FONT_STD",
        maxfont            = getParam(box, "maxfont") or "FONT_S",
        decimals           = getParam(box, "decimals"),
        valuealign         = getParam(box, "valuealign"),
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop") or 18,
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        thickness          = getParam(box, "thickness"),
        maxprefix          = getParam(box, "maxprefix") or "+",
        maxpadding         = getParam(box, "maxpadding") or 0,
        maxpaddingleft     = getParam(box, "maxpaddingleft") or 0,
        maxpaddingtop      = getParam(box, "maxpaddingtop") or 0,
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Title/Arc layout calculation
    local titleHeight = 0
    if c.title then
        lcd.font(_G[c.titlefont] or FONT_XS)
        local _, th = lcd.getTextSize(c.title)
        titleHeight = (th or 0) + (c.titlespacing or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0)
    end
   
    -- Arc region: based on titlepos (default is top)
    local titlepos = c.titlepos
    local arcRegionY, arcRegionH, cy, radius
    local arcMargin, thickness, maxRadius
    local arcoffsety = 0
    local startangle = 225
    local sweep = 270

    if c.titlepos == "top" then
        arcRegionY   = y + titleHeight
        arcRegionH   = h - titleHeight
        arcMargin    = 8
        thickness    = c.thickness or math.max(6, math.min(w, arcRegionH) * 0.07)
        maxRadius    = ((arcRegionH - arcMargin) / 2) - (thickness / 2)
        radius       = math.min(w * 0.50, maxRadius + 8)
        cy           = arcRegionY + arcRegionH * 0.5 + (arcoffsety or 0)
    elseif c.titlepos == "bottom" then
        arcRegionY   = y
        arcRegionH   = h - titleHeight
        arcMargin    = 8
        thickness    = c.thickness or math.max(6, math.min(w, arcRegionH) * 0.07)
        maxRadius    = ((arcRegionH - arcMargin) / 2) - (thickness / 2)
        radius       = math.min(w * 0.50, maxRadius + 8)
        cy           = arcRegionY + arcRegionH * 0.60 + (arcoffsety or 0)
    else
        arcRegionY   = y
        arcRegionH   = h
        arcMargin    = 8
        thickness    = c.thickness or math.max(6, math.min(w, arcRegionH) * 0.07)
        maxRadius    = ((arcRegionH - arcMargin) / 2) - (thickness / 2)
        radius       = math.min(w * 0.50, maxRadius + 8)
        cy           = arcRegionY + arcRegionH * 0.55 + (arcoffsety or 0)
    end

    -- Widget background
    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end     

    -- Draw background arc
    local cx = x + w / 2
    local stepRad = math.rad(2)
    drawArc(cx, cy, radius, thickness, startangle, startangle - sweep, c.fillbgcolor, stepRad)

    -- Draw value arc
    if c.percent > 0 then
        drawArc(cx, cy, radius, thickness, startangle, startangle - sweep * c.percent, c.fillcolor, stepRad)
    end

    -- Draw extra max value arc if enabled
    if c.arcmax and c.maxval and c.max ~= c.min then
        local innerRadius = radius * 0.75
        local innerThickness = thickness * 0.8
        local maxSweep = sweep * c.maxPercent
        drawArc(cx, cy, innerRadius, innerThickness, startangle, startangle - maxSweep, c.maxfillcolor, stepRad)
    end

    -- Draw title and value
    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.displayValue, c.unit, c.font, c.valuealign, c.textcolor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        nil
    )

    -- Draw max value label if enabled
    if c.arcmax and c.maxval then
        local maxStr = tostring(c.maxprefix or "") .. (c.displayMaxValue or c.maxval) .. (c.unit or "")
        local maxTextColor = c.maxtextcolor or c.textcolor
        lcd.color(maxTextColor)
        lcd.font(_G[c.maxfont] or FONT_S)
        local tw2, th2 = lcd.getTextSize(maxStr)
        lcd.drawText(
            cx - tw2 / 2 + (c.maxpaddingleft or 0),
            cy + radius * 0.25 + (c.maxpadding or 0) + (c.maxpaddingtop or 0),
            maxStr
        )
    end
end

return render

--[[
    Arc Gauge Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
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
    arcmax              : bool      -- (Optional) Draw arcmac gauge within the outer arc (false by default)
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
    gaugepadding        : number    -- (Optional) Horizontal-only padding applied to arc radius (shrinks arc from left/right only)
    gaugepaddingbottom  : number    -- (Optional) Extra space added below arc region, pushing arc upward (vertical only)
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local resolveThresholdColor = utils.resolveThresholdColor
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

-- Arc drawing function
local function drawArc(cx, cy, radius, thickness, startAngle, endAngle, color)
    lcd.color(color)
    local outer = radius
    local inner = math.max(1, radius - (thickness or 6))

    -- Normalize angles
    startAngle = startAngle % 360
    endAngle = endAngle % 360
    if endAngle <= startAngle then
        endAngle = endAngle + 360
    end

    local sweep = endAngle - startAngle
    if sweep <= 180 then
        lcd.drawAnnulusSector(cx, cy, inner, outer, startAngle, endAngle)
    else
        local mid = startAngle + sweep / 2
        lcd.drawAnnulusSector(cx, cy, inner, outer, startAngle, mid)
        lcd.drawAnnulusSector(cx, cy, inner, outer, mid, endAngle)
    end
end

function render.wakeup(box)
    local telemetry = rfsuite.tasks.telemetry

    -- Value extraction
    local source = getParam(box, "source")
    local minCfg = getParam(box, "min")
    local maxCfg = getParam(box, "max")
    local thresholdsCfg = getParam(box, "thresholds")

    local value, _, dynamicUnit, sensorMin, sensorMax, sensorThresholds
    if telemetry and source then
        value, _, dynamicUnit, sensorMin, sensorMax, sensorThresholds =
            telemetry.getSensor(source, minCfg, maxCfg, thresholdsCfg)
    end

    -- Optionally cache and calculate max value for max arc
    local arcmax = getParam(box, "arcmax") == true
    local maxval = nil
    if arcmax and source then
        local stats = telemetry.getSensorStats(source)
        local currentMax = stats and stats.max or nil
        local prevMax = box._cache and box._cache.maxval or nil
        maxval = currentMax or prevMax
    end

    -- Dynamic unit logic (User can force a unit or omit unit using "" to hide)
    local manualUnit = getParam(box, "unit")
    local unit
    if manualUnit ~= nil then
        unit = manualUnit  -- use user value, even if ""
    elseif dynamicUnit ~= nil then
        unit = dynamicUnit
    elseif source and telemetry and telemetry.sensorTable[source] then
        unit = telemetry.sensorTable[source].unit_string or ""
    else
        unit = ""
    end

    -- Use localized min/max/thresholds if provided, fallback to config native units if not
    local min = sensorMin or minCfg or 0
    local max = sensorMax or maxCfg or 100
    local thresholds = sensorThresholds or thresholdsCfg

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

    -- ... style loading indicator
    if value == nil then
        local maxDots = 3
        if box._dotCount == nil then
            box._dotCount = 0
        end
        box._dotCount = (box._dotCount + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then
            displayValue = "."
        end
        unit = nil
    end

    -- Suppress unit if we're displaying loading dots
    if type(displayValue) == "string" and displayValue:match("^%.+$") then
        unit = nil
    end

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = value

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
        textcolor          = resolveThresholdColor(value,   box, "textcolor",   "textcolor",   thresholds),
        maxtextcolor       = resolveThresholdColor(maxval,  box, "maxtextcolor","textcolor",   thresholds),
        fillcolor          = resolveThresholdColor(value,   box, "fillcolor",   "fillcolor",   thresholds),
        maxfillcolor       = resolveThresholdColor(maxval,  box, "fillcolor",   "fillcolor",   thresholds),
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
        font               = getParam(box, "font") or "FONT_M",
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
        gaugepadding       = getParam(box, "gaugepadding") or 0,
        gaugepaddingbottom = getParam(box, "gaugepaddingbottom") or 0,
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

    -- Arc region: based on title position
    local arcRegionY, arcRegionH, cy, radius
    local thickness, maxRadius

    if c.titlepos == "top" then
        arcRegionY = y + titleHeight
        arcRegionH = h - titleHeight - (c.gaugepaddingbottom or 0)
        cy = arcRegionY + arcRegionH * 0.5
    elseif c.titlepos == "bottom" then
        arcRegionY = y
        arcRegionH = h - titleHeight - (c.gaugepaddingbottom or 0)
        cy = arcRegionY + arcRegionH * 0.6
    else
        arcRegionY = y
        arcRegionH = h - (c.gaugepaddingbottom or 0)
        cy = arcRegionY + arcRegionH * 0.55
    end

    thickness = c.thickness or math.max(6, math.min(w, arcRegionH) * 0.07)
    local gaugepadding = c.gaugepadding or 0
    maxRadius = (arcRegionH / 2) - (thickness / 2)
    radius = math.min((w / 2) - gaugepadding, maxRadius + 8)

    -- Widget background
    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    -- Arc layout
    local cx = x + w / 2
    local startAngle = 225
    local endAngle = (startAngle + 270) % 360

    -- Draw background arc (full 270° from 225 to 135)
    drawArc(cx, cy, radius, thickness, startAngle, endAngle, c.fillbgcolor)

    -- Foreground arc based on percent fill
    if c.percent and c.percent > 0 then
        local valueEndAngle = (startAngle + 270 * c.percent) % 360
        drawArc(cx, cy, radius, thickness, startAngle, valueEndAngle, c.fillcolor)
    end

    -- Max value arc if enabled
    if c.arcmax and c.maxval and c.max ~= c.min and c.maxPercent > 0 then
        local innerRadius = radius * 0.74
        local innerThickness = thickness * 0.8
        local maxEndAngle = (startAngle + 270 * c.maxPercent) % 360
        drawArc(cx, cy, innerRadius, innerThickness, startAngle, maxEndAngle, c.maxfillcolor)
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

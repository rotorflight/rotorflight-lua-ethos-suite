--[[

    Arc Dial Gauge Widget

    Configurable Parameters (box table fields):
    -------------------------------------------
    wakeupinterval    : number   -- Optional wakeup interval in seconds (set in wrapper)
    bandLabels        : table           -- List of labels for each color band (e.g. {"Bad", "OK", "Good", "Excellent"})
    bandColors        : table           -- List of fill colors for each band (e.g. {lcd.RGB(180,50,50), lcd.RGB(220,150,40), ...})
    startAngle        : number          -- Arc start angle in degrees (default: 180)
    sweep             : number          -- Total arc sweep in degrees (default: 180)
    min               : number          -- Minimum input value (default: 0)
    max               : number          -- Maximum input value (default: 100)
    source            : string          -- Telemetry sensor source name (e.g. "rssi")
    unit              : string          -- (Optional) Display unit string (e.g. "dB") appended to the value
    transform         : string|function -- (Optional) Value transformation ("floor", "ceil", "round", or custom function)
    decimals          : number          -- (Optional) Number of decimal places for numeric display
    title             : string          -- (Optional) Gauge title text
    novalue           : string          -- (Optional) Displayed if no telemetry value is available (default: "-")

    -- Appearance/Theming:
    textcolor         : color           -- (Optional) Main value text color (theme/text fallback if nil)
    bgcolor           : color           -- (Optional) Gauge background color (theme/background fallback if nil)
    accentcolor       : color           -- (Optional) Needle and needle hub color (default: black)
    titlecolor        : color           -- (Optional) Title text color (textcolor fallback if nil)

    -- Needle Styling:
    needlethickness   : number          -- (Optional) Needle width in pixels (default: 5)
    needlehubsize     : number          -- (Optional) Needle hub circle radius in pixels (default: 7)

]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
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
    angleStart = math.rad(angleStart)
    angleEnd = math.rad(angleEnd)
    if angleEnd > angleStart then
        angleEnd = angleEnd2 - 2 * math.pi
    end
    lcd.color(fillcolor or lcd.RGB(255,128,0))
    local stepRad = cachedStepRad or math.rad(step)
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
     -- Resolve and format the display value (with transform, decimals, and unit if set)
    local source = getParam(box, "source")
    local value = nil
    if source and telemetry then
        local sensor = telemetry.getSensorSource and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
    end

    local displayValue
    if value ~= nil then
        displayValue = utils.transformValue(value, box)
        local unit = getParam(box, "unit") or ""
        if unit ~= "" then
            displayValue = displayValue .. unit
        end
    else
        displayValue = getParam(box, "novalue") or "-"
    end

    local displayValue
    if value ~= nil then
        displayValue = utils.transformValue(value, box)
        local unit = getParam(box, "unit") or ""
        if unit ~= "" then
            displayValue = displayValue .. unit
        end
    else
        displayValue = getParam(box, "novalue") or "-"
    end

    local bandLabels = getParam(box, "bandLabels") or {}
    local bandColors = resolveThemeColorArray("fillcolor", getParam(box, "bandColors") or {
        lcd.RGB(180,50,50),
        lcd.RGB(220,150,40),
        lcd.RGB(90,180,90),
        lcd.RGB(170,180,120)
    })

    local startAngle = getParam(box, "startAngle") or 180
    local sweep = getParam(box, "sweep") or 180
    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100

    local percent = nil
    if value ~= nil and max ~= min then
        percent = (value - min) / (max - min)
        if percent < 0 then percent = 0 end
        if percent > 1 then percent = 1 end
    end

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = value

    -- All color keys are resolved here
    box._cache = {
        displayValue = displayValue,
        bandLabels   = bandLabels,
        bandColors   = bandColors,
        startAngle   = startAngle,
        sweep        = sweep,
        min          = min,
        max          = max,
        value        = value,
        percent      = percent,
        unit         = getParam(box, "unit") or "",
        title        = getParam(box, "title"),
        textcolor    = resolveThemeColor("textcolor", getParam(box, "textcolor")),
        bgcolor      = resolveThemeColor("fillbgcolor", getParam(box, "bgcolor")),
        accentcolor  = resolveThemeColor("accentcolor", getParam(box, "accentcolor")),
        titlecolor   = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        needleThickness = getParam(box, "needlethickness") or 5,
        needlehubsize   = getParam(box, "needlehubsize") or 7,
        novalue     = getParam(box, "novalue") or "-",
    }
end

function render.paint(x, y, w, h, box)
    local c = box._cache or {}

    local bandLabels = c.bandLabels
    local bandColors = c.bandColors
    local bandCount = #bandLabels
    local startAngle = c.startAngle
    local sweep = c.sweep
    local min = c.min
    local max = c.max
    local value = c.value
    local percent = c.percent
    local unit = c.unit
    local title = c.title
    local needleColor = c.accentcolor
    local needleThickness = c.needleThickness
    local needlehubcolor = c.accentcolor
    local needlehubsize = c.needlehubsize
    local bgcolor = c.bgcolor
    local novalue = c.novalue
    local textcolor = c.textcolor
    local titlecolor = c.titlecolor

    -- Center & sizing
    local cx = x + w / 2
    local cy = y + h * 0.92
    local radius = math.min(w, h*2) * 0.40
    local thickness = math.max(8, radius * 0.25)

    -- Background
    lcd.color(bgcolor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Draw colored bands
    for i=1,bandCount do
        local segStart = startAngle - (i-1)*(sweep/bandCount)
        local segEnd   = startAngle - i*(sweep/bandCount)
        drawArc(cx, cy, radius, thickness, segStart, segEnd, bandColors[i])
    end

    -- Draw needle
    if percent then
        local needleLen = radius
        local needleAngle = startAngle + sweep * percent
        rfsuite.widgets.dashboard.utils.drawBarNeedle(cx, cy, needleLen, needleThickness, needleAngle, needleColor)
        lcd.color(needlehubcolor)
        lcd.drawFilledCircle(cx, cy, needlehubsize)
    end

    -- Draw band labels
    lcd.font(FONT_XS)
    for i=1,bandCount do
        local midAngle = startAngle - ((i-0.5)*(sweep/bandCount))
        local tx = cx + (radius + thickness*0.7) * math.cos(math.rad(midAngle))
        local ty = cy - (radius + thickness*0.7) * math.sin(math.rad(midAngle))
        local text = bandLabels[i]
        if text then
            local tw, th = lcd.getTextSize(text)
            lcd.color(textcolor)
            lcd.drawText(tx-tw/2, ty-th/2, text)
        end
    end

    -- Value display
    lcd.font(FONT_STD)
    local valStr = value ~= nil and (tostring(value) .. unit) or novalue
    local vw, vh = lcd.getTextSize(valStr)
    lcd.color(textcolor)
    lcd.drawText(cx - vw / 2, cy - thickness - 18, valStr)

    -- Title (below)
    if title then
        lcd.font(FONT_XS)
        local tw, th = lcd.getTextSize(title)
        lcd.color(titlecolor)
        lcd.drawText(cx-tw/2, y+h-14, title)
    end
end

return render

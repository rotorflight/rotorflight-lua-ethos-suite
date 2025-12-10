--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
   wakeupinterval      : number    -- (Optional) Wakeup interval in seconds for the widget (set in wrapper)
Title parameters
    title               : string    -- (Optional) Title text (e.g., "2.4G", "Lora")
    titlepos            : string    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number    -- (Optional) Vertical gap between title and bar/value
    titlecolor          : color     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number    -- (Optional) Title padding (all sides unless overridden)
    titlepaddingleft    : number    -- (Optional) Left padding for title
    titlepaddingright   : number    -- (Optional) Right padding for title
    titlepaddingtop     : number    -- (Optional) Top padding for title
    titlepaddingbottom  : number    -- (Optional) Bottom padding for title
Value/telemetry parameters
    value               : number    -- (Optional) Static value to display if no telemetry
    hidevalue           : bool      -- (Optional) If true, value/unit will NOT be displayed (default: false)
    source              : string    -- (Optional) Telemetry sensor source name (e.g., "rssi", "voltage", "current")
    transform           : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number    -- (Optional) Number of decimal places for numeric display
    thresholds          : table     -- (Optional) List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue             : string    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string    -- (Optional) Unit label to append to value ("" hides, default resolves dynamically)
    font                : font      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number    -- (Optional) Value padding (all sides unless overridden)
    valuepaddingleft    : number    -- (Optional) Left padding for value
    valuepaddingright   : number    -- (Optional) Right padding for value
    valuepaddingtop     : number    -- (Optional) Top padding for value
    valuepaddingbottom  : number    -- (Optional) Bottom padding for value
Step bar parameters
    stepcount           : number    -- (Optional) Number of steps/bars to draw (default: 4)
    stepgap             : number    -- (Optional) Pixel gap between each step/bar (default: 1)
    fillcolor           : color     -- (Optional) Color for active steps (theme fallback, or resolved by thresholds)
    fillbgcolor         : color     -- (Optional) Color for inactive steps (theme fallback)
    bgcolor             : color     -- (Optional) Widget background color (theme fallback if nil)
Bar padding parameters
    barpadding          : number    -- (Optional) Bar padding (all sides unless overridden)
    barpaddingleft      : number    -- (Optional) Left padding for bar
    barpaddingright     : number    -- (Optional) Right padding for bar
    barpaddingtop       : number    -- (Optional) Top padding for bar
    barpaddingbottom    : number    -- (Optional) Bottom padding for bar
]]

local rfsuite = require("rfsuite")

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local resolveThresholdColor = utils.resolveThresholdColor

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

function render.wakeup(box)
    local telemetry = rfsuite.tasks.telemetry

    local source = getParam(box, "source")
    local value, _, dynamicUnit
    if telemetry and source then value, _, dynamicUnit = telemetry.getSensor(source) end

    local manualUnit = getParam(box, "unit")
    local unit
    if manualUnit ~= nil then
        unit = manualUnit
    elseif dynamicUnit ~= nil then
        unit = dynamicUnit
    elseif source and telemetry and telemetry.sensorTable[source] then
        unit = telemetry.sensorTable[source].unit_string or ""
    else
        unit = ""
    end

    local displayValue
    if value ~= nil then displayValue = utils.transformValue(value, box) end

    if getParam(box, "hidevalue") == true then
        displayValue = nil
        unit = nil
    end

    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100

    local percent = 0
    if value ~= nil and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end

    if value == nil then
        local maxDots = 3
        if box._dotCount == nil then box._dotCount = 0 end
        box._dotCount = (box._dotCount + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then displayValue = "." end
        unit = nil
    end

    local thresholds = getParam(box, "thresholds")
    local fillcolor = resolveThemeColor("fillcolor", getParam(box, "fillcolor")) or lcd.WHITE
    local textcolor = resolveThemeColor("textcolor", getParam(box, "textcolor")) or lcd.WHITE
    if thresholds and value ~= nil then
        fillcolor = resolveThresholdColor(value, box, "fillcolor", "fillcolor", thresholds)
        textcolor = resolveThresholdColor(value, box, "textcolor", "textcolor", thresholds)
    end

    box._currentDisplayValue = percent

    box._cache = {
        value = value,
        displayValue = displayValue,
        unit = unit,
        min = min,
        max = max,
        percent = percent,
        title = getParam(box, "title"),
        titlepos = getParam(box, "titlepos"),
        titlefont = getParam(box, "titlefont"),
        titlespacing = getParam(box, "titlespacing"),
        titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        titlepadding = getParam(box, "titlepadding"),
        titlepaddingleft = getParam(box, "titlepaddingleft"),
        titlepaddingright = getParam(box, "titlepaddingright"),
        titlepaddingtop = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        stepcount = getParam(box, "stepcount") or 4,
        fillcolor = fillcolor,
        fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor")),
        bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        font = getParam(box, "font"),
        valuealign = getParam(box, "valuealign"),
        valuepadding = getParam(box, "valuepadding"),
        valuepaddingleft = getParam(box, "valuepaddingleft"),
        valuepaddingright = getParam(box, "valuepaddingright"),
        valuepaddingtop = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        barpadding = getParam(box, "barpadding"),
        barpaddingleft = getParam(box, "barpaddingleft"),
        barpaddingright = getParam(box, "barpaddingright"),
        barpaddingtop = getParam(box, "barpaddingtop"),
        barpaddingbottom = getParam(box, "barpaddingbottom"),
        textcolor = textcolor,
        hidevalue = getParam(box, "hidevalue"),
        thresholds = thresholds,
        stepgap = getParam(box, "stepgap") or 1
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    local title = c.title
    local titlefont = c.titlefont
    local titlespacing = c.titlespacing or 0
    local titlepos = c.titlepos or (title and "top" or nil)
    local title_area_top = 0
    local title_area_bottom = 0

    if title and title ~= "" then
        lcd.font(_G[titlefont] or FONT_XS)
        local _, tsizeH = lcd.getTextSize(title)
        if titlepos == "bottom" then
            title_area_bottom = (tsizeH or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0) + titlespacing
        else
            title_area_top = (tsizeH or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0) + titlespacing
        end
    end

    local stepGap = c.stepgap or 1
    local minStepW = 4
    local minStepH = 6

    local barpadding = c.barpadding or 0
    local barpaddingleft = c.barpaddingleft or barpadding
    local barpaddingright = c.barpaddingright or barpadding
    local barpaddingtop = c.barpaddingtop or barpadding
    local barpaddingbottom = c.barpaddingbottom or barpadding

    local barX = x + barpaddingleft
    local barY = y + title_area_top + barpaddingtop
    local barW = w - barpaddingleft - barpaddingright
    local barH = h - title_area_top - title_area_bottom - barpaddingtop - barpaddingbottom

    local reqSteps = c.stepcount or 4
    local maxFitSteps = math.max(2, math.floor((barW + stepGap) / (minStepW + stepGap)))
    local steps = math.min(reqSteps, maxFitSteps)
    local stepW = (barW - (steps - 1) * stepGap) / steps
    local maxStepH = math.max(minStepH, barH)
    local activeSteps = math.floor((c.percent or 0) * steps + 0.5)

    for i = 1, steps do
        local stepH = math.floor((maxStepH / steps) * i)
        local stepY = barY + maxStepH - stepH
        local stepX = barX + (i - 1) * (stepW + stepGap)
        lcd.color(i <= activeSteps and c.fillcolor or c.fillbgcolor)
        lcd.drawFilledRectangle(stepX, stepY, stepW, stepH)
    end

    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.displayValue, c.unit, c.font, c.valuealign, c.textcolor, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, nil)
end

return render

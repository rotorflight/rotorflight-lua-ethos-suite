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

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd

local floor = math.floor

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local resolveThresholdColor = utils.resolveThresholdColor
local resolveFont = utils.resolveFont
local getPulsingDots = utils.getPulsingDots
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout

function render.dirty(box)
    return utils.dirtyOnDisplayValueChange(box)
end

-- Caches title-area height + step-bar geometry, keyed on everything that can
-- change it. Previously all of this (including a font measurement for the
-- title) was recomputed unconditionally in paint() on every screen redraw --
-- see context.lua's utils.prepareTextLayout() for the fuller explanation of
-- why that's specifically a paint()-budget problem on Ethos.
local function prepareGeometry(x, y, w, h, box, c)
    local g = box._geom
    local barpadding = c.barpadding or 0
    local barpaddingleft = c.barpaddingleft or barpadding
    local barpaddingright = c.barpaddingright or barpadding
    local barpaddingtop = c.barpaddingtop or barpadding
    local barpaddingbottom = c.barpaddingbottom or barpadding
    local stepgap = c.stepgap or 1
    local stepcount = c.stepcount or 4

    local needGeo = (not g) or g.x ~= x or g.y ~= y or g.w ~= w or g.h ~= h
        or g.title ~= c.title or g.titlefont ~= c.titlefont or g.titlespacing ~= (c.titlespacing or 0)
        or g.titlepaddingtop ~= (c.titlepaddingtop or 0) or g.titlepaddingbottom ~= (c.titlepaddingbottom or 0)
        or g.titlepos ~= c.titlepos
        or g.barpaddingleft ~= barpaddingleft or g.barpaddingright ~= barpaddingright
        or g.barpaddingtop ~= barpaddingtop or g.barpaddingbottom ~= barpaddingbottom
        or g.stepgap ~= stepgap or g.stepcount ~= stepcount

    if not needGeo then return g end

    g = g or {}
    g.x, g.y, g.w, g.h = x, y, w, h
    g.title, g.titlefont = c.title, c.titlefont
    g.titlespacing = c.titlespacing or 0
    g.titlepaddingtop = c.titlepaddingtop or 0
    g.titlepaddingbottom = c.titlepaddingbottom or 0
    g.titlepos = c.titlepos
    g.barpaddingleft, g.barpaddingright = barpaddingleft, barpaddingright
    g.barpaddingtop, g.barpaddingbottom = barpaddingtop, barpaddingbottom
    g.stepgap, g.stepcount = stepgap, stepcount

    local title = g.title
    local titlepos = g.titlepos or (title and "top" or nil)
    local title_area_top = 0
    local title_area_bottom = 0
    if title and title ~= "" then
        lcd.font(resolveFont(g.titlefont, FONT_XS))
        local _, tsizeH = lcd.getTextSize(title)
        if titlepos == "bottom" then
            title_area_bottom = (tsizeH or 0) + g.titlepaddingtop + g.titlepaddingbottom + g.titlespacing
        else
            title_area_top = (tsizeH or 0) + g.titlepaddingtop + g.titlepaddingbottom + g.titlespacing
        end
    end

    local barX = x + barpaddingleft
    local barY = y + title_area_top + barpaddingtop
    local barW = w - barpaddingleft - barpaddingright
    local barH = h - title_area_top - title_area_bottom - barpaddingtop - barpaddingbottom

    local minStepW = 4
    local minStepH = 6
    local maxFitSteps = math.max(2, floor((barW + stepgap) / (minStepW + stepgap)))
    local steps = math.min(stepcount, maxFitSteps)
    local stepW = (barW - (steps - 1) * stepgap) / steps
    local maxStepH = math.max(minStepH, barH)

    g.barX, g.barY, g.barW, g.barH = barX, barY, barW, barH
    g.steps, g.stepW, g.maxStepH = steps, stepW, maxStepH

    box._geom = g
    return g
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
        displayValue = getPulsingDots(box)
        unit = nil
    end

    local thresholds = getParam(box, "thresholds")
    local fillcolor = resolveThemeColor("fillcolor", getParam(box, "fillcolor")) or utils.themeColors().fillcolor or lcd.WHITE
    local fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor")) or utils.themeColors().fillbgcolor or fillcolor
    local textcolor = resolveThemeColor("textcolor", getParam(box, "textcolor")) or lcd.WHITE
    if thresholds and value ~= nil then
        fillcolor = resolveThresholdColor(value, box, "fillcolor", "fillcolor", thresholds)
        textcolor = resolveThresholdColor(value, box, "textcolor", "textcolor", thresholds)
    end

    box._currentDisplayValue = percent

    local c = box._cache
    if not c then
        c = {}
        box._cache = c
    end

    c.value = value
    c.displayValue = displayValue
    c.unit = unit
    c.min = min
    c.max = max
    c.percent = percent
    c.title = getParam(box, "title")
    c.titlepos = getParam(box, "titlepos")
    c.titlefont = getParam(box, "titlefont")
    c.titlespacing = getParam(box, "titlespacing")
    c.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
    c.titlepadding = getParam(box, "titlepadding")
    c.titlepaddingleft = getParam(box, "titlepaddingleft")
    c.titlepaddingright = getParam(box, "titlepaddingright")
    c.titlepaddingtop = getParam(box, "titlepaddingtop")
    c.titlepaddingbottom = getParam(box, "titlepaddingbottom")
    c.stepcount = getParam(box, "stepcount") or 4
    c.fillcolor = fillcolor
    c.fillbgcolor = fillbgcolor
    c.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
    c.font = getParam(box, "font")
    c.valuealign = getParam(box, "valuealign")
    c.valuepadding = getParam(box, "valuepadding")
    c.valuepaddingleft = getParam(box, "valuepaddingleft")
    c.valuepaddingright = getParam(box, "valuepaddingright")
    c.valuepaddingtop = getParam(box, "valuepaddingtop")
    c.valuepaddingbottom = getParam(box, "valuepaddingbottom")
    c.barpadding = getParam(box, "barpadding")
    c.barpaddingleft = getParam(box, "barpaddingleft")
    c.barpaddingright = getParam(box, "barpaddingright")
    c.barpaddingtop = getParam(box, "barpaddingtop")
    c.barpaddingbottom = getParam(box, "barpaddingbottom")
    c.textcolor = textcolor
    c.hidevalue = getParam(box, "hidevalue")
    c.thresholds = thresholds
    c.stepgap = getParam(box, "stepgap") or 1

    if box._dashboardRectW and box._dashboardRectH then
        local gx, gy = utils.applyOffset(box._dashboardRectX or 0, box._dashboardRectY or 0, box)
        local gw, gh
        gx, gy, gw, gh = utils.boxContentRect(gx, gy, box._dashboardRectW, box._dashboardRectH, c.bgcolor)
        prepareGeometry(gx, gy, gw, gh, box, c)
        prepareTextLayout(box, gx, gy, gw, gh, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.displayValue, c.unit, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)

    local g = prepareGeometry(x, y, w, h, box, c)

    local activeSteps = floor((c.percent or 0) * g.steps + 0.5)
    for i = 1, g.steps do
        local stepH = floor((g.maxStepH / g.steps) * i)
        local stepY = g.barY + g.maxStepH - stepH
        local stepX = g.barX + (i - 1) * (g.stepW + g.stepgap)
        lcd.color(i <= activeSteps and c.fillcolor or c.fillbgcolor)
        lcd.drawFilledRectangle(stepX, stepY, g.stepW, stepH)
    end

    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, c.displayValue, c.unit, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, c.textcolor, c.titlecolor)
end

return render

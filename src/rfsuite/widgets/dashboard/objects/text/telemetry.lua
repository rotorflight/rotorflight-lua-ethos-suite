--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    value               : any                       -- (Optional) Static value to display if telemetry is not present
    source              : string                    -- Telemetry sensor source name (e.g., "voltage", "current")
    transform           : string|function|number    -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number                    -- (Optional) Number of decimal places for numeric display
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value or configure as "" to omit the unit from being displayed. If not specified, the widget attempts to resolve a dynamic unit
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
]]

local requireModule = assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local system = system

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local getPulsingDots = utils.getPulsingDots
local compileTransform = utils.compileTransform
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout

function render.invalidate(box)
    box._cfg = nil
    box._textLayout = nil
end

function render.dirty(box)
    return utils.dirtyOnDisplayValueChange(box)
end

local function ensureCfg(box)
    return utils.ensureCfg(box, function(cfg, box)
        cfg.title = getParam(box, "title")
        cfg.titlepos = getParam(box, "titlepos")
        cfg.titlealign = getParam(box, "titlealign")
        cfg.titlefont = getParam(box, "titlefont")
        cfg.titlespacing = getParam(box, "titlespacing")
        cfg.titlepadding = getParam(box, "titlepadding")
        cfg.titlepaddingleft = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")
        cfg.font = getParam(box, "font")
        cfg.valuealign = getParam(box, "valuealign")
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))

        cfg.source = getParam(box, "source")
        cfg.manualUnit = getParam(box, "unit")
        cfg.decimals = getParam(box, "decimals")
        cfg.transform = getParam(box, "transform")
        cfg.transformFn = compileTransform(cfg.transform, cfg.decimals)
        cfg.novalue = getParam(box, "novalue") or "-"

        -- Cache system sources so we don't allocate a new descriptor table every wakeup.
        if cfg.source == "txbatt" then
            cfg._txBattSrc = system.getSource({category = CATEGORY_SYSTEM, member = MAIN_VOLTAGE})
        end
    end)
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local telemetry = rfsuite.tasks.telemetry
    local session = rfsuite.session
    local telemetryActive = session and (session.telemetryState or session.isConnected)
    local inPostflight = (rfsuite.flightmode and rfsuite.flightmode.current == "postflight")

    local source = cfg.source
    local thresholdsCfg = getParam(box, "thresholds")
    local value, _, dynamicUnit, _, _, localizedThresholds

    if source == "txbatt" then
        local src = cfg._txBattSrc or system.getSource({category = CATEGORY_SYSTEM, member = MAIN_VOLTAGE})
        value = src and src.value and src:value() or nil
        dynamicUnit = "V"
        localizedThresholds = thresholdsCfg
    elseif telemetry and source then
        value, _, dynamicUnit, _, _, localizedThresholds = telemetry.getSensor(source, nil, nil, thresholdsCfg)
    end

    local displayValue
    if value ~= nil then
        displayValue = cfg.transformFn(value)
    elseif inPostflight and box._lastValidValue ~= nil then
        displayValue = box._lastValidValue
    else
        displayValue = getPulsingDots(box)
    end

    local textcolor = utils.resolveThresholdColor(value, box, "textcolor", "textcolor", localizedThresholds)

    local unit
    if cfg.manualUnit ~= nil then
        unit = cfg.manualUnit
    elseif dynamicUnit ~= nil then
        unit = dynamicUnit
    elseif source and telemetry and telemetry.sensorTable[source] then
        unit = telemetry.sensorTable[source].unit_string or ""
    else
        unit = ""
    end

    if type(displayValue) == "string" and displayValue:match("^%.+$") then unit = nil end

    if value == nil and not telemetryActive and not inPostflight then
        box._lastValidValue = nil
        box._lastValidUnit = nil
        box._lastValidTextcolor = nil
    end

    if value ~= nil then
        box._lastValidValue = displayValue
        box._lastValidUnit = unit
        box._lastValidTextcolor = textcolor
    elseif inPostflight and box._lastValidValue ~= nil then
        unit = box._lastValidUnit
        textcolor = box._lastValidTextcolor
    end

    box._currentDisplayValue = displayValue

    box._dyn_textcolor = textcolor
    box._dyn_unit = unit

    if box._dashboardRectW and box._dashboardRectH then
        local x, y = utils.applyOffset(box._dashboardRectX or 0, box._dashboardRectY or 0, box)
        local w, h
        x, y, w, h = utils.boxContentRect(x, y, box._dashboardRectW, box._dashboardRectH, cfg.bgcolor)
        prepareTextLayout(box, x, y, w, h, cfg.title, cfg.titlepos, cfg.titlealign, cfg.titlefont, cfg.titlespacing, cfg.titlepadding, cfg.titlepaddingleft, cfg.titlepaddingright, cfg.titlepaddingtop, cfg.titlepaddingbottom, box._currentDisplayValue, box._dyn_unit, cfg.font, cfg.valuealign, cfg.valuepadding, cfg.valuepaddingleft, cfg.valuepaddingright, cfg.valuepaddingtop, cfg.valuepaddingbottom)
    end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)
    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, box._currentDisplayValue, box._dyn_unit, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, box._dyn_textcolor, c.titlecolor)
end

render.scheduler = 0.5

return render

--[[
    Telemetry Value Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
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

-- Precompile the value transform
local function compileTransform(t, decimals)
    local pow = decimals and (10 ^ decimals) or nil
    local function round(v)
        return pow and (math.floor(v * pow + 0.5) / pow) or v
    end

    if type(t) == "number" then
        local mul = t
        return function(v) return round(v * mul) end
    elseif t == "floor" then
        return function(v) return math.floor(v) end
    elseif t == "ceil" then
        return function(v) return math.ceil(v) end
    elseif t == "round" or t == nil then
        return function(v) return round(v) end
    elseif type(t) == "function" then
        return t
    else
        return function(v) return v end
    end
end

function render.wakeup(box)
    local telemetry = rfsuite.tasks.telemetry

    -- Reuse cache table
    local c = box._cache or {}
    box._cache = c

   -- Build static config once
    local cfg = box._cfg
    if not cfg then
        cfg = {}
        cfg.title              = getParam(box, "title")
        cfg.titlepos           = getParam(box, "titlepos")
        cfg.titlealign         = getParam(box, "titlealign")
        cfg.titlefont          = getParam(box, "titlefont")
        cfg.titlespacing       = getParam(box, "titlespacing")
        cfg.titlepadding       = getParam(box, "titlepadding")
        cfg.titlepaddingleft   = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright  = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop    = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")
        cfg.font               = getParam(box, "font")
        cfg.valuealign         = getParam(box, "valuealign")
        cfg.valuepadding       = getParam(box, "valuepadding")
        cfg.valuepaddingleft   = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright  = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop    = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.source             = getParam(box, "source")
        cfg.manualUnit         = getParam(box, "unit")
        cfg.decimals           = getParam(box, "decimals")
        cfg.transform          = getParam(box, "transform")
        cfg.transformFn        = compileTransform(cfg.transform, cfg.decimals)

        box._cfg = cfg
    end

    -- Value extraction
    local source = cfg.source
    local thresholdsCfg = getParam(box, "thresholds")
    local value, _, dynamicUnit, _, _, localizedThresholds

    if source == "txbatt" then
        local src = system.getSource({ category = CATEGORY_SYSTEM, member = MAIN_VOLTAGE })
        value = src and src.value and src:value() or nil
        dynamicUnit = "V"
        localizedThresholds = thresholdsCfg
    elseif telemetry and source then
        value, _, dynamicUnit, _, _, localizedThresholds =
            telemetry.getSensor(source, nil, nil, thresholdsCfg)
    end

    -- Transform and decimals
    local displayValue
    if value ~= nil then
        displayValue = cfg.transformFn(value)
    else
        -- Animated loading dots if no telemetry value
        local maxDots = 3
        if box._dotCount == nil then box._dotCount = 0 end
        box._dotCount = (box._dotCount + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then displayValue = "." end
    end

    -- Threshold logic (use localized thresholds)
    local textcolor = utils.resolveThresholdColor(value, box, "textcolor", "textcolor", localizedThresholds)

    -- Dynamic unit logic (User can force a unit or omit unit using "" to hide)
    local manualUnit = cfg.manualUnit
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

    -- Suppress unit if we're displaying loading dots
    if type(displayValue) == "string" and displayValue:match("^%.+$") then
        unit = nil
    end

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = displayValue

    -- Mutate cache
    c.title              = cfg.title
    c.titlepos           = cfg.titlepos
    c.titlealign         = cfg.titlealign
    c.titlefont          = cfg.titlefont
    c.titlespacing       = cfg.titlespacing
    c.titlepadding       = cfg.titlepadding
    c.titlepaddingleft   = cfg.titlepaddingleft
    c.titlepaddingright  = cfg.titlepaddingright
    c.titlepaddingtop    = cfg.titlepaddingtop
    c.titlepaddingbottom = cfg.titlepaddingbottom
    c.displayValue       = displayValue
    c.unit               = unit
    c.font               = cfg.font
    c.valuealign         = cfg.valuealign
    c.textcolor          = textcolor
    c.valuepadding       = cfg.valuepadding
    c.valuepaddingleft   = cfg.valuepaddingleft
    c.valuepaddingright  = cfg.valuepaddingright
    c.valuepaddingtop    = cfg.valuepaddingtop
    c.valuepaddingbottom = cfg.valuepaddingbottom
    c.bgcolor            = cfg.bgcolor
    c.titlecolor         = cfg.titlecolor
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.displayValue, c.unit, c.font, c.valuealign, c.textcolor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.bgcolor
    )
end

return render

--[[
    Stats Display Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)

    -- Title & Layout
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL)
    titlespacing        : number                    -- (Optional) Vertical gap between title and value
    titlecolor          : color                     -- (Optional) Title text color (theme fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title

    -- Stat Source & Value
    source              : string                    -- (Required for stat mode) Telemetry sensor name used to fetch stats (e.g., "rpm", "current")
    stattype            : string                    -- (Optional) Which stat to show ("max", "min", "avg", etc; default: "max")
    value               : any                       -- (Optional, advanced) Static value. If omitted, widget shows the selected stat for 'source'

    -- Value Display
    unit                : string                    -- (Optional) Dynamic localized unit displayed by default, you can use override this or "" to hide unit
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value

    -- General
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
    transform           : string|function|number    -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number                    -- (Optional) Number of decimal places for numeric display
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")

    Notes:
      - The widget only displays stat values (not live telemetry). "source" and "stattype" select which telemetry stat to show.
      - "unit" always overrides; if not set, unit is resolved from telemetry.sensorTable[source] if available.
      - To display min stats, set stattype = "min"; for max, omit or set stattype = "max".
--]]

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
        cfg.titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.font               = getParam(box, "font")
        cfg.valuealign         = getParam(box, "valuealign")
        cfg.valuepadding       = getParam(box, "valuepadding")
        cfg.valuepaddingleft   = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright  = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop    = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.source             = getParam(box, "source")
        cfg.stattype           = getParam(box, "stattype") or "max"
        cfg.manualUnit         = getParam(box, "unit")
        cfg.decimals           = getParam(box, "decimals")
        cfg.transform          = getParam(box, "transform")
        cfg.transformFn        = compileTransform(cfg.transform, cfg.decimals)

        box._cfg = cfg
    end

    -- Value extraction
    local source = cfg.source
    local statType = cfg.stattype
    local value, unit

    -- Determine if telemetry is active
    local telemetryActive = rfsuite.session and rfsuite.session.isConnected

    if source and telemetry and telemetry.getSensorStats then
        local stats = telemetry.getSensorStats(source)
        if stats and stats[statType] then
            value = stats[statType]
        end

        -- Check localization
        local sensorDef = telemetry.sensorTable and telemetry.sensorTable[source]
        local localize = sensorDef and sensorDef.localizations

        if sensorDef and sensorDef.unit_string then
            unit = sensorDef.unit_string
        end

        -- Only localize the unit string for display, never the value itself
        if localize and type(localize) == "function" and value ~= nil then
            local _, _, localizedUnit = localize(value)
            if localizedUnit ~= nil then unit = localizedUnit end
        end
    end

    -- User-specified unit *always* overrides
    local overrideUnit = cfg.manualUnit
    if overrideUnit ~= nil then
        unit = overrideUnit
    end

    -- Cache the last valid value/unit if telemetry is active and value is present
    if value ~= nil and telemetryActive then
        box._lastValidValue = value
        box._lastValidUnit = unit
    elseif box._lastValidValue ~= nil then
        -- Use cached value/unit if telemetry is lost
        value = box._lastValidValue
        unit = box._lastValidUnit
    end

    local fallbackText = getParam(box, "novalue") or "-"
    local displayValue

    if value == nil then
        -- Show animated dots if stat value is not available yet
        local maxDots = 3
        if box._dotCount == nil then box._dotCount = 0 end
        box._dotCount = (box._dotCount + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then displayValue = "." end
    else
        displayValue = cfg.transformFn(value)
    end

    -- Suppress unit if we're displaying loading dots
    if type(displayValue) == "string" and displayValue:match("^%.+$") then
        unit = nil
    end

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = displayValue

    -- Resolve colors
    local textcolor = utils.resolveThresholdColor(value, box, "textcolor", "textcolor")

    -- Mutate cache
    c.displayValue       = displayValue
    c.unit               = unit
    c.textcolor          = textcolor
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
    c.titlecolor         = cfg.titlecolor
    c.font               = cfg.font
    c.valuealign         = cfg.valuealign
    c.valuepadding       = cfg.valuepadding
    c.valuepaddingleft   = cfg.valuepaddingleft
    c.valuepaddingright  = cfg.valuepaddingright
    c.valuepaddingtop    = cfg.valuepaddingtop
    c.valuepaddingbottom = cfg.valuepaddingbottom
    c.bgcolor            = cfg.bgcolor
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

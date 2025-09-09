--[[
    Dynamic Power (Watts) Display Widget

    Computes and displays instantaneous, min, max, or average power by reading voltage and current sensors.

    Configurable Parameters (box table fields):
    -------------------------------------------
    title               : string          -- (Optional) Title text displayed above or below the value
    titlepos            : string          -- "top" or "bottom" (default)
    titlealign          : string          -- "center", "left", or "right"
    titlefont           : font            -- Font for title (e.g., FONT_L)
    titlespacing        : number          -- Vertical gap between title and value (pixels)
    titlecolor          : color           -- Title text color
    titlepadding        : number          -- Padding for title (all sides)
    font                : font            -- Font for value (e.g., FONT_XL)
    valuealign          : string          -- "center", "left", or "right"
    textcolor           : color           -- Value text color
    valuepadding        : number          -- Padding for value (all sides)
    bgcolor             : color           -- Widget background color
    novalue             : string          -- Text to show if sensors unavailable (default: "-")
    source              : string          -- "current", "min", "max", or "avg" (default: "current")
]]

--[[
    Dynamic Power (Watts) Display Widget — cached version

    Computes and displays instantaneous, min, max, or average power by reading
    voltage and current sensors. Caches all static params once into box._cfg,
    only recomputes the dynamic value/unit per tick.

    Params (box fields):
      title, titlepos, titlealign, titlefont, titlespacing,
      titlepadding, titlepaddingleft, titlepaddingright, titlepaddingtop, titlepaddingbottom,
      font, valuealign, valuepadding, valuepaddingleft, valuepaddingright, valuepaddingtop, valuepaddingbottom,
      textcolor, titlecolor, bgcolor,
      novalue (string, default "-"),
      source  ("current" | "min" | "max" | "avg", default "current"),
      unit    (optional manual override; "" to hide)
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

-- external invalidation hook
function render.invalidate(box) box._cfg = nil end

-- repaint only when value actually changes
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

-- build/refresh static config (theme/params aware)
local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0 -- bump externally when params change
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version     = theme_version
        cfg._param_version     = param_version

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
        cfg.textcolor          = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))

        cfg.novalue            = getParam(box, "novalue") or "-"
        cfg.source             = (getParam(box, "source") or "current"):lower()
        cfg.manualUnit         = getParam(box, "unit") -- "" allowed to hide

        box._cfg = cfg
    end
    return box._cfg
end

-- helpers for loading dots
local function nextDots(box)
    local maxDots = 3
    box._dotCount = ((box._dotCount or 0) + 1) % (maxDots + 1)
    local s = string.rep(".", box._dotCount)
    if s == "" then s = "." end
    return s
end

function render.wakeup(box)
    local cfg = ensureCfg(box)
    local telemetry = rfsuite.tasks.telemetry

    local vStats = telemetry and telemetry.sensorStats and telemetry.sensorStats["voltage"]
    local iStats = telemetry and telemetry.sensorStats and telemetry.sensorStats["current"]

    local telemetryActive = rfsuite.session and rfsuite.session.isConnected and rfsuite.session.telemetryState

    local function currentWatts()
        local v = telemetry and telemetry.getSensor and telemetry.getSensor("voltage")
        local i = telemetry and telemetry.getSensor and telemetry.getSensor("current")
        if v and i then return v * i end
        return nil
    end

    local function statsWatts(kind)
        if not (vStats and iStats) then return nil end
        if kind == "min"  and vStats.min and iStats.min then return vStats.min * iStats.min end
        if kind == "max"  and vStats.max and iStats.max then return vStats.max * iStats.max end
        if kind == "avg"  and vStats.avg and iStats.avg then return vStats.avg * iStats.avg end
        return nil
    end

    local value
    if cfg.source == "current" then
        value = currentWatts()
    elseif cfg.source == "min" or cfg.source == "max" or cfg.source == "avg" then
        value = statsWatts(cfg.source)
    else
        value = nil
    end

    -- cache last valid number
    if type(value) == "number" and telemetryActive then
        box._lastValidValue = value
        box._lastValidUnit = "W"
    end

    -- use last valid if unavailable; else show dots until first value
    local displayValue
    local unit = cfg.manualUnit

    if type(value) == "number" then
        displayValue = tostring(math.floor(value))
    elseif box._lastValidValue ~= nil then
        displayValue = tostring(math.floor(box._lastValidValue))
        unit = box._lastValidUnit
    else
        displayValue = nextDots(box)
        unit = nil
    end

    -- manual unit override (including "" to hide) always wins unless dots
    if type(displayValue) == "string" and displayValue:match("^%.+$") then
        unit = nil
    elseif cfg.manualUnit ~= nil then
        unit = cfg.manualUnit
    else
        unit = unit or "W"
    end

    box._currentDisplayValue = displayValue
    box._dyn_unit = unit
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        box._currentDisplayValue, box._dyn_unit, c.font, c.valuealign, c.textcolor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.bgcolor
    )
end

-- frequent enough for live power
render.scheduler = 0.5

return render
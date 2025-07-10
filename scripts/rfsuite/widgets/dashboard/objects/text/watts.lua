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

local render = {}
local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

-- Cached stat storage
local minWatts, maxWatts, avgWatts, sumWatts, countWatts = nil, nil, nil, nil, nil

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

    -- Try to get stat tables (voltage/current) from telemetry, or fallback to nil
    local v = telemetry and telemetry.sensorStats and telemetry.sensorStats["voltage"]
    local i = telemetry and telemetry.sensorStats and telemetry.sensorStats["current"]

    local source = getParam(box, "source") or "current"
    local displayValue, unit, loadingDots

    -- Defensive: Only update stats if all present
    if v and i and v.min and i.min and v.max and i.max and v.avg and i.avg and v.sum and i.sum and v.count and i.count then
        minWatts   = v.min * i.min
        maxWatts   = v.max * i.max
        avgWatts   = v.avg * i.avg
        sumWatts   = v.sum * i.sum
        countWatts = v.count * i.count
    else
        minWatts, maxWatts, avgWatts, sumWatts, countWatts = nil, nil, nil, nil, nil
    end

    -- Detect telemetry state
    local telemetryActive = rfsuite.session and rfsuite.session.isConnected and rfsuite.session.telemetryState
    -- Cache the last valid display value/unit if it's a number and telemetry is active
    if (source == "min" or source == "max" or source == "avg") and countWatts and countWatts > 0 and telemetryActive then
        if source == "min" then
            box._lastValidValue = tostring(math.floor(minWatts))
        elseif source == "max" then
            box._lastValidValue = tostring(math.floor(maxWatts))
        elseif source == "avg" then
            box._lastValidValue = tostring(math.floor(sumWatts / countWatts))
        end
        box._lastValidUnit = "W"
    elseif source == "current" and telemetry and telemetry.getSensor then
        local vc = telemetry.getSensor("voltage")
        local ic = telemetry.getSensor("current")
        if vc and ic and telemetryActive then
            box._lastValidValue = tostring(math.floor(vc * ic))
            box._lastValidUnit = "W"
        end
    end

    -- If missing sensors or stats, show animated loading dots
    if not v or not i then
        local maxDots = 3
        if box._dotCount == nil then box._dotCount = 0 end
        box._dotCount = (box._dotCount + 1) % (maxDots + 1)
        loadingDots = string.rep(".", box._dotCount)
        if loadingDots == "" then loadingDots = "." end
        displayValue = loadingDots
    end

    -- Value resolution (dynamic value or stats)
    if not displayValue then
        if source == "min" and countWatts and countWatts > 0 then
            displayValue = tostring(math.floor(minWatts))
        elseif source == "max" and countWatts and countWatts > 0 then
            displayValue = tostring(math.floor(maxWatts))
        elseif source == "avg" and countWatts and countWatts > 0 then
            displayValue = tostring(math.floor(sumWatts / countWatts))
        elseif source == "current" then
            local vc = telemetry and telemetry.getSensor and telemetry.getSensor("voltage")
            local ic = telemetry and telemetry.getSensor and telemetry.getSensor("current")
            if vc and ic then
                displayValue = tostring(math.floor(vc * ic))
            else
                -- still show loading dots if sensors missing
                local maxDots = 3
                if box._dotCount == nil then box._dotCount = 0 end
                box._dotCount = (box._dotCount + 1) % (maxDots + 1)
                loadingDots = string.rep(".", box._dotCount)
                if loadingDots == "" then loadingDots = "." end
                displayValue = loadingDots
            end
        else
            -- Unknown source
            displayValue = getParam(box, "novalue") or "-"
        end
    end

    -- If telemetry is lost and we have a cached value, show it
    if (not telemetryActive or displayValue == nil or displayValue == "" or (displayValue and displayValue:match("^%.+$"))) and box._lastValidValue then
        displayValue = box._lastValidValue
        unit = box._lastValidUnit
    end

    -- Fallback for empty/null
    if displayValue == nil or displayValue == "" then
        displayValue = getParam(box, "novalue") or "-"
    end

    -- Unit logic
    if type(displayValue) == "string" and displayValue:match("^%.+$") then
        unit = nil -- suppress unit if dots
    else
        unit = unit or "W"
    end

    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = displayValue

    box._cache = {
        displayValue       = displayValue,
        unit               = unit,
        title              = getParam(box, "title"),
        titlepos           = getParam(box, "titlepos"),
        titlealign         = getParam(box, "titlealign"),
        titlefont          = getParam(box, "titlefont"),
        titlespacing       = getParam(box, "titlespacing"),
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        font               = getParam(box, "font"),
        valuealign         = getParam(box, "valuealign"),
        textcolor          = resolveThemeColor("textcolor", getParam(box, "textcolor")),
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
    }
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

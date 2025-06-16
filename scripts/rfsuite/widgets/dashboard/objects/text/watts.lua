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

-- Cached sensor sources
local vSrc, iSrc

-- Stats storage
local minWatts = math.huge
local maxWatts = -math.huge
local sumWatts = 0
local countWatts = 0

function render.init(box, telemetry)
    -- Cache sources once
    if not vSrc then vSrc = telemetry.getSensorSource("voltage") end
    if not iSrc then iSrc = telemetry.getSensorSource("current") end
end

function render.dirty(box)
    return true
end

function render.wakeup(box, telemetry)
    render.init(box, telemetry)

    -- calculate instantaneous power
    local pVal
    if vSrc and iSrc and vSrc:state() and iSrc:state() then
        local v = vSrc:value()
        local i = iSrc:value()
        if v and i then
            pVal = v * i
        end
    end

    -- update stats
    if pVal then
        minWatts = math.min(minWatts, pVal)
        maxWatts = math.max(maxWatts, pVal)
        sumWatts = sumWatts + pVal
        countWatts = countWatts + 1
    end

    -- select stat to display
    local source = getParam(box, "source") 
    local displayValue
    if source == "min" then
        displayValue = countWatts>0 and string.format("%.1f", minWatts)
    elseif source == "max" then
        displayValue = countWatts>0 and string.format("%.1f", maxWatts)
    elseif source == "avg" then
        displayValue = countWatts>0 and string.format("%.1f", sumWatts/countWatts)
    end
    if displayValue then
        displayValue = math.floor(displayValue) 
    end


    -- fallback
    if not displayValue then
        displayValue = getParam(box, "novalue") or "-"
    end
    box._currentDisplayValue = displayValue
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = {}

    -- collect params
    c.displayValue = box._currentDisplayValue
    c.unit = "W"
    c.title = getParam(box, "title")
    c.titlepos = getParam(box, "titlepos")
    c.titlealign = getParam(box, "titlealign")
    c.titlefont = getParam(box, "titlefont")
    c.titlespacing = getParam(box, "titlespacing")
    c.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
    c.titlepadding = getParam(box, "titlepadding")
    c.font = getParam(box, "font")
    c.valuealign = getParam(box, "valuealign")
    c.textcolor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
    c.valuepadding = getParam(box, "valuepadding")
    c.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))

    -- render
    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding,
        nil, nil,
        nil, nil,
        c.displayValue, c.unit, c.font, c.valuealign, c.textcolor,
        c.valuepadding,
        nil, nil,
        nil, nil,
        c.bgcolor
    )
end

return render

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
local avgWatts = 0

function render.wakeup(box, telemetry)

    local watts
    local v = rfsuite.tasks.telemetry.sensorStats["voltage"]
    local i = rfsuite.tasks.telemetry.sensorStats["current"]

    local loadingDots
    if v == nil or i == nil then
        local maxDots = 3
        if box._dotCount == nil then box._dotCount = 0 end
        box._dotCount = (box._dotCount + 1) % (maxDots + 1)
        loadingDots = string.rep(".", box._dotCount)
        if loadingDots == "" then loadingDots = "." end
    else
        minWatts = v.min * i.min
        maxWatts = v.max * i.max
        avgWatts = v.avg * i.avg
        sumWatts = v.sum * i.sum
        countWatts = v.count * i.count     
    end
    
    -- Resolve display value
    local source = getParam(box, "source") or "current"
    local displayValue
    if loadingDots then
        displayValue = loadingDots
    elseif source == "min" and countWatts > 0 then
        displayValue = tostring(math.floor(minWatts))
    elseif source == "max" and countWatts > 0 then
        displayValue = tostring(math.floor(maxWatts))
    elseif source == "avg" and countWatts > 0 then
        displayValue = tostring(math.floor(sumWatts / countWatts))
    elseif source == "current" then
        local vc = telemetry.getSensor("voltage")
        local ic = telemetry.getSensor("current")   
        if vc and ic then
            watts = vc * ic
            displayValue = tostring(math.floor(watts))
        else
            -- still show loading dots if sensors missing
            if loadingDots then
                displayValue = loadingDots
            else
                displayValue = getParam(box, "novalue") or "-"
            end
        end    
    else
        displayValue = getParam(box, "novalue") or "-"
    end

    -- Suppress unit if we're displaying loading dots
    if type(displayValue) == "string" and displayValue:match("^%.+$") then
        unit = nil
    end

    box._cache = {
        displayValue       = displayValue,
        unit               = "W",
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
        c.titlecolor, c.titlepadding,
        c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.displayValue, c.unit or "W", c.font, c.valuealign, c.textcolor,
        c.valuepadding,
        c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.bgcolor
    )
end

return render

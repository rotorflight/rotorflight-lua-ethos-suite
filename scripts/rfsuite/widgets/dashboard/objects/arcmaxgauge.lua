--[[

    Arc Max Gauge Widget

    Configurable Arguments (box table keys):
    ----------------------------------------
    min               : number   -- Minimum possible value (default: 0)
    max               : number   -- Maximum possible value (default: 100)
    gaugemin          : number   -- Gauge minimum value (default: min)
    gaugemax          : number   -- Gauge maximum value (default: max)
    source            : string   -- Telemetry sensor source name (e.g., "current")
    transform         : string/function/number -- Optional value transform (math function or custom function)
    unit              : string   -- Unit label for value (e.g., "A")
    decimals          : number   -- Number of decimal places for value display
    valueFormat       : function -- Function to format value display (overrides decimals)
    thresholds        : table    -- List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue           : string   -- Text shown if telemetry value is missing (default: "-")

    -- Appearance/Theming:
    fillbgcolor       : color    -- Arc background color (default: theme fallback)
    fillcolor         : color    -- Arc foreground color (default: theme fallback)
    textcolor         : color    -- Value text color (default: theme/text fallback)
    bgcolor           : color    -- Widget background color (default: theme fallback)
    titlecolor        : color    -- Title text color (default: textcolor fallback)

    -- Layout/Font:
    font              : font     -- Font for value (default: FONT_XL)
    textoffsetx       : number   -- X offset for centering value text (default: 0)

    -- Arc geometry:
    arcOffsetY        : number   -- Y offset for the arc center (default: 0)
    startAngle        : number   -- Arc start angle in degrees (default: 135)
    sweep             : number   -- Arc sweep angle in degrees (default: 270)

    -- Title/Label:
    title             : string   -- Gauge title text
    titlepadding      : number   -- Padding for title (applies to all sides unless overridden)
    titlepaddingleft  : number   -- Left padding for title (overrides titlepadding)
    titlepaddingright : number   -- Right padding for title (overrides titlepadding)
    titlepaddingtop   : number   -- Top padding for title (overrides titlepadding)
    titlepaddingbottom: number   -- Bottom padding for title (overrides titlepadding)
    titlepos          : string   -- "top" or "bottom" (default: top)
    titlealign        : string   -- "center", "left", "right" (default: center)

    -- Subtext:
    subText           : string   -- Optional sub-label displayed below arc (e.g., "Max")
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

-- Arc drawing helper
local function drawArc(cx, cy, radius, thickness, angleStart, angleEnd, color, cachedStepRad)
    local step = 1
    local rad_thick = thickness / 2
    angleStart = math.rad(angleStart)
    angleEnd = math.rad(angleEnd)
    if angleEnd > angleStart then
        angleEnd = angleEnd - 2 * math.pi
    end
    lcd.color(color or lcd.RGB(255,128,0))
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
    local min = getParam(box, "min") or 0
    local max = getParam(box, "max") or 100
    local gaugemin = getParam(box, "gaugemin") or min
    local gaugemax = getParam(box, "gaugemax") or max

    local source = getParam(box, "source")
    local value = nil
    if source then
        local sensor = telemetry and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
        local transform = getParam(box, "transform")
        if type(transform) == "string" and math[transform] then
            value = value and math[transform](value)
        elseif type(transform) == "function" then
            value = value and transform(value)
        elseif type(transform) == "number" then
            value = value and transform
        end
    end

    local percent = 0
    if value and gaugemax ~= gaugemin then
        percent = (value - gaugemin) / (gaugemax - gaugemin)
        percent = math.max(0, math.min(1, percent))
    end

    -- Extra: max value logic from arcmaxgauge
    local stats = rfsuite.tasks.telemetry.getSensorStats(source)
    local currentMax = stats and stats.max or nil
    local prevMax = box._cache and box._cache.maxval or nil
    if currentMax and gaugemax ~= gaugemin then
        currentMax = math.min(currentMax, gaugemax)
    end
    local maxval = currentMax or prevMax

    -- Color resolution (normalized to arcgauge style)
    local fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor"))
    local fillcolor   = resolveThemeColor("fillcolor", getParam(box, "fillcolor"))
    local textcolor   = resolveThemeColor("textcolor", getParam(box, "textcolor"))
    local titlecolor  = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))

    local thresholds = getParam(box, "thresholds")
    if thresholds and value then
        for _, t in ipairs(thresholds) do
            local tval = (type(t.value) == "function" and t.value(box, value) or t.value)
            if value <= tval then
                if t.fillcolor then
                    fillcolor = resolveThemeColor("fillcolor", t.fillcolor) or fillcolor
                end
                if t.textcolor then
                    textcolor = resolveThemeColor("textcolor", t.textcolor) or textcolor
                end
                break
            end
        end
    end

    -- Main config cache
    box._cache = {
        maxval = maxval,
        min = min,
        max = max,
        gaugemin = gaugemin,
        gaugemax = gaugemax,
        value = value,
        percent = percent,
        arcOffsetY = getParam(box, "arcOffsetY") or 0,
        startAngle = getParam(box, "startAngle") or 135,
        sweep = getParam(box, "sweep") or 270,
        fillbgcolor = fillbgcolor,
        fillcolor = fillcolor,
        thresholds = thresholds,
        font = getParam(box, "font") or FONT_XL,
        textcolor = textcolor,
        valueFormat = getParam(box, "valueFormat"),
        unit = getParam(box, "unit") or "",
        decimals = getParam(box, "decimals"),
        title = getParam(box, "title"),
        titlepadding = getParam(box, "titlepadding") or 0,
        titlepaddingleft = getParam(box, "titlepaddingleft"),
        titlepaddingright = getParam(box, "titlepaddingright"),
        titlepaddingtop = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        titlepos = getParam(box, "titlepos"),
        titlealign = getParam(box, "titlealign") or "center",
        titlecolor = titlecolor,
        textoffsetx = getParam(box, "textoffsetx") or 0,
        novalue = getParam(box, "novalue") or "-",
        bgcolor = resolveThemeColor("fillbgcolor", getParam(box, "bgcolor")),
        subText = getParam(box, "subText"),
    }
end

function render.paint(x, y, w, h, box)
    local c = box._cache or {}

    -- Layout caching (as in arcgauge)
    box._layoutcache = box._layoutcache or {}
    local layoutcache = box._layoutcache

    local arcOffsetY = c.arcOffsetY or 0
    local layoutKey = string.format("%d,%d,%d,%d,%d",
        math.floor(x + 0.5), math.floor(y + 0.5),
        math.floor(w + 0.5), math.floor(h + 0.5),
        math.floor(arcOffsetY + 0.5)
    )
    if layoutcache._layoutKey ~= layoutKey then
        layoutcache.cx = x + w / 2
        layoutcache.cy = y + h / 2 - arcOffsetY
        layoutcache.radius = math.min(w, h) * 0.42
        layoutcache.thickness = math.max(6, layoutcache.radius * 0.22)
        layoutcache.stepRad = math.rad(4)
        layoutcache._layoutKey = layoutKey
    end

    local cx, cy, radius, thickness, stepRad = layoutcache.cx, layoutcache.cy, layoutcache.radius, layoutcache.thickness, layoutcache.stepRad

    -- Paint background
    local bgColor = c.bgcolor
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Draw background arc
    drawArc(cx, cy, radius, thickness, c.startAngle, c.startAngle - c.sweep, c.fillbgcolor, stepRad)

    -- Draw max value arc (extra feature)
    if type(c.maxval) == "number" and c.gaugemax ~= c.gaugemin then
        local maxPercent = (c.maxval - c.gaugemin) / (c.gaugemax - c.gaugemin)
        maxPercent = math.max(0, math.min(1, maxPercent))
        local maxEndAngle = c.startAngle - c.sweep * maxPercent

        local innerRadius = radius * 0.75
        local innerThickness = thickness * 0.8

        local maxColor = c.fillcolor
        if c.thresholds then
            for _, t in ipairs(c.thresholds) do
                local t_val = type(t.value) == "function" and t.value(box, c.maxval) or t.value
                local t_color = type(t.fillcolor) == "function" and t.fillcolor(box, c.maxval) or t.fillcolor
                if c.maxval <= t_val and t_color then
                    maxColor = utils.resolveThemeColor("fillcolor", t_color) or maxColor
                    break
                end
            end
        end

        lcd.color(maxColor, 0.8)
        drawArc(cx, cy, innerRadius, innerThickness, c.startAngle, maxEndAngle, maxColor, stepRad)
    end

    -- Draw value arc (threshold overrides)
    local arcColor = c.fillcolor
    if c.thresholds and c.value ~= nil then
        for _, t in ipairs(c.thresholds) do
            local t_val = type(t.value) == "function" and t.value(box, c.value) or t.value
            local t_color = type(t.fillcolor) == "function" and t.fillcolor(box, c.value) or t.fillcolor
            if c.value <= t_val and t_color then
                arcColor = utils.resolveThemeColor("fillcolor", t_color) or arcColor
                break
            end
        end
    end
    if c.percent > 0 then
        drawArc(cx, cy, radius, thickness, c.startAngle, c.startAngle - c.sweep * c.percent, arcColor, stepRad)
    end

    -- Draw value text (centered)
    lcd.font(c.font and _G[c.font] or FONT_XL)
    lcd.color(c.textcolor)
    local valStr
    if c.valueFormat then
        valStr = c.valueFormat(c.value)
    elseif type(c.value) == "number" then
        if c.decimals ~= nil then
            if c.decimals == 0 then
                valStr = string.format("%d", c.value)
            else
                valStr = string.format("%." .. c.decimals .. "f", c.value)
            end
        else
            if math.floor(c.value) == c.value then
                valStr = string.format("%d", c.value)
            else
                valStr = string.format("%.1f", c.value)
            end
        end
    else
        valStr = c.novalue or "-"
    end
    if c.value ~= nil then
        valStr = valStr .. (c.unit or "")
    end
    local tw, th = lcd.getTextSize(valStr)
    lcd.drawText(cx - tw / 2 + (c.textoffsetx or 0), cy - th / 2, valStr)

    -- Draw max value text
    if c.maxval then
        local maxStr = string.format("+%.0f%s", c.maxval, c.unit or "")
        lcd.font(FONT_S)
        local tw2, th2 = lcd.getTextSize(maxStr)
        lcd.drawText(cx - tw2 / 2, cy + radius * 0.2, maxStr)
    end

    -- Draw title
    local title = c.title
    if title then
        local titlepadding = c.titlepadding or 0
        local titlepaddingleft = c.titlepaddingleft or titlepadding
        local titlepaddingright = c.titlepaddingright or titlepadding
        local titlepaddingtop = c.titlepaddingtop or titlepadding
        local titlepaddingbottom = c.titlepaddingbottom or titlepadding
        lcd.font(FONT_XS)
        local tsizeW, tsizeH = lcd.getTextSize(title)
        local region_x = x + titlepaddingleft
        local region_w = w - titlepaddingleft - titlepaddingright
        local sy = (c.titlepos == "bottom") and (y + h - titlepaddingbottom - tsizeH) or (y + titlepaddingtop)
        local align = (c.titlealign or "center"):lower()
        local sx
        if align == "left" then
            sx = region_x
        elseif align == "right" then
            sx = region_x + region_w - tsizeW
        else
            sx = region_x + (region_w - tsizeW) / 2
        end
        lcd.color(c.titlecolor)
        lcd.drawText(sx, sy, title)
    end

    -- Draw subText if any
    if c.subText then
        lcd.font(FONT_XS)
        local tw, _ = lcd.getTextSize(c.subText)
        lcd.color(c.textcolor)
        lcd.drawText(cx - tw / 2, cy + radius * 0.55, c.subText)
    end
end

return render

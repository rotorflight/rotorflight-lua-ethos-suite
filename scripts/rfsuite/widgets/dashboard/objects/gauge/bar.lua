--[[
    Bar Gauge Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
    -- Title/label
    title                   : string    -- (Optional) Title text
    titlepos                : string    -- (Optional) "top" or "bottom"
    titlealign              : string    -- (Optional) "center", "left", "right"
    titlefont               : font      -- (Optional) Title font (e.g., FONT_L)
    titlespacing            : number    -- (Optional) Vertical gap below title
    titlecolor              : color     -- (Optional) Title text color (theme/text fallback)
    titlepadding            : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft        : number    -- (Optional)
    titlepaddingright       : number    -- (Optional)
    titlepaddingtop         : number    -- (Optional)
    titlepaddingbottom      : number    -- (Optional)

    -- Value/source
    value                   : any       -- (Optional) Static value to display if no telemetry
    hidevalue               : bool      -- (Optional) If true, do not display the value text (default: false; value is shown)
    source                  : string    -- (Optional) Telemetry sensor source name
    transform               : string|function|number -- (Optional) Value transformation
    decimals                : number    -- (Optional) Number of decimal places for display
    thresholds              : table     -- (Optional) List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue                 : string    -- (Optional) Text shown if value missing (default: "-")
    unit                    : string    -- (Optional) Unit label, "" to hide, or nil to auto-resolve
    font                    : font      -- (Optional) Value font (e.g., FONT_L)
    valuealign              : string    -- (Optional) "center", "left", "right"
    textcolor               : color     -- (Optional) Value text color (theme/text fallback)
    valuepadding            : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft        : number    -- (Optional)
    valuepaddingright       : number    -- (Optional)
    valuepaddingtop         : number    -- (Optional)
    valuepaddingbottom      : number    -- (Optional)

    -- Bar geometry/appearance
    min                     : number    -- (Optional) Min value (alias for gaugemin)
    max                     : number    -- (Optional) Max value (alias for gaugemax)
    gaugeorientation        : string    -- (Optional) "vertical" or "horizontal"
    gaugepaddingleft        : number    -- (Optional)
    gaugepaddingright       : number    -- (Optional)
    gaugepaddingtop         : number    -- (Optional)
    gaugepaddingbottom      : number    -- (Optional)
    roundradius             : number    -- (Optional) Corner radius to apply rounding on edges of the bar

    -- Appearance/Theming
    bgcolor                 : color     -- (Optional) Widget background color (theme fallback)
    fillbgcolor             : color     -- (Optional) Bar background color (theme fallback)
    fillcolor               : color     -- (Optional) Bar fill color (theme fallback)

    -- Battery-style bar options
    batteryframe            : bool      -- (Optional) Draw battery frame & cap around the bar (applies to both standard and segmented bars)
    battery                 : bool      -- (Optional) If true, draw a segmented battery bar instead of a standard fill bar
    batteryframethickness   : number    -- (Optional) Battery frame outline thickness (default: 2)
    batterysegments         : number    -- (Optional) Number of segments for segmented battery bar (default: 6)
    batteryspacing          : number    -- (Optional) Spacing (pixels) between battery segments (default: 2)
    batterysegmentpaddingtop    : number   -- (Optional) Padding (pixels) from the top of each horizontal segment (default: 0)
    batterysegmentpaddingbottom : number   -- (Optional) Padding (pixels) from the bottom of each horizontal segment (default: 0)
    accentcolor             : color     -- (Optional) Color for the battery frame and cap (theme fallback)
    cappaddingleft        : number   -- (Optional) Padding from the left edge of the cap (default: 0)
    cappaddingright       : number   -- (Optional) Padding from the right edge of the cap (default: 0)
    cappaddingtop         : number   -- (Optional) Padding from the top edge of the cap (default: 0)
    cappaddingbottom      : number   -- (Optional) Padding from the bottom edge of the cap (default: 0)


    -- Battery Advanced Info (Optional overlay for battery/fuel bar)
    battadv         : bool      -- (Optional) If true, shows advanced battery/fuel telemetry info lines (voltage, per-cell voltage, consumption, cell count)
    battadvfont             : font      -- Font for advanced info lines (e.g., "FONT_XS", "FONT_M"). Defaults to FONT_XS if unset
    battadvblockalign       : string    -- Horizontal alignment of the entire info block: "left", "center", or "right" (default: "right")
    battadvvaluealign       : string    -- Text alignment within each info line: "left", "center", or "right" (default: "left")
    battadvpadding          : number    -- Padding (pixels) applied to all sides unless overridden by individual paddings (default: 4)
    battadvpaddingleft      : number    -- Padding (pixels) on the left side of the info block (overrides battadvpadding)
    battadvpaddingright     : number    -- Padding (pixels) on the right side of the info block (overrides battadvpadding)
    battadvpaddingtop       : number    -- Padding (pixels) above the first info line (overrides battadvpadding)
    battadvpaddingbottom    : number    -- Padding (pixels) below the last info line (overrides battadvpadding)
    battadvgap              : number    -- Vertical gap (pixels) between info lines (default: 5)

    -- Subtext
    subtext              : string   -- (Optional) A line of subtext to draw inside the bar (usually below value)
    subtextfont          : font     -- (Optional) Font for subtext (default: FONT_XS)
    subtextalign         : string   -- (Optional) "center", "left", or "right" (default: "left")
    subtextpaddingleft   : number   -- (Optional) Padding from left edge of bar (default: 0)
    subtextpaddingright  : number   -- (Optional) Padding from right edge of bar (default: 0)
    subtextpaddingtop    : number   -- (Optional) Extra offset from top of bar (default: 0)
    subtextpaddingbottom : number   -- (Optional) Padding above bottom of bar (default: 0)
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local resolveThresholdColor = utils.resolveThresholdColor
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


local function drawFilledRoundedRectangle(x, y, w, h, r)
    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    w = math.floor(w + 0.5)
    h = math.floor(h + 0.5)
    r = r or 0
    if r > 0 then
        lcd.drawFilledRectangle(x + r, y, w - 2*r, h)
        lcd.drawFilledRectangle(x, y + r, r, h - 2*r)
        lcd.drawFilledRectangle(x + w - r, y + r, r, h - 2*r)
        lcd.drawFilledCircle(x + r, y + r, r)
        lcd.drawFilledCircle(x + w - r - 1, y + r, r)
        lcd.drawFilledCircle(x + r, y + h - r - 1, r)
        lcd.drawFilledCircle(x + w - r - 1, y + h - r - 1, r)
    else
        lcd.drawFilledRectangle(x, y, w, h)
    end
end

local function drawBatteryBox(
    x, y, w, h,
    percent,
    gaugeorientation,
    batterysegments, batteryspacing,
    fillbgcolor, fillcolor,
    batteryframe, batteryframethickness, accentcolor, battery,
    batterysegmentpaddingtop, batterysegmentpaddingbottom,
    batterysegmentpaddingleft, batterysegmentpaddingright,
    cappaddingleft, cappaddingright, cappaddingtop, cappaddingbottom
)

    local frameThickness = batteryframethickness or 4
    local segments = batterysegments or 5
    local spacing = batteryspacing or 2

    if gaugeorientation == "vertical" then
        local capH = 0
        if batteryframe then
            local maxCapH = math.floor(h * 0.5)
            capH = math.min(math.max(8, math.floor(h * 0.10)), maxCapH)
            -- Draw cap at top
            lcd.color(accentcolor)
            local capW = math.min(math.max(4, math.floor(w * 0.40)), w)
            local capX = x + math.floor((w - capW) / 2 + 0.5) + (cappaddingleft or 0)
            local capY = y + (cappaddingtop or 0)
            local capWFinal = capW - (cappaddingleft or 0) - (cappaddingright or 0)
            local capHFinal = capH - (cappaddingtop or 0) - (cappaddingbottom or 0)
            for i = 0, frameThickness - 1 do
                lcd.drawFilledRectangle(capX - i, capY + i, capWFinal + 2 * i, capHFinal - i)
            end
        end
        local bodyY = y + capH
        local bodyH = h - capH

        -- Draw body/frame
        if battery then
            local segCount = math.max(1, segments)
            local fillSegs = math.floor(segCount * percent + 0.5)
            local totalSpacing = (segCount - 1) * spacing
            local segH = (bodyH - totalSpacing) / segCount
            for i = 1, segCount do
                local segY = bodyY + bodyH - (segH + spacing) * i + spacing
                lcd.color(i <= fillSegs and fillcolor or fillbgcolor)
                lcd.drawFilledRectangle(x, segY, w, segH)
            end
        else
            lcd.color(fillbgcolor)
            lcd.drawFilledRectangle(x, bodyY, w, bodyH)
            if percent > 0 then
                lcd.color(fillcolor)
                local fillH = math.floor(bodyH * percent)
                local fillY = bodyY + bodyH - fillH
                lcd.drawFilledRectangle(x, fillY, w, fillH)
            end
        end

        -- Draw frame around body
        if batteryframe then
            lcd.color(accentcolor)
            lcd.drawRectangle(x, bodyY, w, bodyH, frameThickness)
        end

    else
        -- --- Horizontal battery ---
        local maxCapW = math.floor(w * 0.5)
        local capOffset = math.min(math.max(8, math.floor(w * 0.03)), maxCapW)
        local bodyW = w - capOffset

        -- Draw fill or segments inside battery body
        if battery then
            local segCount = math.max(1, segments)
            local fillSegs = math.floor(segCount * percent + 0.5)
            local totalSpacing = (segCount - 1) * spacing
            local segW = (bodyW - totalSpacing) / segCount
            local segPadT = batterysegmentpaddingtop or 0
            local segPadB = batterysegmentpaddingbottom or 0
            local segHeight = h - segPadT - segPadB
            local segPadL = batterysegmentpaddingleft or 0
            local segPadR = batterysegmentpaddingright or 0
            local segAvailW = bodyW - segPadL - segPadR
            local segW = (segAvailW - totalSpacing) / segCount

            for i = 1, segCount do
                local segX = x + segPadL + (i - 1) * (segW + spacing)
                lcd.color(i <= fillSegs and fillcolor or fillbgcolor)
                lcd.drawFilledRectangle(segX, y + segPadT, segW, segHeight)
            end
        else
            lcd.color(fillbgcolor)
            lcd.drawFilledRectangle(x, y, bodyW, h)
            if percent > 0 then
                lcd.color(fillcolor)
                local fillW = math.floor(bodyW * percent)
                lcd.drawFilledRectangle(x, y, fillW, h)
            end
        end

        -- Frame & cap
        if batteryframe then
            lcd.color(accentcolor)
            lcd.drawRectangle(x, y, bodyW, h, frameThickness)
            local capW = capOffset
            local capH = math.min(math.max(4, math.floor(h * 0.33)), h)
            -- Cap is vertically centered, right of bar
            local capX = x + bodyW + (cappaddingleft or 0)
            local capY = y + math.floor((h - capH) / 2 + 0.5) + (cappaddingtop or 0)
            local capWFinal = capW - (cappaddingleft or 0) - (cappaddingright or 0)
            local capHFinal = capH - (cappaddingtop or 0) - (cappaddingbottom or 0)
            for i = 0, frameThickness - 1 do
                lcd.drawFilledRectangle(capX + i, capY + i, capWFinal, capHFinal - 2 * i)
            end
        end
    end
end

function render.wakeup(box)

    local telemetry = rfsuite.tasks.telemetry
    
    -- Value extraction
    local source = getParam(box, "source")
    local value, _, dynamicUnit

    if source == "txbatt" then
        local src = system.getSource({ category = CATEGORY_SYSTEM, member = MAIN_VOLTAGE })
        value = src and src.value and src:value() or nil
        dynamicUnit = "V"
    elseif telemetry and source then
        value, _, dynamicUnit = telemetry.getSensor(source)
    else
        value = getParam(box, "value")
    end

    -- Battery config
    local bc = rfsuite and rfsuite.session and rfsuite.session.batteryConfig

    -- Battery Advanced value extraction
    local getSensor = telemetry and telemetry.getSensor
    local voltage   = getSensor and getSensor("voltage") or 0
    local cellCount = bc and bc.batteryCellCount or 0
    local consumed  = getSensor and getSensor("smartconsumption") or 0
    local perCellVoltage = (cellCount > 0) and (voltage / cellCount) or 0

    -- Dynamic unit logic (User can force a unit or omit unit using "" to hide)
    local manualUnit = getParam(box, "unit")
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

    -- Transform and decimals (if required)
    local displayValue
    if value ~= nil then
        displayValue = utils.transformValue(value, box)
    end

    -- Force suppress value if hidevalue is true
    if getParam(box, "hidevalue") == true then
        displayValue = nil
    end

    -- Resolve bar min/max
    local min, max
    if source == "txbatt" then
        min = getParam(box, "min") or 7.2
        max = getParam(box, "max") or 8.4
    else
        min = getParam(box, "min") or 0
        max = getParam(box, "max") or 100
    end

    -- Calculate percent fill for the gauge (clamped 0-1)
    local percent = 0
    if value and max ~= min then
        percent = (value - min) / (max - min)
        percent = math.max(0, math.min(1, percent))
    end

    -- ... style loading indicator
    if value == nil then
        local maxDots = 3
        if box._dotCount == nil then
            box._dotCount = 0
        end
        box._dotCount = (box._dotCount + 1) % (maxDots + 1)
        displayValue = string.rep(".", box._dotCount)
        if displayValue == "" then
            displayValue = "."
        end
        unit = nil
    end

    -- Calculate title area height(s) for layout
    local title = getParam(box, "title")
    local titlefont = getParam(box, "titlefont")
    local titlespacing = getParam(box, "titlespacing") or 0
    local titlepos = getParam(box, "titlepos") or (title and "top" or nil)
    local title_area_top = 0
    local title_area_bottom = 0

    if title and title ~= "" then
        lcd.font(_G[titlefont] or FONT_XS)
        local _, tsizeH = lcd.getTextSize(title)
        if titlepos == "bottom" then
            title_area_bottom = (tsizeH or 0) + (getParam(box, "titlepaddingtop") or 0)
                + (getParam(box, "titlepaddingbottom") or 0) + titlespacing
        else
            title_area_top = (tsizeH or 0) + (getParam(box, "titlepaddingtop") or 0)
                + (getParam(box, "titlepaddingbottom") or 0) + titlespacing
        end
    else
        title_area_top = 0
        title_area_bottom = 0
    end

    -- If battadv is enabled, cache extra telemetry info for detailed battery display
    local battadv = getParam(box, "battadv")

    if battadv then
        box._batteryLines = {
        line1 = string.format("%.1fv / %.2fv (%dS)", voltage, perCellVoltage, cellCount),
        line2 = string.format("%d mah", consumed)
        }
    else
        box._batteryLines = nil
    end

    -- Suppress unit if we're displaying loading dots
    if type(displayValue) == "string" and displayValue:match("^%.+$") then
        unit = nil
    end
    
    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = value

    box._cache = {
        value                    = value,
        displayValue             = displayValue,
        unit                     = unit,
        min                      = min,
        max                      = max,
        percent                  = percent,
        title                    = title,
        titlepos                 = titlepos,
        titlefont                = titlefont,
        titlespacing             = titlespacing,
        title_area_top           = title_area_top,
        title_area_bottom        = title_area_bottom,
        voltage                  = voltage,
        cellCount                = cellCount,
        consumed                 = consumed,
        perCellVoltage           = perCellVoltage,
        battadv                  = battadv,
        hidevalue                = getParam(box, "hidevalue"),
        textcolor                = resolveThresholdColor(value, box, "textcolor",   "textcolor"),
        fillcolor                = resolveThresholdColor(value,   box, "fillcolor",   "fillcolor"),
        fillbgcolor              = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor")),
        bgcolor                  = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        titlecolor               = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        accentcolor              = resolveThemeColor("accentcolor", getParam(box, "accentcolor")),
        font                     = getParam(box, "font") or "FONT_XL",
        titlealign               = getParam(box, "titlealign"),
        titlepadding             = getParam(box, "titlepadding"),
        titlepaddingleft         = getParam(box, "titlepaddingleft"),
        titlepaddingright        = getParam(box, "titlepaddingright"),
        titlepaddingtop          = getParam(box, "titlepaddingtop"),
        titlepaddingbottom       = getParam(box, "titlepaddingbottom"),
        valuealign               = getParam(box, "valuealign"),
        valuepadding             = getParam(box, "valuepadding"),
        valuepaddingleft         = getParam(box, "valuepaddingleft"),
        valuepaddingright        = getParam(box, "valuepaddingright"),
        valuepaddingtop          = getParam(box, "valuepaddingtop"),
        valuepaddingbottom       = getParam(box, "valuepaddingbottom"),
        gaugeorientation         = getParam(box, "gaugeorientation") or "horizontal",
        gpad_left                = getParam(box, "gaugepaddingleft"),
        gpad_right               = getParam(box, "gaugepaddingright"),
        gpad_top                 = getParam(box, "gaugepaddingtop"),
        gpad_bottom              = getParam(box, "gaugepaddingbottom"),
        roundradius              = getParam(box, "roundradius"),
        battery                  = getParam(box, "battery"),
        batteryframe             = getParam(box, "batteryframe"),
        batteryframethickness    = getParam(box, "batteryframethickness"),
        batterysegments          = getParam(box, "batterysegments"),
        batteryspacing           = getParam(box, "batteryspacing"),
        batterysegmentpaddingleft   = getParam(box, "batterysegmentpaddingleft") or 0,
        batterysegmentpaddingright  = getParam(box, "batterysegmentpaddingright") or 0,
        batterysegmentpaddingtop    = getParam(box, "batterysegmentpaddingtop") or 0,
        batterysegmentpaddingbottom = getParam(box, "batterysegmentpaddingbottom") or 0,
        battadvfont              = getParam(box, "battadvfont") or "FONT_S",
        battadvblockalign        = getParam(box, "battadvblockalign") or "right",
        battadvvaluealign        = getParam(box, "battadvvaluealign") or "left",
        battadvpadding           = getParam(box, "battadvpadding") or 4,
        battadvpaddingleft       = getParam(box, "battadvpaddingleft") or 0,
        battadvpaddingright      = getParam(box, "battadvpaddingright") or 0,
        battadvpaddingtop        = getParam(box, "battadvpaddingtop") or 0,
        battadvpaddingbottom     = getParam(box, "battadvpaddingbottom") or 0,
        battadvgap               = getParam(box, "battadvgap") or 5,
        battstats                = getParam(box, "battstats") or false,
        subtext                  = getParam(box, "subtext"),
        subtextfont              = getParam(box, "subtextfont") or "FONT_XS",
        subtextalign             = getParam(box, "subtextalign") or "left",
        subtextpaddingleft       = getParam(box, "subtextpaddingleft") or 0,
        subtextpaddingright      = getParam(box, "subtextpaddingright") or 0,
        subtextpaddingtop        = getParam(box, "subtextpaddingtop") or 0,
        subtextpaddingbottom     = getParam(box, "subtextpaddingbottom") or 0,
        cappaddingleft           = getParam(box, "cappaddingleft") or 0,
        cappaddingright          = getParam(box, "cappaddingright") or 0,
        cappaddingtop            = getParam(box, "cappaddingtop") or 0,
        cappaddingbottom         = getParam(box, "cappaddingbottom") or 0,
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    -- Widget background
    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    -- Gauge rectangle (with padding and title space)
    local gauge_x = x + (c.gpad_left or 0)
    local gauge_y = y + (c.gpad_top or 0) + (c.title_area_top or 0)
    local gauge_w = w - (c.gpad_left or 0) - (c.gpad_right or 0)
    local gauge_h = h - (c.gpad_top or 0) - (c.gpad_bottom or 0) - (c.title_area_top or 0) - (c.title_area_bottom or 0)

    if c.batteryframe or c.battery then
        drawBatteryBox(
            gauge_x, gauge_y, gauge_w, gauge_h,
            c.percent,
            c.gaugeorientation,
            c.batterysegments, c.batteryspacing,
            c.fillbgcolor, c.fillcolor,
            c.batteryframe, c.batteryframethickness, c.accentcolor, c.battery,
            c.batterysegmentpaddingtop, c.batterysegmentpaddingbottom,
            c.batterysegmentpaddingleft, c.batterysegmentpaddingright,
            c.cappaddingleft, c.cappaddingright, c.cappaddingtop, c.cappaddingbottom
        )
    else
        -- Standard bar background
        lcd.color(c.fillbgcolor)
        drawFilledRoundedRectangle(gauge_x, gauge_y, gauge_w, gauge_h, c.roundradius)

        -- Bar fill
        if not c.battstats and (tonumber(c.percent) or 0) > 0 then
            lcd.color(c.fillcolor)
            if c.gaugeorientation == "vertical" then
                local fillH = math.floor(gauge_h * c.percent)
                local fillY = gauge_y + gauge_h - fillH
                lcd.setClipping(gauge_x, fillY, gauge_w, fillH)
                drawFilledRoundedRectangle(gauge_x, gauge_y, gauge_w, gauge_h, c.roundradius)
                lcd.setClipping()
            else
                local fillW = math.floor(gauge_w * c.percent)
                if fillW > 0 then
                    lcd.setClipping(gauge_x, gauge_y, fillW, gauge_h)
                    drawFilledRoundedRectangle(gauge_x, gauge_y, gauge_w, gauge_h, c.roundradius)
                    lcd.setClipping()
                end
            end
        end
    end

    if c.subtext and c.subtext ~= "" then
        lcd.font(_G[c.subtextfont] or FONT_XS)
        lcd.color(c.textcolor)
        local textW, textH = lcd.getTextSize(c.subtext)
        local sy = gauge_y + gauge_h - textH - c.subtextpaddingbottom
        local sx
        if c.subtextalign == "right" then
            sx = gauge_x + gauge_w - textW - c.subtextpaddingright
        elseif c.subtextalign == "center" then
            sx = gauge_x + math.floor((gauge_w - textW) / 2 + 0.5)
        else
            sx = gauge_x + c.subtextpaddingleft
        end
        sy = sy + c.subtextpaddingtop
        lcd.drawText(sx, sy, c.subtext)
    end


    -- Draw title and value
    local boxValue = c.displayValue
    local boxUnit = c.unit
    if c.hidevalue then
        boxValue = nil
        boxUnit = nil
    end
    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        boxValue, boxUnit, c.font, c.valuealign, c.textcolor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        nil
    )

    -- Ensure paddings are numeric and defaulted
    c.battadvpaddingleft    = tonumber(c.battadvpaddingleft)    or 0
    c.battadvpaddingright   = tonumber(c.battadvpaddingright)   or 0
    c.battadvpaddingtop     = tonumber(c.battadvpaddingtop)     or 0
    c.battadvpaddingbottom  = tonumber(c.battadvpaddingbottom)  or 0
    c.battadvgap            = tonumber(c.battadvgap)            or 5

    -- battadv info lines
    if c.battadv and box._batteryLines then
        local textColor = c.textcolor
        local line1 = box._batteryLines.line1 or ""
        local line2 = box._batteryLines.line2 or ""

        lcd.font(_G[c.battadvfont] or FONT_S)
        local w1, h1 = lcd.getTextSize(line1)
        local w2, h2 = lcd.getTextSize(line2)
        local blockW = math.max(w1, w2) + c.battadvpaddingleft + c.battadvpaddingright
        local blockH = h1 + h2 + c.battadvpaddingtop + c.battadvpaddingbottom + c.battadvgap

        -- Block alignment
        local startY = y + math.max(0, math.floor((h - blockH) / 2 + 0.5))
        local startX
        if c.battadvblockalign == "left" then
            startX = x
        elseif c.battadvblockalign == "center" then
            startX = x + math.floor((w - blockW) / 2 + 0.5)
        else
            startX = x + w - blockW
        end

        -- Draw line 1
        utils.box(
            startX + c.battadvpaddingleft, startY + c.battadvpaddingtop,
            blockW - c.battadvpaddingleft - c.battadvpaddingright, h1,
            nil, nil, c.battadvvaluealign, c.battadvfont, 0,
            textColor,
            0, 0, 0, 0, 0,
            line1, nil, c.battadvfont, c.battadvvaluealign, textColor,
            0, 0, 0, 0, 0,
            nil
        )
        -- Draw line 2
        utils.box(
            startX + c.battadvpaddingleft, startY + c.battadvpaddingtop + h1 + c.battadvgap,
            blockW - c.battadvpaddingleft - c.battadvpaddingright, h2,
            nil, nil, c.battadvvaluealign, c.battadvfont, 0,
            textColor,
            0, 0, 0, 0, 0,
            line2, nil, c.battadvfont, c.battadvvaluealign, textColor,
            0, 0, 0, 0, 0,
            nil
        )
    end
end

return render

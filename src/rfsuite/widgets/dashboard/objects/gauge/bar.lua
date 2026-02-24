--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
Title/label
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
Value/source
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
Bar geometry/appearance
    min                     : number    -- (Optional) Min value (alias for gaugemin)
    max                     : number    -- (Optional) Max value (alias for gaugemax)
    gaugeorientation        : string    -- (Optional) "vertical" or "horizontal"
    gaugepaddingleft        : number    -- (Optional)
    gaugepaddingright       : number    -- (Optional)
    gaugepaddingtop         : number    -- (Optional)
    gaugepaddingbottom      : number    -- (Optional)
    roundradius             : number    -- (Optional) Corner radius to apply rounding on edges of the bar
Appearance/Theming
    bgcolor                 : color     -- (Optional) Widget background color (theme fallback)
    fillbgcolor             : color     -- (Optional) Bar background color (theme fallback)
    fillcolor               : color     -- (Optional) Bar fill color (theme fallback)
Battery-style bar options
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
Battery Advanced Info (Optional overlay for battery/fuel bar)
    battadv         : bool      -- (Optional) If true, shows advanced battery/fuel telemetry info lines (voltage, per-cell voltage, consumption, cell count)
    battadvfont             : font      -- Font for advanced info lines (e.g., "FONT_XS", "FONT_STD"). Defaults to FONT_XS if unset
    battadvblockalign       : string    -- Horizontal alignment of the entire info block: "left", "center", or "right" (default: "right")
    battadvvaluealign       : string    -- Text alignment within each info line: "left", "center", or "right" (default: "left")
    battadvpadding          : number    -- Padding (pixels) applied to all sides unless overridden by individual paddings (default: 4)
    battadvpaddingleft      : number    -- Padding (pixels) on the left side of the info block (overrides battadvpadding)
    battadvpaddingright     : number    -- Padding (pixels) on the right side of the info block (overrides battadvpadding)
    battadvpaddingtop       : number    -- Padding (pixels) above the first info line (overrides battadvpadding)
    battadvpaddingbottom    : number    -- Padding (pixels) below the last info line (overrides battadvpadding)
    battadvgap              : number    -- Vertical gap (pixels) between info lines (default: 5)
Subtext
    subtext              : string   -- (Optional) A line of subtext to draw inside the bar (usually below value)
    subtextfont          : font     -- (Optional) Font for subtext (default: FONT_XS)
    subtextalign         : string   -- (Optional) "center", "left", or "right" (default: "left")
    subtextpaddingleft   : number   -- (Optional) Padding from left edge of bar (default: 0)
    subtextpaddingright  : number   -- (Optional) Padding from right edge of bar (default: 0)
    subtextpaddingtop    : number   -- (Optional) Extra offset from top of bar (default: 0)
    subtextpaddingbottom : number   -- (Optional) Padding above bottom of bar (default: 0)
]]

local rfsuite = require("rfsuite")
local lcd = lcd
local system = system

local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max
local format = string.format
local rep = string.rep
local tonumber = tonumber

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local resolveThresholdColor = utils.resolveThresholdColor
local lastDisplayValue = nil

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

local function drawFilledRoundedRectangle(x, y, w, h, r)
    x = floor(x + 0.5)
    y = floor(y + 0.5)
    w = floor(w + 0.5)
    h = floor(h + 0.5)
    r = r or 0
    if r > 0 then
        lcd.drawFilledRectangle(x + r, y, w - 2 * r, h)
        lcd.drawFilledRectangle(x, y + r, r, h - 2 * r)
        lcd.drawFilledRectangle(x + w - r, y + r, r, h - 2 * r)
        lcd.drawFilledCircle(x + r, y + r, r)
        lcd.drawFilledCircle(x + w - r - 1, y + r, r)
        lcd.drawFilledCircle(x + r, y + h - r - 1, r)
        lcd.drawFilledCircle(x + w - r - 1, y + h - r - 1, r)
    else
        lcd.drawFilledRectangle(x, y, w, h)
    end
end

local function drawBatteryBox(x, y, w, h, percent, gaugeorientation, batterysegments, batteryspacing, fillbgcolor, fillcolor, batteryframe, batteryframethickness, accentcolor, battery, batterysegmentpaddingtop, batterysegmentpaddingbottom, batterysegmentpaddingleft, batterysegmentpaddingright, cappaddingleft, cappaddingright, cappaddingtop, cappaddingbottom)

    local frameThickness = batteryframethickness or 4
    local segments = batterysegments or 5
    local spacing = batteryspacing or 2

    if gaugeorientation == "vertical" then
        local capH = 0
        if batteryframe then
            local maxCapH = floor(h * 0.5)
            capH = min(max(8, floor(h * 0.10)), maxCapH)

            lcd.color(accentcolor)
            local capW = min(max(4, floor(w * 0.40)), w)
            local capX = x + floor((w - capW) / 2 + 0.5) + (cappaddingleft or 0)
            local capY = y + (cappaddingtop or 0)
            local capWFinal = capW - (cappaddingleft or 0) - (cappaddingright or 0)
            local capHFinal = capH - (cappaddingtop or 0) - (cappaddingbottom or 0)
            for i = 0, frameThickness - 1 do lcd.drawFilledRectangle(capX - i, capY + i, capWFinal + 2 * i, capHFinal - i) end
        end
        local bodyY = y + capH
        local bodyH = h - capH

        if battery then
            local segCount = max(1, segments)
            local fillSegs = floor(segCount * percent + 0.5)
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
                local fillH = floor(bodyH * percent)
                local fillY = bodyY + bodyH - fillH
                lcd.drawFilledRectangle(x, fillY, w, fillH)
            end
        end

        if batteryframe then
            lcd.color(accentcolor)
            lcd.drawRectangle(x, bodyY, w, bodyH, frameThickness)
        end

    else

        local maxCapW = floor(w * 0.5)
        local capOffset = min(max(8, floor(w * 0.03)), maxCapW)
        local bodyW = w - capOffset

        if battery then
            local segCount = max(1, segments)
            local fillSegs = floor(segCount * percent + 0.5)
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
                local fillW = floor(bodyW * percent)
                lcd.drawFilledRectangle(x, y, fillW, h)
            end
        end

        if batteryframe then
            lcd.color(accentcolor)
            lcd.drawRectangle(x, y, bodyW, h, frameThickness)
            local capW = capOffset
            local capH = min(max(4, floor(h * 0.33)), h)

            local capX = x + bodyW + (cappaddingleft or 0)
            local capY = y + floor((h - capH) / 2 + 0.5) + (cappaddingtop or 0)
            local capWFinal = capW - (cappaddingleft or 0) - (cappaddingright or 0)
            local capHFinal = capH - (cappaddingtop or 0) - (cappaddingbottom or 0)
            for i = 0, frameThickness - 1 do lcd.drawFilledRectangle(capX + i, capY + i, capWFinal, capHFinal - 2 * i) end
        end
    end
end

local function compileTransform(t, decimals)
    local pow = decimals and (10 ^ decimals) or nil
    local function round(v) return pow and (floor(v * pow + 0.5) / pow) or v end

    if type(t) == "number" then
        local mul = t
        return function(v) return round(v * mul) end
    elseif t == "floor" then
        return function(v) return floor(v) end
    elseif t == "ceil" then
        return function(v) return ceil(v) end
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

    local c = box._cache
    if not c then
        c = {}
        box._cache = c
    end

    local cfg = box._cfg
    if not cfg then
        cfg = {}
        cfg.title = getParam(box, "title")
        cfg.titlepos = getParam(box, "titlepos") or (cfg.title and "top" or nil)
        cfg.titlealign = getParam(box, "titlealign")
        cfg.titlefont = getParam(box, "titlefont")
        cfg.titlespacing = getParam(box, "titlespacing") or 0
        cfg.titlepadding = getParam(box, "titlepadding")
        cfg.titlepaddingleft = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")
        cfg.font = getParam(box, "font") or "FONT_XL"
        cfg.valuealign = getParam(box, "valuealign")
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.gaugeorientation = getParam(box, "gaugeorientation") or "horizontal"
        cfg.gpad_left = getParam(box, "gaugepaddingleft")
        cfg.gpad_right = getParam(box, "gaugepaddingright")
        cfg.gpad_top = getParam(box, "gaugepaddingtop")
        cfg.gpad_bottom = getParam(box, "gaugepaddingbottom")
        cfg.roundradius = getParam(box, "roundradius")
        cfg.battery = getParam(box, "battery")
        cfg.batteryframe = getParam(box, "batteryframe")
        cfg.batteryframethickness = getParam(box, "batteryframethickness")
        cfg.batterysegments = getParam(box, "batterysegments")
        cfg.batteryspacing = getParam(box, "batteryspacing")
        cfg.batterysegmentpaddingleft = getParam(box, "batterysegmentpaddingleft") or 0
        cfg.batterysegmentpaddingright = getParam(box, "batterysegmentpaddingright") or 0
        cfg.batterysegmentpaddingtop = getParam(box, "batterysegmentpaddingtop") or 0
        cfg.batterysegmentpaddingbottom = getParam(box, "batterysegmentpaddingbottom") or 0
        cfg.battadv = getParam(box, "battadv")
        cfg.battadvfont = getParam(box, "battadvfont") or "FONT_S"
        cfg.battadvblockalign = getParam(box, "battadvblockalign") or "right"
        cfg.battadvvaluealign = getParam(box, "battadvvaluealign") or "left"
        cfg.battadvpadding = getParam(box, "battadvpadding") or 4
        cfg.battadvpaddingleft = getParam(box, "battadvpaddingleft") or 0
        cfg.battadvpaddingright = getParam(box, "battadvpaddingright") or 0
        cfg.battadvpaddingtop = getParam(box, "battadvpaddingtop") or 0
        cfg.battadvpaddingbottom = getParam(box, "battadvpaddingbottom") or 0
        cfg.battadvgap = getParam(box, "battadvgap") or 5
        cfg.battstats = getParam(box, "battstats") or false
        cfg.subtext = getParam(box, "subtext")
        cfg.subtextfont = getParam(box, "subtextfont") or "FONT_XS"
        cfg.subtextalign = getParam(box, "subtextalign") or "left"
        cfg.subtextpaddingleft = getParam(box, "subtextpaddingleft") or 0
        cfg.subtextpaddingright = getParam(box, "subtextpaddingright") or 0
        cfg.subtextpaddingtop = getParam(box, "subtextpaddingtop") or 0
        cfg.subtextpaddingbottom = getParam(box, "subtextpaddingbottom") or 0
        cfg.cappaddingleft = getParam(box, "cappaddingleft") or 0
        cfg.cappaddingright = getParam(box, "cappaddingright") or 0
        cfg.cappaddingtop = getParam(box, "cappaddingtop") or 0
        cfg.cappaddingbottom = getParam(box, "cappaddingbottom") or 0
        cfg.fillbgcolor = resolveThemeColor("fillbgcolor", getParam(box, "fillbgcolor"))
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.accentcolor = resolveThemeColor("accentcolor", getParam(box, "accentcolor"))
        cfg.manualUnit = getParam(box, "unit")
        cfg.source = getParam(box, "source")
        cfg.hidevalue = getParam(box, "hidevalue")
        cfg.decimals = getParam(box, "decimals")
        cfg.transform = getParam(box, "transform")
        cfg.transformFn = compileTransform(cfg.transform, cfg.decimals)

        -- Cache system sources so we don't allocate a new descriptor table every paint.
        if cfg.source == "txbatt" then
            cfg._txBattSrc = system.getSource({category = CATEGORY_SYSTEM, member = MAIN_VOLTAGE})
        end

        box._cfg = cfg
    end

    local source = cfg.source
    local value, _, dynamicUnit

    if source == "txbatt" then
        local src = cfg._txBattSrc or system.getSource({category = CATEGORY_SYSTEM, member = MAIN_VOLTAGE})
        value = src and src.value and src:value() or nil
        dynamicUnit = "V"
    elseif telemetry and source then
        value, _, dynamicUnit = telemetry.getSensor(source)
    else
        value = getParam(box, "value")
    end

    local bc = rfsuite and rfsuite.session and rfsuite.session.batteryConfig

    local getSensor = telemetry and telemetry.getSensor
    local voltage = getSensor and getSensor("voltage") or 0
    local cellCount = bc and bc.batteryCellCount or 0
    local consumed = getSensor and getSensor("smartconsumption") or 0
    local perCellVoltage = (cellCount > 0) and (voltage / cellCount) or 0

    local manualUnit = cfg.manualUnit
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
    if value ~= nil then displayValue = cfg.transformFn(value) end

    if cfg.hidevalue == true then displayValue = nil end

    local vmin, vmax
    if source == "txbatt" then
        vmin = getParam(box, "min") or 7.2
        vmax = getParam(box, "max") or 8.4
    else
        vmin = getParam(box, "min") or 0
        vmax = getParam(box, "max") or 100
    end

    local percent = 0
    if value and vmax ~= vmin then
        percent = (value - vmin) / (vmax - vmin)
        percent = max(0, min(1, percent))
    end

    if value == nil then
        local maxDots = 3
        if c._dotCount == nil then c._dotCount = 0 end
        c._dotCount = (c._dotCount + 1) % (maxDots + 1)
        displayValue = rep(".", c._dotCount)
        if displayValue == "" then displayValue = "." end
        unit = nil
    end

    local battadv = cfg.battadv
    if battadv then
        local batteryLines = box._batteryLines
        if not batteryLines then
            batteryLines = {}
            box._batteryLines = batteryLines
        end
        batteryLines.line1 = format("%.1fv / %.2fv (%dS)", voltage, perCellVoltage, cellCount)
        batteryLines.line2 = format("%d mah", consumed)
    else
        local batteryLines = box._batteryLines
        if batteryLines then
            batteryLines.line1 = nil
            batteryLines.line2 = nil
        end
    end

    if type(displayValue) == "string" and displayValue:match("^%.+$") then unit = nil end

    box._currentDisplayValue = value

    c.value = value
    c.displayValue = displayValue
    c.unit = unit
    c.min = vmin
    c.max = vmax
    c.percent = percent
    c.voltage = voltage
    c.cellCount = cellCount
    c.consumed = consumed
    c.perCellVoltage = perCellVoltage
    c.battadv = battadv
    c.textcolor = resolveThresholdColor(value, box, "textcolor", "textcolor")
    c.fillcolor = resolveThresholdColor(value, box, "fillcolor", "fillcolor")
    c.fillbgcolor = cfg.fillbgcolor
    c.bgcolor = cfg.bgcolor
    c.titlecolor = cfg.titlecolor
    c.accentcolor = cfg.accentcolor
    c.title = cfg.title
    c.titlepos = cfg.titlepos
    c.titlealign = cfg.titlealign
    c.titlefont = cfg.titlefont
    c.titlespacing = cfg.titlespacing
    c.titlepadding = cfg.titlepadding
    c.titlepaddingleft = cfg.titlepaddingleft
    c.titlepaddingright = cfg.titlepaddingright
    c.titlepaddingtop = cfg.titlepaddingtop
    c.titlepaddingbottom = cfg.titlepaddingbottom
    c.font = cfg.font
    c.valuealign = cfg.valuealign
    c.valuepadding = cfg.valuepadding
    c.valuepaddingleft = cfg.valuepaddingleft
    c.valuepaddingright = cfg.valuepaddingright
    c.valuepaddingtop = cfg.valuepaddingtop
    c.valuepaddingbottom = cfg.valuepaddingbottom
    c.gaugeorientation = cfg.gaugeorientation
    c.gpad_left = cfg.gpad_left
    c.gpad_right = cfg.gpad_right
    c.gpad_top = cfg.gpad_top
    c.gpad_bottom = cfg.gpad_bottom
    c.roundradius = cfg.roundradius
    c.battery = cfg.battery
    c.batteryframe = cfg.batteryframe
    c.batteryframethickness = cfg.batteryframethickness
    c.batterysegments = cfg.batterysegments
    c.batteryspacing = cfg.batteryspacing
    c.batterysegmentpaddingleft = cfg.batterysegmentpaddingleft
    c.batterysegmentpaddingright = cfg.batterysegmentpaddingright
    c.batterysegmentpaddingtop = cfg.batterysegmentpaddingtop
    c.batterysegmentpaddingbottom = cfg.batterysegmentpaddingbottom
    c.battadvfont = cfg.battadvfont
    c.battadvblockalign = cfg.battadvblockalign
    c.battadvvaluealign = cfg.battadvvaluealign
    c.battadvpadding = cfg.battadvpadding
    c.battadvpaddingleft = cfg.battadvpaddingleft
    c.battadvpaddingright = cfg.battadvpaddingright
    c.battadvpaddingtop = cfg.battadvpaddingtop
    c.battadvpaddingbottom = cfg.battadvpaddingbottom
    c.battadvgap = cfg.battadvgap
    c.battstats = cfg.battstats
    c.subtext = cfg.subtext
    c.subtextfont = cfg.subtextfont
    c.subtextalign = cfg.subtextalign
    c.subtextpaddingleft = cfg.subtextpaddingleft
    c.subtextpaddingright = cfg.subtextpaddingright
    c.subtextpaddingtop = cfg.subtextpaddingtop
    c.subtextpaddingbottom = cfg.subtextpaddingbottom
    c.cappaddingleft = cfg.cappaddingleft
    c.cappaddingright = cfg.cappaddingright
    c.cappaddingtop = cfg.cappaddingtop
    c.cappaddingbottom = cfg.cappaddingbottom
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache
    if not c then return end

    if c.bgcolor then
        lcd.color(c.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    local g = box._geom
    local needGeo = (not g) or g.w ~= w or g.h ~= h or g.title ~= c.title or g.titlefont ~= c.titlefont or g.titlespacing ~= (c.titlespacing or 0) or g.titlepaddingtop ~= (c.titlepaddingtop or 0) or g.titlepaddingbottom ~= (c.titlepaddingbottom or 0) or g.titlepos ~= c.titlepos or g.gpad_left ~= (c.gpad_left or 0) or g.gpad_right ~= (c.gpad_right or 0) or g.gpad_top ~= (c.gpad_top or 0) or g.gpad_bottom ~= (c.gpad_bottom or 0)

    if needGeo then
        g = g or {}
        g.w, g.h = w, h
        g.title, g.titlefont = c.title, c.titlefont
        g.titlespacing = c.titlespacing or 0
        g.titlepaddingtop = c.titlepaddingtop or 0
        g.titlepaddingbottom = c.titlepaddingbottom or 0
        g.titlepos = c.titlepos
        g.gpad_left = c.gpad_left or 0
        g.gpad_right = c.gpad_right or 0
        g.gpad_top = c.gpad_top or 0
        g.gpad_bottom = c.gpad_bottom or 0

        local title_area_top = 0
        local title_area_bottom = 0
        if c.title and c.title ~= "" then
            lcd.font(_G[c.titlefont] or FONT_XS)
            local _, tsizeH = lcd.getTextSize(c.title)
            if c.titlepos == "bottom" then
                title_area_bottom = (tsizeH or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0) + (c.titlespacing or 0)
            else
                title_area_top = (tsizeH or 0) + (c.titlepaddingtop or 0) + (c.titlepaddingbottom or 0) + (c.titlespacing or 0)
            end
        end
        g.title_area_top = title_area_top
        g.title_area_bottom = title_area_bottom

        g.gauge_x = x + g.gpad_left
        g.gauge_y = y + g.gpad_top + g.title_area_top
        g.gauge_w = w - g.gpad_left - g.gpad_right
        g.gauge_h = h - g.gpad_top - g.gpad_bottom - g.title_area_top - g.title_area_bottom

        box._geom = g
    end

    local gauge_x, gauge_y, gauge_w, gauge_h = g.gauge_x, g.gauge_y, g.gauge_w, g.gauge_h

    if c.batteryframe or c.battery then
        drawBatteryBox(gauge_x, gauge_y, gauge_w, gauge_h, c.percent, c.gaugeorientation, c.batterysegments, c.batteryspacing, c.fillbgcolor, c.fillcolor, c.batteryframe, c.batteryframethickness, c.accentcolor, c.battery, c.batterysegmentpaddingtop, c.batterysegmentpaddingbottom, c.batterysegmentpaddingleft, c.batterysegmentpaddingright, c.cappaddingleft, c.cappaddingright, c.cappaddingtop, c.cappaddingbottom)
    else

        lcd.color(c.fillbgcolor)
        drawFilledRoundedRectangle(gauge_x, gauge_y, gauge_w, gauge_h, c.roundradius)

        if not c.battstats and (tonumber(c.percent) or 0) > 0 then
            lcd.color(c.fillcolor)
            if c.gaugeorientation == "vertical" then
                local fillH = floor(gauge_h * c.percent)
                local fillY = gauge_y + gauge_h - fillH
                lcd.setClipping(gauge_x, fillY, gauge_w, fillH)
                drawFilledRoundedRectangle(gauge_x, gauge_y, gauge_w, gauge_h, c.roundradius)
                lcd.setClipping()
            else
                local fillW = floor(gauge_w * c.percent)
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
            sx = gauge_x + floor((gauge_w - textW) / 2 + 0.5)
        else
            sx = gauge_x + c.subtextpaddingleft
        end
        sy = sy + c.subtextpaddingtop
        lcd.drawText(sx, sy, c.subtext)
    end

    local boxValue = c.displayValue
    local boxUnit = c.unit
    if c.hidevalue then
        boxValue = nil
        boxUnit = nil
    end
    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, boxValue, boxUnit, c.font, c.valuealign, c.textcolor, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, nil)

    c.battadvpaddingleft = tonumber(c.battadvpaddingleft) or 0
    c.battadvpaddingright = tonumber(c.battadvpaddingright) or 0
    c.battadvpaddingtop = tonumber(c.battadvpaddingtop) or 0
    c.battadvpaddingbottom = tonumber(c.battadvpaddingbottom) or 0
    c.battadvgap = tonumber(c.battadvgap) or 5

    if c.battadv and box._batteryLines then
        local textColor = c.textcolor
        local line1 = box._batteryLines.line1 or ""
        local line2 = box._batteryLines.line2 or ""

        lcd.font(_G[c.battadvfont] or FONT_S)
        local w1, h1 = lcd.getTextSize(line1)
        local w2, h2 = lcd.getTextSize(line2)
        local blockW = max(w1, w2) + c.battadvpaddingleft + c.battadvpaddingright
        local blockH = h1 + h2 + c.battadvpaddingtop + c.battadvpaddingbottom + c.battadvgap

        local startY = y + max(0, floor((h - blockH) / 2 + 0.5))
        local startX
        if c.battadvblockalign == "left" then
            startX = x
        elseif c.battadvblockalign == "center" then
            startX = x + floor((w - blockW) / 2 + 0.5)
        else
            startX = x + w - blockW
        end

        utils.box(startX + c.battadvpaddingleft, startY + c.battadvpaddingtop, blockW - c.battadvpaddingleft - c.battadvpaddingright, h1, nil, nil, c.battadvvaluealign, c.battadvfont, 0, textColor, 0, 0, 0, 0, 0, line1, nil, c.battadvfont, c.battadvvaluealign, textColor, 0, 0, 0, 0, 0, nil)

        utils.box(startX + c.battadvpaddingleft, startY + c.battadvpaddingtop + h1 + c.battadvgap, blockW - c.battadvpaddingleft - c.battadvpaddingright, h2, nil, nil, c.battadvvaluealign, c.battadvfont, 0, textColor, 0, 0, 0, 0, 0, line2, nil, c.battadvfont, c.battadvvaluealign, textColor, 0, 0, 0, 0, 0, nil)
    end
end

return render

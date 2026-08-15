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
    value               : any                       -- (Optional) Static value to display if not present
    transform           : string|function|number    -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function) on used MB
    decimals            : number                    -- (Optional) Number of decimal places for numeric display
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
    ]] --

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")

local format = string.format

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout
local LOADING_DOTS = {".", "..", "...", "."}
local BLACKBOX_UNIT_LABEL = "@i18n(app.modules.fblstatus.megabyte)@"

function render.invalidate(box)
    box._cfg = nil
    box._textLayout = nil
end

function render.dirty(box)
    if not rfsuite.session.telemetryState then return false end
    return utils.dirtyOnDisplayValueChange(box)
end

local function ensureCfg(box)
    return utils.ensureCfg(box, function(cfg, box)
        cfg.title = getParam(box, "title")
        cfg.titlepos = getParam(box, "titlepos")
        cfg.titlealign = getParam(box, "titlealign")
        cfg.titlefont = getParam(box, "titlefont")
        cfg.titlespacing = getParam(box, "titlespacing")
        cfg.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.titlepadding = getParam(box, "titlepadding")
        cfg.titlepaddingleft = getParam(box, "titlepaddingleft")
        cfg.titlepaddingright = getParam(box, "titlepaddingright")
        cfg.titlepaddingtop = getParam(box, "titlepaddingtop")
        cfg.titlepaddingbottom = getParam(box, "titlepaddingbottom")

        cfg.decimals = getParam(box, "decimals") or 1
        cfg.valueFormat = "%." .. cfg.decimals .. "f/%." .. cfg.decimals .. "f %s"
        cfg.novalue = getParam(box, "novalue") or "-"
        cfg.unit = getParam(box, "unit")
        cfg.font = getParam(box, "font")
        cfg.valuealign = getParam(box, "valuealign")
        cfg.defaultTextColor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
    end)
end

function render.wakeup(box)

    local cfg = ensureCfg(box)

    local totalSize = rfsuite.session.bblSize
    local usedSize = rfsuite.session.bblUsed

    local displayValue
    local percentUsed

    if totalSize and usedSize then
        local usedMB = usedSize / (1024 * 1024)
        local totalMB = totalSize / (1024 * 1024)
        percentUsed = totalSize > 0 and (usedSize / totalSize) * 100 or 0

        if box._lastUsedSize ~= usedSize or box._lastTotalSize ~= totalSize or box._lastDisplayFormat ~= cfg.valueFormat then
            local transformedUsed = utils.transformValue(usedMB, box)
            local transformedTotal = utils.transformValue(totalMB, box)
            box._formattedDisplayValue = format(cfg.valueFormat, transformedUsed, transformedTotal, BLACKBOX_UNIT_LABEL)
            box._lastUsedSize = usedSize
            box._lastTotalSize = totalSize
            box._lastDisplayFormat = cfg.valueFormat
        end
        displayValue = box._formattedDisplayValue
    else
        if totalSize == nil and usedSize == nil then

            box._dotCount = ((box._dotCount or 0) + 1) % 4
            displayValue = LOADING_DOTS[box._dotCount + 1]
        else
            displayValue = cfg.novalue
        end
        percentUsed = nil
        box._lastUsedSize = nil
        box._lastTotalSize = nil
    end

    box._isLoadingDots = type(displayValue) == "string" and displayValue:match("^%.+$") ~= nil

    box._dynamicTextColor = percentUsed ~= nil and utils.resolveThresholdColor(percentUsed, box, "textcolor", "textcolor") or cfg.defaultTextColor

    box._currentDisplayValue = displayValue

    if box._dashboardRectW and box._dashboardRectH then
        local unitForPaint = box._isLoadingDots and nil or cfg.unit
        local x, y = utils.applyOffset(box._dashboardRectX or 0, box._dashboardRectY or 0, box)
        local w, h
        x, y, w, h = utils.boxContentRect(x, y, box._dashboardRectW, box._dashboardRectH, cfg.bgcolor)
        prepareTextLayout(box, x, y, w, h, cfg.title, cfg.titlepos, cfg.titlealign, cfg.titlefont, cfg.titlespacing, cfg.titlepadding, cfg.titlepaddingleft, cfg.titlepaddingright, cfg.titlepaddingtop, cfg.titlepaddingbottom, box._currentDisplayValue, unitForPaint, cfg.font, cfg.valuealign, cfg.valuepadding, cfg.valuepaddingleft, cfg.valuepaddingright, cfg.valuepaddingtop, cfg.valuepaddingbottom)
    end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    local unitForPaint = box._isLoadingDots and nil or c.unit
    local textColor = box._dynamicTextColor or c.defaultTextColor

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)
    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, box._currentDisplayValue, unitForPaint, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, textColor, c.titlecolor)
end

return render


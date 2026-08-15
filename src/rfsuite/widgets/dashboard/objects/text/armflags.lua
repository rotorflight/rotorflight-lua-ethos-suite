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
    thresholds          : table                     -- (Optional) List of thresholds: {value=..., textcolor=...} for coloring ARMED/DISARMED states.
    novalue             : string                    -- (Optional) Text shown if telemetry value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value (not used here)
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
Example thresholds:
thresholds = {
    { value = "ARMED", textcolor = "green" },
    { value = "DISARMED", textcolor = "red" },
    { value = "Throttle high", textcolor = "orange" },
    { value = "Failsafe", textcolor = "orange" },
}
]]--

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")

local floor = math.floor

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local armingDisableFlagsToString = rfsuite.utils.armingDisableFlagsToString
local getPulsingDots = utils.getPulsingDots
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout

function render.invalidate(box)
    box._cfg = nil
    box._textLayout = nil
end

function render.dirty(box)
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
        cfg.font = getParam(box, "font")
        cfg.valuealign = getParam(box, "valuealign")
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.novalue = getParam(box, "novalue") or "-"
        cfg.unit = nil
        cfg.defaultTextColor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
    end)
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local telemetry = rfsuite.tasks.telemetry
    local value = telemetry and telemetry.getSensor("armflags")
    local disableflags = telemetry and telemetry.getSensor("armdisableflags")

    local displayValue
    local showReason = false

    if disableflags ~= nil and armingDisableFlagsToString then
        disableflags = floor(disableflags)
        local reason = armingDisableFlagsToString(disableflags)
        if reason and reason ~= "OK" then
            displayValue = reason
            showReason = true
        end
    end

    if not showReason then
        if value ~= nil then
            -- Bit 0 (ARMED, firmware runtime_config.h) is the only bit
            -- that reflects current arm state -- bits 1/2 accumulate over
            -- a session (e.g. PREARM users see 5, then 7), so a
            -- whole-value check like value == 1 or 3 stops matching once
            -- either has been set.
            if (floor(value) & 1) == 1 then
                displayValue = "@i18n(widgets.governor.ARMED)@"
            else
                displayValue = "@i18n(widgets.governor.DISARMED)@"
            end
        end
    end

    if displayValue == nil and value == nil and disableflags == nil then
        displayValue = getPulsingDots(box)
    elseif displayValue == nil then
        displayValue = cfg.novalue
    end

    box._dynamicTextColor = utils.resolveThresholdColor(displayValue, box, "textcolor", "textcolor") or cfg.defaultTextColor

    box._currentDisplayValue = displayValue

    if box._dashboardRectW and box._dashboardRectH then
        local x, y = utils.applyOffset(box._dashboardRectX or 0, box._dashboardRectY or 0, box)
        local w, h
        x, y, w, h = utils.boxContentRect(x, y, box._dashboardRectW, box._dashboardRectH, cfg.bgcolor)
        prepareTextLayout(box, x, y, w, h, cfg.title, cfg.titlepos, cfg.titlealign, cfg.titlefont, cfg.titlespacing, cfg.titlepadding, cfg.titlepaddingleft, cfg.titlepaddingright, cfg.titlepaddingtop, cfg.titlepaddingbottom, box._currentDisplayValue, cfg.unit, cfg.font, cfg.valuealign, cfg.valuepadding, cfg.valuepaddingleft, cfg.valuepaddingright, cfg.valuepaddingtop, cfg.valuepaddingbottom)
    end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}
    local textColor = box._dynamicTextColor or c.defaultTextColor

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)
    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, box._currentDisplayValue, c.unit, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, textColor, c.titlecolor)
end

render.scheduler = 0.5

return render

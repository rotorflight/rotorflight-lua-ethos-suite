--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
    wakeupinterval      : number          -- Optional wakeup interval in seconds (set in wrapper)
    title               : string          -- (Optional) Title text displayed above or below the value
    titlepos            : string          -- (Optional) Title position: "top" or "bottom"
    titlealign          : string          -- (Optional) Title alignment: "center", "left", or "right"
    titlefont           : font            -- (Optional) Font for title (e.g., FONT_L, FONT_XL). Uses theme or default if unset.
    titlespacing        : number          -- (Optional) Vertical gap between title and value (pixels)
    titlecolor          : color           -- (Optional) Title text color (theme fallback if nil)
    titlepadding        : number          -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number          -- (Optional) Left padding for title
    titlepaddingright   : number          -- (Optional) Right padding for title
    titlepaddingtop     : number          -- (Optional) Top padding for title
    titlepaddingbottom  : number          -- (Optional) Bottom padding for title
    value               : string|number   -- (Optional) **Static** value to display (required for this widget)
    font                : font            -- (Optional) Font for value (e.g., FONT_L, FONT_XL). Uses theme or default if unset.
    valuealign          : string          -- (Optional) Value alignment: "center", "left", or "right"
    textcolor           : color           -- (Optional) Value text color (theme fallback if nil)
    valuepadding        : number          -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number          -- (Optional) Left padding for value
    valuepaddingright   : number          -- (Optional) Right padding for value
    valuepaddingtop     : number          -- (Optional) Top padding for value
    valuepaddingbottom  : number          -- (Optional) Bottom padding for value
    bgcolor             : color           -- (Optional) Widget background color (theme fallback if nil)
    novalue             : string          -- (Optional) Text to show if value is nil (default: "-")
Note:
This widget is for **static or label text only**. It does not support live telemetry or stats.
If you need dynamic stats or telemetry (min/max/live), use `stats.lua` or other appropriate widgets.
]]

local rfsuite = assert(loadfile("widgets/dashboard/context.lua"))()

local tostring = tostring

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
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

        cfg.titlecolor = resolveThemeColor("titlecolor", getParam(box, "titlecolor"))
        cfg.textcolor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))

        cfg.novalue = getParam(box, "novalue") or "-"
        cfg.unit = nil
    end)
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local value = getParam(box, "value")
    local displayValue = (value ~= nil) and tostring(value) or cfg.novalue

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

    x, y, w, h = utils.drawBoxBackground(x, y, w, h, c.bgcolor)
    local layout = prepareTextLayout(box, x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, box._currentDisplayValue, c.unit, c.font, c.valuealign, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom)
    paintTextLayout(layout, c.textcolor, c.titlecolor)
end

render.scheduler = 2.0

return render

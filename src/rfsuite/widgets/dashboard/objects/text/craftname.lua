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
    novalue             : string                    -- (Optional) Text shown if craft name is missing (default: "-")
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
]]

local requireModule = assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local model = model

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local getPulsingDots = utils.getPulsingDots
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout

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
        cfg.font = getParam(box, "font")
        cfg.valuealign = getParam(box, "valuealign")
        cfg.textcolor = resolveThemeColor("textcolor", getParam(box, "textcolor"))
        cfg.valuepadding = getParam(box, "valuepadding")
        cfg.valuepaddingleft = getParam(box, "valuepaddingleft")
        cfg.valuepaddingright = getParam(box, "valuepaddingright")
        cfg.valuepaddingtop = getParam(box, "valuepaddingtop")
        cfg.valuepaddingbottom = getParam(box, "valuepaddingbottom")
        cfg.bgcolor = resolveThemeColor("bgcolor", getParam(box, "bgcolor"))
        cfg.novalue = getParam(box, "novalue") or "Craftname not set"
        cfg.unit = nil
    end)
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local value = rfsuite.session.craftName
    local telemetryActive = rfsuite.session and rfsuite.session.isConnected

    if value and type(value) == "string" and value:match("^%s*$") == nil and telemetryActive then box._lastValidCraftName = value end

    local displayValue
    if value and type(value) == "string" and value:match("^%s*$") == nil then
        displayValue = value
    elseif box._lastValidCraftName then
        displayValue = box._lastValidCraftName
    else
        -- MSP has never reported a craft name (the FC-side name field is
        -- simply left blank, not merely slow to arrive) -- fall back to the
        -- Ethos model's own name rather than leaving this box pinned on
        -- pulsing dots for the whole session. Same fallback
        -- themes/danielrc's and themes/helihud's own craftname handling
        -- already use.
        local modelName = model and model.name and model.name()
        if modelName and type(modelName) == "string" and modelName:match("^%s*$") == nil then
            displayValue = modelName
        else
            displayValue = getPulsingDots(box)
        end
    end

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

render.scheduler = 0.5

return render

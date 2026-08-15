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
    titlespacing        : number                    -- (Optional) Vertical gap between title and value text
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    displayValue        : any                       -- (Optional) Value to display (processed governor state)
    unit                : string                    -- (Not used)
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
Example thresholds:
thresholds = {
    { value = "DISARMED", textcolor = "red" },
    { value = "ACTIVE",   textcolor = "green" },
    ...
}
]]

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")

local gmatch = string.gmatch
local clock = os.clock

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local getPulsingDots = utils.getPulsingDots
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout

local function splitCSV(str, out)
    local t = out or {}
    for i = #t, 1, -1 do
        t[i] = nil
    end
    for part in gmatch(str, "([^,]+)") do
        t[#t + 1] = part:gsub("^%s*(.-)%s*$", "%1") -- trim
    end
    return t
end

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
        cfg.unit = nil
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

    local telemetry = rfsuite.tasks.telemetry
    local raw = telemetry and telemetry.getSensor("governor")
    local displayValue = rfsuite.utils.getGovernorState(raw)

    -- Loading dots
    if raw == nil then
        displayValue = getPulsingDots(box)

        -- reset CSV state
        box._csvParts = nil
        box._csvIndex = nil
        box._csvLastTick = nil
    end

    -- CSV handling
    if type(displayValue) == "string" and string.find(displayValue, ",", 1, true) then
        -- Initialise CSV state if new or changed
        if box._csvRaw ~= displayValue then
            box._csvRaw = displayValue
            box._csvParts = splitCSV(displayValue, box._csvParts)
            box._csvIndex = 1
            box._csvLastTick = clock()
        end

        -- Rotate every 1s
        if box._csvParts and #box._csvParts > 0 then
            local now = clock()
            if now - (box._csvLastTick or 0) >= 1.5 then  -- 1.5 seconds per value
                box._csvIndex = (box._csvIndex % #box._csvParts) + 1
                box._csvLastTick = now
            end
            displayValue = box._csvParts[box._csvIndex]
        end
    else
        -- Not CSV → clear state
        box._csvParts = nil
        box._csvIndex = nil
        box._csvLastTick = nil
        box._csvRaw = nil
    end

    if displayValue == nil or displayValue == "" then
        displayValue = getParam(box, "novalue") or "-"
    end

    box._dynamicTextColor =
        utils.resolveThresholdColor(displayValue, box, "textcolor", "textcolor")
        or cfg.defaultTextColor

    box._isLoadingDots = (raw == nil)
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

render.scheduler = 0.5

return render

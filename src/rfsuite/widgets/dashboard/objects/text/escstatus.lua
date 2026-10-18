--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
    Shows the speed controller's health in words (issue #2354): what the controller says about
    itself, read from its status word and signature by lib/esc_status.lua. The text is coloured
    by level, so a warning and an error look different from OK.

    Most parameters are those of craftname.lua. The ones specific to this box:

    novalue             : string                    -- (Optional) Text shown while no controller answers (default: "--")
    warningcolor        : color                     -- (Optional) Text colour for a WARNING (default: orange)
    errorcolor          : color                     -- (Optional) Text colour for an ERROR (default: red)
]]

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local escStatus = requireModule("lib/esc_status.lua")

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local prepareTextLayout = utils.prepareTextLayout
local paintTextLayout = utils.paintTextLayout

function render.invalidate(box)
    box._cfg = nil
    box._textLayout = nil
    box._verdictWord = nil
    box._verdictSignature = nil
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
        cfg.novalue = getParam(box, "novalue") or "--"
        cfg.warningcolor = resolveThemeColor("warningcolor", getParam(box, "warningcolor") or "orange")
        cfg.errorcolor = resolveThemeColor("errorcolor", getParam(box, "errorcolor") or "red")
        cfg.unit = nil
    end)
end

-- The verdict is worked out again only when the status word or the signature changed: this runs
-- on every wakeup, and the decode is not free.
local function verdictFor(box, signature, word)
    if box._verdictWord == word and box._verdictSignature == signature then
        return box._verdict
    end
    box._verdictWord = word
    box._verdictSignature = signature
    box._verdict = escStatus.decode(signature, word)
    return box._verdict
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local verdict = verdictFor(box, rfsuite.session.escSignature, rfsuite.session.escStatusWord)

    local displayValue
    local levelColor = cfg.textcolor
    if verdict then
        displayValue = verdict.text
        if verdict.level == escStatus.LEVEL_WARNING then
            levelColor = cfg.warningcolor
        elseif verdict.level == escStatus.LEVEL_ERROR then
            levelColor = cfg.errorcolor
        end
    else
        displayValue = cfg.novalue
    end
    box._currentLevelColor = levelColor
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
    paintTextLayout(layout, box._currentLevelColor or c.textcolor, c.titlecolor)
end

render.scheduler = 0.5

return render

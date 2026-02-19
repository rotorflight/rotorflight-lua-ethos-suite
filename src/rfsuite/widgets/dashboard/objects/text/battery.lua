--[[
  Copyright (C) 2026 Rotorflight Project
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
]]

local rfsuite = require("rfsuite")

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor

local ADJUSTMENT_BATTERY_PROFILE = 34

function render.invalidate(box) box._cfg = nil end

function render.dirty(box)
    if not rfsuite.session.telemetryState then return false end
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

local function isAdjustmentConfigured()
    if not rfsuite.session.adjustmentRanges then return false end
    for _, adj in ipairs(rfsuite.session.adjustmentRanges) do
        if adj.adjFunction == ADJUSTMENT_BATTERY_PROFILE then
            return true
        end
    end
    return false
end

local function setBatteryType(typeIndex)
    if typeIndex == rfsuite.session.activeBatteryType then return end
    local api = rfsuite.tasks.msp.api.load("BATTERY_TYPE")
    api.write({batteryType = typeIndex})
end

local function openSelectionDialog()
    if isAdjustmentConfigured() then
        form.openDialog({
            title = "@i18n(widgets.battery.title)@",
            message = "@i18n(widgets.battery.adjustment_active)@",
            buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}},
            options = TEXT_LEFT
        })
        return
    end

    local buttons = {}
    local profiles = rfsuite.session.batteryConfig and rfsuite.session.batteryConfig.profiles
    if profiles then
        for i = 0, 5 do
            local cap = profiles[i]
            if cap and cap > 0 then
                table.insert(buttons, {
                    label = tostring(cap) .. "mAh",
                    action = function()
                        setBatteryType(i)
                        return true
                    end
                })
            end
        end
    end

    if #buttons == 0 then
         form.openDialog({
            title = "@i18n(widgets.battery.title)@",
            message = "@i18n(widgets.battery.no_profiles)@",
            buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}},
            options = TEXT_LEFT
        })
        return
    end

    table.insert(buttons, {label = "@i18n(app.btn_cancel)@", action = function() return true end})

    form.openDialog({
        title = "@i18n(widgets.battery.select_title)@",
        message = nil,
        buttons = buttons,
        options = TEXT_LEFT
    })
end

local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version = theme_version
        cfg._param_version = param_version
        cfg.title = getParam(box, "title")
        if type(cfg.title) == "boolean" then
            cfg.title = cfg.title and "@i18n(widgets.battery.title)@" or nil
        end
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

        cfg.decimals = getParam(box, "decimals") or 0
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

        box._cfg = cfg
    end
    return box._cfg
end

function render.wakeup(box)
    local cfg = ensureCfg(box)

    local telemetry = rfsuite.tasks.telemetry
    local sensorVal = telemetry and telemetry.getSensor and telemetry.getSensor("battery_type")
    if sensorVal then
        rfsuite.session.activeBatteryType = math.floor(sensorVal)
    end

    local activeType = rfsuite.session.activeBatteryType
    local profiles = rfsuite.session.batteryConfig and rfsuite.session.batteryConfig.profiles
    
    local displayValue
    if activeType and profiles and profiles[activeType] then
        displayValue = tostring(profiles[activeType])
    else
        displayValue = cfg.novalue
    end

    box._currentDisplayValue = displayValue .. " mAh"
    
    if not box.onpress then box.onpress = openSelectionDialog end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, box._currentDisplayValue, c.unit, c.font, c.valuealign, c.defaultTextColor, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, c.bgcolor)
end

return render
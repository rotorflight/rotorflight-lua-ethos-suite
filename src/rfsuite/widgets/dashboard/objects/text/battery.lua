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
local lcd = lcd

local rep = string.rep
local floor = math.floor
local ceil = math.ceil
local render = {}

local utils = rfsuite.widgets.dashboard.utils
local resolveThemeColor = utils.resolveThemeColor

local progress
local progressBaseMessage
local progressMspStatusLast
local MSP_DEBUG_PLACEHOLDER = "MSP Waiting"

local function openProgressDialog(...)
    if rfsuite.utils.ethosVersionAtLeast({1, 7, 0}) and form.openWaitDialog then
        local arg1 = select(1, ...)
        if type(arg1) == "table" then
            arg1.progress = true
            return form.openWaitDialog(arg1)
        end
        local title = arg1
        local message = select(2, ...)
        return form.openWaitDialog({title = title, message = message, progress = true})
    end
    return form.openProgressDialog(...)
end

local function updateProgressMessage()
    if not progress or not progressBaseMessage then return end
    local showMsp = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.mspstatusdialog
    local mspStatus = (showMsp and rfsuite.session and rfsuite.session.mspStatusMessage) or nil
    if showMsp then
        local msg = mspStatus or MSP_DEBUG_PLACEHOLDER
        if msg ~= progressMspStatusLast then
            progress:message(msg)
            progressMspStatusLast = msg
        end
    else
        if progressMspStatusLast ~= nil then
            progress:message(progressBaseMessage)
            progressMspStatusLast = nil
        end
    end
end

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
    -- The ajustment must be read via MSP fist, but this needs a lot of time, so this check is currently disabled until
    -- we find a better way to determine if the adjustment is active without reading it first
    return false
end

local function setBatteryType(typeIndex, profileName)
    if not rfsuite.session.isConnected then return end

    if typeIndex == rfsuite.session.activeBatteryType then
        if rfsuite.session.showConfirmationDialog then
            form.openDialog({
                title = "@i18n(widgets.battery.title)@",
                message = "@i18n(widgets.battery.msg_battery_selected)@ " .. tostring(profileName),
                buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}},
                options = TEXT_LEFT
            })
        end
        return
    end

    progress = openProgressDialog("@i18n(app.msg_saving)@", "@i18n(app.msg_saving_to_fbl)@")
    progress:value(0)
    progress:closeAllowed(false)
    progressBaseMessage = "@i18n(app.msg_saving_to_fbl)@"
    progressMspStatusLast = nil

    if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.registerProgressDialog then
        rfsuite.app.ui.registerProgressDialog(progress, progressBaseMessage)
    end

    local api = rfsuite.tasks.msp.api.load("BATTERY_TYPE")

    api.setCompleteHandler(function()
        rfsuite.session.activeBatteryType = typeIndex

        if rfsuite.session.showConfirmationDialog then
            progress:value(100)
            progress:message("@i18n(widgets.battery.msg_battery_selected)@ " .. tostring(profileName))
            progress:closeAllowed(true)
            if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.clearProgressDialog then
                rfsuite.app.ui.clearProgressDialog(progress)
            end
            progress = nil
        else
            progress:value(100)
            progress:close()
            if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.clearProgressDialog then
                rfsuite.app.ui.clearProgressDialog(progress)
            end
            progress = nil
        end
    end)

    api.setErrorHandler(function()
        progress:close()
        if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.clearProgressDialog then
            rfsuite.app.ui.clearProgressDialog(progress)
        end
        progress = nil
    end)

    api.setValue("batteryType", typeIndex)
    api.write()
end

local function chooseBatteryType(widget, box, x, y)
    if isAdjustmentConfigured() then
        form.openDialog({
            title = "@i18n(widgets.battery.title)@",
            message = "@i18n(widgets.battery.adjustment_active)@",
            buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}},
            options = TEXT_LEFT
        })
        return
    end

    -- Normalize profiles to a sequential array of tables with .name and .idx
    local profilesRaw = rfsuite.session.batteryConfig and rfsuite.session.batteryConfig.profiles
    local profileList = {}
    if profilesRaw then
        -- Legacy: numeric keys 0-5, value is capacity
        for i = 0, 5 do
            local cap = profilesRaw[i]
            if cap and cap > 0 then
                table.insert(profileList, { name = tostring(cap) .. "mAh", idx = i })
            end
        end
        -- New: array of tables with .name
        if #profileList == 0 then
            for i, p in ipairs(profilesRaw) do
                if type(p) == "table" and p.name then
                    table.insert(profileList, { name = p.name, idx = i })
                end
            end
        end
    end

    if #profileList == 0 then
        form.openDialog({
            title = "@i18n(widgets.battery.title)@",
            message = "@i18n(widgets.battery.no_profiles)@",
            buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}},
            options = TEXT_LEFT
        })
        return
    end

    local buttons = {}
    local message = "@i18n(widgets.battery.msg_select_battery)@\n\n"
    for _, profile in ipairs(profileList) do
        local label = tostring(profile.idx + 1)
        message = message .. label .. " - " .. profile.name .. "\n"
    end

    for i = #profileList, 1, -1 do
        local profile = profileList[i]
        local label = tostring(profile.idx + 1)
        table.insert(buttons, {
            label = label,
            action = function()
                setBatteryType(profile.idx, profile.name)
                return true
            end
        })
    end
    
    local w, h = lcd.getWindowSize()

    form.openDialog({
        title = "@i18n(widgets.battery.select_title)@",
        message = message,
        --width = w,
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

        local getParam = utils.getParam
        
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
        rfsuite.session.activeBatteryType = floor(sensorVal)
    end

    local activeType = rfsuite.session.activeBatteryType
    local profiles = rfsuite.session.batteryConfig and rfsuite.session.batteryConfig.profiles
    
    local displayValue
    if activeType and profiles and profiles[activeType] then
        displayValue = tostring(profiles[activeType]) .. " " .. (cfg.unit or "mAh")
    elseif rfsuite.session.batteryConfig == nil then
        local maxDots = 3
        box._dotCount = ((box._dotCount or 0) + 1) % (maxDots + 1)
        displayValue = rep(".", box._dotCount)
        if displayValue == "" then displayValue = "." end
    else
        displayValue = cfg.novalue
    end

    box._isLoadingDots = type(displayValue) == "string" and displayValue:match("^%.+$") ~= nil
    box._currentDisplayValue = displayValue
    
    if not box.onpress then box.onpress = chooseBatteryType end

    if progress then
        updateProgressMessage()
    end
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cfg or {}

    local unitForPaint = box._isLoadingDots and nil or c.unit
    local textColor = box._dynamicTextColor or c.defaultTextColor
    utils.box(x, y, w, h, c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing, c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright, c.titlepaddingtop, c.titlepaddingbottom, box._currentDisplayValue, unitForPaint, c.font, c.valuealign, textColor, c.valuepadding, c.valuepaddingleft, c.valuepaddingright, c.valuepaddingtop, c.valuepaddingbottom, c.bgcolor)
end

render.chooseBatteryType = chooseBatteryType    

return render
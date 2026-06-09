--[[
  Toolbar action: choose battery type
]] --

local rfsuite = require("rfsuite")
local M = {}

local progress
local progressBaseMessage
local progressMspStatusLast
local MSP_DEBUG_PLACEHOLDER = "MSP Waiting"
local BATTERY_PROFILE_API = "BATTERY_PROFILE"
local getDashboardUtils
local DIALOG_WIDTH_NUMERATOR = 9
local DIALOG_WIDTH_DENOMINATOR = 10
local BUTTON_LABEL_PADDING = {
    " %s ",
    "  %s  ",
    "   %s   ",
    "    %s    ",
    "     %s     ",
    "      %s      ",
    "       %s       "
}

local function getBatteryDialogWidth()
    local screenW = lcd.getWindowSize()
    if not screenW or screenW <= 0 then return nil end
    return math.floor((screenW * DIALOG_WIDTH_NUMERATOR) / DIALOG_WIDTH_DENOMINATOR)
end

local function getBatteryButtonPaddingIndex(matchedW, dialogWidth, buttonCount)
    if matchedW == 800 or matchedW == 784 then
        if buttonCount <= 3 then return 7 end
        if buttonCount <= 4 then return 6 end
        return 5
    elseif matchedW == 640 or matchedW == 630 then
        if buttonCount <= 3 then return 7 end
        if buttonCount <= 4 then return 5 end
        if buttonCount <= 5 then return 4 end
        return 3
    elseif matchedW == 480 or matchedW == 472 then
        if buttonCount <= 2 then return 7 end
        if buttonCount <= 3 then return 5 end
        if buttonCount <= 4 then return 3 end
        return 1
    end

    local buttonArea = math.floor(dialogWidth / buttonCount)
    if buttonCount <= 3 or buttonArea >= 180 then return 7 end
    if buttonArea >= 145 then return 5 end
    if buttonArea >= 115 then return 3 end
    return 1
end

local function getBatteryButtonLabel(label, dialogWidth, buttonCount)
    if not dialogWidth or not buttonCount or buttonCount <= 0 then
        return tostring(label)
    end

    local screenW, screenH = lcd.getWindowSize()
    local utils = getDashboardUtils and getDashboardUtils() or nil
    local matchedW = utils and utils.matchSupportedResolution and utils.matchSupportedResolution(screenW, screenH) or nil
    local paddingIndex = getBatteryButtonPaddingIndex(matchedW, dialogWidth, buttonCount)

    return string.format(BUTTON_LABEL_PADDING[paddingIndex], tostring(label))
end

function getDashboardUtils()
    local widgets = rfsuite and rfsuite.widgets
    local dashboard = widgets and widgets.dashboard
    return dashboard and dashboard.utils or nil
end

local function registerProgressDialog(handle, baseMessage)
    local utils = getDashboardUtils()
    if utils and utils.registerProgressDialog then
        utils.registerProgressDialog(handle, baseMessage)
    end
end

local function clearProgressDialog(handle)
    local utils = getDashboardUtils()
    if utils and utils.clearProgressDialog then
        utils.clearProgressDialog(handle)
    end
end

local function clearApiEntry(apiName)
    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if api and type(api.clearEntry) == "function" then
        api.clearEntry(apiName)
    end
end

local function closeAndClearProgress()
    if not progress then return end
    local handle = progress
    if handle.close then
        pcall(handle.close, handle)
    end
    clearProgressDialog(handle)
    progress = nil
    progressBaseMessage = nil
    progressMspStatusLast = nil
end

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

local function isAdjustmentConfigured()
    -- The ajustment must be read via MSP fist, but this needs a lot of time, so this check is currently disabled until
    -- we find a better way to determine if the adjustment is active without reading it first
    return false
end

local function buildBatteryProfileList()
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
    return profileList
end

function M.hasSelectableBatteryProfiles()
    return #buildBatteryProfileList() > 1
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

    closeAndClearProgress()

    progress = openProgressDialog("@i18n(app.msg_saving)@", "@i18n(app.msg_saving_to_fbl)@")
    if not progress then return end
    progress:value(0)
    progress:closeAllowed(false)
    progressBaseMessage = "@i18n(app.msg_saving_to_fbl)@"
    progressMspStatusLast = nil

    registerProgressDialog(progress, progressBaseMessage)

    local api = rfsuite.tasks.msp.api.load(BATTERY_PROFILE_API)

    api.setCompleteHandler(function()
        rfsuite.session.activeBatteryType = typeIndex

        if rfsuite.session.showConfirmationDialog then
            if progress then
                progress:value(100)
                progress:message("@i18n(widgets.battery.msg_battery_selected)@ " .. tostring(profileName))
                progress:closeAllowed(true)
                clearProgressDialog(progress)
                progress = nil
                progressBaseMessage = nil
                progressMspStatusLast = nil
            end
        else
            if progress then
                progress:value(100)
            end
            closeAndClearProgress()
        end
        clearApiEntry(BATTERY_PROFILE_API)
    end)

    api.setErrorHandler(function()
        closeAndClearProgress()
        clearApiEntry(BATTERY_PROFILE_API)
    end)

    api.setValue("batteryProfile", typeIndex)
    api.write()
end

function M.chooseBatteryType()
    if isAdjustmentConfigured() then
        form.openDialog({
            title = "@i18n(widgets.battery.title)@",
            message = "@i18n(widgets.battery.adjustment_active)@",
            buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}},
            options = TEXT_LEFT
        })
        return
    end

    local profileList = buildBatteryProfileList()

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
    local dialogWidth = getBatteryDialogWidth()
    local buttonCount = #profileList
    local message = "@i18n(widgets.battery.msg_select_battery)@\n\n"
    for _, profile in ipairs(profileList) do
        local label = tostring(profile.idx + 1)
        message = message .. label .. " - " .. profile.name .. "\n"
    end

    for i = buttonCount, 1, -1 do
        local profile = profileList[i]
        local label = tostring(profile.idx + 1)
        table.insert(buttons, {
            label = getBatteryButtonLabel(label, dialogWidth, buttonCount),
            action = function()
                setBatteryType(profile.idx, profile.name)
                return true
            end
        })
    end

    form.openDialog({
        title = "@i18n(widgets.battery.select_title)@",
        message = message,
        width = dialogWidth,
        buttons = buttons,
        options = TEXT_LEFT
    })
end

function M.wakeup()
    if progress then
        updateProgressMessage()
    end
end

function M.reset()
    clearApiEntry(BATTERY_PROFILE_API)
    closeAndClearProgress()
end

return M

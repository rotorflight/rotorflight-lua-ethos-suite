--[[
  Toolbar action: choose battery type
]] --

local rfsuite = require("rfsuite")
local M = {}

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

    local api = rfsuite.tasks.msp.api.load("BATTERY_PROFILE")

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

    form.openDialog({
        title = "@i18n(widgets.battery.select_title)@",
        message = message,
        --width = w,
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
    if progress then
        progress:close()
    end
    progress = nil
    progressBaseMessage = nil
    progressMspStatusLast = nil
end

return M

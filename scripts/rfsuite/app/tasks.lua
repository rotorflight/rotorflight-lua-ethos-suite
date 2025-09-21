--[[

 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/

]] --
local utils = rfsuite.utils
local log  = utils.log

-- tune the tasks Accumulator
local nextUiTask      = 1   -- Index of the next UI task to run
local taskAccumulator = 0    -- Accumulator for fractional tasks
local uiTaskPercent   = 100  -- Percentage of tasks to run per wakeup (1-100)

-- 1. Exit App
local function exitApp()
    local app = rfsuite.app
    if app.triggers.exitAPP then
        app.triggers.exitAPP = false
        form.invalidate()
        system.exit()
    end
end

-- 2. Profile / Rate Change Detection
local function profileRateChangeDetection()
    local app = rfsuite.app
    if not (
        app.Page and (
            app.Page.refreshOnProfileChange or
            app.Page.refreshOnRateChange or
            app.Page.refreshFullOnProfileChange or
            app.Page.refreshFullOnRateChange
        ) and
        app.uiState == app.uiStatus.pages and
        not app.triggers.isSaving and
        not app.dialogs.saveDisplay and
        not app.dialogs.progressDisplay and
        rfsuite.tasks.msp.mspQueue:isProcessed()
    ) then
        return
    end

    local now = os.clock()
    local interval = (
        rfsuite.tasks.telemetry.getSensorSource("pid_profile") and
        rfsuite.tasks.telemetry.getSensorSource("rate_profile")
    ) and 0.1 or 1.5

    if (now - (app.profileCheckScheduler or 0)) >= interval then
        app.profileCheckScheduler = now
        app.utils.getCurrentProfile()
        if rfsuite.session.activeProfileLast and app.Page.refreshOnProfileChange and
            rfsuite.session.activeProfile ~= rfsuite.session.activeProfileLast then
            app.triggers.reload = not app.Page.refreshFullOnProfileChange
            app.triggers.reloadFull = app.Page.refreshFullOnProfileChange
            return
        end
        if rfsuite.session.activeRateProfileLast and app.Page.refreshOnRateChange and
            rfsuite.session.activeRateProfile ~= rfsuite.session.activeRateProfileLast then
            app.triggers.reload = not app.Page.refreshFullOnRateChange
            app.triggers.reloadFull = app.Page.refreshFullOnRateChange
            return
        end
    end
end

-- 3. Main Menu Icon Enable/Disable
local function mainMenuIconEnableDisable()
    local app = rfsuite.app
    if app.uiState ~= app.uiStatus.mainMenu and app.uiState ~= app.uiStatus.pages then return end

    if rfsuite.session.mspBusy then return end

    if app.uiState == app.uiStatus.mainMenu then
        local apiV = tostring(rfsuite.session.apiVersion)
        if not rfsuite.tasks.active() then
            for i, v in pairs(app.formFieldsBGTask) do 
                if v == false and app.formFields[i] then
                    app.formFields[i]:enable(false)
                elseif v == false then
                    log("Main Menu Icon " .. i .. " not found in formFields", "info")
                end
            end
        elseif not rfsuite.session.isConnected then
            for i, v in pairs(app.formFieldsOffline) do
                if v == false and app.formFields[i] then
                    app.formFields[i]:enable(false)
                elseif v == false then
                    log("Main Menu Icon " .. i .. " not found in formFields", "info")
                end
            end
        elseif rfsuite.session.apiVersion and rfsuite.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiV) then
            app.offlineMode = false
            for i in pairs(app.formFieldsOffline) do 
                if app.formFields[i] then
                    app.formFields[i]:enable(true)
                else
                    log("Main Menu Icon " .. i .. " not found in formFields", "info")
                end
            end
        end
    elseif not app.isOfflinePage then
        if not rfsuite.session.isConnected then app.ui.openMainMenu() end
    end
end

-- 4. No-Link Progress & Message Update
local function noLinkProgressUpdate()
    local app = rfsuite.app
    if rfsuite.session.telemetryState ~= 1 or not app.triggers.disableRssiTimeout then
        if not app.dialogs.nolinkDisplay and not app.triggers.wasConnected then
            if app.dialogs.progressDisplay and app.dialogs.progress then app.dialogs.progress:close() end
            if app.dialogs.saveDisplay and app.dialogs.save then app.dialogs.save:close() end
            app.ui.progressDisplay("@i18n(app.msg_connecting)@", "@i18n(app.msg_connecting_to_fbl)@", true)
            app.dialogs.nolinkDisplay = true
        end
    end
end

-- 5. Trigger Save Dialogs
local function triggerSaveDialogs()
    local app = rfsuite.app
    if app.triggers.triggerSave then
        app.triggers.triggerSave = false
        form.openDialog({
            width   = nil,
            title   = "@i18n(app.msg_save_settings)@",
            message = (app.Page.extraMsgOnSave and "@i18n(app.msg_save_current_page)@".."\n\n"..app.Page.extraMsgOnSave or "@i18n(app.msg_save_current_page)@"),
            buttons = {
                { label="@i18n(app.btn_ok)@", action=function()
                        app.PageTmp = app.Page
                        app.triggers.isSaving = true
                        app.ui.saveSettings()
                        return true
                    end
                },
                { label="@i18n(app.btn_cancel)@", action=function() return true end }
            },
            wakeup = function() end,
            paint  = function() end,
            options= TEXT_LEFT
        })
    elseif app.triggers.triggerSaveNoProgress then
        app.triggers.triggerSaveNoProgress = false
        app.PageTmp = app.Page
        app.ui.saveSettings()
    end

    if app.triggers.isSaving then
        if app.pageState >= app.pageStatus.saving and not app.dialogs.saveDisplay then
            app.triggers.saveFailed         = false
            app.dialogs.saveProgressCounter = 0
            app.ui.progressDisplaySave()
            rfsuite.tasks.msp.mspQueue.retryCount = 0
        end
    end
end

-- 6. Armed-Save Warning
local function armedSaveWarning()
    local app = rfsuite.app
    if not app.triggers.showSaveArmedWarning or app.triggers.closeSave then return end
    if not app.dialogs.progressDisplay then
        app.audio.playSaveArmed = true
        app.dialogs.progressCounter = 0
        local key =
            (rfsuite.utils.apiVersionCompare(">=", "12.08")
                and "@i18n(app.msg_please_disarm_to_save_warning)@"
                or "@i18n(app.msg_please_disarm_to_save)@")

        app.ui.progressDisplay("@i18n(app.msg_save_not_commited)@", key)
    end
    if app.dialogs.progressCounter >= 100 then
        app.triggers.showSaveArmedWarning = false
        app.dialogs.progressDisplay = false
        app.dialogs.progress:close()
    end
end

-- 7. Trigger Reload Dialogs
local function triggerReloadDialogs()
    local app = rfsuite.app
    if app.triggers.triggerReloadNoPrompt then
        app.triggers.triggerReloadNoPrompt = false
        app.triggers.reload = true
        return
    end
    if app.triggers.triggerReload then
        app.triggers.triggerReload = false
        form.openDialog({
            title   = "@i18n(reload)@",
            message = "@i18n(app.msg_reload_settings)@",
            buttons = {
                { label="@i18n(app.btn_ok)@",     action=function() app.triggers.reload = true;      return true end },
                { label="@i18n(app.btn_cancel)@", action=function() return true end }
            },
            options = TEXT_LEFT
        })
    elseif app.triggers.triggerReloadFull then
        app.triggers.triggerReloadFull = false
        form.openDialog({
            title   = "@i18n(reload)@",
            message = "@i18n(app.msg_reload_settings)@",
            buttons = {
                { label="@i18n(app.btn_ok)@",     action=function() app.triggers.reloadFull = true;  return true end },
                { label="@i18n(app.btn_cancel)@", action=function() return true end }
            },
            options = TEXT_LEFT
        })
    end
end

-- 8. Telemetry & Page State Updates
local function telemetryAndPageStateUpdates()
    local app = rfsuite.app
    if app.uiState == app.uiStatus.mainMenu then
        app.utils.invalidatePages()
    elseif app.triggers.isReady and (rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue:isProcessed())
        and app.Page and app.Page.values then
        app.triggers.isReady = false
        app.triggers.closeProgressLoader = true
    end
end

-- 9. Perform Reload Actions
local function performReloadActions()
    local app = rfsuite.app
    if app.triggers.reload then
        app.triggers.reload = false
        app.ui.progressDisplay()
        app.ui.openPageRefresh(app.lastIdx, app.lastTitle, app.lastScript)
    end
    if app.triggers.reloadFull then
        app.triggers.reloadFull = false
        app.ui.progressDisplay()
        app.ui.openPage(app.lastIdx, app.lastTitle, app.lastScript)
    end
end

-- 10. Play Pending Audio Alerts
local function playPendingAudioAlerts()
    local app = rfsuite.app
    if app.audio then
        local a = app.audio
        if a.playEraseFlash          then utils.playFile("app","eraseflash.wav");        a.playEraseFlash = false end
        if a.playTimeout             then utils.playFile("app","timeout.wav");           a.playTimeout = false end
        if a.playEscPowerCycle       then utils.playFile("app","powercycleesc.wav");     a.playEscPowerCycle = false end
        if a.playServoOverideEnable  then utils.playFile("app","soverideen.wav");        a.playServoOverideEnable = false end
        if a.playServoOverideDisable then utils.playFile("app","soveridedis.wav");       a.playServoOverideDisable = false end
        if a.playMixerOverideEnable  then utils.playFile("app","moverideen.wav");        a.playMixerOverideEnable = false end
        if a.playMixerOverideDisable then utils.playFile("app","moveridedis.wav");       a.playMixerOverideDisable = false end
        if a.playSaveArmed           then utils.playFileCommon("warn.wav");              a.playSaveArmed = false end
        if a.playBufferWarn          then utils.playFileCommon("warn.wav");              a.playBufferWarn = false end
    end
end

-- 11. Wakeup UI Tasks
local function wakeupUITasks()
    local app = rfsuite.app
    if app.Page and app.uiState == app.uiStatus.pages and app.Page.wakeup then
        app.Page.wakeup(app.Page)
    end
end

-- 12. Request data
local function requestPage()
    local app = rfsuite.app
    -- Ensure page is loaded if needed
    if app.uiState == app.uiStatus.pages then
        if not app.Page and app.PageTmp then app.Page = app.PageTmp end
        if app.ui and app.Page and app.Page.apidata and app.pageState == app.pageStatus.display and not app.triggers.isReady then
        app.ui.requestPage()
        end
    end
end

local tasks = {}

-- proper array of tasks
tasks.list = {
    exitApp,
    profileRateChangeDetection,
    noLinkProgressUpdate,
    triggerSaveDialogs,
    armedSaveWarning,
    triggerReloadDialogs,
    telemetryAndPageStateUpdates,
    performReloadActions,
    playPendingAudioAlerts,
    wakeupUITasks,
    mainMenuIconEnableDisable,
    requestPage,    
}

-- wakeup function uses the local tasks
function tasks.wakeup()
    -- Run a portion of the tasks each wakeup to keep the UI responsive
    local list  = tasks.list
    local total = #list
    if total == 0 then return end

    local perTick = (total * uiTaskPercent) / 100
    if perTick < 1 then perTick = 1 end

    taskAccumulator = taskAccumulator + perTick

    if nextUiTask > total then
        nextUiTask = 1
    end

    while taskAccumulator >= 1 do
        list[nextUiTask]()
        nextUiTask = (nextUiTask % total) + 1
        taskAccumulator = taskAccumulator - 1
    end

end

return tasks

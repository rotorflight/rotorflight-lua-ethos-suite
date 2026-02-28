--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local system = system

local utils = rfsuite.utils
local log = utils.log

local nextUiTask = 1
local taskAccumulator = 0
local uiTaskPercent = 100
local lastMainMenuBuildApiVersion = nil
local MAIN_MENU_ENABLE_INTERVAL = 0.05
local mainMenuLastEnableState = {}
local mainMenuLastModeTag = nil
local mainMenuLastMenuId = nil
local mainMenuLastFocusEpoch = nil
local mainMenuLastPassAt = 0
local mainMenuWasActive = false
local mainMenuFocusModeTag = nil
local mainMenuFocusMenuId = nil
local mainMenuFocusIndex = nil
local mainMenuFocusEpoch = nil
local mainMenuFocusApplied = false

local function resetMainMenuFocusLatch()
    mainMenuFocusModeTag = nil
    mainMenuFocusMenuId = nil
    mainMenuFocusIndex = nil
    mainMenuFocusEpoch = nil
    mainMenuFocusApplied = false
end

local function desiredFocusIndex(app)
    local lm = (app.uiState == app.uiStatus.mainMenu) and "mainmenu" or (app.lastMenu or "mainmenu")
    return rfsuite.preferences.menulastselected[lm] or rfsuite.preferences.menulastselected["mainmenu"]
end

local function focusOnce(app, modeTag)
    local idx = desiredFocusIndex(app)
    if not idx or not app.formFields then return end
    local field = app.formFields[idx]
    if not (field and field.focus) then return end

    local lm = (app.uiState == app.uiStatus.mainMenu) and "mainmenu" or (app.lastMenu or "mainmenu")
    local focusEpoch = app._menuFocusEpoch or 0
    if mainMenuFocusModeTag ~= modeTag or mainMenuFocusMenuId ~= lm or mainMenuFocusIndex ~= idx or mainMenuFocusEpoch ~= focusEpoch then
        mainMenuFocusModeTag = modeTag
        mainMenuFocusMenuId = lm
        mainMenuFocusIndex = idx
        mainMenuFocusEpoch = focusEpoch
        mainMenuFocusApplied = false
    end

    if not mainMenuFocusApplied then
        mainMenuFocusApplied = true
        field:focus()
    end
end

local function setMainMenuFieldEnabled(app, index, shouldEnable)
    local fields = app.formFields
    local field = fields and fields[index]
    if field and field.enable then
        if mainMenuLastEnableState[index] ~= shouldEnable then
            field:enable(shouldEnable)
            mainMenuLastEnableState[index] = shouldEnable
        end
        return true
    end
    mainMenuLastEnableState[index] = nil
    return false
end

local function exitApp()
    local app = rfsuite.app
    if app.triggers.exitAPP then
        app.triggers.exitAPP = false
        form.invalidate()
        system.exit()
    end
end

local function profileRateChangeDetection()
    local app = rfsuite.app
    if not (app.Page and (app.Page.refreshOnProfileChange or app.Page.refreshOnRateChange or app.Page.refreshFullOnProfileChange or app.Page.refreshFullOnRateChange) and app.uiState == app.uiStatus.pages and not app.triggers.isSaving and not app.dialogs.saveDisplay and not app.dialogs.progressDisplay and rfsuite.tasks.msp.mspQueue:isProcessed()) then return end

    local now = os.clock()
    local interval = (rfsuite.tasks.telemetry.getSensorSource("pid_profile") and rfsuite.tasks.telemetry.getSensorSource("rate_profile")) and 0.1 or 1.5

    if (now - (app.profileCheckScheduler or 0)) >= interval then
        app.profileCheckScheduler = now

        app.utils.getCurrentProfile()
        if rfsuite.session.activeProfileLast and app.Page.refreshOnProfileChange and rfsuite.session.activeProfile ~= rfsuite.session.activeProfileLast then
            app.triggers.reload = not app.Page.refreshFullOnProfileChange
            app.triggers.reloadFull = app.Page.refreshFullOnProfileChange
        end

        app.utils.getCurrentRateProfile()
        if rfsuite.session.activeRateProfileLast and app.Page.refreshOnRateChange and rfsuite.session.activeRateProfile ~= rfsuite.session.activeRateProfileLast then
            app.triggers.reload = not app.Page.refreshFullOnRateChange
            app.triggers.reloadFull = app.Page.refreshFullOnRateChange
        end
    end
end

local function mainMenuIconEnableDisable()
    local app = rfsuite.app
    if app.uiState ~= app.uiStatus.mainMenu and app.uiState ~= app.uiStatus.pages then return end

    if app.uiState == app.uiStatus.mainMenu then
        mainMenuWasActive = true
    elseif mainMenuWasActive then
        mainMenuWasActive = false
        mainMenuLastEnableState = {}
        mainMenuLastModeTag = nil
        mainMenuLastMenuId = nil
        mainMenuLastFocusEpoch = nil
        mainMenuLastPassAt = 0
        resetMainMenuFocusLatch()
    end

    local currentApiVersion = rfsuite.session and rfsuite.session.apiVersion
    if currentApiVersion == nil then
        lastMainMenuBuildApiVersion = nil
    elseif currentApiVersion ~= lastMainMenuBuildApiVersion then
        lastMainMenuBuildApiVersion = currentApiVersion
        app.MainMenu = assert(loadfile("app/modules/init.lua"))()
    end

    if app.uiState == app.uiStatus.mainMenu then
        local formFieldsOffline = app.formFieldsOffline
        if type(formFieldsOffline) ~= "table" then return end

        local apiV = tostring(rfsuite.session.apiVersion)
        local connected = (rfsuite.session and rfsuite.session.isConnected) == true
        local postConnectComplete = (rfsuite.session and rfsuite.session.postConnectComplete) == true
        local supportedApi = rfsuite.session.apiVersion and rfsuite.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiV)
        local modeTag
        if not connected then
            modeTag = "offline"
        elseif not postConnectComplete then
            modeTag = "postconnect"
        elseif supportedApi then
            modeTag = "online"
        else
            modeTag = "online-fallback"
        end

        local focusEpoch = tostring(app._menuFocusEpoch or 0)
        if mainMenuLastFocusEpoch ~= focusEpoch then
            mainMenuLastFocusEpoch = focusEpoch
            mainMenuLastEnableState = {}
            mainMenuLastPassAt = 0
            resetMainMenuFocusLatch()
        end

        local menuId = app.lastMenu or "mainmenu"
        if mainMenuLastModeTag ~= modeTag or mainMenuLastMenuId ~= menuId then
            mainMenuLastModeTag = modeTag
            mainMenuLastMenuId = menuId
            mainMenuLastEnableState = {}
            mainMenuLastPassAt = 0
            resetMainMenuFocusLatch()
        end

        local now = os.clock()
        if (now - mainMenuLastPassAt) < MAIN_MENU_ENABLE_INTERVAL then return end
        mainMenuLastPassAt = now

        -- Offline: only allow items explicitly marked offline.
        if not connected then
            for i, v in pairs(formFieldsOffline) do
                if setMainMenuFieldEnabled(app, i, v == true) then
                elseif v == false then
                    log("Main Menu Icon " .. i .. " not found in formFields", "debug")
                end
            end
            focusOnce(app, "offline")

        -- Connected but still in post-connect: still honor offline-only accessibility.
        elseif not postConnectComplete then
            for i, v in pairs(formFieldsOffline) do
                if setMainMenuFieldEnabled(app, i, v == true) then
                elseif v == false then
                    log("Main Menu Icon " .. i .. " not found in formFields", "debug")
                end
            end
            focusOnce(app, "postconnect")

        -- Fully connected + supported API: enable everything.
        elseif supportedApi then
            app.offlineMode = false
            for i in pairs(formFieldsOffline) do
                if setMainMenuFieldEnabled(app, i, true) then
                else
                    log("Main Menu Icon " .. i .. " not found in formFields", "debug")
                end
            end
            focusOnce(app, "online")

        else
            -- Fallback: if we are connected and post-connect complete, never leave icons latched disabled.
            -- This avoids a rare dead-end where menu icons stay disabled until restart.
            app.offlineMode = false
            for i in pairs(formFieldsOffline) do
                if setMainMenuFieldEnabled(app, i, true) then
                else
                    log("Main Menu Icon " .. i .. " not found in formFields", "debug")
                end
            end
            focusOnce(app, "online-fallback")
        end

    elseif not app.isOfflinePage and not app.triggers.escPowerCycleLoader then
        if not rfsuite.session.postConnectComplete then
            log("Entering Offline Mode", "info")
            app.ui.openMainMenu()
        end
    end
end

local function triggerSaveDialogs()
    local app = rfsuite.app
    if app.triggers.triggerSave then
        app.triggers.triggerSave = false
        local page = app.Page
        if not page then
            log("triggerSave ignored: no active page", "debug")
            app.triggers.isSaving = false
            return
        end

        local saveMessage = "@i18n(app.msg_save_current_page)@"
        if page.extraMsgOnSave then
            saveMessage = saveMessage .. "\n\n" .. page.extraMsgOnSave
        end

        if rfsuite.preferences.general.save_confirm == true or rfsuite.preferences.general.save_confirm == "true" then
            form.openDialog({
                width = nil,
                title = "@i18n(app.msg_save_settings)@",
                message = saveMessage,
                buttons = {
                    {
                        label = "@i18n(app.btn_ok)@",
                        action = function()
                            if not app.Page and app.uiState == app.uiStatus.pages and page then
                                app.Page = page
                            end
                            if not app.Page then
                                log("Save confirm ignored: page closed before confirmation", "debug")
                                app.triggers.isSaving = false
                                return true
                            end
                            app.triggers.isSaving = true
                            app.ui.saveSettings(page)
                            return true
                        end
                    }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
                },
                wakeup = function() end,
                paint = function() end,
                options = TEXT_LEFT
            })
        else    
                app.triggers.isSaving = true
                app.ui.saveSettings(page)            
        end    
    elseif app.triggers.triggerSaveNoProgress then
        app.triggers.triggerSaveNoProgress = false
        if not app.Page then
            log("triggerSaveNoProgress ignored: no active page", "debug")
            app.triggers.isSaving = false
            return
        end
        app.ui.saveSettings(app.Page)
    end

    if app.triggers.isSaving then
        if app.pageState >= app.pageStatus.saving and not app.dialogs.saveDisplay then
            app.triggers.saveFailed = false
            app.dialogs.saveProgressCounter = 0
            app.ui.progressDisplaySave()
            rfsuite.tasks.msp.mspQueue.retryCount = 0
        end
    end
end

local function armedSaveWarning()
    local app = rfsuite.app
    if not app.triggers.showSaveArmedWarning or app.triggers.closeSave then return end
    local pref = rfsuite.preferences.general.save_armed_warning
    local showDialog = not (pref == false or pref == "false")
    if not showDialog then
        if app.dialogs.progressDisplay then
            app.dialogs.progressDisplay = false
            app.dialogs.progress:close()
        end
        if not app.dialogs.progressDisplay then
            app.audio.playSaveArmed = true
        end
        app.triggers.showSaveArmedWarning = false
        return
    end
    if not app.dialogs.progressDisplay then
        app.audio.playSaveArmed = true
        app.dialogs.progressCounter = 0
        local key = (rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) and "@i18n(app.msg_please_disarm_to_save_warning)@" or "@i18n(app.msg_please_disarm_to_save)@")

        app.ui.progressDisplay("@i18n(app.msg_save_not_commited)@", key)
    end
    if app.dialogs.progressCounter >= 100 then
        app.triggers.showSaveArmedWarning = false
        app.dialogs.progressDisplay = false
        app.dialogs.progress:close()
    end
end

local function triggerReloadDialogs()
    local app = rfsuite.app
    if app.triggers.triggerReloadNoPrompt  then
        app.triggers.triggerReloadNoPrompt = false
        app.triggers.reload = true
        return
    end
    if app.triggers.triggerReload then
        app.triggers.triggerReload = false
        if rfsuite.preferences.general.reload_confirm == false or rfsuite.preferences.general.reload_confirm == "false" then
            app.triggers.reload = true;
            return
        else 
            form.openDialog({
                title = "@i18n(reload)@",
                message = "@i18n(app.msg_reload_settings)@",
                buttons = {
                    {
                        label = "@i18n(app.btn_ok)@",
                        action = function()
                            app.triggers.reload = true;
                            return true
                        end
                    }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
                },
                options = TEXT_LEFT
            })
        end    
    elseif app.triggers.triggerReloadFull then
        app.triggers.triggerReloadFull = false        
        if rfsuite.preferences.general.reload_confirm == false or rfsuite.preferences.general.reload_confirm == "false" then
            app.triggers.reloadFull = true;
            return
        else         
            form.openDialog({
                title = "@i18n(reload)@",
                message = "@i18n(app.msg_reload_settings)@",
                buttons = {
                    {
                        label = "@i18n(app.btn_ok)@",
                        action = function()
                            app.triggers.reloadFull = true;
                            return true
                        end
                    }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
                },
                options = TEXT_LEFT
            })
        end    
    end
end

local function telemetryAndPageStateUpdates()
    local app = rfsuite.app
    if app.uiState == app.uiStatus.mainMenu then
        app.utils.invalidatePages()
    elseif app.triggers.isReady and (rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue:isProcessed()) and app.Page and app.Page.values then
        app.triggers.isReady = false
        app.triggers.closeProgressLoader = true
    end
end

local function performReloadActions()

    if rfsuite.session.mspBusy then return end

    local app = rfsuite.app
    if app.triggers.reload then
        app.triggers.reload = false
        app.ui.progressDisplay()
        app.ui.openPageRefresh({idx = app.lastIdx, title = app.lastTitle, script = app.lastScript})
    end
    if app.triggers.reloadFull then
        app.triggers.reloadFull = false
        app.ui.progressDisplay()
        app.ui.openPage({idx = app.lastIdx, title = app.lastTitle, script = app.lastScript})
    end
end

local function playPendingAudioAlerts()
    local app = rfsuite.app
    if app.audio then
        local a = app.audio
        if a.playEraseFlash then
            utils.playFile("app", "eraseflash.wav");
            a.playEraseFlash = false
        end
        if a.playTimeout then
            utils.playFile("app", "timeout.wav");
            a.playTimeout = false
        end
        if a.playEscPowerCycle then
            utils.playFile("app", "powercycleesc.wav");
            a.playEscPowerCycle = false
        end
        if a.playServoOverideEnable then
            utils.playFile("app", "soverideen.wav");
            a.playServoOverideEnable = false
        end
        if a.playServoOverideDisable then
            utils.playFile("app", "soveridedis.wav");
            a.playServoOverideDisable = false
        end
        if a.playMixerOverideEnable then
            utils.playFile("app", "moverideen.wav");
            a.playMixerOverideEnable = false
        end
        if a.playMixerOverideDisable then
            utils.playFile("app", "moveridedis.wav");
            a.playMixerOverideDisable = false
        end
        if a.playMixerPassthroughOverideEnable then
            utils.playFile("app", "mpoverideen.wav");
            a.playMixerPassthroughOverideEnable = false
        end
        if a.playMixerPassthroughOverideDisable then
            utils.playFile("app", "mpoveridedis.wav");
            a.playMixerPassthroughOverideDisable = false
        end
        if a.playSaveArmed then
            utils.playFileCommon("warn.wav");
            a.playSaveArmed = false
        end
        if a.playBufferWarn then
            utils.playFileCommon("warn.wav");
            a.playBufferWarn = false
        end
    end
end

local function wakeupUITasks()
    local app = rfsuite.app
    if app.Page and app.uiState == app.uiStatus.pages and app.Page.wakeup then app.Page.wakeup(app.Page) end
end

local function requestPage()
    local app = rfsuite.app

    if app.uiState == app.uiStatus.pages then
        if app.ui and app.Page and app.Page.apidata and app.pageState == app.pageStatus.display and not app.triggers.isReady then app.ui.requestPage() end
    end
end

local tasks = {}

tasks.list = {exitApp, profileRateChangeDetection,  triggerSaveDialogs, armedSaveWarning, triggerReloadDialogs, telemetryAndPageStateUpdates, performReloadActions, playPendingAudioAlerts, wakeupUITasks, mainMenuIconEnableDisable, requestPage}

function tasks.wakeup()

    local list = tasks.list
    local total = #list
    if total == 0 then return end

    local perTick = (total * uiTaskPercent) / 100
    if perTick < 1 then perTick = 1 end

    taskAccumulator = taskAccumulator + perTick

    if nextUiTask > total then nextUiTask = 1 end

    while taskAccumulator >= 1 do
        list[nextUiTask]()
        nextUiTask = (nextUiTask % total) + 1
        taskAccumulator = taskAccumulator - 1
    end

end

function tasks.reset()
    nextUiTask = 1
    taskAccumulator = 0
    lastMainMenuBuildApiVersion = nil
    mainMenuLastEnableState = {}
    mainMenuLastModeTag = nil
    mainMenuLastMenuId = nil
    mainMenuLastFocusEpoch = nil
    mainMenuLastPassAt = 0
    mainMenuWasActive = false
    resetMainMenuFocusLatch()
end

return tasks

--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = rfsuite.utils
local log = utils.log

local nextUiTask = 1
local taskAccumulator = 0
local uiTaskPercent = 100

local mspCallsComplete = false


local function mspCalls()

    if (rfsuite.session.governorMode == nil ) then
        local API = rfsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local governorMode = API.readValue("gov_mode")
            if governorMode then 
                rfsuite.utils.log("Governor mode: " .. governorMode, "info") 
            end
            rfsuite.session.governorMode = governorMode
        end)
        API.setUUID("e2a1c5b3-7f4a-4c8e-9d2a-3b6f8e2d9a1c")
        API.read()
    elseif (rfsuite.session.servoCount == nil) then
        local API = rfsuite.tasks.msp.api.load("STATUS")
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.servoCount = API.readValue("servo_count")
            if rfsuite.session.servoCount then 
                rfsuite.utils.log("Servo count: " .. rfsuite.session.servoCount, "info") 
            end    
        end)
        API.setUUID("d7e0db36-ca3c-4e19-9a64-40e76c78329c")
        API.read()

    elseif (rfsuite.session.servoOverride == nil) then
        local API = rfsuite.tasks.msp.api.load("SERVO_OVERRIDE")
        API.setCompleteHandler(function(self, buf)
            for i, v in pairs(API.data().parsed) do
                if v == 0 then
                    rfsuite.utils.log("Servo override: true (" .. i .. ")", "info")
                    rfsuite.session.servoOverride = true
                end
            end
            if rfsuite.session.servoOverride == nil then rfsuite.session.servoOverride = false end
        end)
        API.setUUID("b9617ec3-5e01-468e-a7d5-ec7460d277ef")
        API.read()
    elseif (rfsuite.session.tailMode == nil or rfsuite.session.swashMode == nil)  then
        local API = rfsuite.tasks.msp.api.load("MIXER_CONFIG")
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.tailMode = API.readValue("tail_rotor_mode")
            rfsuite.session.swashMode = API.readValue("swash_type")
            if rfsuite.session.tailMode and rfsuite.session.swashMode then
                rfsuite.utils.log("Tail mode: " .. rfsuite.session.tailMode, "info")
                rfsuite.utils.log("Swash mode: " .. rfsuite.session.swashMode, "info")
            end
        end)
        API.setUUID("fbccd634-c9b7-4b48-8c02-08ef560dc515")
        API.read()
    elseif (rfsuite.session.governorMode ~= nil and rfsuite.session.servoCount ~= nil and rfsuite.session.servoOverride ~= nil and rfsuite.session.tailMode ~= nil and rfsuite.session.swashMode ~= nil) then
        -- All MSP calls complete
        mspCallsComplete = true
        return
    end

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

    if rfsuite.session.mspBusy then return end

    if app.uiState == app.uiStatus.mainMenu then
        local apiV = tostring(rfsuite.session.apiVersion)
        if not mspCallsComplete then
            for i, v in pairs(app.formFieldsBGTask) do
                if v == false and app.formFields[i] then
                    app.formFields[i]:enable(false)
                elseif v == false then
                    log("Main Menu Icon " .. i .. " not found in formFields", "debug")
                end
            end            
        elseif not rfsuite.tasks.active() then
            for i, v in pairs(app.formFieldsBGTask) do
                if v == false and app.formFields[i] then
                    app.formFields[i]:enable(false)
                elseif v == false then
                    log("Main Menu Icon " .. i .. " not found in formFields", "debug")
                end
            end
        elseif not rfsuite.session.postConnectComplete then
            for i, v in pairs(app.formFieldsOffline) do
                if v == false and app.formFields[i] then
                    app.formFields[i]:enable(false)
                elseif v == false then
                    log("Main Menu Icon " .. i .. " not found in formFields", "debug")
                end
            end
        elseif rfsuite.session.apiVersion and rfsuite.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiV) then
            app.offlineMode = false
            for i in pairs(app.formFieldsOffline) do
                if app.formFields[i] then
                    app.formFields[i]:enable(true)
                else
                    log("Main Menu Icon " .. i .. " not found in formFields", "debug")
                end
            end
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
        if rfsuite.preferences.general.save_confirm == true or rfsuite.preferences.general.save_confirm == "true" then
            form.openDialog({
                width = nil,
                title = "@i18n(app.msg_save_settings)@",
                message = (app.Page.extraMsgOnSave and "@i18n(app.msg_save_current_page)@" .. "\n\n" .. app.Page.extraMsgOnSave or "@i18n(app.msg_save_current_page)@"),
                buttons = {
                    {
                        label = "@i18n(app.btn_ok)@",
                        action = function()
                            app.PageTmp = app.Page
                            app.triggers.isSaving = true
                            app.ui.saveSettings()
                            return true
                        end
                    }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
                },
                wakeup = function() end,
                paint = function() end,
                options = TEXT_LEFT
            })
        else    
                app.PageTmp = app.Page
                app.triggers.isSaving = true
                app.ui.saveSettings()            
        end    
    elseif app.triggers.triggerSaveNoProgress then
        app.triggers.triggerSaveNoProgress = false
        app.PageTmp = app.Page
        app.ui.saveSettings()
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
    if not app.dialogs.progressDisplay then
        app.audio.playSaveArmed = true
        app.dialogs.progressCounter = 0
        local key = (rfsuite.utils.apiVersionCompare(">=", "12.08") and "@i18n(app.msg_please_disarm_to_save_warning)@" or "@i18n(app.msg_please_disarm_to_save)@")

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
        if not app.Page and app.PageTmp then app.Page = app.PageTmp end
        if app.ui and app.Page and app.Page.apidata and app.pageState == app.pageStatus.display and not app.triggers.isReady then app.ui.requestPage() end
    end
end

local tasks = {}

tasks.list = {mspCalls, exitApp, profileRateChangeDetection,  triggerSaveDialogs, armedSaveWarning, triggerReloadDialogs, telemetryAndPageStateUpdates, performReloadActions, playPendingAudioAlerts, wakeupUITasks, mainMenuIconEnableDisable, requestPage}

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

return tasks

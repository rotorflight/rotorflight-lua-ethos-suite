--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local system = system

local app = {}
local utils = rfsuite.utils
local log = utils.log
local compile = loadfile

local arg = {...}
local config = arg[1]

-- Make sure this is set - even if not initialised
app.guiIsRunning = false

function app.paint()
    if app.Page and app.Page.paint then app.Page.paint(app.Page) end

    if app.ui and app.ui.adminStatsOverlay then app.ui.adminStatsOverlay() end

end

function app.wakeup_protected()
    app.guiIsRunning = true

    if app.tasks then app.tasks.wakeup() end

    local hasBreadcrumb = app.uiState == app.uiStatus.pages and (
        (app.headerParentBreadcrumb and app.headerParentBreadcrumb ~= "") or
        (app.lastMenu ~= nil) or
        (app.lastScript ~= nil)
    )
    local wantsStats = rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.overlaystatsadmin

    if hasBreadcrumb or (wantsStats and not rfsuite.session.mspBusy) then
        lcd.invalidate()
    end
end

function app.wakeup()
    local success, err = pcall(app.wakeup_protected)
    if not success then
        print("Error in wakeup_protected: " .. tostring(err))
    end
end

function app.create()

    if not app.initialized then

        -- Initialize app state
        app.sensors = {}
        app.formFields = {}
        app.formLines = {}
        app.formNavigationFields = {}
        app.PageTmp = {}
        app.Page = {}
        app.radio = {}
        app.sensor = {}
        app.gfx_buttons = {}        

        app.saveTS = 0 -- timestamp of last save trigger
        app.lastPage = nil -- last opened page id
        app.lastSection = nil -- last opened menu section id
        app.lastIdx = nil -- last selected button index
        app.lastTitle = nil -- last page title string
        app.lastScript = nil -- last page script path
        app.headerTitle = nil -- resolved large header title
        app.headerParentBreadcrumb = nil -- resolved micro breadcrumb parent path
        app.menuContextStack = {} -- submenu return stack (parent chain)
        app.uiStatus = {init = 1, mainMenu = 2, pages = 3, confirm = 4}
        app.pageStatus = {display = 1, editing = 2, saving = 3, eepromWrite = 4, rebooting = 5}
        app.uiState = app.uiStatus.init -- current UI state machine
        app.pageState = app.pageStatus.display -- current page state machine
        app.lastLabel = nil -- last focused label id (for help text)
        app.NewRateTable = nil -- staging rates table during edit
        app.RateTable = nil -- active rates table
        app.fieldHelpTxt = nil -- active help text for focused field
        app.init = nil
        app.guiIsRunning = false  -- flag to indicate if the app is active (for event handling)
        app.adjfunctions = nil -- assigned adjust functions (if any)
        app.profileCheckScheduler = os.clock() -- last profile check time
        app.offlineMode = false -- app-wide offline flag
        app.isOfflinePage = false -- current page does not require FC link
        app.uiState = app.uiStatus.init -- reset UI state (redundant safety)
        app.lcdWidth, app.lcdHeight = lcd.getWindowSize() -- cached screen size
        app.escPowerCycleLoader = false -- ESC power-cycle loader flag

        app.audio = {}
        app.audio.playTimeout = false
        app.audio.playEscPowerCycle = false
        app.audio.playServoOverideDisable = false
        app.audio.playServoOverideEnable = false
        app.audio.playMixerOverideDisable = false
        app.audio.playMixerOverideEnable = false
        app.audio.playEraseFlash = false

        app.dialogs = {}
        app.dialogs.progress = false
        app.dialogs.progressDisplay = false -- loader active
        app.dialogs.progressWatchDog = nil -- timeout watchdog start
        app.dialogs.progressCounter = 0 -- loader progress value
        app.dialogs.progressSpeed = nil -- loader speed multiplier
        app.dialogs.progressRateLimit = os.clock() -- throttle loader updates
        app.dialogs.progressRate = 0.25 -- loader update rate (s)

        app.dialogs.progressESC = false
        app.dialogs.progressDisplayEsc = false
        app.dialogs.progressWatchDogESC = nil
        app.dialogs.progressCounterESC = 0
        app.dialogs.progressESCRateLimit = os.clock()
        app.dialogs.progressESCRate = 2.5

        app.dialogs.save = false
        app.dialogs.saveDisplay = false -- save dialog active
        app.dialogs.saveWatchDog = nil -- save timeout watchdog
        app.dialogs.saveProgressCounter = 0 -- save progress value
        app.dialogs.saveRateLimit = os.clock() -- throttle save updates
        app.dialogs.saveRate = 0.25 -- save update rate (s)

        app.dialogs.nolinkDisplay = false

        app.dialogs.badversion = false
        app.dialogs.badversionDisplay = false

        app.triggers = {}
        app.triggers.exitAPP = false -- request app exit
        app.triggers.noRFMsg = false -- show no RF message
        app.triggers.triggerSave = false -- start save workflow
        app.triggers.triggerSaveNoProgress = false -- save without progress dialog
        app.triggers.triggerReload = false -- reload current page
        app.triggers.triggerReloadFull = false -- reload with full reset
        app.triggers.triggerReloadNoPrompt = false -- reload without prompt
        app.triggers.reloadFull = false -- force full reload
        app.triggers.isReady = false -- page ready to interact
        app.triggers.isSaving = false -- save in progress
        app.triggers.isSavingFake = false -- fake save progress
        app.triggers.saveFailed = false -- save failed flag
        app.triggers.profileswitchLast = nil -- last profile switch id
        app.triggers.rateswitchLast = nil -- last rate switch id
        app.triggers.closeSave = false -- close save dialog
        app.triggers.closeSaveFake = false -- close fake save dialog
        app.triggers.badMspVersion = false -- bad MSP version detected
        app.triggers.badMspVersionDisplay = false -- show bad MSP dialog
        app.triggers.closeProgressLoader = false -- close loader dialog
        app.triggers.closeProgressLoaderNoisProcessed = false -- close loader when queue not processed
        app.triggers.disableRssiTimeout = false -- disable RSSI timeout
        app.triggers.timeIsSet = false -- time sync flag
        app.triggers.invalidConnectionSetup = false -- invalid connection state
        app.triggers.wasConnected = false -- last connection state
        app.triggers.isArmed = false -- model armed flag
        app.triggers.showSaveArmedWarning = false -- warn when saving armed

        -- default speeds for loaders (multipliers of default animation speed)
        app.loaderSpeed = {
            DEFAULT = 1.0,
            FAST = 2.0,
            SLOW = 0.75
        }

        app.tasks = assert(compile("app/tasks.lua"))()

        config.environment = system.getVersion()
        config.ethosRunningVersion = {config.environment.major, config.environment.minor, config.environment.revision}

        app.radio = assert(compile("app/radios.lua"))()

        app.MainMenu = assert(compile("app/modules/init.lua"))()

        app.ui = assert(compile("app/lib/ui.lua"))(config)
        app.utils = assert(compile("app/lib/utils.lua"))(config)

        app.initialized = true
    end

    app.ui.openMainMenu()
end

function app.event(widget, category, value, x, y)



    if value == KEY_RTN_LONG then
        log("KEY_RTN_LONG", "info")
        app.utils.invalidatePages()
        system.exit()
        return 0
    end

    if app.Page and (app.uiState == app.uiStatus.pages or app.uiState == app.uiStatus.mainMenu) then
        if app.Page.event then
            log("USING PAGES EVENTS", "debug")
            local ret = app.Page.event(widget, category, value, x, y)
            if ret ~= nil then return ret end
        end
    end

    if app.uiState == app.uiStatus.mainMenu and app.lastMenu ~= nil and value == 35 then
        app.ui.openMainMenu()
        return true
    end
    if rfsuite.app.lastMenu ~= nil and category == 3 and value == 0 then
        app.ui.openMainMenu()
        return true
    end

    if app.uiState == app.uiStatus.pages then

        if category == EVT_CLOSE and value == 0 or value == 35 then
            log("EVT_CLOSE", "info")
            if app.dialogs.progressDisplay and app.dialogs.progress then app.dialogs.progress:close() end
            if app.dialogs.saveDisplay and app.dialogs.save then app.dialogs.save:close() end
            if app.Page.onNavMenu then
                app.Page.onNavMenu(app.Page)
            else
                app.ui.openMenuContext()
            end
            return true
        end

        if value == KEY_ENTER_LONG then
            if app.Page.navButtons and app.Page.navButtons.save == false then return true end
            local dirtyPref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
            local requireDirty = not (dirtyPref == false or dirtyPref == "false")

            -- Block long-press save when page is not dirty on standard API pages.
            if app.Page and app.Page.canSave and app.Page.canSave(app.Page) == false then
                system.killEvents(KEY_ENTER_BREAK)
                return true
            end
            if requireDirty and not app._pageUsesCustomOpen and app.Page and app.Page.apidata and app.Page.apidata.formdata and app.Page.apidata.formdata.fields then
                if app.pageDirty ~= true then
                    system.killEvents(KEY_ENTER_BREAK)
                    return true
                end
            end

            log("EVT_ENTER_LONG (PAGES)", "info")
            if app.dialogs.progressDisplay and app.dialogs.progress then app.dialogs.progress:close() end
            if app.dialogs.saveDisplay and app.dialogs.save then app.dialogs.save:close() end
            if app.Page and app.Page.onSaveMenu then
                app.Page.onSaveMenu(app.Page)
            else
                app.triggers.triggerSave = true
            end
            system.killEvents(KEY_ENTER_BREAK)
            return true
        end
    end

    if app.uiState == app.uiStatus.mainMenu and value == KEY_ENTER_LONG then
        log("EVT_ENTER_LONG (MAIN MENU)", "info")
        if app.dialogs.progressDisplay and app.dialogs.progress then app.dialogs.progress:close() end
        if app.dialogs.saveDisplay and app.dialogs.save then app.dialogs.save:close() end
        system.killEvents(KEY_ENTER_BREAK)
        return true
    end

    return false
end

function app.close()
    rfsuite.utils.reportMemoryUsage("app.close", "start")

    local userpref_file = "SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini"
    rfsuite.ini.save_ini_file(userpref_file, rfsuite.preferences)

    app.guiIsRunning = false
    app.offlineMode = false
    app.uiState = app.uiStatus.init
    app.escPowerCycleLoader = false

    if app.Page and (app.uiState == app.uiStatus.pages or app.uiState == app.uiStatus.mainMenu) and app.Page.close then app.Page.close() end

    if app.dialogs.progress then app.dialogs.progress:close() end
    if app.dialogs.save then app.dialogs.save:close() end
    if app.dialogs.noLink then app.dialogs.noLink:close() end

    config.useCompiler = true
    rfsuite.config.useCompiler = true

    config.useCompiler = true
    app.triggers.exitAPP = false
    app.triggers.noRFMsg = false
    app.dialogs.nolinkDisplay = false
    app.dialogs.nolinkValueCounter = 0
    app.triggers.telemetryState = nil
    app.dialogs.progressDisplayEsc = false
    app.triggers.wasConnected = false
    app.triggers.invalidConnectionSetup = false
    app.triggers.profileswitchLast = nil

    if rfsuite.tasks.msp then rfsuite.tasks.msp.api.resetApidata() end

    rfsuite.utils.reportMemoryUsage("app.close", "end")

    system.exit()

    return true
end

return app

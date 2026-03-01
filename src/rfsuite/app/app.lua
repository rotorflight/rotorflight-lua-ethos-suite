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
local lastNoOpSaveToneAt = 0
local busyUiTick = 0
-- Busy cadence: run app tasks on RUN_NUM of RUN_DEN ticks while MSP is busy.
-- Lower RUN_NUM to yield more CPU to MSP; set RUN_NUM == RUN_DEN to disable this throttle.
local BUSY_UI_RUN_NUM = 2
local BUSY_UI_RUN_DEN = 3

local function closeTransientDialogs()
    if not app or not app.dialogs then return end

    local progressHandle = app.dialogs.progress
    local saveHandle = app.dialogs.save

    if app.dialogs.progressDisplay and progressHandle and progressHandle.close then
        pcall(function() progressHandle:close() end)
    end
    if app.dialogs.saveDisplay and saveHandle and saveHandle.close then
        pcall(function() saveHandle:close() end)
    end

    if app.ui and app.ui.clearProgressDialog then
        app.ui.clearProgressDialog(progressHandle)
        app.ui.clearProgressDialog(saveHandle)
    end

    app.dialogs.progressDisplay = false
    app.dialogs.saveDisplay = false
    app.dialogs.progressWatchDog = nil
    app.dialogs.saveWatchDog = nil
    app.dialogs.progressSpeed = nil
    app.dialogs.progressCounter = 0
    app.dialogs.saveProgressCounter = 0
    app.triggers.closeProgressLoader = false
    app.triggers.closeProgressLoaderNoisProcessed = false
    app.triggers.closeSave = false
    app.triggers.closeSaveFake = false
    app.triggers.isSaving = false
end

local function playNoOpSaveTone()
    local now = os.clock()
    if (now - lastNoOpSaveToneAt) < 0.25 then return end
    lastNoOpSaveToneAt = now

    if system and system.playTone then
        pcall(system.playTone, 420, 180, 0)
        return
    end

    if utils and utils.playFileCommon then
        utils.playFileCommon("beep.wav")
    end
end

local arg = {...}
local config = arg[1]

local function isMaxInstructionError(err)
    local msg = tostring(err)
    return msg:find("Max instructions count reached", 1, true) or msg:find("Max instructions count", 1, true)
end

-- Make sure this is set - even if not initialised
app.guiIsRunning = false

function app.paint()
    if app.Page and app.Page.paint then app.Page.paint(app.Page) end

    if app.ui and app.ui.adminStatsOverlay then app.ui.adminStatsOverlay() end

end

function app.wakeup_protected()
    app.guiIsRunning = true

    -- Trap main menu opening to early and defer until wakeup to avoid VM instruction limit issues on some models when opening from shortcuts or after profile switch.
    if app._pendingMainMenuOpen and app.ui and app.ui.openMainMenu then

        local ok, err = pcall(app.ui.openMainMenu)
        if ok then
            app._pendingMainMenuOpen = false
        else
            if isMaxInstructionError(err) then
                -- Retry on next wakeup tick when the VM budget resets.
                return
            end
            error(err)
        end
    end

    -- Trap deferred page openings and retry them on wakeup to avoid VM instruction
    -- limit issues when pages are opened from a busy input/event tick.
    if app._pendingOpenPageOpts and app.ui and app.ui.openPage then
        local pendingOpts = app._pendingOpenPageOpts
        local ok, err = pcall(app.ui.openPage, pendingOpts)
        if ok then
            if app._pendingOpenPageOpts == pendingOpts then
                app._pendingOpenPageOpts = nil
            end
        else
            if isMaxInstructionError(err) then
                -- Retry on next wakeup tick when the VM budget resets.
                return
            end
            app._pendingOpenPageOpts = nil
            error(err)
        end
    end

    -- Defer opening main menu until post-connect processing 
    if rfsuite.session.isConnected and not rfsuite.session.postConnectComplete then
        return 
    end

    -- If MSP is busy, only run UI tasks every N ticks to allow background processing to complete and avoid UI freezes.
    local runUiTasks = true
    if rfsuite.session and rfsuite.session.mspBusy then
        busyUiTick = (busyUiTick % BUSY_UI_RUN_DEN) + 1
        runUiTasks = busyUiTick <= BUSY_UI_RUN_NUM
    else
        busyUiTick = 0
    end
    if runUiTasks and app.tasks then app.tasks.wakeup() end
end

function app.wakeup()
    local success, err = pcall(app.wakeup_protected)
    if not success then
        print("Error in wakeup_protected: " .. tostring(err))
    end
end

function app.create()
    app._closing = false

    if not app.initialized then

        -- Initialize app state
        app.sensors = {}
        app.formFields = {}
        app.formLines = {}
        app.formNavigationFields = {}
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
        app.audio.playMixerPassthroughOverideDisable = false
        app.audio.playMixerPassthroughOverideEnable = false
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
        app.triggers.rebootInProgress = false -- expected reboot/link drop in progress

        -- default speeds for loaders (multipliers of default animation speed)
        app.loaderSpeed = {
            DEFAULT = 1.0,
            FAST = 2.0,
            SLOW = 0.75,
            VSLOW = 0.5
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

    app._pendingMainMenuOpen = true
    app._pendingOpenPageOpts = nil
end

function app.event(widget, category, value, x, y)

    if rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.logevents then
        local events = rfsuite.ethos_events
        if events and events.debug then
            local line = events.debug("app", category, value, x, y, {returnOnly = true})
            if line then rfsuite.utils.log(line, "info") end
        end
    end

    local isCloseEvent = ((category == EVT_CLOSE and value == 0) or value == KEY_DOWN_BREAK) and value ~= KEY_ENTER_LONG

    if value == KEY_RTN_LONG then
        log("KEY_RTN_LONG", "info")
        app.utils.invalidatePages()
        system.exit()
        return 0
    end

    if app.Page and (app.uiState == app.uiStatus.pages or app.uiState == app.uiStatus.mainMenu) then
        if (app._openedFromShortcuts or app._forceMenuToMain) and isCloseEvent then
            app.ui.openMainMenu()
            return true
        end
        if app.Page.event then
            log("USING PAGES EVENTS", "debug")
            local ret = app.Page.event(widget, category, value, x, y)
            if ret ~= nil and ret ~= false then return ret end
        end
    end

    if app.uiState == app.uiStatus.mainMenu and isCloseEvent then
        if app.lastMenu and app.lastMenu ~= "mainmenu" then
            app.ui.openMainMenu()
        else
            app.close()
        end
        return true
    end

    if app.uiState == app.uiStatus.pages then

        if isCloseEvent then
            log("EVT_CLOSE", "info")
            closeTransientDialogs()
            if app._forceMenuToMain then
                app.ui.openMainMenu()
            elseif app.Page and app.Page.onNavMenu then
                app.Page.onNavMenu(app.Page)
            else
                app.ui.openMenuContext()
            end
            return true
        end

        if value == KEY_ENTER_LONG then
            if app.Page and app.Page.navButtons and app.Page.navButtons.save == false then return true end
            local dirtyPref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
            local requireDirty = not (dirtyPref == false or dirtyPref == "false")

            -- Block long-press save when page is not dirty on standard API pages.
            if app.Page and app.Page.canSave and app.Page.canSave(app.Page) == false then
                playNoOpSaveTone()
                system.killEvents(KEY_ENTER_BREAK)
                return true
            end
            if requireDirty and not app._pageUsesCustomOpen and app.Page and app.Page.apidata and app.Page.apidata.formdata and app.Page.apidata.formdata.fields then
                if app.pageDirty ~= true then
                    playNoOpSaveTone()
                    system.killEvents(KEY_ENTER_BREAK)
                    return true
                end
            end

            log("EVT_ENTER_LONG (PAGES)", "info")
            closeTransientDialogs()
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
        closeTransientDialogs()
        system.killEvents(KEY_ENTER_BREAK)
        return true
    end

    return false
end

function app.close()
    if app._closing then
        return true
    end
    app._closing = true

    rfsuite.utils.reportMemoryUsage("app.close", "start")

    local userpref_file = "SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini"
    rfsuite.ini.save_ini_file(userpref_file, rfsuite.preferences)

    app.guiIsRunning = false
    app.offlineMode = false
    app.escPowerCycleLoader = false

    if app.ui and app.ui.cleanupCurrentPage then
        local ok, err = pcall(app.ui.cleanupCurrentPage)
        if not ok then
            log("app.close cleanupCurrentPage failed: " .. tostring(err), "debug")
        end
    elseif app.Page and app.Page.close then
        app.Page.close()
    end

    app.uiState = app.uiStatus.init

    closeTransientDialogs()
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

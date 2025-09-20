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

-- Root app table and common shortcuts
local app     = {}
local utils   = rfsuite.utils
local log     = utils.log
local compile = rfsuite.compiler.loadfile

local arg = {...}
local config = arg[1]

-- Paint hook (lcd.refresh-driven)
function app.paint()
  if app.Page and app.Page.paint then
    app.Page.paint(app.Page)
  end
  
  if app.ui and app.ui.adminStatsOverlay then
    if not rfsuite.session.mspBusy then
      app.ui.adminStatsOverlay()
    end
  end


end

function app.wakeup()
    app.guiIsRunning = true

    if app.tasks then
      app.tasks.wakeup()
    end

    -- turn on stats in admin
    -- we need to trigger an invalidate
    if rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.overlaystatsadmin then
      if not rfsuite.session.mspBusy then
        lcd.invalidate()
      end
    end
end

-- App bootstrap
function app.create()

  -- App state containers and constants
  app.sensors               = {}
  app.formFields            = {}
  app.formNavigationFields  = {}
  app.PageTmp               = {}
  app.Page                  = {}
  app.saveTS                = 0
  app.lastPage              = nil
  app.lastSection           = nil
  app.lastIdx               = nil
  app.lastTitle             = nil
  app.lastScript            = nil
  app.gfx_buttons           = {}
  app.uiStatus              = { init = 1, mainMenu = 2, pages = 3, confirm = 4 }
  app.pageStatus            = { display = 1, editing = 2, saving = 3, eepromWrite = 4, rebooting = 5 }
  app.uiState               = app.uiStatus.init
  app.pageState             = app.pageStatus.display
  app.lastLabel             = nil
  app.NewRateTable          = nil
  app.RateTable             = nil
  app.fieldHelpTxt          = nil
  app.radio                 = {}
  app.sensor                = {}
  app.init                  = nil
  app.guiIsRunning          = false
  app.adjfunctions          = nil
  app.profileCheckScheduler = os.clock()
  app.offlineMode           = false
  app.isOfflinePage         = false
  app.uiState               = app.uiStatus.init
  app.lcdWidth, app.lcdHeight = lcd.getWindowSize()

  -- Audio flags
  app.audio = {}
  app.audio.playTimeout              = false
  app.audio.playEscPowerCycle        = false
  app.audio.playServoOverideDisable  = false -- (typo left for compatibility)
  app.audio.playServoOverideEnable   = false -- (typo left for compatibility)
  app.audio.playMixerOverideDisable  = false -- (typo left for compatibility)
  app.audio.playMixerOverideEnable   = false -- (typo left for compatibility)
  app.audio.playEraseFlash           = false

  -- Dialog state
  app.dialogs = {}
  app.dialogs.progress          = false
  app.dialogs.progressDisplay   = false
  app.dialogs.progressWatchDog  = nil
  app.dialogs.progressCounter   = 0
  app.dialogs.progressSpeed     = false
  app.dialogs.progressRateLimit = os.clock()
  app.dialogs.progressRate      = 0.25

  -- ESC progress dialog
  app.dialogs.progressESC          = false
  app.dialogs.progressDisplayEsc   = false
  app.dialogs.progressWatchDogESC  = nil
  app.dialogs.progressCounterESC   = 0
  app.dialogs.progressESCRateLimit = os.clock()
  app.dialogs.progressESCRate      = 2.5

  -- Save dialog
  app.dialogs.save              = false
  app.dialogs.saveDisplay       = false
  app.dialogs.saveWatchDog      = nil
  app.dialogs.saveProgressCounter = 0
  app.dialogs.saveRateLimit     = os.clock()
  app.dialogs.saveRate          = 0.25

  -- No-link dialog
  app.dialogs.nolinkDisplay     = false

  -- Bad version dialog
  app.dialogs.badversion        = false
  app.dialogs.badversionDisplay = false

  -- Triggers
  app.triggers = {}
  app.triggers.exitAPP               = false
  app.triggers.noRFMsg               = false
  app.triggers.triggerSave           = false
  app.triggers.triggerSaveNoProgress = false
  app.triggers.triggerReload         = false
  app.triggers.triggerReloadFull     = false
  app.triggers.triggerReloadNoPrompt = false
  app.triggers.reloadFull            = false
  app.triggers.isReady               = false
  app.triggers.isSaving              = false
  app.triggers.isSavingFake          = false
  app.triggers.saveFailed            = false
  app.triggers.profileswitchLast     = nil
  app.triggers.rateswitchLast        = nil
  app.triggers.closeSave             = false
  app.triggers.closeSaveFake         = false
  app.triggers.badMspVersion         = false
  app.triggers.badMspVersionDisplay  = false
  app.triggers.closeProgressLoader   = false
  app.triggers.closeProgressLoaderNoisProcessed = false
  app.triggers.disableRssiTimeout    = false
  app.triggers.timeIsSet             = false
  app.triggers.invalidConnectionSetup= false
  app.triggers.wasConnected          = false
  app.triggers.isArmed               = false
  app.triggers.showSaveArmedWarning  = false

  -- Task _taskAccumulator
  app.tasks = assert(compile("app/tasks.lua"))()

  config.environment        = system.getVersion()
  config.ethosRunningVersion= {config.environment.major, config.environment.minor, config.environment.revision}


  app.radio = assert(compile("app/radios.lua"))()

  -- Load main menu module
  app.MainMenu = assert(compile("app/modules/init.lua"))()

  -- Load libraries
  app.ui = assert(compile("app/lib/ui.lua"))(config)
  app.utils = assert(compile("app/lib/utils.lua"))(config)

  -- Start with main menu
  app.ui.openMainMenu()
end

-- Event router
function app.event(widget, category, value, x, y)
  -- Rapid exit on long return
  if value == KEY_RTN_LONG then
    log("KEY_RTN_LONG", "info")
    app.utils.invalidatePages()
    system.exit()
    return 0
  end

  -- Delegate to page events first
  if app.Page and (app.uiState == app.uiStatus.pages or app.uiState == app.uiStatus.mainMenu) then
    if app.Page.event then
      log("USING PAGES EVENTS", "debug")
      local ret = app.Page.event(widget, category, value, x, y)
      if ret ~= nil then return ret end
    end
  end

  -- Exit from sub menu
  if app.uiState == app.uiStatus.mainMenu and app.lastMenu ~= nil and value == 35 then
    app.ui.openMainMenu()
    return true
  end
  if rfsuite.app.lastMenu ~= nil and category == 3 and value == 0 then
    app.ui.openMainMenu()
    return true
  end

  -- Generic handler when inside pages
  if app.uiState == app.uiStatus.pages then
    -- Close (top menu)
    if category == EVT_CLOSE and value == 0 or value == 35 then
      log("EVT_CLOSE", "info")
      if app.dialogs.progressDisplay and app.dialogs.progress then app.dialogs.progress:close() end
      if app.dialogs.saveDisplay and app.dialogs.save then app.dialogs.save:close() end
      if app.Page.onNavMenu then app.Page.onNavMenu(app.Page) end
      if app.lastMenu == nil then app.ui.openMainMenu() else app.ui.openMainMenuSub(app.lastMenu) end
      return true
    end
    -- Save (long enter)
    if value == KEY_ENTER_LONG then
      if app.Page.navButtons and app.Page.navButtons.save == false then return true end
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

  -- Ignore long-press on main menu
  if app.uiState == app.uiStatus.mainMenu and value == KEY_ENTER_LONG then
    log("EVT_ENTER_LONG (MAIN MENU)", "info")
    if app.dialogs.progressDisplay and app.dialogs.progress then app.dialogs.progress:close() end
    if app.dialogs.saveDisplay and app.dialogs.save then app.dialogs.save:close() end
    system.killEvents(KEY_ENTER_BREAK)
    return true
  end

  return false
end

-- Close and cleanup
function app.close()
  rfsuite.utils.reportMemoryUsage("app.close", "start")

  -- Save user preferences
  local userpref_file = "SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini"
  rfsuite.ini.save_ini_file(userpref_file, rfsuite.preferences)

  app.guiIsRunning = false
  app.offlineMode  = false
  app.uiState      = app.uiStatus.init

  if app.Page and (app.uiState == app.uiStatus.pages or app.uiState == app.uiStatus.mainMenu) and app.Page.close then
    app.Page.close()
  end

  if app.dialogs.progress then app.dialogs.progress:close() end
  if app.dialogs.save then app.dialogs.save:close() end
  if app.dialogs.noLink then app.dialogs.noLink:close() end

  -- Reset flags toggled by compiler and config
  config.useCompiler            = true
  rfsuite.config.useCompiler    = true

  --[[
  App state containers and constants
  ]]
  app.sensors               = nil
  app.formFields            = nil
  app.formNavigationFields  = nil
  app.PageTmp               = nil
  app.Page                  = nil
  app.saveTS                = nil
  app.lastPage              = nil
  app.lastSection           = nil
  app.lastIdx               = nil
  app.lastTitle             = nil
  app.lastScript            = nil
  app.gfx_buttons           = nil
  app.uiStatus              = nil
  app.pageStatus            = nil
  app.uiState               = nil
  app.pageState             = nil
  app.lastLabel             = nil
  app.NewRateTable          = nil
  app.RateTable             = nil
  app.fieldHelpTxt          = nil
  app.radio                 = nil
  app.sensor                = nil
  app.init                  = nil
  app.guiIsRunning          = nil
  app.adjfunctions          = nil
  app.profileCheckScheduler = nil
  app.offlineMode           = nil
  app.audio                 = nil
  app.dialogs               = nil
  app.triggers              = nil
  app.utils                 = nil
  app.ui                    = nil
  app.formFieldsBGTask      = nil
  app.formLines             = nil
  app.moduleList            = nil
  app.MainMenu              = nil
  app.isOfflinePage         = nil
  app.lcdWidth              = nil
  app.lcdHeight             = nil
  app.formFieldsOffline     = nil
  app.formLineCnt           = nil
  app.formFieldCount        = nil
  app.tasks                 = nil

  -- Telemetry/protocol
  ELRS_PAUSE_TELEMETRY = false
  CRSF_PAUSE_TELEMETRY = false

  rfsuite.utils.reportMemoryUsage("app.close", "end")

  system.exit()

  return true
end

return app

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
local i18n    = rfsuite.i18n.get
local utils   = rfsuite.utils
local log     = utils.log
local compile = rfsuite.compiler.loadfile

local arg = {...}
local config = arg[1]

--[[
triggers table:
  - exitAPP:               boolean, indicates if the app should exit.
  - noRFMsg:               boolean, indicates if there is no RF message.
  - triggerSave:           boolean, triggers a save operation.
  - triggerSaveNoProgress: boolean, triggers a save without progress dialog.
  - triggerReload:         boolean, triggers a reload.
  - triggerReloadFull:     boolean, triggers a full reload.
  - triggerReloadNoPrompt: boolean, triggers a reload without prompt.
  - reloadFull:            boolean, tracks a full reload in progress.
  - isReady:               boolean, indicates if the app is ready.
  - isSaving / isSavingFake/ saveFailed: saving state flags.
  - telemetryState:        current telemetry state.
  - profileswitchLast / rateswitchLast: last switch states.
  - closeSave / closeSaveFake: close save dialog flags.
  - badMspVersion / badMspVersionDisplay: MSP version flags.
  - closeProgressLoader:   flag to close progress loader.
  - mspBusy:               MSP busy state.
  - disableRssiTimeout:    disables RSSI timeout gating.
  - timeIsSet:             real-time clock set flag.
  - invalidConnectionSetup:invalid connection state detected.
  - wasConnected:          saw at least one valid connection.
  - isArmed:               system armed state.
  - showSaveArmedWarning:  show warning when saving while armed.
]]
local triggers = {}
triggers.exitAPP               = false
triggers.noRFMsg               = false
triggers.triggerSave           = false
triggers.triggerSaveNoProgress = false
triggers.triggerReload         = false
triggers.triggerReloadFull     = false
triggers.triggerReloadNoPrompt = false
triggers.reloadFull            = false
triggers.isReady               = false
triggers.isSaving              = false
triggers.isSavingFake          = false
triggers.saveFailed            = false
triggers.telemetryState        = nil
triggers.profileswitchLast     = nil
triggers.rateswitchLast        = nil
triggers.closeSave             = false
triggers.closeSaveFake         = false
triggers.badMspVersion         = false
triggers.badMspVersionDisplay  = false
triggers.closeProgressLoader   = false
triggers.closeProgressLoaderNoisProcessed = false
triggers.mspBusy               = false
triggers.disableRssiTimeout    = false
triggers.timeIsSet             = false
triggers.invalidConnectionSetup= false
triggers.wasConnected          = false
triggers.isArmed               = false
triggers.showSaveArmedWarning  = false

-- Expose triggers
app.triggers = triggers

-- UI
app.ui = assert(compile("app/lib/ui.lua"))(config)

-- Utils (loaded later in app.create if missing)
app.utils = nil

--[[
App state containers and constants
]]
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
app.telemetryStatus       = { ok = 1, noSensor = 2, noTelemetry = 3 }
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

--[[
Audio flags
]]
app.audio = {}
app.audio.playTimeout              = false
app.audio.playEscPowerCycle        = false
app.audio.playServoOverideDisable  = false -- (typo left for compatibility)
app.audio.playServoOverideEnable   = false -- (typo left for compatibility)
app.audio.playMixerOverideDisable  = false -- (typo left for compatibility)
app.audio.playMixerOverideEnable   = false -- (typo left for compatibility)
app.audio.playEraseFlash           = false

--[[
Dialog state
]]
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

-- Invalidate pages after writes/reloads
local function invalidatePages()
  app.Page      = nil
  app.pageState = app.pageStatus.display
  app.saveTS    = 0
  collectgarbage()
end

-- Reboot FC (MSP)
local function rebootFc()
  app.pageState = app.pageStatus.rebooting
  rfsuite.tasks.msp.mspQueue:add({
    command = 68, -- MSP_REBOOT
    processReply = function(self, buf)
      invalidatePages()
      utils.onReboot()
    end,
    simulatorResponse = {}
  })
end

-- MSP EEPROM write command descriptor
local mspEepromWrite = {
  command = 250, -- MSP_EEPROM_WRITE (fails when armed)
  processReply = function(self, buf)
    app.triggers.closeSave = true
    if app.Page.postEepromWrite then app.Page.postEepromWrite() end
    if app.Page.reboot then
      rebootFc()
    else
      invalidatePages()
    end
  end,
  errorHandler = function(self)
    if rfsuite.session.isArmed then
      app.triggers.closeSave = true
      app.audio.playSaveArmed = true
      app.triggers.showSaveArmedWarning = true
    end
  end,
  simulatorResponse = {}
}

-- Called when settings writes have completed (may queue EEPROM write)
function app.settingsSaved()
  if app.Page and app.Page.eepromWrite then
    if app.pageState ~= app.pageStatus.eepromWrite then
      app.pageState = app.pageStatus.eepromWrite
      app.triggers.closeSave = true
      rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)
    end
  elseif app.pageState ~= app.pageStatus.eepromWrite then
    invalidatePages()
    app.triggers.closeSave = true
  end
  collectgarbage()
  utils.reportMemoryUsage("app.settingsSaved")
end

-- Save current page's settings via MSP API(s)
local function saveSettings()
  if app.pageState == app.pageStatus.saving then return end

  app.pageState = app.pageStatus.saving
  app.saveTS    = os.clock()

  log("Saving data", "debug")

  local mspapi  = app.Page.apidata
  local apiList = mspapi.api
  local values  = mspapi.values

  local totalRequests    = #apiList
  local completedRequests= 0

  rfsuite.app.Page.apidata.apiState.isProcessing = true

  if app.Page.preSave then app.Page.preSave(app.Page) end

  for apiID, apiNAME in ipairs(apiList) do
    log("Saving data for API: " .. apiNAME, "debug")

    local payloadData      = values[apiNAME]
    local payloadStructure = mspapi.structure[apiNAME]

    local API = rfsuite.tasks.msp.api.load(apiNAME)
    API.setErrorHandler(function(self, buf)
      app.triggers.saveFailed = true
    end)
    API.setCompleteHandler(function(self, buf)
      completedRequests = completedRequests + 1
      log("API " .. apiNAME .. " write complete", "debug")
      if completedRequests == totalRequests then
        log("All API requests have been completed!", "debug")
        if app.Page.postSave then app.Page.postSave(app.Page) end
        app.settingsSaved()
        rfsuite.app.Page.apidata.apiState.isProcessing = false
      end
    end)

    -- Build lookup maps (normal + bitmap)
    local fieldMap       = {}
    local fieldMapBitmap = {}
    for fidx, f in ipairs(app.Page.apidata.formdata.fields) do
      if not f.bitmap then
        if f.mspapi == apiID then fieldMap[f.apikey] = fidx end
      else
        local p1, p2 = string.match(f.apikey, "([^%-]+)%-%>(.+)")
        if not fieldMapBitmap[p1] then fieldMapBitmap[p1] = {} end
        fieldMapBitmap[p1][f.bitmap] = fidx
      end
    end

    -- Inject values into payload
    for k, v in pairs(payloadData) do
      local fieldIndex = fieldMap[k]
      if fieldIndex then
        payloadData[k] = app.Page.fields[fieldIndex].value
      elseif fieldMapBitmap[k] then
        local originalValue = tonumber(v) or 0
        local newValue = originalValue
        for bit, idx in pairs(fieldMapBitmap[k]) do
          local fieldVal = math.floor(tonumber(app.Page.fields[idx].value) or 0)
          local mask = 1 << (bit)
          if fieldVal ~= 0 then newValue = newValue | mask else newValue = newValue & (~mask) end
        end
        payloadData[k] = newValue
      end
    end

    -- Send payload
    for k, v in pairs(payloadData) do
      log("Set value for " .. k .. " to " .. v, "debug")
      API.setValue(k, v)
    end

    API.write()
  end
end

-- Update form fields with MSP API values/attributes
function app.mspApiUpdateFormAttributes(values, structure)
  if not (app.Page.apidata.formdata and app.Page.apidata.api and app.Page.fields) then
    log("app.Page.apidata.formdata or its components are nil", "debug")
    return
  end

  local function combined_api_parts(s)
    local part1, part2 = s:match("^([^:]+):([^:]+)$")
    if part1 and part2 then
      local num = tonumber(part1)
      if num then
        part1 = num
      else
        part1 = app.Page.apidata.api_reversed[part1] or nil
      end
      if part1 then return { part1, part2 } end
    end
    return nil
  end

  local fields = app.Page.apidata.formdata.fields
  local api    = app.Page.apidata.api

  if not app.Page.apidata.api_reversed then
    app.Page.apidata.api_reversed = {}
    for index, value in pairs(app.Page.apidata.api) do
      app.Page.apidata.api_reversed[value] = index
    end
  end

  for i, f in ipairs(fields) do
    local formField = app.formFields[i]
    if type(formField) == 'userdata' then
      if f.api then
        log("API field found: " .. f.api, "debug")
        local parts = combined_api_parts(f.api)
        if parts then f.mspapi = parts[1]; f.apikey = parts[2] end
      end

      local apikey      = f.apikey
      local mspapiID    = f.mspapi
      local mspapiNAME  = api[mspapiID]
      local target      = structure[mspapiNAME]

      if mspapiID == nil or mspapiID == nil then
        log("API field missing mspapi or apikey", "debug")
      else
        for _, v in ipairs(target) do
          if not v.bitmap then
            if v.field == apikey and mspapiID == f.mspapi then
              local help_target = "api." .. mspapiNAME .. "." .. apikey
              local help_return = i18n(help_target)
              if help_target ~= help_return then v.help = help_return else v.help = nil end

              app.ui.injectApiAttributes(formField, f, v)

              local scale = f.scale or 1
              if values and values[mspapiNAME] and values[mspapiNAME][apikey] then
                app.Page.fields[i].value = values[mspapiNAME][apikey] / scale
              end

              if values[mspapiNAME][apikey] == nil then
                log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                formField:enable(false)
              end
              break
            end
          else
            -- bitmap fields
            for bidx, b in ipairs(v.bitmap) do
              local bitmapField = v.field .. "->" .. b.field
              if bitmapField == apikey and mspapiID == f.mspapi then
                local help_target = "api." .. mspapiNAME .. "." .. apikey
                local help_return = i18n(help_target)
                if help_target ~= help_return then v.help = help_return else v.help = nil end

                app.ui.injectApiAttributes(formField, f, b)

                local scale = f.scale or 1
                if values and values[mspapiNAME] and values[mspapiNAME][v.field] then
                  local raw_value = values[mspapiNAME][v.field]
                  local bit_value = (raw_value >> bidx - 1) & 1
                  app.Page.fields[i].value = bit_value / scale
                end

                if values[mspapiNAME][v.field] == nil then
                  log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                  formField:enable(false)
                end

                app.Page.fields[i].bitmap = bidx - 1
              end
            end
          end
        end
      end
    else
      log("Form field skipped; not valid for this api version?", "debug")
    end
  end

  collectgarbage()
  utils.reportMemoryUsage("app.mspApiUpdateFormAttributes")
  app.formNavigationFields['menu']:focus(true)
end

-- Request page data via the API form system
local function requestPage()
  if not app.Page.apidata then return end
  if not app.Page.apidata.api and not app.Page.apidata.formdata then
    log("app.Page.apidata.api did not pass consistancy checks", "debug")
    return
  end

  if not app.Page.apidata.apiState then
    app.Page.apidata.apiState = { currentIndex = 1, isProcessing = false }
  end

  local apiList = app.Page.apidata.api
  local state   = app.Page.apidata.apiState

  if state.isProcessing then
    log("requestPage is already running, skipping duplicate call.", "debug")
    return
  end
  state.isProcessing = true

  if not app.Page.apidata.values then
    log("requestPage Initialize values on first run", "debug")
    app.Page.apidata.values             = {}
    app.Page.apidata.structure          = {}
    app.Page.apidata.receivedBytesCount = {}
    app.Page.apidata.receivedBytes      = {}
    app.Page.apidata.positionmap        = {}
    app.Page.apidata.other              = {}
  end

  if state.currentIndex == nil then state.currentIndex = 1 end

  local function checkForUnresolvedTimeouts()
    if not app or not app.Page or not app.Page.apidata then return end
    local hasUnresolvedTimeouts = false
    for apiKey, retries in pairs(app.Page.apidata.retryCount or {}) do
      if retries >= 3 then
        hasUnresolvedTimeouts = true
        log("[ALERT] API " .. apiKey .. " failed after 3 timeouts.", "info")
      end
    end
    if hasUnresolvedTimeouts then
      app.ui.disableAllFields()
      app.ui.disableAllNavigationFields()
      app.ui.enableNavigationField('menu')
      app.triggers.closeProgressLoader = true
    end
  end

  local function processNextAPI()
    if not app or not app.Page or not app.Page.apidata then
      log("App is closing. Stopping processNextAPI.", "debug")
      return
    end

    if state.currentIndex > #apiList or #apiList == 0 then
      if state.isProcessing then
        state.isProcessing = false
        state.currentIndex = 1
        app.triggers.isReady = true
        if app.Page.postRead then app.Page.postRead(app.Page) end
        app.mspApiUpdateFormAttributes(app.Page.apidata.values, app.Page.apidata.structure)
        if app.Page.postLoad then app.Page.postLoad(app.Page) else app.triggers.closeProgressLoader = true end
        checkForUnresolvedTimeouts()
      end
      return
    end

    local v      = apiList[state.currentIndex]
    local apiKey = type(v) == "string" and v or v.name
    if not apiKey then
      log("API key is missing for index " .. tostring(state.currentIndex), "warning")
      state.currentIndex = state.currentIndex + 1
      local base = 0.25
      local backoff = math.min(2.0, base * (2 ^ retryCount))
      local jitter = math.random() * 0.2
      rfsuite.tasks.callback.inSeconds(backoff + jitter, processNextAPI)
      return
    end

    local API = rfsuite.tasks.msp.api.load(v)

    if app and app.Page and app.Page.apidata then app.Page.apidata.retryCount = app.Page.apidata.retryCount or {} end

    local retryCount = app.Page.apidata.retryCount[apiKey] or 0
    local handled = false

    log("[PROCESS] API: " .. apiKey .. " (Attempt " .. (retryCount + 1) .. ")", "debug")

    local function handleTimeout()
      if handled then return end
      handled = true
      if not app or not app.Page or not app.Page.apidata then
        log("App is closing. Timeout handling skipped.", "debug")
        return
      end
      retryCount = retryCount + 1
      app.Page.apidata.retryCount[apiKey] = retryCount
      if retryCount < 3 then
        log("[TIMEOUT] API: " .. apiKey .. " (Retry " .. retryCount .. ")", "warning")
        rfsuite.tasks.callback.inSeconds(0.25, processNextAPI)
      else
        log("[TIMEOUT FAIL] API: " .. apiKey .. " failed after 3 attempts. Skipping.", "error")
        state.currentIndex = state.currentIndex + 1
        rfsuite.tasks.callback.inSeconds(0.25, processNextAPI)
      end
    end

    rfsuite.tasks.callback.inSeconds(2, handleTimeout)

    API.setCompleteHandler(function(self, buf)
      if handled then return end
      handled = true
      if not app or not app.Page or not app.Page.apidata then
        log("App is closing. Skipping API success handling.", "debug")
        return
      end
      log("[SUCCESS] API: " .. apiKey .. " completed successfully.", "debug")
      app.Page.apidata.values[apiKey]             = API.data().parsed
      app.Page.apidata.structure[apiKey]          = API.data().structure
      app.Page.apidata.receivedBytes[apiKey]      = API.data().buffer
      app.Page.apidata.receivedBytesCount[apiKey] = API.data().receivedBytesCount
      app.Page.apidata.positionmap[apiKey]        = API.data().positionmap
      app.Page.apidata.other[apiKey]              = API.data().other or {}
      app.Page.apidata.retryCount[apiKey]         = 0
      state.currentIndex = state.currentIndex + 1
      rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)
    end)

    API.setErrorHandler(function(self, err)
      if handled then return end
      handled = true
      if not app or not app.Page or not app.Page.apidata then
        log("App is closing. Skipping API error handling.", "debug")
        return
      end
      retryCount = retryCount + 1
      app.Page.apidata.retryCount[apiKey] = retryCount
      if retryCount < 3 then
        log("[ERROR] API: " .. apiKey .. " failed (Retry " .. retryCount .. "): " .. tostring(err), "warning")
        rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)
      else
        log("[ERROR FAIL] API: " .. apiKey .. " failed after 3 attempts. Skipping.", "error")
        state.currentIndex = state.currentIndex + 1
        rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)
      end
    end)

    API.read()
  end

  processNextAPI()
end

-- Telemetry state updater
function app.updateTelemetryState()
  if system:getVersion().simulation ~= true then
    if not rfsuite.session.telemetrySensor then
      app.triggers.telemetryState = app.telemetryStatus.noSensor
    elseif app.utils.getRSSI() == 0 then
      app.triggers.telemetryState = app.telemetryStatus.noTelemetry
    else
      app.triggers.telemetryState = app.telemetryStatus.ok
    end
  else
    app.triggers.telemetryState = app.telemetryStatus.noTelemetry
  end
end

-- Paint hook (lcd.refresh-driven)
function app.paint()
  if app.Page and app.Page.paint then
    app.Page.paint(app.Page)
  end
end

--[[
Round‑robin UI task list
]]
app._uiTasks = {
  -- 1. Exit App
  function()
    if app.triggers.exitAPP then
      app.triggers.exitAPP = false
      form.invalidate()
      system.exit()
      utils.reportMemoryUsage("Exit App")
    end
  end,

  -- 2. Profile / Rate Change Detection
  function()
    if not (app.Page and (app.Page.refreshOnProfileChange or app.Page.refreshOnRateChange or app.Page.refreshFullOnProfileChange or app.Page.refreshFullOnRateChange)
           and app.uiState == app.uiStatus.pages and not app.triggers.isSaving
           and not app.dialogs.saveDisplay and not app.dialogs.progressDisplay
           and rfsuite.tasks.msp.mspQueue:isProcessed()) then return end
    local now = os.clock();
    local interval = (rfsuite.tasks.telemetry.getSensorSource("pid_profile") and rfsuite.tasks.telemetry.getSensorSource("rate_profile"))
                     and 0.1 or 1.5
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
  end,

  -- 3. Main Menu Icon Enable/Disable
  function()
    if app.uiState ~= app.uiStatus.mainMenu and app.uiState ~= app.uiStatus.pages then return end
    if app.uiState == app.uiStatus.mainMenu then
      local apiV = tostring(rfsuite.session.apiVersion)

      if not rfsuite.tasks.active() then
          for i, v in pairs(app.formFieldsBGTask) do
            if v == false then
              if app.formFields[i] then
                app.formFields[i]:enable(false)
              else
                log("Main Menu Icon " .. i .. " not found in formFields", "info")
              end
            end
          end 
      elseif not rfsuite.session.isConnected then
        for i, v in pairs(app.formFieldsOffline) do
          if v == false then
            if app.formFields[i] then
              app.formFields[i]:enable(false)
            else
              log("Main Menu Icon " .. i .. " not found in formFields", "info")
            end
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
  end,

  -- 4. No-Link Progress & Message Update
  function()
    if app.triggers.telemetryState ~= 1 or not app.triggers.disableRssiTimeout then
      if not app.dialogs.nolinkDisplay and not app.triggers.wasConnected then
        if app.dialogs.progressDisplay and app.dialogs.progress then app.dialogs.progress:close() end
        if app.dialogs.saveDisplay and app.dialogs.save then app.dialogs.save:close() end
        app.ui.progressDisplay(i18n("app.msg_connecting"),i18n("app.msg_connecting_to_fbl"),true)
        app.dialogs.nolinkDisplay = true
      end
    end

  end,

  -- 5. Trigger Save Dialogs
  function()
    if app.triggers.triggerSave then
      app.triggers.triggerSave = false
      form.openDialog({
        width   = nil,
        title   = i18n("app.msg_save_settings"),
        message = (app.Page.extraMsgOnSave and i18n("app.msg_save_current_page").."\n\n"..app.Page.extraMsgOnSave or i18n("app.msg_save_current_page")),
        buttons = {
          { label=i18n("app.btn_ok"), action=function()
              app.PageTmp = app.Page
              app.triggers.isSaving = true
              saveSettings()
              return true
            end
          },
          { label=i18n("app.btn_cancel"), action=function() return true end }
        },
        wakeup = function() end,
        paint  = function() end,
        options= TEXT_LEFT
      })
    elseif app.triggers.triggerSaveNoProgress then
      app.triggers.triggerSaveNoProgress = false
      app.PageTmp = app.Page
      saveSettings()
    end

    if app.triggers.isSaving then
      if app.pageState >= app.pageStatus.saving and not app.dialogs.saveDisplay then
        app.triggers.saveFailed         = false
        app.dialogs.saveProgressCounter = 0
        app.ui.progressDisplaySave()
        rfsuite.tasks.msp.mspQueue.retryCount = 0
      end
    end
  end,

  -- 6. Armed-Save Warning
  function()
    if not app.triggers.showSaveArmedWarning or app.triggers.closeSave then return end
    if not app.dialogs.progressDisplay then
      app.dialogs.progressCounter = 0
      local key = (rfsuite.utils.apiVersionCompare(">=", "12.08") and "app.msg_please_disarm_to_save_warning" or "app.msg_please_disarm_to_save")
      app.ui.progressDisplay(i18n("app.msg_save_not_commited"), i18n(key))
    end
    if app.dialogs.progressCounter >= 100 then
      app.triggers.showSaveArmedWarning = false
      app.dialogs.progress:close()
    end
  end,

  -- 7. Trigger Reload Dialogs
  function()
    if app.triggers.triggerReloadNoPrompt then
      app.triggers.triggerReloadNoPrompt = false
      app.triggers.reload = true
      return
    end
    if app.triggers.triggerReload then
      app.triggers.triggerReload = false
      form.openDialog({
        title   = i18n("reload"):gsub("^%l", string.upper),
        message = i18n("app.msg_reload_settings"),
        buttons = {
          { label=i18n("app.btn_ok"),     action=function() app.triggers.reload = true;      return true end },
          { label=i18n("app.btn_cancel"), action=function() return true end }
        },
        options = TEXT_LEFT
      })
    elseif app.triggers.triggerReloadFull then
      app.triggers.triggerReloadFull = false
      form.openDialog({
        title   = i18n("reload"):gsub("^%l", string.upper),
        message = i18n("app.msg_reload_settings"),
        buttons = {
          { label=i18n("app.btn_ok"),     action=function() app.triggers.reloadFull = true;  return true end },
          { label=i18n("app.btn_cancel"), action=function() return true end }
        },
        options = TEXT_LEFT
      })
    end
  end,

  -- 8. Telemetry & Page State Updates
  function()
    app.updateTelemetryState()
    if app.uiState == app.uiStatus.mainMenu then
      invalidatePages()
    elseif app.triggers.isReady and (rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue:isProcessed())
           and app.Page and app.Page.values then
      app.triggers.isReady = false
      app.triggers.closeProgressLoader = true
    end
  end,

  -- 9. Perform Reload Actions
  function()
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
  end,

  -- 10. Play Pending Audio Alerts
  function()
    local a = app.audio
    if a.playEraseFlash          then utils.playFile("app","eraseflash.wav");        a.playEraseFlash = false end
    if a.playTimeout             then utils.playFile("app","timeout.wav");           a.playTimeout = false end
    if a.playEscPowerCycle       then utils.playFile("app","powercycleesc.wav");     a.playEscPowerCycle = false end
    if a.playServoOverideEnable  then utils.playFile("app","soverideen.wav");        a.playServoOverideEnable = false end
    if a.playServoOverideDisable then utils.playFile("app","soveridedis.wav");       a.playServoOverideDisable = false end
    if a.playMixerOverideEnable  then utils.playFile("app","moverideen.wav");        a.playMixerOverideEnable = false end
    if a.playMixerOverideDisable then utils.playFile("app","moveridedis.wav");       a.playMixerOverideDisable = false end
    if a.playSaveArmed           then utils.playFileCommon("warn.wav");               a.playSaveArmed = false end
    if a.playBufferWarn          then utils.playFileCommon("warn.wav");               a.playBufferWarn = false end
  end,

  -- 11. Wakeup UI Tasks
  function()
    if app.Page and app.uiState == app.uiStatus.pages and app.Page.wakeup then
      app.Page.wakeup(app.Page)
    end
  end,
}

-- Round‑robin executor
app._nextUiTask      = 1
app._taskAccumulator = 0
app._uiTaskPercent   = 100
function app.wakeup()
  app.guiIsRunning = true
  local total = #app._uiTasks
  local tasksThisTick = math.max(1, (total * app._uiTaskPercent) / 100)
  app._taskAccumulator = app._taskAccumulator + tasksThisTick
  while app._taskAccumulator >= 1 do
    local idx = app._nextUiTask
    app._uiTasks[idx]()
    app._nextUiTask = (idx % total) + 1
    app._taskAccumulator = app._taskAccumulator - 1
  end

  if app.uiState == app.uiStatus.pages then
    if not app.Page and app.PageTmp then app.Page = app.PageTmp end
    if app.Page and app.Page.apidata and app.pageState == app.pageStatus.display and not app.triggers.isReady then
      requestPage()
    end
  end
end

-- Log Tool bootstrap (standalone logs page)
function app.create_logtool()
  triggers.showUnderUsedBufferWarning = false
  triggers.showOverUsedBufferWarning  = false

  config.environment       = system.getVersion()
  config.ethosRunningVersion= {config.environment.major, config.environment.minor, config.environment.revision}

  app.lcdWidth, app.lcdHeight = lcd.getWindowSize()
  app.radio = assert(compile("app/radios.lua"))()

  app.uiState = app.uiStatus.init

  rfsuite.preferences.menulastselected["mainmenu"] = pidx
  app.ui.progressDisplay()

  app.offlineMode = true
  app.ui.openPage(1, "Logs", "logs/logs.lua", 1)
end

-- App bootstrap
function app.create()
  config.environment        = system.getVersion()
  config.ethosRunningVersion= {config.environment.major, config.environment.minor, config.environment.revision}

  app.lcdWidth, app.lcdHeight = lcd.getWindowSize()
  app.radio = assert(compile("app/radios.lua"))()

  app.uiState = app.uiStatus.init

  if not app.MainMenu then
    app.MainMenu = assert(compile("app/modules/init.lua"))()
  end

  if not app.ui then
    app.ui = assert(compile("app/lib/ui.lua"))(config)
  end

  if not app.utils then
    app.utils = assert(compile("app/lib/utils.lua"))(config)
  end

  app.ui.openMainMenu()
end

-- Event router
function app.event(widget, category, value, x, y)
  -- Rapid exit on long return
  if value == KEY_RTN_LONG then
    log("KEY_RTN_LONG", "info")
    invalidatePages()
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
  rfsuite.utils.reportMemoryUsage("closing application: start")

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

  -- Reset page/nav state
  pageLoaded  = 100
  pageTitle   = nil
  pageFile    = nil
  app.Page    = {}
  app.formFields = {}
  app.formNavigationFields = {}
  app.gfx_buttons = {}
  app.formLines = nil
  app.MainMenu  = nil
  app.formNavigationFields = {}
  app.PageTmp = nil
  app.moduleList = nil
  app.utils = nil
  app.ui    = nil

  -- Reset triggers
  app.triggers.exitAPP = false
  app.triggers.noRFMsg = false
  app.triggers.telemetryState = nil
  app.triggers.wasConnected = false
  app.triggers.invalidConnectionSetup = false
  app.triggers.disableRssiTimeout = false

  -- Reset dialogs
  app.dialogs.nolinkDisplay = false
  app.dialogs.nolinkValueCounter = 0
  app.dialogs.progressDisplayEsc = false

  -- Reset audio
  app.audio = {}

  -- Telemetry/protocol
  ELRS_PAUSE_TELEMETRY = false
  CRSF_PAUSE_TELEMETRY = false

  -- Profile/rate
  app.triggers.profileswitchLast = nil
  rfsuite.session.activeProfileLast = nil
  rfsuite.session.activeProfile = nil
  rfsuite.session.activeRateProfile = nil
  rfsuite.session.activeRateProfileLast = nil
  rfsuite.session.activeRateTable = nil

  collectgarbage()
  invalidatePages()

  rfsuite.utils.reportMemoryUsage("closing application: end")
  system.exit()
  return true
end

return app

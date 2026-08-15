-- Shared controller for Blackbox Configuration and Logging pages.

if package.loaded["rfsuite.app.pages.blackbox_edit_page"] then
  return package.loaded["rfsuite.app.pages.blackbox_edit_page"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local blackboxConfig = requireModule("lib/msp_blackbox_config.lua")
local dataflashSummary = requireModule("lib/msp_dataflash_summary.lua")
local sdcardSummary = requireModule("lib/msp_sdcard_summary.lua")
local featureConfig = requireModule("lib/msp_feature_config.lua")

local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_LOADING_TITLE = "@i18n(app.msg_loading)@"
local MSG_LOADING_BODY = "@i18n(app.msg_loading_from_fbl)@"
local MSG_SAVING_TITLE = "@i18n(app.msg_saving)@"
local MSG_SAVING_BODY = "@i18n(app.msg_saving_settings)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"
local MSG_RELOAD_TITLE = "@i18n(reload)@"
local MSG_RELOAD_BODY = "@i18n(app.msg_reload_settings)@"

local FEATURE_BIT_GPS = 7
local FEATURE_BIT_GOVERNOR = 26
local FEATURE_BIT_ESC_SENSOR = 27

local function bitMask(bit)
  return 2 ^ bit
end

local function hasBit(mask, bit)
  return math.floor((tonumber(mask or 0) or 0) / bitMask(bit)) % 2 >= 1
end

local function setBit(mask, bit, enabled)
  mask = tonumber(mask or 0) or 0
  local flag = bitMask(bit)
  local wasEnabled = hasBit(mask, bit)
  if enabled == true and not wasEnabled then return mask + flag end
  if enabled ~= true and wasEnabled then return mask - flag end
  return mask
end

local function formatRateHz(denom)
  local d = tonumber(denom or 1) or 1
  if d < 1 then d = 1 end
  local hz = 1000 / d
  if math.floor(hz) == hz then
    return string.format("%dHz", hz)
  end
  return string.format("%.1fHz", hz)
end

local function denomChoices(currentDenom)
  local presets = {1, 2, 4, 10, 20, 40, 100}
  local current = tonumber(currentDenom or 1) or 1
  if current < 1 then current = 1 end
  local choices = {}
  local seen = false
  for _, denom in ipairs(presets) do
    if denom == current then seen = true end
    choices[#choices + 1] = {formatRateHz(denom), denom}
  end
  if not seen then
    choices[#choices + 1] = {string.format("@i18n(app.modules.blackbox.rate_custom)@", formatRateHz(current), current), current}
  end
  return choices
end

local function choiceHasValue(choices, value)
  for _, choice in ipairs(choices) do
    if tonumber(choice[2]) == tonumber(value) then return true end
  end
  return false
end

local blackbox_edit_page = {}

function blackbox_edit_page.new(pageConfig)
  local page = {}

  function page.open(opts)
    opts = opts or {}
    local disposed = false
    local headerHandle = nil
    local dialog = nil
    local loaded = false
    local busy = false
    local pendingReads = 0
    local current = blackboxConfig.defaultConfig()
    local original = blackboxConfig.defaultConfig()
    local featureMask = 0
    local media = {dataflashSupported = true, sdcardSupported = false}
    local fields = {}
    local controlFields = {}
    local renderPage = nil
    local needsRender = false
    local renderFocus = "menu"

    local function closeDialog(focusFn)
      if not dialog then return end
      dialog:value(100)
      dialog:close()
      dialog = nil
      if focusFn then
        focusFn()
      elseif headerHandle then
        headerHandle.focusMenu()
      end
    end

    local function showProgress(title, message)
      dialog = progressDialog.open({
        title = title,
        message = message,
      })
    end

    local function canEdit()
      if not loaded or busy or (current.blackbox_supported or 0) ~= 1 then return false end
      if pageConfig.kind == "logging" then
        return (current.device or 0) ~= 0 and (current.mode or 0) ~= 0
      end
      return true
    end

    local function updateSaveEnabled()
      if headerHandle then
        headerHandle.setSaveEnabled(canEdit() and not blackboxConfig.same(current, original))
      end
    end

    local function updateEnabled()
      local enabled = canEdit()
      for _, field in ipairs(fields) do
        field:enable(enabled)
      end
      if pageConfig.kind == "config" then
        local device = tonumber(current.device or 0) or 0
        local mode = tonumber(current.mode or 0) or 0
        if controlFields.gracePeriod then
          controlFields.gracePeriod:enable(enabled and device ~= 0 and (mode == 1 or mode == 2))
        end
        if controlFields.initialErase then
          controlFields.initialErase:enable(enabled and device == 1)
        end
        if controlFields.rollingErase then
          controlFields.rollingErase:enable(enabled and device == 1)
        end
      end
      if headerHandle then headerHandle.setReloadEnabled(not busy) end
      updateSaveEnabled()
    end

    local function markDirty()
      updateEnabled()
    end

    local function goBack()
      disposed = true
      if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
      if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
      closeDialog()
      if opts.onBack then opts.onBack() end
    end

    local function finishLoad(focusTarget)
      pendingReads = pendingReads - 1
      if pendingReads > 0 or disposed then return end
      original = blackboxConfig.clone(current)
      loaded = true
      busy = false
      needsRender = true
      renderFocus = focusTarget or "menu"
      closeDialog()
      updateEnabled()
    end

    local function loadData(focusTarget)
      if disposed then return end
      loaded = false
      busy = true
      pendingReads = pageConfig.kind == "config" and 3 or 2
      showProgress(MSG_LOADING_TITLE, MSG_LOADING_BODY)
      updateEnabled()

      bus.publish("msp.request", blackboxConfig.buildReadMessage(function(data)
        if disposed then return end
        current = blackboxConfig.clone(data)
        finishLoad(focusTarget)
      end, function()
        if disposed then return end
        finishLoad(focusTarget)
      end))

      if pageConfig.kind == "config" then
        bus.publish("msp.request", dataflashSummary.buildReadMessage(function(data)
          if disposed then return end
          media.dataflashSupported = hasBit(data.flags, 1)
          finishLoad(focusTarget)
        end, function()
          if disposed then return end
          finishLoad(focusTarget)
        end))
        bus.publish("msp.request", sdcardSummary.buildReadMessage(function(data)
          if disposed then return end
          media.sdcardSupported = hasBit(data.flags, 0)
          finishLoad(focusTarget)
        end, function()
          if disposed then return end
          finishLoad(focusTarget)
        end))
      else
        bus.publish("msp.request", featureConfig.buildReadMessage(function(data)
          if disposed then return end
          featureMask = data.enabledFeatures or 0
          finishLoad(focusTarget)
        end, function()
          if disposed then return end
          finishLoad(focusTarget)
        end))
      end
    end

    local function saveData(focusFn)
      if disposed or not canEdit() then return end
      busy = true
      updateEnabled()
      showProgress(MSG_SAVING_TITLE, MSG_SAVING_BODY)
      bus.publish("msp.request", blackboxConfig.buildWriteMessage(current, function()
        if disposed then return end
        bus.publish("msp.request", eeprom.buildWriteMessage(function()
          if disposed then return end
          original = blackboxConfig.clone(current)
          busy = false
          closeDialog(focusFn)
          updateEnabled()
        end, function()
          if disposed then return end
          busy = false
          closeDialog(focusFn)
          updateEnabled()
        end))
      end, function()
        if disposed then return end
        busy = false
        closeDialog(focusFn)
        updateEnabled()
      end))
    end

    local function confirmSave(focusFn)
      form.openDialog({
        title = MSG_SAVE_TITLE,
        message = MSG_SAVE_BODY,
        buttons = {
          {label = BTN_OK, action = function() saveData(focusFn); return true end},
          {label = BTN_CANCEL, action = function() return true end},
        },
        wakeup = function() end,
        paint = function() end,
      })
    end

    local function confirmReload(focusTarget)
      form.openDialog({
        title = MSG_RELOAD_TITLE,
        message = MSG_RELOAD_BODY,
        buttons = {
          {label = BTN_OK, action = function() loadData(focusTarget); return true end},
          {label = BTN_CANCEL, action = function() return true end},
        },
        wakeup = function() end,
        paint = function() end,
      })
    end

    renderPage = function()
      fields = {}
      controlFields = {}
      form.clear()
      headerHandle = header.build(pageConfig.title, {
        onBack = goBack,
        onSave = function() confirmSave(headerHandle and headerHandle.focusSave) end,
        onReload = function() confirmReload("reload") end,
      })

      if not loaded then
        form.addLine("@i18n(app.modules.blackbox.loading_feature_config)@")
        updateEnabled()
        return
      end

      if pageConfig.kind == "config" then
        local function deviceChoices()
          local choices = {{"@i18n(app.modules.blackbox.device_disabled)@", 0}}
          if media.dataflashSupported then choices[#choices + 1] = {"@i18n(app.modules.blackbox.device_onboard_flash)@", 1} end
          if media.sdcardSupported then choices[#choices + 1] = {"@i18n(app.modules.blackbox.device_sdcard)@", 2} end
          choices[#choices + 1] = {"@i18n(app.modules.blackbox.device_serial_port)@", 3}
          return choices
        end

        local choices = deviceChoices()
        if not choiceHasValue(choices, current.device) then current.device = 0 end

        local line = form.addLine("@i18n(app.modules.blackbox.device)@")
        controlFields.device = form.addChoiceField(line, nil, choices, function()
          return current.device
        end, function(value)
          current.device = value
          markDirty()
        end)
        fields[#fields + 1] = controlFields.device

        line = form.addLine("@i18n(app.modules.blackbox.logging_mode)@")
        controlFields.mode = form.addChoiceField(line, nil, {
          {"@i18n(app.modules.blackbox.mode_off)@", 0},
          {"@i18n(app.modules.blackbox.mode_normal)@", 1},
          {"@i18n(app.modules.blackbox.mode_armed)@", 2},
          {"@i18n(app.modules.blackbox.mode_switch)@", 3},
        }, function()
          return current.mode
        end, function(value)
          current.mode = value
          markDirty()
        end)
        fields[#fields + 1] = controlFields.mode

        line = form.addLine("@i18n(app.modules.blackbox.logging_rate)@")
        controlFields.denom = form.addChoiceField(line, nil, denomChoices(current.denom), function()
          return current.denom
        end, function(value)
          current.denom = value
          markDirty()
        end)
        fields[#fields + 1] = controlFields.denom

        line = form.addLine("@i18n(app.modules.blackbox.disarm_grace_period)@")
        controlFields.gracePeriod = form.addNumberField(line, nil, 0, 255, function()
          return current.gracePeriod
        end, function(value)
          current.gracePeriod = value
          markDirty()
        end)
        controlFields.gracePeriod:suffix("s")
        fields[#fields + 1] = controlFields.gracePeriod

        line = form.addLine("@i18n(app.modules.blackbox.initial_erase)@")
        controlFields.initialErase = form.addNumberField(line, nil, 0, 65535, function()
          return current.initialEraseFreeSpaceKiB
        end, function(value)
          current.initialEraseFreeSpaceKiB = value
          markDirty()
        end)
        controlFields.initialErase:suffix("KiB")
        fields[#fields + 1] = controlFields.initialErase

        line = form.addLine("@i18n(app.modules.blackbox.rolling_erase)@")
        controlFields.rollingErase = form.addBooleanField(line, nil, function()
          return (current.rollingErase or 0) == 1
        end, function(value)
          current.rollingErase = value and 1 or 0
          markDirty()
        end)
        fields[#fields + 1] = controlFields.rollingErase
      else
        for _, def in ipairs(pageConfig.fields or {}) do
          local supported = true
          if def.featureBit then supported = hasBit(featureMask, def.featureBit) end
          if supported then
            local line = form.addLine(def.label)
            local field = form.addBooleanField(line, nil, function()
              return hasBit(current.fields, def.bit)
            end, function(value)
              current.fields = setBit(current.fields, def.bit, value)
              markDirty()
            end)
            fields[#fields + 1] = field
          end
        end
      end

      if not choiceHasValue(denomChoices(current.denom), current.denom) then
        current.denom = 8
      end
      updateEnabled()
    end

    if opts.setEventHandler then
      opts.setEventHandler(function(category, value)
        if closeKey.shouldHandleClose(category, value) then
          goBack()
          return true
        end
        return false
      end)
    end
    if opts.setCleanupHandler then
      opts.setCleanupHandler(function()
        disposed = true
        closeDialog()
      end)
    end
    if opts.setWakeupHandler then
      opts.setWakeupHandler(function()
        if needsRender and renderPage then
          needsRender = false
          renderPage()
          if headerHandle then
            if renderFocus == "reload" then
              headerHandle.focusReload()
            else
              headerHandle.focusMenu()
            end
          end
        else
          updateEnabled()
        end
      end)
    end

    renderPage()
    loadData()
  end

  return page
end

blackbox_edit_page.FEATURE_BIT_GPS = FEATURE_BIT_GPS
blackbox_edit_page.FEATURE_BIT_GOVERNOR = FEATURE_BIT_GOVERNOR
blackbox_edit_page.FEATURE_BIT_ESC_SENSOR = FEATURE_BIT_ESC_SENSOR

package.loaded["rfsuite.app.pages.blackbox_edit_page"] = blackbox_edit_page
return blackbox_edit_page

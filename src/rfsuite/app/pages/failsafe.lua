-- Controls -> Failsafe page.
--
-- Edits MSP_RXFAIL_CONFIG channel fallback mode/value pairs. The value
-- field is enabled only when that channel's mode is SET, matching the
-- original suite's wakeup-driven enable rule.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local rxfail = requireModule("lib/msp_rxfail_config.lua")

local PAGE_TITLE = "@i18n(app.modules.failsafe.name)@"
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
local MODE_SET = 2

local CHANNEL_LABELS = {
  "@i18n(app.modules.failsafe.roll)@",
  "@i18n(app.modules.failsafe.pitch)@",
  "@i18n(app.modules.failsafe.yaw)@",
  "@i18n(app.modules.failsafe.collective)@",
  "@i18n(app.modules.failsafe.throttle)@",
  "@i18n(app.modules.failsafe.aux1)@",
  "@i18n(app.modules.failsafe.aux2)@",
  "@i18n(app.modules.failsafe.aux3)@",
  "@i18n(app.modules.failsafe.aux4)@",
  "@i18n(app.modules.failsafe.aux5)@",
  "@i18n(app.modules.failsafe.aux6)@",
  "@i18n(app.modules.failsafe.aux7)@",
  "@i18n(app.modules.failsafe.aux8)@",
  "@i18n(app.modules.failsafe.aux9)@",
  "@i18n(app.modules.failsafe.aux10)@",
  "@i18n(app.modules.failsafe.aux11)@",
  "@i18n(app.modules.failsafe.aux12)@",
  "@i18n(app.modules.failsafe.aux13)@",
}

local MODE_OPTIONS = {
  {"@i18n(api.RXFAIL_CONFIG.tbl_auto)@", 0},
  {"@i18n(api.RXFAIL_CONFIG.tbl_hold)@", 1},
  {"@i18n(api.RXFAIL_CONFIG.tbl_set)@", 2},
}

local function cloneChannels(channels)
  local out = {}
  for i = 1, rxfail.CHANNEL_COUNT do
    local channel = channels and channels[i] or nil
    out[i] = {
      mode = channel and channel.mode or 0,
      value = channel and channel.value or 1500,
    }
  end
  return out
end

local function changed(current, original, index)
  local a, b = current[index], original[index]
  if not a or not b then return true end
  return a.mode ~= b.mode or a.value ~= b.value
end

local function open(opts)
  local disposed = false
  local headerHandle = nil
  local dialog = nil
  local loaded = false
  local busy = false
  local dirty = false
  local channels = cloneChannels()
  local original = cloneChannels()
  local fields = {}

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

  -- Save only lights up once the page has finished loading, isn't mid
  -- save/reload, and the pilot has actually changed a channel -- see
  -- markDirty() below, called from both field setters.
  local function updateSaveEnabled()
    if not headerHandle then return end
    headerHandle.setSaveEnabled(not busy and loaded and dirty)
  end

  local function markDirty()
    if dirty then return end
    dirty = true
    updateSaveEnabled()
  end

  local function applyBusy(value)
    busy = value == true
    updateSaveEnabled()
    if headerHandle then
      headerHandle.setReloadEnabled(not busy)
    end
    for _, pair in ipairs(fields) do
      if pair.mode then pair.mode:enable(not busy and loaded) end
      if pair.value then pair.value:enable(not busy and loaded and channels[pair.index].mode == MODE_SET) end
    end
  end

  local function refreshEnabled()
    if busy then return end
    for _, pair in ipairs(fields) do
      if pair.value then pair.value:enable(loaded and channels[pair.index].mode == MODE_SET) end
    end
  end

  local function goBack()
    disposed = true
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    closeDialog()
    if opts.onBack then opts.onBack() end
  end

  local function loadData(focusFn)
    if disposed then return end
    loaded = false
    applyBusy(true)
    showProgress(MSG_LOADING_TITLE, MSG_LOADING_BODY)
    bus.publish("msp.request", rxfail.buildReadMessage(function(data)
      if disposed then return end
      channels = cloneChannels(data.channels)
      original = cloneChannels(data.channels)
      loaded = true
      dirty = false
      applyBusy(false)
      closeDialog(focusFn)
      if form.invalidate then form.invalidate() end
    end, function()
      if disposed then return end
      applyBusy(false)
      closeDialog(focusFn)
    end))
  end

  local function saveData(focusFn)
    if disposed or not loaded then return end
    applyBusy(true)
    showProgress(MSG_SAVING_TITLE, MSG_SAVING_BODY)

    local index = 1
    local function writeNext()
      if disposed then return end
      while index <= rxfail.CHANNEL_COUNT and not changed(channels, original, index) do
        index = index + 1
      end
      if index > rxfail.CHANNEL_COUNT then
        bus.publish("msp.request", eeprom.buildWriteMessage(function()
          if disposed then return end
          original = cloneChannels(channels)
          dirty = false
          applyBusy(false)
          closeDialog(focusFn)
        end, function()
          if disposed then return end
          applyBusy(false)
          closeDialog(focusFn)
        end))
        return
      end
      local writeIndex = index
      index = index + 1
      bus.publish("msp.request", rxfail.buildWriteMessage(writeIndex, channels[writeIndex], writeNext, function()
        if disposed then return end
        applyBusy(false)
        closeDialog(focusFn)
      end))
    end

    writeNext()
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

  local function confirmReload(focusFn)
    form.openDialog({
      title = MSG_RELOAD_TITLE,
      message = MSG_RELOAD_BODY,
      buttons = {
        {label = BTN_OK, action = function() loadData(focusFn); return true end},
        {label = BTN_CANCEL, action = function() return true end},
      },
      wakeup = function() end,
      paint = function() end,
    })
  end

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {
    onBack = goBack,
    onSave = function() confirmSave(headerHandle and headerHandle.focusSave) end,
    onReload = function() confirmReload(headerHandle and headerHandle.focusReload) end,
  })

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
    opts.setWakeupHandler(refreshEnabled)
  end

  local slotsHint = {0, 0}
  for i = 1, #CHANNEL_LABELS do
    local line = form.addLine(CHANNEL_LABELS[i])
    local slots = form.getFieldSlots(line, slotsHint)
    local pair = {index = i}
    pair.mode = form.addChoiceField(line, slots[1], MODE_OPTIONS,
      function() return channels[i].mode end,
      function(value)
        markDirty()
        channels[i].mode = value
        refreshEnabled()
      end)
    pair.value = form.addNumberField(line, slots[2], 875, 2125,
      function() return channels[i].value end,
      function(value) markDirty(); channels[i].value = value end)
    pair.value:suffix("us")
    if pair.value.step then pair.value:step(5) end
    pair.mode:enable(false)
    pair.value:enable(false)
    fields[#fields + 1] = pair
  end

  loadData()
end

return {open = open}

-- Tools -> Copy Profiles page.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local copyProfile = requireModule("lib/msp_copy_profile.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")

local PAGE_TITLE = "@i18n(app.modules.copyprofiles.name)@"
local BTN_OK = "@i18n(app.btn_ok_long)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVING_TITLE = "@i18n(app.msg_saving)@"
local MSG_SAVING_BODY = "@i18n(app.msg_saving_settings)@"
local MSG_SAVE_TITLE = "@i18n(app.modules.copyprofiles.msgbox_save)@"
local MSG_SAVE_BODY = "@i18n(app.modules.copyprofiles.msgbox_msg)@"

local PROFILE_TYPE_CHOICES = {
  {"@i18n(app.modules.copyprofiles.profile_type_pid)@", 0},
  {"@i18n(app.modules.copyprofiles.profile_type_rate)@", 1},
}

local PROFILE_CHOICES = {
  {"1", 0}, {"2", 1}, {"3", 2}, {"4", 3}, {"5", 4}, {"6", 5},
}

local function clampProfile(value)
  value = math.floor(tonumber(value or 0) or 0)
  if value < 0 then return 0 end
  if value > 5 then return 5 end
  return value
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle = nil
  local dialog = nil
  local busy = false
  local fields = {}
  local fieldsEnabled = nil
  local saveEnabled = nil
  local data = {
    profileType = 0,
    sourceProfile = 0,
    destProfile = 1,
  }

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

  local function showProgress()
    dialog = progressDialog.open({
      title = MSG_SAVING_TITLE,
      message = MSG_SAVING_BODY,
    })
  end

  local function updateEnabled()
    local nextFieldsEnabled = not busy
    if fieldsEnabled ~= nextFieldsEnabled then
      fieldsEnabled = nextFieldsEnabled
      for _, field in ipairs(fields) do
        field:enable(nextFieldsEnabled)
      end
    end

    local nextSaveEnabled = nextFieldsEnabled and data.sourceProfile ~= data.destProfile
    if headerHandle then
      if saveEnabled ~= nextSaveEnabled then
        saveEnabled = nextSaveEnabled
        headerHandle.setSaveEnabled(nextSaveEnabled)
      end
    end
  end

  local function goBack()
    if disposed then return end
    disposed = true
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    closeDialog()
    fields = nil
    if opts.onBack then opts.onBack() end
  end

  local function finishSave(focusFn)
    if disposed then return end
    busy = false
    closeDialog(focusFn)
    updateEnabled()
  end

  local function save(focusFn)
    if disposed or busy or data.sourceProfile == data.destProfile then return end
    busy = true
    updateEnabled()
    showProgress()
    bus.publish("msp.request", copyProfile.buildWriteMessage(data.profileType, data.destProfile, data.sourceProfile, function()
      if disposed then return end
      bus.publish("msp.request", eeprom.buildWriteMessage(function()
        finishSave(focusFn)
      end, function()
        finishSave(focusFn)
      end))
    end, function()
      finishSave(focusFn)
    end))
  end

  local function confirmSave(focusFn)
    form.openDialog({
      title = MSG_SAVE_TITLE,
      message = MSG_SAVE_BODY,
      buttons = {
        {label = BTN_OK, action = function() save(focusFn); return true end},
        {label = BTN_CANCEL, action = function() return true end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  local function buildPage()
    form.clear()
    fields = {}
    fieldsEnabled = nil
    saveEnabled = nil
    headerHandle = header.build(PAGE_TITLE, {
      onBack = goBack,
      onSave = function() confirmSave(headerHandle and headerHandle.focusSave) end,
    })
    headerHandle.setReloadEnabled(false)

    local line = form.addLine("@i18n(app.modules.copyprofiles.profile_type)@")
    fields[#fields + 1] = form.addChoiceField(line, nil, PROFILE_TYPE_CHOICES,
      function() return data.profileType end,
      function(value)
        data.profileType = tonumber(value) or 0
        updateEnabled()
      end)

    line = form.addLine("@i18n(app.modules.copyprofiles.source_profile)@")
    fields[#fields + 1] = form.addChoiceField(line, nil, PROFILE_CHOICES,
      function() return data.sourceProfile end,
      function(value)
        data.sourceProfile = clampProfile(value)
        updateEnabled()
      end)

    line = form.addLine("@i18n(app.modules.copyprofiles.dest_profile)@")
    fields[#fields + 1] = form.addChoiceField(line, nil, PROFILE_CHOICES,
      function() return data.destProfile end,
      function(value)
        data.destProfile = clampProfile(value)
        updateEnabled()
      end)

    updateEnabled()
  end

  buildPage()

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if closeKey.shouldHandleClose(category, value) then
        goBack()
        return true
      end
      return false
    end)
  end
  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      updateEnabled()
    end)
  end
  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      disposed = true
      closeDialog()
      fields = nil
    end)
  end
end

return {open = open}

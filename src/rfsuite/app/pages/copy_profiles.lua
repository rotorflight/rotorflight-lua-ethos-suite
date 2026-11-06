-- Tools -> Copy Profiles page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local statusMsp = requireModule("lib/msp_status.lua")
local copyProfile = requireModule("lib/msp_copy_profile.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")

local PAGE_TITLE = "@i18n(app.modules.copyprofiles.name)@"
local BTN_OK = "@i18n(app.btn_ok_long)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVING_TITLE = "@i18n(app.msg_saving)@"
local MSG_SAVING_BODY = "@i18n(app.msg_saving_settings)@"
local MSG_SAVE_TITLE = "@i18n(app.modules.copyprofiles.msgbox_save)@"
-- The confirmation names what is copied and what is overwritten (#2349). The arguments are the
-- profile type, the source number and the destination number, the destination once more.
local MSG_COPY_TITLE = "@i18n(app.modules.copyprofiles.msgbox_copy_title)@"
local MSG_COPY_FMT = "@i18n(app.modules.copyprofiles.msgbox_copy_fmt)@"
local MSG_SAVE_BODY = "@i18n(app.modules.copyprofiles.msgbox_msg)@"

local PROFILE_TYPE_CHOICES = {
  {"@i18n(app.modules.copyprofiles.profile_type_pid)@", 0},
  {"@i18n(app.modules.copyprofiles.profile_type_rate)@", 1},
}

local PROFILE_TYPE_RATE = 1
local MAX_PROFILE_COUNT = 6

-- The profiles of the chosen type that the board has (MSP_STATUS reports both counts), as Select
-- Profile does it. A copy onto a profile the board does not have is acknowledged and changes
-- nothing, so the choices are the board's own (#2661).
local function countFor(status, profileType)
  local count = profileType == PROFILE_TYPE_RATE and status.control_rate_profile_count or status.pid_profile_count
  count = math.floor(tonumber(count) or 0)
  if count < 1 then return 1 end
  if count > MAX_PROFILE_COUNT then return MAX_PROFILE_COUNT end
  return count
end

local function profileChoices(count)
  local choices = {}
  for i = 1, count do choices[#choices + 1] = {tostring(i), i - 1} end
  return choices
end

local function clampProfile(value, count)
  value = math.floor(tonumber(value or 0) or 0)
  if value < 0 then return 0 end
  if value > count - 1 then return count - 1 end
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
  -- The board's profile counts, once read. Until then no profile can be chosen and Save stays off.
  local status = nil
  local loaded = false
  -- The profile type changed: the lists of profiles are rebuilt on the next wakeup.
  local pendingRebuild = false
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

    local nextSaveEnabled = loaded and nextFieldsEnabled and data.sourceProfile ~= data.destProfile
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
    if disposed or busy or not loaded or data.sourceProfile == data.destProfile then return end
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
    local typeName = PROFILE_TYPE_CHOICES[data.profileType + 1] and PROFILE_TYPE_CHOICES[data.profileType + 1][1] or ""
    form.openDialog({
      title = MSG_COPY_TITLE,
      message = string.format(MSG_COPY_FMT, typeName, data.sourceProfile + 1, data.destProfile + 1, data.destProfile + 1),
      buttons = {
        {label = BTN_OK, action = function() save(focusFn); return true end},
        {label = BTN_CANCEL, action = function() return true end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  -- The three lines. The profile lists follow the chosen type and the board's counts.
  local function addFields()
    local count = countFor(status, data.profileType)
    data.sourceProfile = clampProfile(data.sourceProfile, count)
    data.destProfile = clampProfile(data.destProfile, count)
    local choices = profileChoices(count)

    local line = form.addLine("@i18n(app.modules.copyprofiles.profile_type)@")
    fields[#fields + 1] = form.addChoiceField(line, nil, PROFILE_TYPE_CHOICES,
      function() return data.profileType end,
      function(value)
        data.profileType = tonumber(value) or 0
        pendingRebuild = true
        updateEnabled()
      end)

    line = form.addLine("@i18n(app.modules.copyprofiles.source_profile)@")
    fields[#fields + 1] = form.addChoiceField(line, nil, choices,
      function() return data.sourceProfile end,
      function(value)
        data.sourceProfile = clampProfile(value, countFor(status, data.profileType))
        updateEnabled()
      end)

    line = form.addLine("@i18n(app.modules.copyprofiles.dest_profile)@")
    fields[#fields + 1] = form.addChoiceField(line, nil, choices,
      function() return data.destProfile end,
      function(value)
        data.destProfile = clampProfile(value, countFor(status, data.profileType))
        updateEnabled()
      end)
  end

  -- Clears the lines and builds them again for the current counts and type.
  local function rebuildFields()
    pendingRebuild = false
    form.clear()
    fields = {}
    fieldsEnabled = nil
    addFields()
    updateEnabled()
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
    if loaded then addFields() end
    updateEnabled()
  end

  buildPage()

  -- The board's counts, read on open (as Select Profile does). Lines are built once they are known.
  bus.publish("msp.request", statusMsp.buildReadMessage(function(data)
    if disposed then return end
    if not data then return end
    status = data
    loaded = true
    rebuildFields()
  end, function()
    if disposed then return end
  end))

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
      if pendingRebuild and loaded and not disposed then rebuildFields() end
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

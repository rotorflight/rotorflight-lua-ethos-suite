-- Developer settings and logging toggles.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local settingsStore = requireModule("lib/settings_store.lua")
local mspApiVersion = requireModule("lib/msp_api_version.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.txt_developer)@ / @i18n(app.modules.settings.developer_settings)@"

-- Simulator-only (see tasks/session.lua's runHandshake() and
-- lib/msp_api_version.lua): index 0 is the "wrong firmware family" case,
-- index 1..N are lib/msp_api_version.lua's own SIMULATABLE_VERSIONS --
-- extend that list, not this one, when a new MSP API version ships.
local SIMULATED_API_VERSION_CHOICES = {
  {"@i18n(app.modules.settings.simulated_api_version_invalid)@", 0},
}
for i, version in ipairs(mspApiVersion.SIMULATABLE_VERSIONS) do
  SIMULATED_API_VERSION_CHOICES[#SIMULATED_API_VERSION_CHOICES + 1] = {version, i}
end
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle
  local settings = settingsStore.load()
  local original = settingsStore.clone(settings)

  local function isDirty()
    return not settingsStore.same(settings, original)
  end

  local function updateSaveEnabled()
    if headerHandle then headerHandle.setSaveEnabled(isDirty()) end
  end

  local function goBack()
    if disposed then return end
    disposed = true
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    settings = nil
    original = nil
    if opts.onBack then opts.onBack() end
  end

  local function save(focusFn)
    if disposed then return end
    settingsStore.save(settings)
    original = settingsStore.clone(settings)
    bus.publish("settings.update", settingsStore.clone(settings))
    updateSaveEnabled()
    if focusFn then focusFn() end
  end

  local function confirmSave(focusFn)
    if not isDirty() then
      if focusFn then focusFn() end
      return
    end
    form.openDialog({
      title = MSG_SAVE_TITLE,
      message = MSG_SAVE_BODY,
      buttons = {
        {label = BTN_OK, action = function() save(focusFn); return true end},
        {label = BTN_CANCEL, action = function() if focusFn then focusFn() end; return true end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {
    onBack = goBack,
    onSave = function() confirmSave(headerHandle and headerHandle.focusSave) end,
  })

  settings.developer = settings.developer or {}

  local line = form.addLine("@i18n(app.modules.settings.debug_logs)@")
  form.addBooleanField(line, nil,
    function()
      return settings and settings.developer and settings.developer.debug_logs == true
    end,
    function(value)
      if not settings then return end
      settings.developer = settings.developer or {}
      settings.developer.debug_logs = value == true
      updateSaveEnabled()
    end)

  line = form.addLine("@i18n(app.modules.settings.log_msp_data)@")
  form.addBooleanField(line, nil,
    function()
      return settings and settings.developer and settings.developer.log_msp == true
    end,
    function(value)
      if not settings then return end
      settings.developer = settings.developer or {}
      settings.developer.log_msp = value == true
      updateSaveEnabled()
    end)

  line = form.addLine("@i18n(app.modules.settings.memory_logs)@")
  form.addBooleanField(line, nil,
    function()
      return settings and settings.developer and settings.developer.memory_logs == true
    end,
    function(value)
      if not settings then return end
      settings.developer = settings.developer or {}
      settings.developer.memory_logs = value == true
      updateSaveEnabled()
    end)

  line = form.addLine("@i18n(app.modules.settings.simulated_api_version)@")
  form.addChoiceField(line, nil, SIMULATED_API_VERSION_CHOICES,
    function()
      local value = settings and settings.developer and settings.developer.simulated_api_version
      for i, version in ipairs(mspApiVersion.SIMULATABLE_VERSIONS) do
        if version == value then return i end
      end
      return 0
    end,
    function(value)
      if not settings then return end
      settings.developer = settings.developer or {}
      settings.developer.simulated_api_version = mspApiVersion.SIMULATABLE_VERSIONS[value] or "invalid"
      updateSaveEnabled()
    end)

  updateSaveEnabled()

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if closeKey.shouldHandleClose(category, value) then
        goBack()
        return true
      end
      return false
    end)
  end
  if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      disposed = true
      settings = nil
      original = nil
    end)
  end
end

return {open = open}

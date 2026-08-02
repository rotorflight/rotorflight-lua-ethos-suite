-- Settings -> General.

local bus = assert(loadfile("lib/bus.lua"))()
local closeKey = assert(loadfile("app/close_key.lua"))()
local header = assert(loadfile("app/header.lua"))()
local settingsStore = assert(loadfile("lib/settings_store.lua"))()

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.txt_general)@"

local TXBATT_CHOICES = {
  {"@i18n(app.modules.settings.tx_battery_default)@", 0},
  {"@i18n(app.modules.settings.tx_battery_text)@", 1},
  {"@i18n(app.modules.settings.tx_battery_digital)@", 2},
}

local TEMPERATURE_UNIT_CHOICES = {
  {"Celsius", 0},
  {"Fahrenheit", 1},
}

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

  settings.general = settings.general or {}

  local displayPanel = form.addExpansionPanel("@i18n(app.modules.settings.dashboard_display_panel)@")
  displayPanel:open(true)

  form.addChoiceField(displayPanel:addLine("@i18n(app.modules.settings.tx_battery_options)@"), nil, TXBATT_CHOICES,
    function()
      return settings and settings.general and settings.general.txbatt_type or 0
    end,
    function(value)
      if not settings then return end
      settings.general = settings.general or {}
      settings.general.txbatt_type = tonumber(value) or 0
      updateSaveEnabled()
    end)

  form.addChoiceField(displayPanel:addLine("@i18n(app.modules.settings.temperature_unit)@"), nil, TEMPERATURE_UNIT_CHOICES,
    function()
      return settings and settings.general and settings.general.temperature_unit or 0
    end,
    function(value)
      if not settings then return end
      settings.general = settings.general or {}
      settings.general.temperature_unit = tonumber(value) or 0
      updateSaveEnabled()
    end)

  local developmentPanel = form.addExpansionPanel("@i18n(app.modules.settings.txt_developer)@")
  developmentPanel:open(false)

  settings.developer = settings.developer or {}

  form.addBooleanField(developmentPanel:addLine("@i18n(app.modules.settings.developer_mode)@"), nil,
    function()
      return settings and settings.developer and settings.developer.developer_mode == true
    end,
    function(value)
      if not settings then return end
      settings.developer = settings.developer or {}
      settings.developer.developer_mode = value == true
      updateSaveEnabled()
    end)

  local safetyPanel = form.addExpansionPanel("@i18n(app.modules.settings.panel_safety_prompts)@")
  safetyPanel:open(false)

  form.addBooleanField(safetyPanel:addLine("@i18n(app.modules.settings.txt_save_confirm)@"), nil,
    function()
      return settings and settings.general and settings.general.save_confirm ~= false
    end,
    function(value)
      if not settings then return end
      settings.general = settings.general or {}
      settings.general.save_confirm = value == true
      updateSaveEnabled()
    end)

  form.addBooleanField(safetyPanel:addLine("@i18n(app.modules.settings.txt_reload_confirm)@"), nil,
    function()
      return settings and settings.general and settings.general.reload_confirm ~= false
    end,
    function(value)
      if not settings then return end
      settings.general = settings.general or {}
      settings.general.reload_confirm = value == true
      updateSaveEnabled()
    end)

  local integrationPanel = form.addExpansionPanel("@i18n(app.modules.settings.panel_integration)@")
  integrationPanel:open(false)
  form.addStaticText(integrationPanel:addLine(""), nil, "@i18n(app.modules.settings.panel_coming_soon)@")

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

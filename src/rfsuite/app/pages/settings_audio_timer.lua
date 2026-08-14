-- Settings -> Audio -> Timer.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local settingsStore = requireModule("lib/settings_store.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@ / @i18n(app.modules.settings.txt_audio_timer)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"

local ELAPSED_CHOICES = {
  {"@i18n(app.modules.settings.timer_elapsed_beep)@", 0},
  {"@i18n(app.modules.settings.timer_elapsed_multi_beep)@", 1},
  {"@i18n(app.modules.settings.timer_elapsed_elapsed)@", 2},
  {"@i18n(app.modules.settings.timer_elapsed_seconds)@", 3},
}

local INTERVAL_CHOICES = {
  {"10s", 10},
  {"15s", 15},
  {"30s", 30},
}

local PERIOD_CHOICES = {
  {"30s", 30},
  {"60s", 60},
  {"90s", 90},
}

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle
  local settings = settingsStore.load()
  local original = settingsStore.clone(settings)
  local fields = {}

  local function isDirty()
    return not settingsStore.same(settings, original)
  end

  local function updateSaveEnabled()
    if headerHandle then headerHandle.setSaveEnabled(isDirty()) end
  end

  local function setEnabled(field, enabled)
    if field and field.enable then field:enable(enabled == true) end
  end

  local function timerEnabled()
    return settings and settings.timer and settings.timer.timeraudioenable == true
  end

  local function updateTimerFields()
    local enabled = timerEnabled()
    local preEnabled = enabled and settings.timer.prealerton == true
    local postEnabled = enabled and settings.timer.postalerton == true
    setEnabled(fields.elapsedalertmode, enabled)
    setEnabled(fields.prealerton, enabled)
    setEnabled(fields.prealertperiod, preEnabled)
    setEnabled(fields.prealertinterval, preEnabled)
    setEnabled(fields.postalerton, enabled)
    setEnabled(fields.postalertperiod, postEnabled)
    setEnabled(fields.postalertinterval, postEnabled)
  end

  local function goBack()
    if disposed then return end
    disposed = true
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    settings = nil
    original = nil
    fields = nil
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

  local line = form.addLine("@i18n(app.modules.settings.timer_alerting)@")
  fields.timeraudioenable = form.addBooleanField(line, nil,
    function()
      return settings and settings.timer and settings.timer.timeraudioenable == true
    end,
    function(value)
      if not settings then return end
      settings.timer.timeraudioenable = value == true
      updateTimerFields()
      updateSaveEnabled()
    end)

  line = form.addLine("@i18n(app.modules.settings.timer_elapsed_alert_mode)@")
  fields.elapsedalertmode = form.addChoiceField(line, nil, ELAPSED_CHOICES,
    function()
      return settings and settings.timer and settings.timer.elapsedalertmode or 0
    end,
    function(value)
      if not settings then return end
      settings.timer.elapsedalertmode = value or 0
      updateSaveEnabled()
    end)

  local prePanel = form.addExpansionPanel("@i18n(app.modules.settings.timer_prealert_options)@")
  prePanel:open(settings.timer.prealerton == true)
  fields.prealerton = form.addBooleanField(prePanel:addLine("@i18n(app.modules.settings.timer_prealert)@"), nil,
    function()
      return settings and settings.timer and settings.timer.prealerton == true
    end,
    function(value)
      if not settings then return end
      settings.timer.prealerton = value == true
      updateTimerFields()
      updateSaveEnabled()
    end)
  fields.prealertperiod = form.addChoiceField(prePanel:addLine("@i18n(app.modules.settings.timer_alert_period)@"), nil, PERIOD_CHOICES,
    function()
      return settings and settings.timer and settings.timer.prealertperiod or 30
    end,
    function(value)
      if not settings then return end
      settings.timer.prealertperiod = value or 30
      updateSaveEnabled()
    end)
  fields.prealertinterval = form.addChoiceField(prePanel:addLine("@i18n(app.modules.settings.timer_alert_interval)@"), nil, INTERVAL_CHOICES,
    function()
      return settings and settings.timer and settings.timer.prealertinterval or 10
    end,
    function(value)
      if not settings then return end
      settings.timer.prealertinterval = value or 10
      updateSaveEnabled()
    end)

  local postPanel = form.addExpansionPanel("@i18n(app.modules.settings.timer_postalert_options)@")
  postPanel:open(settings.timer.postalerton == true)
  fields.postalerton = form.addBooleanField(postPanel:addLine("@i18n(app.modules.settings.timer_postalert)@"), nil,
    function()
      return settings and settings.timer and settings.timer.postalerton == true
    end,
    function(value)
      if not settings then return end
      settings.timer.postalerton = value == true
      updateTimerFields()
      updateSaveEnabled()
    end)
  fields.postalertperiod = form.addChoiceField(postPanel:addLine("@i18n(app.modules.settings.timer_alert_period)@"), nil, PERIOD_CHOICES,
    function()
      return settings and settings.timer and settings.timer.postalertperiod or 30
    end,
    function(value)
      if not settings then return end
      settings.timer.postalertperiod = value or 30
      updateSaveEnabled()
    end)
  fields.postalertinterval = form.addChoiceField(postPanel:addLine("@i18n(app.modules.settings.timer_postalert_interval)@"), nil, INTERVAL_CHOICES,
    function()
      return settings and settings.timer and settings.timer.postalertinterval or 10
    end,
    function(value)
      if not settings then return end
      settings.timer.postalertinterval = value or 10
      updateSaveEnabled()
    end)

  updateTimerFields()
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
      fields = nil
    end)
  end
end

return {open = open}

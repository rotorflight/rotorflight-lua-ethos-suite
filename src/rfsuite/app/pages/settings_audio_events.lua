-- Settings -> Audio -> Events.

local bus = assert(loadfile("lib/bus.lua"))()
local closeKey = assert(loadfile("app/close_key.lua"))()
local header = assert(loadfile("app/header.lua"))()
local settingsStore = assert(loadfile("lib/settings_store.lua"))()

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@ / @i18n(app.modules.settings.txt_audio_events)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"

local FUEL_CHOICES = {
  {"@i18n(app.modules.settings.fuel_callout_default)@", 0},
  {"@i18n(app.modules.settings.fuel_callout_5)@", 5},
  {"@i18n(app.modules.settings.fuel_callout_10)@", 10},
  {"@i18n(app.modules.settings.fuel_callout_20)@", 20},
  {"@i18n(app.modules.settings.fuel_callout_25)@", 25},
  {"@i18n(app.modules.settings.fuel_callout_50)@", 50},
}

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle
  local settings = settingsStore.load()
  local original = settingsStore.clone(settings)
  local eventFields = {}

  local function isDirty()
    return not settingsStore.same(settings, original)
  end

  local function updateSaveEnabled()
    if headerHandle then headerHandle.setSaveEnabled(isDirty()) end
  end

  local function setEnabled(field, enabled)
    if field and field.enable then field:enable(enabled == true) end
  end

  local function updateFuelFields()
    local enabled = settings and settings.events and settings.events.smartfuel == true
    setEnabled(eventFields.smartfuelcallout, enabled)
    setEnabled(eventFields.smartfuelrepeats, enabled)
    setEnabled(eventFields.smartfuelhaptic, enabled)
  end

  local function updateVoltageFields()
    local enabled = settings and settings.events and settings.events.voltage == true
    setEnabled(eventFields.voltageRepeat, enabled)
  end

  local function updateEscFields()
    local enabled = settings and settings.events and settings.events.temp_esc == true
    setEnabled(eventFields.escTempThreshold, enabled)
  end

  local function updateBecRxFields()
    local becEnabled = settings and settings.events and settings.events.bec_voltage == true
    local rxEnabled = settings and settings.events and settings.events.rx_voltage == true
    setEnabled(eventFields.becVoltageThreshold, becEnabled)
    setEnabled(eventFields.rxVoltageThreshold, rxEnabled)
  end

  local function goBack()
    if disposed then return end
    disposed = true
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    settings = nil
    original = nil
    eventFields = nil
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

  local function addBool(panel, label, key, afterChange)
    local line = panel:addLine(label)
    return form.addBooleanField(line, nil,
      function()
        return settings and settings.events and settings.events[key] == true
      end,
      function(value)
        if not settings then return end
        settings.events[key] = value == true
        if afterChange then afterChange() end
        updateSaveEnabled()
      end)
  end

  form.clear()
  headerHandle = header.build(PAGE_TITLE, {
    onBack = goBack,
    onSave = function() confirmSave(headerHandle and headerHandle.focusSave) end,
  })

  local statePanel = form.addExpansionPanel("@i18n(app.modules.settings.audio_event_state)@")
  statePanel:open(true)
  addBool(statePanel, "@i18n(app.modules.settings.arming_flags)@", "armflags")
  addBool(statePanel, "@i18n(app.modules.settings.governor_state)@", "governor")
  addBool(statePanel, "@i18n(app.modules.settings.pid_profile)@", "pid_profile")
  addBool(statePanel, "@i18n(app.modules.settings.rate_profile)@", "rate_profile")
  addBool(statePanel, "@i18n(app.modules.settings.battery_profile_event)@", "battery_profile")

  local adjPanel = form.addExpansionPanel("@i18n(app.modules.settings.adj_callouts)@")
  adjPanel:open(settings.events.adj_f == true or settings.events.adj_v == true)
  addBool(adjPanel, "@i18n(app.modules.settings.adj_function)@", "adj_f")
  addBool(adjPanel, "@i18n(app.modules.settings.adj_value)@", "adj_v")

  local escPanel = form.addExpansionPanel("@i18n(app.modules.settings.esc_temperature)@")
  escPanel:open(settings.events.temp_esc == true)
  addBool(escPanel, "@i18n(app.modules.settings.esc_temperature)@", "temp_esc", updateEscFields)
  local line = escPanel:addLine("@i18n(app.modules.settings.esc_threshold)@")
  eventFields.escTempThreshold = form.addNumberField(line, nil, 60, 300,
    function()
      return settings and settings.events and settings.events.escalertvalue or 90
    end,
    function(value)
      if not settings then return end
      settings.events.escalertvalue = value or 90
      updateSaveEnabled()
    end)
  if eventFields.escTempThreshold and eventFields.escTempThreshold.suffix then eventFields.escTempThreshold:suffix("deg") end

  local becPanel = form.addExpansionPanel("@i18n(app.modules.settings.bec_rx_voltage)@")
  becPanel:open(settings.events.bec_voltage == true or settings.events.rx_voltage == true)
  addBool(becPanel, "@i18n(app.modules.settings.bec_voltage_alert)@", "bec_voltage", updateBecRxFields)
  line = becPanel:addLine("@i18n(app.modules.settings.bec_voltage_threshold)@")
  eventFields.becVoltageThreshold = form.addNumberField(line, nil, 30, 150,
    function()
      local value = settings and settings.events and settings.events.becalertvalue or 6.5
      return math.floor((value * 10) + 0.5)
    end,
    function(value)
      if not settings then return end
      settings.events.becalertvalue = (value or 65) / 10
      updateSaveEnabled()
    end)
  if eventFields.becVoltageThreshold then
    if eventFields.becVoltageThreshold.decimals then eventFields.becVoltageThreshold:decimals(1) end
    if eventFields.becVoltageThreshold.suffix then eventFields.becVoltageThreshold:suffix("V") end
  end
  addBool(becPanel, "@i18n(app.modules.settings.rx_voltage_alert)@", "rx_voltage", updateBecRxFields)
  line = becPanel:addLine("@i18n(app.modules.settings.rx_voltage_threshold)@")
  eventFields.rxVoltageThreshold = form.addNumberField(line, nil, 30, 150,
    function()
      local value = settings and settings.events and settings.events.rxalertvalue or 7.4
      return math.floor((value * 10) + 0.5)
    end,
    function(value)
      if not settings then return end
      settings.events.rxalertvalue = (value or 74) / 10
      updateSaveEnabled()
    end)
  if eventFields.rxVoltageThreshold then
    if eventFields.rxVoltageThreshold.decimals then eventFields.rxVoltageThreshold:decimals(1) end
    if eventFields.rxVoltageThreshold.suffix then eventFields.rxVoltageThreshold:suffix("V") end
  end

  local voltagePanel = form.addExpansionPanel("@i18n(app.modules.settings.voltage)@")
  voltagePanel:open(settings.events.voltage == true)
  addBool(voltagePanel, "@i18n(app.modules.settings.low_voltage_alert)@", "voltage", updateVoltageFields)
  local line = voltagePanel:addLine("@i18n(app.modules.settings.alert_repeat_interval)@")
  eventFields.voltageRepeat = form.addNumberField(line, nil, 5, 120,
    function()
      return settings and settings.events and settings.events.voltage_repeat_interval or 10
    end,
    function(value)
      if not settings then return end
      settings.events.voltage_repeat_interval = value or 10
      updateSaveEnabled()
    end)
  if eventFields.voltageRepeat and eventFields.voltageRepeat.suffix then eventFields.voltageRepeat:suffix("s") end

  local fuelPanel = form.addExpansionPanel("@i18n(app.modules.settings.fuel)@")
  fuelPanel:open(settings.events.smartfuel == true)
  addBool(fuelPanel, "@i18n(app.modules.settings.fuel)@", "smartfuel", updateFuelFields)
  line = fuelPanel:addLine("@i18n(app.modules.settings.fuel_callout_percent)@")
  eventFields.smartfuelcallout = form.addChoiceField(line, nil, FUEL_CHOICES,
    function()
      return settings and settings.events and settings.events.smartfuelcallout or 10
    end,
    function(value)
      if not settings then return end
      settings.events.smartfuelcallout = value or 10
      updateSaveEnabled()
    end)
  line = fuelPanel:addLine("@i18n(app.modules.settings.fuel_repeats_below)@")
  eventFields.smartfuelrepeats = form.addNumberField(line, nil, 1, 10,
    function()
      return settings and settings.events and settings.events.smartfuelrepeats or 1
    end,
    function(value)
      if not settings then return end
      settings.events.smartfuelrepeats = value or 1
      updateSaveEnabled()
    end)
  if eventFields.smartfuelrepeats and eventFields.smartfuelrepeats.suffix then eventFields.smartfuelrepeats:suffix("x") end
  eventFields.smartfuelhaptic = addBool(fuelPanel, "@i18n(app.modules.settings.fuel_haptic_below)@", "smartfuelhaptic")

  -- Plays SD:/audio/<model name>.wav (spaces also tried as underscores)
  -- once per connect, if the pilot has recorded one -- see
  -- tasks/audio_events.lua's announceCraftName().
  local otherPanel = form.addExpansionPanel("@i18n(app.modules.settings.model_announcement)@")
  otherPanel:open(settings.events.craft_name == true)
  addBool(otherPanel, "@i18n(app.modules.settings.model_announcement)@", "craft_name")

  updateVoltageFields()
  updateEscFields()
  updateBecRxFields()
  updateFuelFields()
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
      eventFields = nil
    end)
  end
end

return {open = open}

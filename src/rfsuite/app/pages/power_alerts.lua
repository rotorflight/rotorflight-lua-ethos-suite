-- Setup -> Power -> Alerts page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local modelPreferences = requireModule("lib/model_preferences.lua")

local PAGE_TITLE = "@i18n(app.modules.power.alert_name)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.modules.power.save_alerts_prompt)@"
local MSG_RELOAD_TITLE = "@i18n(reload)@"
local MSG_RELOAD_BODY = "@i18n(app.modules.power.reload_alerts_prompt)@"

local ALERT_TYPE_CHOICES = {
  {"@i18n(api.BATTERY_INI.alert_off)@", 0},
  {"@i18n(api.BATTERY_INI.alert_bec)@", 1},
  {"@i18n(api.BATTERY_INI.alert_rxbatt)@", 2},
}

local function copyAlerts(alerts)
  return {
    flighttime = alerts and alerts.flighttime or 300,
    alert_type = alerts and alerts.alert_type or 0,
    becalertvalue = alerts and alerts.becalertvalue or 6.5,
    rxalertvalue = alerts and alerts.rxalertvalue or 7.5,
  }
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle = nil
  local sessionHandler = nil
  local loaded = false
  local mcuId = nil
  local prefs = nil
  local prefsFile = nil
  local alerts = copyAlerts()
  local originalAlerts = copyAlerts()
  local fields = {}

  local function isDirty()
    return alerts.flighttime ~= originalAlerts.flighttime
      or alerts.alert_type ~= originalAlerts.alert_type
      or alerts.becalertvalue ~= originalAlerts.becalertvalue
      or alerts.rxalertvalue ~= originalAlerts.rxalertvalue
  end

  local function updateEnabled()
    local enabled = loaded and mcuId ~= nil
    if fields.flighttime and fields.flighttime.enable then fields.flighttime:enable(enabled) end
    if fields.alertType and fields.alertType.enable then fields.alertType:enable(enabled) end
    if fields.becAlert and fields.becAlert.enable then fields.becAlert:enable(enabled and alerts.alert_type == 1) end
    if fields.rxAlert and fields.rxAlert.enable then fields.rxAlert:enable(enabled and alerts.alert_type == 2) end
    if headerHandle then
      headerHandle.setReloadEnabled(mcuId ~= nil)
      headerHandle.setSaveEnabled(enabled and isDirty())
    end
  end

  local function loadLocal()
    if not mcuId then
      loaded = false
      prefs = nil
      prefsFile = nil
      alerts = copyAlerts()
      originalAlerts = copyAlerts()
      updateEnabled()
      return
    end
    prefs, prefsFile = modelPreferences.load(mcuId)
    alerts = modelPreferences.powerAlerts(prefs)
    originalAlerts = copyAlerts(alerts)
    loaded = true
    updateEnabled()
    if form.invalidate then form.invalidate() end
  end

  local function goBack()
    if disposed then return end
    disposed = true
    if sessionHandler then bus.unsubscribe("session.update", sessionHandler) end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    prefs = nil
    prefsFile = nil
    alerts = nil
    originalAlerts = nil
    fields = nil
    if opts.onBack then opts.onBack() end
  end

  local function save(focusFn)
    if disposed or not loaded or not mcuId then return end
    prefs = modelPreferences.setPowerAlerts(prefs, alerts)
    modelPreferences.save(prefsFile, prefs)
    originalAlerts = copyAlerts(alerts)
    bus.publish("model.timer.update", {
      mcuId = mcuId,
      flighttime = alerts.flighttime,
    })
    bus.publish("model.power_alerts.update", {
      mcuId = mcuId,
      alerts = copyAlerts(alerts),
    })
    updateEnabled()
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

  local function confirmReload(focusFn)
    form.openDialog({
      title = MSG_RELOAD_TITLE,
      message = MSG_RELOAD_BODY,
      buttons = {
        {label = BTN_OK, action = function() loadLocal(); if focusFn then focusFn() end; return true end},
        {label = BTN_CANCEL, action = function() if focusFn then focusFn() end; return true end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  local function onSessionUpdate(snapshot)
    if disposed then return end
    local nextMcuId = snapshot and snapshot.mcuId or nil
    if nextMcuId ~= mcuId then
      mcuId = nextMcuId
      loadLocal()
      return
    end
    if not isDirty() and snapshot and snapshot.timerTarget then
      alerts.flighttime = tonumber(snapshot.timerTarget) or 300
      originalAlerts = copyAlerts(alerts)
      loaded = true
      updateEnabled()
      if form.invalidate then form.invalidate() end
    end
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
      if sessionHandler then bus.unsubscribe("session.update", sessionHandler) end
      prefs = nil
      prefsFile = nil
      alerts = nil
      originalAlerts = nil
      fields = nil
    end)
  end
  if opts.setWakeupHandler then opts.setWakeupHandler(updateEnabled) end

  local line = form.addLine("@i18n(app.modules.power.timer)@")
  fields.flighttime = form.addNumberField(line, nil, 0, 3600, function()
    return alerts and alerts.flighttime or 300
  end, function(value)
    if not alerts then return end
    alerts.flighttime = value or 300
    updateEnabled()
  end)
  if fields.flighttime and fields.flighttime.suffix then fields.flighttime:suffix("s") end

  line = form.addLine("@i18n(app.modules.power.alert_type)@")
  fields.alertType = form.addChoiceField(line, nil, ALERT_TYPE_CHOICES, function()
    return alerts and alerts.alert_type or 0
  end, function(value)
    if not alerts then return end
    alerts.alert_type = value or 0
    updateEnabled()
  end)

  line = form.addLine("@i18n(app.modules.power.bec_voltage_alert)@")
  fields.becAlert = form.addNumberField(line, nil, 30, 140, function()
    local value = alerts and alerts.becalertvalue or 6.5
    return math.floor((value * 10) + 0.5)
  end, function(value)
    if not alerts then return end
    alerts.becalertvalue = (value or 65) / 10
    updateEnabled()
  end)
  if fields.becAlert then
    if fields.becAlert.decimals then fields.becAlert:decimals(1) end
    if fields.becAlert.suffix then fields.becAlert:suffix("V") end
  end

  line = form.addLine("@i18n(app.modules.power.rx_voltage_alert)@")
  fields.rxAlert = form.addNumberField(line, nil, 30, 140, function()
    local value = alerts and alerts.rxalertvalue or 7.5
    return math.floor((value * 10) + 0.5)
  end, function(value)
    if not alerts then return end
    alerts.rxalertvalue = (value or 75) / 10
    updateEnabled()
  end)
  if fields.rxAlert then
    if fields.rxAlert.decimals then fields.rxAlert:decimals(1) end
    if fields.rxAlert.suffix then fields.rxAlert:suffix("V") end
  end

  sessionHandler = bus.subscribe("session.update", onSessionUpdate)
  updateEnabled()
end

return {open = open}

-- Settings -> Audio -> Switches.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local settingsStore = requireModule("lib/settings_store.lua")

local PAGE_TITLE = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@ / @i18n(app.modules.settings.txt_audio_switches)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"

local SWITCH_SENSORS = {
  {key = "altitude", name = "@i18n(telemetry.sensor_altitude)@"},
  {key = "bec_voltage", name = "@i18n(telemetry.sensor_bec_voltage)@"},
  {key = "consumption", name = "@i18n(telemetry.sensor_consumption)@"},
  {key = "current", name = "@i18n(telemetry.sensor_current)@"},
  {key = "temp_esc", name = "@i18n(telemetry.sensor_esc_temp)@"},
  {key = "rpm", name = "@i18n(telemetry.sensor_headspeed)@"},
  {key = "smartfuel", name = "@i18n(sensors.smartfuel)@"},
  {key = "throttle_percent", name = "@i18n(telemetry.sensor_throttle_pct)@"},
  {key = "voltage", name = "@i18n(telemetry.sensor_voltage)@"},
}

local function switchFromConfig(value)
  if type(value) ~= "string" then return nil end
  local category, member = value:match("([^,]+),([^,]+)")
  category = tonumber(category)
  member = tonumber(member)
  if not category or not member then return nil end
  return system.getSource({category = category, member = member})
end

local function switchToConfig(source)
  if not source then return nil end
  if not (source.category and source.member) then return nil end
  return tostring(source:category()) .. "," .. tostring(source:member())
end

local function open(opts)
  opts = opts or {}
  local disposed = false
  local headerHandle
  local settings = settingsStore.load()
  local original = settingsStore.clone(settings)
  local fields = {}

  settings.switches = settings.switches or {}

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

  for i = 1, #SWITCH_SENSORS do
    local sensor = SWITCH_SENSORS[i]
    local line = form.addLine(sensor.name or sensor.key)
    local field = form.addSwitchField(line, nil,
      function()
        return switchFromConfig(settings and settings.switches and settings.switches[sensor.key])
      end,
      function(source)
        if not settings then return end
        settings.switches = settings.switches or {}
        settings.switches[sensor.key] = switchToConfig(source)
        updateSaveEnabled()
      end)
    fields[#fields + 1] = field
  end

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

-- Setup -> Power -> SmartFuel page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local smartfuelConfig = requireModule("lib/msp_smartfuel_config.lua")
local modelPreferences = requireModule("lib/model_preferences.lua")
local bus = requireModule("lib/bus.lua")

local PAGE_TITLE = "@i18n(app.modules.power.smartfuel_name)@"
local MODEL_TYPE_CHOICES = {
  {"@i18n(api.BATTERY_INI.tbl_auto)@", 0},
  {"@i18n(api.BATTERY_INI.tbl_electric)@", 1},
  {"@i18n(api.BATTERY_INI.tbl_nitro)@", 2},
}

local function cleanModelType(value)
  value = tonumber(value) or 0
  if value < 0 then value = 0 end
  if value > 2 then value = 2 end
  return math.floor(value + 0.5)
end

local function tuningActive(runtime)
  local mode = tonumber(runtime.data.smartfuel_mode or 0) or 0
  return mode == 1 or mode == 3
end

local function refreshTuning(runtime)
  local enabled = runtime.loaded and tuningActive(runtime) and not runtime.activeDialog
  local fields = runtime.fields or {}
  if fields.voltage_drop_rate then fields.voltage_drop_rate:enable(enabled) end
  if fields.charge_drop_rate then fields.charge_drop_rate:enable(enabled) end
  if fields.sag_gain then fields.sag_gain:enable(enabled) end
end

local function open(opts)
  local lastEnabled = nil
  local sessionHandler = nil
  local mcuId = nil
  local prefs = nil
  local prefsFile = nil
  local modelType = 0
  local savedModelType = 0
  local modelTypeLoaded = false
  local modelTypeField = nil

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "power_smartfuel",
    mspModule = smartfuelConfig,
    opts = opts,
    profileField = "none",
    unloadPackageKeys = {
      "rfsuite.lib.msp_smartfuel_config",
    },
    onLoaded = function()
      lastEnabled = nil
      refreshTuning(runtime)
      if modelTypeField and modelTypeField.enable then
        modelTypeField:enable(modelTypeLoaded and runtime.loaded and not runtime.activeDialog)
      end
    end,
    -- Same staleness problem as app/pages/power_battery.lua's own onSaved --
    -- tasks/session.lua caches SMARTFUEL_CONFIG once at connect
    -- (session.smartfuelMode/session.smartfuelVoltageFallPerSecond/
    -- session.smartfuelChargeDropPerSecond), so a mode/tuning change here
    -- would otherwise keep driving the fuel estimate with pre-edit values
    -- until reconnect.
    onSaved = function()
      bus.publish("smartfuel.config.saved")
    end,
    beforeSave = function()
      if not modelTypeLoaded or not mcuId then return end
      modelType = cleanModelType(modelType)
      if runtime and runtime.data then runtime.data.smartfuel_model_type = modelType end
      if modelType == cleanModelType(savedModelType) then return end
      prefs = modelPreferences.setSmartfuelModelType(prefs, modelType)
      modelPreferences.save(prefsFile, prefs)
      savedModelType = modelType
      bus.publish("model.smartfuel_type.update", {
        mcuId = mcuId,
        smartfuelModelType = modelType,
      })
    end,
    onDispose = function()
      if sessionHandler then bus.unsubscribe("session.update", sessionHandler) end
      prefs = nil
      prefsFile = nil
      modelTypeField = nil
    end,
    onWakeup = function(rt)
      local enabled = tuningActive(rt)
      if enabled ~= lastEnabled then
        lastEnabled = enabled
        refreshTuning(rt)
      end
      if modelTypeField and modelTypeField.enable then
        modelTypeField:enable(modelTypeLoaded and rt.loaded and not rt.activeDialog)
      end
    end,
  })

  local captureCleanData = runtime.captureCleanData
  function runtime:captureCleanData()
    if self.data then self.data.smartfuel_model_type = modelType end
    return captureCleanData(self)
  end

  local function loadModelType(nextMcuId)
    mcuId = nextMcuId
    if not mcuId then
      prefs = nil
      prefsFile = nil
      modelType = 0
      savedModelType = 0
      modelTypeLoaded = false
    else
      prefs, prefsFile = modelPreferences.load(mcuId)
      modelType = modelPreferences.smartfuelModelType(prefs)
      savedModelType = modelType
      modelTypeLoaded = true
    end
    if runtime and runtime.data then runtime.data.smartfuel_model_type = modelType end
    if modelTypeField and modelTypeField.enable then
      modelTypeField:enable(modelTypeLoaded and runtime.loaded and not runtime.activeDialog)
    end
    if form.invalidate then form.invalidate() end
  end

  sessionHandler = function(snapshot)
    local nextMcuId = snapshot and snapshot.mcuId or nil
    if nextMcuId ~= mcuId then
      loadModelType(nextMcuId)
      return
    end
    if cleanModelType(modelType) ~= cleanModelType(savedModelType) then return end
    if snapshot and snapshot.smartfuelModelType ~= nil then
      local nextType = cleanModelType(snapshot.smartfuelModelType)
      if nextType == cleanModelType(savedModelType) then return end
      modelType = nextType
      savedModelType = modelType
      if runtime and runtime.data then runtime.data.smartfuel_model_type = modelType end
      -- session.update arrives every snapshot: patch only this key in the
      -- clean copy, never recapture the whole of data, or any unsaved MSP
      -- field edit is taken as clean and Save disables itself again.
      if runtime and runtime.cleanData then
        runtime.cleanData.smartfuel_model_type = modelType
        runtime:refreshDirty()
      end
      if form.invalidate then form.invalidate() end
    end
  end

  form.clear()
  runtime:buildChrome()

  local modelTypeLine = form.addLine("@i18n(app.modules.power.model_type)@")
  modelTypeField = form.addChoiceField(modelTypeLine, nil, MODEL_TYPE_CHOICES, function()
    return modelType
  end, function(value)
    modelType = cleanModelType(value)
    if runtime and runtime.data then runtime.data.smartfuel_model_type = modelType end
    runtime:refreshDirty()
  end)
  runtime:registerField("smartfuel_model_type", modelTypeField)

  fieldLayout.buildSingle(runtime, "@i18n(sensors.smartfuel)@", {
    key = "smartfuel_mode",
    choices = smartfuelConfig.MODE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.power.smartfuel_voltage_drop_rate)@", {key = "voltage_drop_rate"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.power.smartfuel_charge_drop_rate)@", {key = "charge_drop_rate"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.power.smartfuel_sag_gain)@", {key = "sag_gain"})

  bus.subscribe("session.update", sessionHandler)
  runtime:loadInitial()
end

return {open = open}

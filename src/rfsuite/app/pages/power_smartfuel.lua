-- Setup -> Power -> SmartFuel page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local smartfuelConfig = requireModule("lib/msp_smartfuel_config.lua")
local bus = requireModule("lib/bus.lua")

local PAGE_TITLE = "@i18n(app.modules.power.smartfuel_name)@"

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
    onWakeup = function(rt)
      local enabled = tuningActive(rt)
      if enabled ~= lastEnabled then
        lastEnabled = enabled
        refreshTuning(rt)
      end
    end,
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(sensors.smartfuel)@", {
    key = "smartfuel_mode",
    choices = smartfuelConfig.MODE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.power.smartfuel_voltage_drop_rate)@", {key = "voltage_drop_rate"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.power.smartfuel_charge_drop_rate)@", {key = "charge_drop_rate"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.power.smartfuel_sag_gain)@", {key = "sag_gain"})

  runtime:loadInitial()
end

return {open = open}

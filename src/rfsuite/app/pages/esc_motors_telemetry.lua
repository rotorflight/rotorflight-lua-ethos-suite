-- Setup -> ESC & Motors -> Telemetry page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local escSensorConfig = requireModule("lib/msp_esc_sensor_config.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_motors.telemetry)@"

local function refreshProtocolFields(runtime)
  local protocol = tonumber(runtime.data.protocol or 0) or 0
  local enabled = runtime.loaded and protocol ~= 0 and not runtime.activeDialog
  local fields = runtime.fields or {}
  if fields.half_duplex then fields.half_duplex:enable(enabled) end
  if fields.pin_swap then fields.pin_swap:enable(enabled) end
  if fields.voltage_correction then fields.voltage_correction:enable(enabled) end
  if fields.current_correction then fields.current_correction:enable(enabled) end
  if fields.consumption_correction then fields.consumption_correction:enable(enabled) end
end

local function open(opts)
  local lastProtocol = nil

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "esc_telem",
    mspModule = escSensorConfig,
    opts = opts,
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {"rfsuite.lib.msp_esc_sensor_config"},
    onLoaded = function()
      lastProtocol = nil
      refreshProtocolFields(runtime)
    end,
    onWakeup = function(rt)
      local protocol = tonumber(rt.data.protocol or 0) or 0
      if protocol ~= lastProtocol then
        lastProtocol = protocol
        refreshProtocolFields(rt)
      end
    end,
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.telemetry_protocol)@", {
    key = "protocol",
    choices = escSensorConfig.PROTOCOL_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.half_duplex)@", {
    key = "half_duplex",
    choices = escSensorConfig.ON_OFF_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.pin_swap)@", {
    key = "pin_swap",
    choices = escSensorConfig.ON_OFF_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.voltage_correction)@", {key = "voltage_correction"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.current_correction)@", {key = "current_correction"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.consumption_correction)@", {key = "consumption_correction"})

  runtime:loadInitial()
end

return {open = open}

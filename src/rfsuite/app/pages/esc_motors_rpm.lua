-- Setup -> ESC & Motors -> RPM page.

local requireModule = assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local featureConfig = requireModule("lib/msp_feature_config.lua")
local motorConfig = requireModule("lib/msp_motor_config.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_motors.rpm)@"

local function isDshotProtocol(protocol)
  protocol = tonumber(protocol or 10) or 10
  return protocol >= 5 and protocol <= 8
end

local function refreshDshotTelemetry(runtime)
  local motor = runtime.data.motor or {}
  local enabled = runtime.loaded and isDshotProtocol(motor.motor_pwm_protocol) and not runtime.activeDialog
  local field = runtime.fields["motor:use_dshot_telemetry"]
  if field then field:enable(enabled) end
end

local function open(opts)
  local lastProtocol = nil

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "esc_rpm",
    sources = {
      {key = "motor", mspModule = motorConfig},
      {key = "feature", mspModule = featureConfig},
    },
    opts = opts,
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {
      "rfsuite.lib.msp_motor_config",
      "rfsuite.lib.msp_feature_config",
    },
    onLoaded = function()
      lastProtocol = nil
      refreshDshotTelemetry(runtime)
    end,
    onWakeup = function(rt)
      local protocol = tonumber(rt.data.motor and rt.data.motor.motor_pwm_protocol or 10) or 10
      if protocol ~= lastProtocol then
        lastProtocol = protocol
        refreshDshotTelemetry(rt)
      end
    end,
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.rpm_sensor_source)@", {
    source = "feature",
    key = "enabledFeatures",
    bit = featureConfig.FEATURE_BIT_FREQ_SENSOR,
    choices = motorConfig.ON_OFF_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.use_dshot_telemetry)@", {
    source = "motor",
    key = "use_dshot_telemetry",
    choices = motorConfig.ON_OFF_CHOICES,
  })
  fieldLayout.buildGroup(runtime, "@i18n(app.modules.esc_motors.main_motor_ratio)@", {
    {title = "@i18n(app.modules.esc_motors.pinion)@", spec = {source = "motor", key = "main_rotor_gear_ratio_0"}},
    {title = "@i18n(app.modules.esc_motors.main)@", spec = {source = "motor", key = "main_rotor_gear_ratio_1"}},
  })
  fieldLayout.buildGroup(runtime, "@i18n(app.modules.esc_motors.tail_motor_ratio)@", {
    {title = "@i18n(app.modules.esc_motors.rear)@", spec = {source = "motor", key = "tail_rotor_gear_ratio_0"}},
    {title = "@i18n(app.modules.esc_motors.front)@", spec = {source = "motor", key = "tail_rotor_gear_ratio_1"}},
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.motor_pole_count)@", {
    source = "motor",
    key = "motor_pole_count_0",
  })

  runtime:loadInitial()
end

return {open = open}

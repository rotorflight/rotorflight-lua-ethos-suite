-- Setup -> ESC & Motors -> Forward Programming -> FlyRotor.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local vendorPage = requireModule("app/pages/esc_forward_vendor.lua")
local msp = requireModule("lib/msp_esc_parameters_flyrotor.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_tools.mfg.flrtr.name)@"

local function not150A(data)
  return not msp.isModel150A(data)
end

local FIELDS = {
  {group = "@i18n(app.modules.esc_tools.mfg.flrtr.basic)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.cell_count)@", key = "cell_count"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.low_voltage_protection)@", key = "low_voltage_protection"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.temperature_protection)@", key = "temperature_protection"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.bec_voltage)@", key = "bec_voltage"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.electrical_angle)@", key = "electrical_angle"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.motor_direction)@", key = "motor_direction"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.starting_torque)@", key = "starting_torque"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.response_speed)@", key = "response_speed"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.buzzer_volume)@", key = "buzzer_volume"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.current_gain)@", key = "current_gain"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.fan_control)@", key = "fan_control"},

  {group = "@i18n(app.modules.esc_tools.mfg.flrtr.governor)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.esc_mode)@", key = "esc_mode"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.soft_start)@", key = "soft_start"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.gov_p)@", key = "gov_p"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.gov_i)@", key = "gov_i"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.motor_erpm_max)@", key = "motor_erpm_max"},

  {group = "@i18n(app.modules.esc_tools.mfg.flrtr.advanced)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.auto_restart_time)@", key = "auto_restart_time"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.restart_acc)@", key = "restart_acc"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.active_freewheel)@", key = "active_freewheel"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.drive_freq)@", key = "drive_freq"},

  {group = "@i18n(app.modules.esc_tools.mfg.flrtr.other)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.throttle_protocol)@", key = "throttle_protocol", enabledWhen = not150A},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.telemetry_protocol)@", key = "telemetry_protocol", enabledWhen = not150A},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.led_color)@", key = "led_color_index", enabledWhen = not150A},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.motor_temp_sensor)@", key = "motor_temp_sensor", enabledWhen = not150A},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.motor_temp)@", key = "motor_temp", enabledWhen = not150A},
  {label = "@i18n(app.modules.esc_tools.mfg.flrtr.battery_capacity)@", key = "battery_capacity"},
}

local function open(opts)
  vendorPage.open(opts, {
    pageTitle = PAGE_TITLE,
    logTag = "esc_flyrotor",
    mspModule = msp,
    fields = FIELDS,
    unloadPackageKeys = {"rfsuite.lib.msp_esc_parameters_flyrotor"},
  })
end

return {open = open}

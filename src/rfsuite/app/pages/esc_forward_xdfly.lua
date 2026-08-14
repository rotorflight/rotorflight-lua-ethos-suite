-- Setup -> ESC & Motors -> Forward Programming -> XDFLY.

local requireModule = assert(loadfile("lib/require.lua"))()
local vendorPage = requireModule("app/pages/esc_forward_vendor.lua")
local msp = requireModule("lib/msp_esc_parameters_xdfly.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_tools.mfg.xdfly.name)@"

local function enabled(data, key)
  return msp.isFieldAvailable(data, key)
end

local FIELDS = {
  {group = "@i18n(app.modules.esc_tools.mfg.xdfly.basic)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.lv_bec_voltage)@", key = "lv_bec_voltage", enabledWhen = function(data) return enabled(data, "lv_bec_voltage") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.hv_bec_voltage)@", key = "hv_bec_voltage", enabledWhen = function(data) return enabled(data, "hv_bec_voltage") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.motor_direction)@", key = "motor_direction", enabledWhen = function(data) return enabled(data, "motor_direction") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.startup_power)@", key = "startup_power", enabledWhen = function(data) return enabled(data, "startup_power") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.led_color)@", key = "led_color", enabledWhen = function(data) return enabled(data, "led_color") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.smart_fan)@", key = "smart_fan", enabledWhen = function(data) return enabled(data, "smart_fan") end},

  {group = "@i18n(app.modules.esc_tools.mfg.xdfly.governor)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.gov)@", key = "governor", enabledWhen = function(data) return enabled(data, "governor") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.gov_p)@", key = "gov_p", enabledWhen = function(data) return enabled(data, "gov_p") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.gov_i)@", key = "gov_i", enabledWhen = function(data) return enabled(data, "gov_i") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.motor_poles)@", key = "motor_poles", enabledWhen = function(data) return enabled(data, "motor_poles") end},

  {group = "@i18n(app.modules.esc_tools.mfg.xdfly.advanced)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.timing)@", key = "timing", enabledWhen = function(data) return enabled(data, "timing") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.acceleration)@", key = "acceleration", enabledWhen = function(data) return enabled(data, "acceleration") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.brake_force)@", key = "brake_force", enabledWhen = function(data) return enabled(data, "brake_force") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.sr_function)@", key = "sr_function", enabledWhen = function(data) return enabled(data, "sr_function") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.capacity_correction)@", key = "capacity_correction", enabledWhen = function(data) return enabled(data, "capacity_correction") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.auto_restart_time)@", key = "auto_restart_time", enabledWhen = function(data) return enabled(data, "auto_restart_time") end},
  {label = "@i18n(app.modules.esc_tools.mfg.xdfly.cell_cutoff)@", key = "cell_cutoff", enabledWhen = function(data) return enabled(data, "cell_cutoff") end},
}

local function open(opts)
  vendorPage.open(opts, {
    pageTitle = PAGE_TITLE,
    logTag = "esc_xdfly",
    mspModule = msp,
    fields = FIELDS,
    unloadPackageKeys = {"rfsuite.lib.msp_esc_parameters_xdfly"},
  })
end

return {open = open}

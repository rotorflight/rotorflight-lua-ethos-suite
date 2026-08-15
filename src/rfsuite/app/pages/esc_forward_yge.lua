-- Setup -> ESC & Motors -> Forward Programming -> YGE.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local vendorPage = requireModule("app/pages/esc_forward_vendor.lua")
local msp = requireModule("lib/msp_esc_parameters_yge.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_tools.mfg.yge.name)@"

local ROTATION = {{"Normal", 0}, {"Reverse", 1}}
local OFF_ON = {{"Off", 0}, {"On", 1}}

local FIELDS = {
  {group = "@i18n(app.modules.esc_tools.mfg.yge.basic)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.esc_mode)@", key = "governor"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.direction)@", key = "flags", bit = 0, choices = ROTATION},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.lv_bec_voltage)@", key = "lv_bec_voltage"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.f3c_auto)@", key = "flags", bit = 1, choices = OFF_ON},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.auto_restart_time)@", key = "auto_restart_time"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.cell_cutoff)@", key = "cell_cutoff"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.current_limit)@", key = "current_limit"},

  {group = "@i18n(app.modules.esc_tools.mfg.yge.advanced)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.min_start_power)@", key = "min_start_power"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.max_start_power)@", key = "max_start_power"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.throttle_response)@", key = "throttle_response"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.timing)@", key = "timing"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.active_freewheel)@", key = "active_freewheel"},

  {group = "@i18n(app.modules.esc_tools.mfg.yge.other)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.gov_p)@", key = "gov_p"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.gov_i)@", key = "gov_i"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.motor_pole_pairs)@", key = "motor_pole_pairs"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.main_teeth)@", key = "main_teeth"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.pinion_teeth)@", key = "pinion_teeth"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.stick_zero_us)@", key = "stick_zero_us"},
  {label = "@i18n(app.modules.esc_tools.mfg.yge.stick_range_us)@", key = "stick_range_us"},
}

local function open(opts)
  vendorPage.open(opts, {
    pageTitle = PAGE_TITLE,
    logTag = "esc_yge",
    mspModule = msp,
    fields = FIELDS,
    unloadPackageKeys = {"rfsuite.lib.msp_esc_parameters_yge"},
  })
end

return {open = open}

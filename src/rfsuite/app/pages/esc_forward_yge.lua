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
  -- The ceiling is a property of the model that answered, not of the field, so
  -- it is a function of the read data rather than a constant here. 8.4 V is what
  -- every YGE model shares; the 12 V models may go to 12.0 V. An id the codec
  -- does not know reports the 8.4 V ceiling -- see msp_esc_parameters_yge.lua's
  -- supportsBec12v(). #2337
  --
  -- And the row is hidden outright on an Opto model, which has no BEC at all --
  -- a capped control for a setting that cannot exist is worse than no control.
  -- enabledWhen is the same mechanism six other ESC pages use, and Bluejay
  -- already gates its LED row on a capability function in exactly this shape.
  {label = "@i18n(app.modules.esc_tools.mfg.yge.lv_bec_voltage)@", key = "lv_bec_voltage",
    max = function(data) return msp.becVoltageMax(data) end,
    enabledWhen = function(data) return msp.hasBec(data) end},
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
    -- Selects 12.0 V, sets the flags byte's HV-BEC bit. #2337
    beforeSave = msp.beforeSave,
    unloadPackageKeys = {"rfsuite.lib.msp_esc_parameters_yge"},
  })
end

return {open = open}

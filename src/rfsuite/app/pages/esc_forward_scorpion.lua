-- Setup -> ESC & Motors -> Forward Programming -> Scorpion.

local requireModule = assert(loadfile("lib/require.lua"))()
local vendorPage = requireModule("app/pages/esc_forward_vendor.lua")
local msp = requireModule("lib/msp_esc_parameters_scorpion.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_tools.mfg.scorp.name)@"
local EXTRA_SAVE_MESSAGE = "@i18n(app.modules.esc_tools.mfg.scorp.extra_msg_save)@"

local FIELDS = {
  {group = "@i18n(app.modules.esc_tools.mfg.scorp.basic)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.esc_mode)@", key = "esc_mode"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.rotation)@", key = "rotation"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.bec_voltage)@", key = "bec_voltage"},

  {group = "@i18n(app.modules.esc_tools.mfg.scorp.limits)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.protection_delay)@", key = "protection_delay"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.cutoff_handling)@", key = "cutoff_handling"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.max_temperature)@", key = "max_temperature"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.max_current)@", key = "max_current"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.min_voltage)@", key = "min_voltage"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.max_used)@", key = "max_used"},

  {group = "@i18n(app.modules.esc_tools.mfg.scorp.advanced)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.soft_start_time)@", key = "soft_start_time"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.runup_time)@", key = "runup_time"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.bailout)@", key = "bailout"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.gov_proportional)@", key = "gov_proportional"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.gov_integral)@", key = "gov_integral"},
  {label = "@i18n(app.modules.esc_tools.mfg.scorp.motor_startup_sound)@", key = "motor_startup_sound"},
}

local function open(opts)
  vendorPage.open(opts, {
    pageTitle = PAGE_TITLE,
    logTag = "esc_scorpion",
    mspModule = msp,
    fields = FIELDS,
    beforeSave = msp.beforeSave,
    extraSaveMessage = EXTRA_SAVE_MESSAGE,
    eepromWrite = false,
    rebootAfterSave = false,
    unloadPackageKeys = {"rfsuite.lib.msp_esc_parameters_scorpion"},
  })
end

return {open = open}

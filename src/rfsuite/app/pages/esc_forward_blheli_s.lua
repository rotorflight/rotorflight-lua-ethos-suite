-- Setup -> ESC & Motors -> Forward Programming -> BLHeli_S.

local requireModule = assert(loadfile("lib/require.lua"))()
local vendorPage = requireModule("app/pages/esc_forward_vendor.lua")
local fourWayPage = requireModule("app/pages/esc_forward_4way.lua")
local msp = requireModule("lib/msp_esc_parameters_blheli_s.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_tools.mfg.blheli_s.name)@"

local FIELDS = {
  {group = "@i18n(app.modules.esc_tools.mfg.blheli_s.basic)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.motordirection)@", key = "motor_direction"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.startuppower)@", key = "startup_power"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.motortiming)@", key = "commutation_timing"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.demagcompensation)@", key = "demag_compensation"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.brakeonstop)@", key = "brake_on_stop"},

  {group = "@i18n(app.modules.esc_tools.mfg.blheli_s.advanced)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.temperatureprotection)@", key = "temperature_protection"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.beepstrength)@", key = "beep_strength"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.beaconstrength)@", key = "beacon_strength"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.beacondelay)@", key = "beacon_delay"},

  {group = "@i18n(app.modules.esc_tools.mfg.blheli_s.input)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.ppmminthrottle)@", key = "ppm_min_throttle"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.ppmmaxthrottle)@", key = "ppm_max_throttle"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.ppmcenterthrottle)@", key = "ppm_center_throttle"},
}

local function openEditor(opts, selection)
  vendorPage.open(opts, {
    pageTitle = PAGE_TITLE .. " " .. selection.label,
    logTag = "esc_blheli_s",
    mspModule = msp,
    fields = FIELDS,
    eepromWrite = false,
    rebootAfterSave = false,
    release4WayOnExit = true,
    unloadPackageKeys = {"rfsuite.lib.msp_esc_parameters_blheli_s"},
  })
end

local function open(opts)
  fourWayPage.open(opts, {
    pageTitle = PAGE_TITLE,
    switchReadDelay = 5.0,
    openEditor = openEditor,
  })
end

return {open = open}

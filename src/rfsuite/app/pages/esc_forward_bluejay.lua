-- Setup -> ESC & Motors -> Forward Programming -> Bluejay.

local requireModule = assert(loadfile("lib/require.lua"))()
local vendorPage = requireModule("app/pages/esc_forward_vendor.lua")
local fourWayPage = requireModule("app/pages/esc_forward_4way.lua")
local msp = requireModule("lib/msp_esc_parameters_bluejay.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_tools.mfg.bluejay.name)@"

local function layout(data)
  return tonumber(data and data.layout_revision) or 0
end

local function atMost(max)
  return function(data) return layout(data) <= max end
end

local function atLeast(min)
  return function(data) return layout(data) >= min end
end

local function pwmSupported(data)
  local rev = layout(data)
  return rev == 205 or rev >= 209
end

local function startupPowerLabel(data)
  if layout(data) <= 200 then
    return "@i18n(app.modules.esc_tools.mfg.bluejay.rampupstartpower)@"
  end
  return "@i18n(app.modules.esc_tools.mfg.bluejay.rampuppower)@"
end

local function brakingStrengthLabel(data)
  if layout(data) == 202 then
    return "@i18n(app.modules.esc_tools.mfg.bluejay.brakingmode)@"
  end
  return "@i18n(app.modules.esc_tools.mfg.bluejay.brakingstrength)@"
end

local FIELDS = {
  {group = "@i18n(app.modules.esc_tools.mfg.bluejay.general)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.motordirection)@", key = "motor_direction"},
  {label = startupPowerLabel, key = "rpm_power_slope"},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.minstartuppower)@", key = "startup_power_min"},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.maxstartuppower)@", key = "startup_power_max", enabledWhen = atLeast(201)},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.pwmfrequency)@", key = "pwm_frequency", enabledWhen = pwmSupported},

  {group = "@i18n(app.modules.esc_tools.mfg.bluejay.brake)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.motortiming)@", key = "commutation_timing"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.demagcompensation)@", key = "demag_compensation"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.brakeonstop)@", key = "brake_on_stop"},
  {label = brakingStrengthLabel, key = "braking_strength", enabledWhen = atLeast(202)},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.ledcontrol)@", key = "led_control", enabledWhen = function(data) return msp.supportsLedControl(data) end},

  {group = "@i18n(app.modules.esc_tools.mfg.bluejay.beacon)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.beepstrength)@", key = "beep_strength"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.beaconstrength)@", key = "beacon_strength"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.beacondelay)@", key = "beacon_delay"},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.startupbeep)@", key = "startup_beep", enabledWhen = function(data)
    local rev = layout(data)
    return rev <= 202 or rev == 205
  end},

  {group = "@i18n(app.modules.esc_tools.mfg.bluejay.other)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.blheli_s.temperatureprotection)@", key = "temperature_protection"},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.lowrpmpowerprotection)@", key = "low_rpm_power_protection", enabledWhen = atMost(200)},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.powerrating)@", key = "power_rating", enabledWhen = atLeast(206)},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.forceedtarm)@", key = "force_edt_arm", enabledWhen = atLeast(207)},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.dithering)@", key = "dithering", enabledWhen = atMost(207)},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.threshold96to48)@", key = "threshold_96to48", enabledWhen = atLeast(209)},
  {label = "@i18n(app.modules.esc_tools.mfg.bluejay.threshold48to24)@", key = "threshold_48to24", enabledWhen = atLeast(209)},
}

local function openEditor(opts, selection)
  vendorPage.open(opts, {
    pageTitle = PAGE_TITLE .. " " .. selection.label,
    logTag = "esc_bluejay",
    mspModule = msp,
    fields = FIELDS,
    eepromWrite = false,
    rebootAfterSave = false,
    release4WayOnExit = true,
    unloadPackageKeys = {"rfsuite.lib.msp_esc_parameters_bluejay"},
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

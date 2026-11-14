-- Setup -> ESC & Motors -> Forward Programming -> AM32.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local vendorPage = requireModule("app/pages/esc_forward_vendor.lua")
local fourWayPage = requireModule("app/pages/esc_forward_4way.lua")
local msp = requireModule("lib/msp_esc_parameters_am32.lua")
local escCurrentLimit = requireModule("lib/esc_current_limit.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_tools.mfg.am32.name)@"
local SWITCH_READ_DELAY = 4.0
-- The firmware enables a current limit only for bytes 1..100 (Src/main.c:730-731), that is
-- 2..200 A on this page. Byte 0 and bytes 101..255 are off, and they arrive here as 0 or as
-- 202..510 A. An off ESC clears the figure on file rather than storing it.
local AM32_HIGHEST_LIMIT_AMPS = 200

local FIELDS = {
  {group = "@i18n(app.modules.esc_tools.mfg.am32.basic)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.direction)@", key = "motor_direction"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.motorkv)@", key = "motor_kv"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.motorpoles)@", key = "motor_poles"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.startuppower)@", key = "startup_power"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.brakeonstop)@", key = "brake_on_stop"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.brakestrength)@", key = "brake_strength"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.runningbrake)@", key = "running_brake_level"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.beepvolume)@", key = "beep_volume"},

  {group = "@i18n(app.modules.esc_tools.mfg.am32.advanced)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.timing)@", key = "timing_advance"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.stuckrotorprotection)@", key = "stuck_rotor_protection"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.sinusoidalstartup)@", key = "sinusoidal_startup"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.sinepowermode)@", key = "sine_mode_power"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.sinemoderange)@", key = "sine_mode_range"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.bidirectionalmode)@", key = "bidirectional_mode"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.protocol)@", key = "esc_protocol"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.stallprotection)@", key = "stall_protection"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.telemetryinterval)@", key = "interval_telemetry"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.autoadvance)@", key = "auto_advance"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.complementary_pwm)@", key = "complementary_pwm"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.variablepwmfrequency)@", key = "variable_pwm_frequency"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.pwmfrequency)@", key = "pwm_frequency"},

  {group = "@i18n(app.modules.esc_tools.mfg.am32.limits)@"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.temperaturelimit)@", key = "temperature_limit"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.currentlimit)@", key = "current_limit"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.lowvoltagecutoff)@", key = "low_voltage_cutoff"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.lowvoltagethreshold)@", key = "low_voltage_threshold"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.servolowthreshold)@", key = "servo_low_threshold"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.servohighthreshold)@", key = "servo_high_threshold"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.servoneutral)@", key = "servo_neutral"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.servodeadband)@", key = "servo_dead_band"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.rcarreversing)@", key = "rc_car_reversing"},
  {label = "@i18n(app.modules.esc_tools.mfg.am32.usehallsensors)@", key = "use_hall_sensors"},
}

local function updateDependentFields(runtime)
  if not (runtime and runtime.loaded) or runtime.activeDialog then return end
  local field = runtime and runtime.fields and runtime.fields.pwm_frequency
  if field and field.enable then
    field:enable(tonumber(runtime.data and runtime.data.variable_pwm_frequency) == 1)
  end
end

-- The brand the page runs under. esc_forward_goosky.lua opens this page with its own
-- title and log tag: a Goosky ESC is an AM32 ESC (same signature, layout and handshake).
local function brandOf(config)
  if type(config) ~= "table" then return PAGE_TITLE, "esc_am32", nil end
  return config.pageTitle or PAGE_TITLE, config.logTag or "esc_am32", config.summaryBrand
end

-- The ESC reports no brand: its summary line reads "AM32 / EEPROM n / vX.Y" whatever the
-- label on it. Under another brand the line is prefixed with that brand, as the
-- configurator does, so the pilot sees "Goosky AM32 / ...". Everything else is the module.
local function brandedModule(summaryBrand)
  if not summaryBrand then return msp end
  return setmetatable({
    summaryFor = function(data, title)
      return summaryBrand .. " " .. msp.summaryFor(data, title)
    end,
  }, {__index = msp})
end

local function openEditor(opts, selection, pageTitle, logTag, summaryBrand)
  vendorPage.open(opts, {
    pageTitle = pageTitle .. " " .. selection.label,
    logTag = logTag,
    mspModule = brandedModule(summaryBrand),
    fields = FIELDS,
    onLoaded = function(runtime)
      updateDependentFields(runtime)
      local reported = tonumber(runtime and runtime.data and runtime.data.current_limit)
      if reported == nil then return end
      if reported <= 0 or reported > AM32_HIGHEST_LIMIT_AMPS then
        escCurrentLimit.forget()
      else
        escCurrentLimit.remember(reported)
      end
    end,
    onWakeup = updateDependentFields,
    eepromWrite = false,
    rebootAfterSave = false,
    release4WayOnExit = true,
    unloadPackageKeys = {"rfsuite.lib.msp_esc_parameters_am32"},
  })
end

local function open(opts, config)
  local pageTitle, logTag, summaryBrand = brandOf(config)
  fourWayPage.open(opts, {
    pageTitle = pageTitle,
    switchReadDelay = SWITCH_READ_DELAY,
    openEditor = function(editorOpts, selection)
      openEditor(editorOpts, selection, pageTitle, logTag, summaryBrand)
    end,
  })
end

return {open = open}

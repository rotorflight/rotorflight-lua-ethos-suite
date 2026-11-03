-- Setup Wizard step: Finish. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepFinish.svelte: what the
-- wizard set (swash type and rotor direction, tail type, pitch limits, ESC
-- protocol, the servos it worked on), the checks to do before the first
-- flight, and Save and finish (the footer's way forward on the last step),
-- which saves and leaves the wizard. With DShot150 the summary repeats the
-- Motor step's note: no bidirectional DShot, so no RPM for the governor or
-- the RPM filter (setup_wizard_motor.lua).

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()).
local OWNED = ui.notLoaded({"rfsuite.lib.msp_motor_config", "rfsuite.lib.msp_esc_sensor_config", "rfsuite.lib.msp_modes"})
local motorConfig = requireModule("lib/msp_motor_config.lua")
local escSensorConfig = requireModule("lib/msp_esc_sensor_config.lua")
local modesMsp = requireModule("lib/msp_modes.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")
local art = requireModule("app/setup_wizard_art.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.fin_title)@",
  intro = "@i18n(app.modules.setup_wizard.fin_intro)@",
  before = "@i18n(app.modules.setup_wizard.fin_before)@",
  swash = "@i18n(app.modules.setup_wizard.fin_swash)@",
  tail = "@i18n(app.modules.setup_wizard.fin_tail)@",
  pitch = "@i18n(app.modules.setup_wizard.step_pitch)@",
  escTelemetry = "@i18n(app.modules.setup_wizard.tel_row_used)@",
  arm = "@i18n(app.modules.setup_wizard.mod_arm)@",
  armSwitch = "@i18n(app.modules.setup_wizard.fin_arm_switch)@",
  armNone = "@i18n(app.modules.setup_wizard.fin_arm_none)@",
  govMode = {
    [0] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_off)@",
    [1] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_limit)@",
    [2] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_direct)@",
    [3] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_electric)@",
    [4] = "@i18n(api.GOVERNOR_CONFIG.tbl_govmode_nitro)@",
  },
  govThrottle = {
    [0] = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_normal)@",
    [1] = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_switch)@",
    [2] = "@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_function)@",
  },
  pitchFmt = "@i18n(app.modules.setup_wizard.fin_pitch_fmt)@",
  esc = "@i18n(app.modules.setup_wizard.fin_esc)@",
  dshot150Note = "@i18n(app.modules.setup_wizard.mot_dshot150_note)@",
  cw = "@i18n(app.modules.setup_wizard.fin_cw)@",
  ccw = "@i18n(app.modules.setup_wizard.fin_ccw)@",
  none = "@i18n(app.modules.setup_wizard.fin_none)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  governor = "@i18n(app.modules.setup_wizard.step_governor)@",
  profiles = "@i18n(app.modules.pids.name)@",
}

local TAIL_NAMES = {
  [heli.TAIL_VARIABLE] = "@i18n(app.modules.setup_wizard.fin_tail_variable)@",
  [heli.TAIL_MOTORIZED] = "@i18n(app.modules.setup_wizard.fin_tail_motor)@",
  [heli.TAIL_BIDIRECTIONAL] = "@i18n(app.modules.setup_wizard.fin_tail_bidir)@",
}

local DSHOT150 = 5

-- The arm mode's id on the FC (rotorflight-firmware msp_box.c): a range on it is the arm switch.
local ARM_MODE = 0
-- The governor mode from this: electric and nitro also have a throttle type.
local GOV_THROTTLE_FROM_MODE = 3

-- The protocols as the Motor step's tiles and Other drop-down name them; the
-- rest by the codec's name, then the number.
local PROTOCOL_NAMES = {
  [0] = "PWM",
  [DSHOT150] = "DShot150",
  [6] = "DShot300",
  [7] = "DShot600",
  [motorConfig.CASTLE_PROTOCOL] = "Castle",
}

local function protocolName(protocol)
  if protocol == nil then return "-" end
  if PROTOCOL_NAMES[protocol] then return PROTOCOL_NAMES[protocol] end
  local choices = motorConfig.BASE_PROTOCOL_CHOICES
  for i = 1, #choices do
    if choices[i][2] == protocol then return choices[i][1] end
  end
  if protocol == motorConfig.SRXL2_PROTOCOL then return "SRXL2" end
  return tostring(protocol)
end

-- The ESC telemetry protocol's name, as the ESC telemetry step lists it.
local function escTelemetryName(protocol)
  if protocol == nil then return "-" end
  if protocol == 0 then return T.none end
  local choices = escSensorConfig.choicesFor(nil)
  for i = 1, #choices do
    if choices[i][2] == protocol then return choices[i][1] end
  end
  return tostring(protocol)
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local motor = nil
  local escSensor = nil
  local modes = nil
  local loaded = false
  local screen = "summary"

  wiz.fetch({
    motor = function(ok, err) return motorConfig.buildReadMessage(ok, err) end,
    escSensor = function(ok, err) return escSensorConfig.buildReadMessage(ok, err) end,
    modes = function(ok, err) return modesMsp.buildModeRangesReadMessage(ok, err) end,
  }, function(results)
    motor = results.motor
    escSensor = results.escSensor
    modes = results.modes
    loaded = true
    wiz.rebuild()
  end)

  -- The governor as the Governor step names it: its mode, and for electric and nitro the throttle type.
  local function governorText()
    local config = wiz.governorConfig()
    if not config then return "-" end
    local mode = wiz.governorMode() or 0
    local text = T.govMode[mode] or "-"
    if mode >= GOV_THROTTLE_FROM_MODE then
      text = text .. " \u{00B7} " .. (T.govThrottle[config.gov_throttle_type or 0] or "-")
    end
    return text
  end

  -- The arm switch: a mode range on the arm mode, set to a real range.
  local function armText()
    for _, r in ipairs(modes or {}) do
      if r.id == ARM_MODE and r.range and r.range.start ~= r.range["end"] then return T.armSwitch end
    end
    return T.armNone
  end

  local function degrees(axis)
    local input = wiz.inputs[axis]
    if not input then return "-" end
    return string.format("%.1f", heli.limitDegrees(input.max, false))
  end

  function self.build()
    scr:begin()
    if not loaded then
      scr:text(T.title, "@i18n(app.msg_loading)@")
      return nil
    end
    if screen == "before" then
      scr:text(T.title, T.before)
      scr:step(2, 2)
      -- The Configurator's helicopter drawing (the flying scene), as a picture of the wizard.
      scr:picture(art.image("heli-flying", 220, 160))
      -- The two settings to check before the first flight, on the right: the governor and the profiles.
      local field = scr:checks({
        {answer = T.governor, press = function() wiz.openScript("app/pages/setup_governor_general.lua") end},
        {answer = T.profiles, press = function() wiz.openScript("app/pages/pids.lua") end},
      })
      -- The last step: the default way forward is Save and finish.
      local rowField = scr:row(function() screen = "summary"; wiz.rebuild() end)
      return field or rowField
    end
    local cfg = wiz.mixConfig() or {}
    local swash = heli.SWASH[cfg.swash_type or 0]
    local swashText = swash and (swash.name .. ", " .. ((cfg.main_rotor_dir or 0) == 1 and T.ccw or T.cw)) or T.none
    local protocol = motor and motor.motor_pwm_protocol
    scr:text(T.title, T.intro, protocol == DSHOT150 and T.dshot150Note or nil)
    scr:step(1, 2)
    scr:picture(art.image("heli-flying", 220, 160))
    local field = scr:checks({
      {label = T.swash, value = swashText, valueRight = true},
      {label = T.tail, value = TAIL_NAMES[cfg.tail_rotor_mode or 0] or "-", valueRight = true},
      {label = T.pitch, value = string.format(T.pitchFmt, degrees("collective"), degrees("pitch")), valueRight = true},
      {label = T.esc, value = protocolName(protocol), valueRight = true},
      {label = T.escTelemetry, value = escTelemetryName(escSensor and escSensor.protocol), valueRight = true},
      {label = T.governor, value = governorText(), valueRight = true},
      {label = T.arm, value = armText(), valueRight = true},
    })
    local rowField = scr:row(nil, nil, {text = T.next, press = function() screen = "before"; wiz.rebuild() end})
    return field or rowField
  end

  function self.paint() scr:paint() end
  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}

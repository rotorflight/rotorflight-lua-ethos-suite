-- Setup Wizard step: Finish. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepFinish.svelte: what the
-- wizard set (swash type and rotor direction, tail type, pitch limits, ESC
-- protocol, the servos it worked on), the checks to do before the first
-- flight, and Save and finish (the footer's way forward on the last step),
-- which saves and leaves the wizard.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()).
local OWNED = ui.notLoaded({"rfsuite.lib.msp_motor_config"})
local motorConfig = requireModule("lib/msp_motor_config.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")
local art = requireModule("app/setup_wizard_art.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.fin_title)@",
  intro = "@i18n(app.modules.setup_wizard.fin_intro)@",
  before = "@i18n(app.modules.setup_wizard.fin_before)@",
  swash = "@i18n(app.modules.setup_wizard.fin_swash)@",
  tail = "@i18n(app.modules.setup_wizard.fin_tail)@",
  pitch = "@i18n(app.modules.setup_wizard.fin_pitch)@",
  pitchFmt = "@i18n(app.modules.setup_wizard.fin_pitch_fmt)@",
  esc = "@i18n(app.modules.setup_wizard.fin_esc)@",
  cw = "@i18n(app.modules.setup_wizard.fin_cw)@",
  ccw = "@i18n(app.modules.setup_wizard.fin_ccw)@",
  none = "@i18n(app.modules.setup_wizard.fin_none)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
}

local TAIL_NAMES = {
  [heli.TAIL_VARIABLE] = "@i18n(app.modules.setup_wizard.fin_tail_variable)@",
  [heli.TAIL_MOTORIZED] = "@i18n(app.modules.setup_wizard.fin_tail_motor)@",
  [heli.TAIL_BIDIRECTIONAL] = "@i18n(app.modules.setup_wizard.fin_tail_bidir)@",
}

local function protocolName(protocol)
  if protocol == nil then return "-" end
  local choices = motorConfig.BASE_PROTOCOL_CHOICES
  for i = 1, #choices do
    if choices[i][2] == protocol then return choices[i][1] end
  end
  if protocol == motorConfig.SRXL2_PROTOCOL then return "SRXL2" end
  return tostring(protocol)
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local motor = nil
  local loaded = false
  local screen = "summary"

  wiz.fetch({
    motor = function(ok, err) return motorConfig.buildReadMessage(ok, err) end,
  }, function(results)
    motor = results.motor
    loaded = true
    wiz.rebuild()
  end)

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
      scr:picture(art.heli(0))
      -- The last step: the default way forward is Save and finish.
      return scr:row(function() screen = "summary"; wiz.rebuild() end)
    end
    local cfg = wiz.mixConfig() or {}
    local swash = heli.SWASH[cfg.swash_type or 0]
    local swashText = swash and (swash.name .. ", " .. ((cfg.main_rotor_dir or 0) == 1 and T.ccw or T.cw)) or T.none
    scr:text(T.title, T.intro)
    scr:step(1, 2)
    scr:rows({
      {T.swash, swashText},
      {T.tail, TAIL_NAMES[cfg.tail_rotor_mode or 0] or "-"},
      {T.pitch, string.format(T.pitchFmt, degrees("collective"), degrees("pitch"))},
      {T.esc, protocolName(motor and motor.motor_pwm_protocol)},
    })
    -- The outputs the wizard set up: the swash servos by number, the rotor
    -- direction, and the tail.
    local servos = wiz.servos()
    local tailServo = nil
    for _, s in ipairs(servos) do
      if s.tail then tailServo = s end
    end
    scr:picture(art.map(servos, {dir = cfg.main_rotor_dir, motorised = wiz.motorised(),
      tailLabel = tailServo and tostring(tailServo.servo + 1) or nil, tailMissing = tailServo and tailServo.missing}))
    return scr:row(nil, nil, {text = T.next, press = function() screen = "before"; wiz.rebuild() end})
  end

  function self.paint() scr:paint() end
  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}

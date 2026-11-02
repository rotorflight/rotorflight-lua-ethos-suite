-- Setup Wizard step: ESC & spin test. Opened by app/pages/setup_wizard.lua, after the
-- Connect servos gate.
--
-- The radio's copy of rotorflight-configurator's ESC & spin test:
--
--   * prepare     a safety card: the main blades off, the pinion out of mesh or the
--                 helicopter held down. Start goes on once it is confirmed.
--   * calibrate   a PWM ESC learns its throttle range: Full throttle (the output
--                 rises to 100 %) with the battery still unplugged, then the battery
--                 is plugged in and Low throttle is pressed. Only for a PWM protocol
--                 (MSP_MOTOR motor_pwm_protocol 0); other protocols skip it.
--   * spin        the main motor at a test speed (up to 50 %) for 3 seconds, or
--                 until Stop. On PWM the calibration comes first.
--
-- The Configurator's hold-to-spin is not possible on the radio (a button gives
-- a press only), so the spin runs for SPIN_SECONDS and Stop ends it early.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local motorConfig = requireModule("lib/msp_motor_config.lua")

local OWNED = {}

local PICTURE_W, PICTURE_H = 220, 160
local PWM_PROTOCOL = 0
local SPIN_SECONDS = 3
local POWER_MIN, POWER_MAX, POWER_DEFAULT = 0, 50, 10
local FULL_SECONDS, LOW_SECONDS = 4, 3

local T = {
  title = "@i18n(app.modules.setup_wizard.esc_title)@",
  prepareText = "@i18n(app.modules.setup_wizard.esc_prepare_text)@",
  prepareWarn = "@i18n(app.modules.setup_wizard.esc_prepare_warn)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  fullBtn = "@i18n(app.modules.setup_wizard.esc_full_btn)@",
  fullText = "@i18n(app.modules.setup_wizard.esc_full_text)@",
  battText = "@i18n(app.modules.setup_wizard.esc_batt_text)@",
  lowBtn = "@i18n(app.modules.setup_wizard.esc_low_btn)@",
  confirmed = "@i18n(app.modules.setup_wizard.esc_confirmed)@",
  pending = "@i18n(app.modules.setup_wizard.esc_pending)@",
  spinTitle = "@i18n(app.modules.setup_wizard.esc_spin_title)@",
  spinText = "@i18n(app.modules.setup_wizard.esc_spin_text)@",
  speed = "@i18n(app.modules.setup_wizard.esc_speed)@",
  spinBtn = "@i18n(app.modules.setup_wizard.esc_spin_btn)@",
  stopBtn = "@i18n(app.modules.setup_wizard.esc_stop_btn)@",
  needCalib = "@i18n(app.modules.setup_wizard.esc_need_calib)@",
  cal = "@i18n(app.modules.setup_wizard.esc_cal_status)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  running = "@i18n(app.modules.setup_wizard.esc_running)@",
  stopped = "@i18n(app.modules.setup_wizard.esc_stopped)@",
  loading = "@i18n(app.msg_loading)@",
  loadFailed = "@i18n(app.msg_load_failed_body)@",
}

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local screen = "prepare"
  local answers = {blades = false}   -- the safety answer, kept across rebuilds
  local picture = art.image("motor-esc", PICTURE_W, PICTURE_H)
  -- The spin picture: the bell's ring, turned while the motor runs (the centre and radius
  -- of the bell in motor-esc.png).
  local spinPicture = art.image("motor-esc", PICTURE_W, PICTURE_H)
  spinPicture.spin = {cx = 162, cy = 80, r = 26, phase = 0, visible = false}
  local spinning = false
  -- The spin's own run time: from the Spin press to Stop or SPIN_SECONDS later. The motor
  -- holds of the calibration do not count as a spin.
  local spinUntil = 0
  local function isSpinning() return os.clock() < spinUntil end

  -- The protocol is read once per visit; PWM is the only one that calibrates.
  local loaded, loadFailed = false, false
  local pwm = false
  -- Session state across rebuilds: the calibration steps done, the spin's confirmation
  -- and test speed.
  local calib = {full = false, low = false}
  local power = POWER_DEFAULT

  wiz.fetch({
    motor = function(ok, err) return motorConfig.buildReadMessage(ok, err) end,
  }, function(results, failed)
    local cfg = results.motor
    loadFailed = failed or cfg == nil
    pwm = cfg ~= nil and cfg.motor_pwm_protocol == PWM_PROTOCOL
    loaded = true
    wiz.rebuild()
  end)

  -- The screens: a PWM ESC has three, the others two (no calibration).
  local function total() return pwm and 3 or 2 end
  local function spinStep() return pwm and 3 or 2 end

  local function spinCaption() return spinning and T.running or T.stopped end

  -- Run by the shell's wakeup: the ring turns while the motor runs, and the caption follows
  -- the motor (a start or a stop from the Stop button or by the time running out).
  function self.wakeup()
    if screen ~= "spin" then return end
    local running = isSpinning()
    if running then spinPicture.spin.phase = (spinPicture.spin.phase + 15) % 360 end
    if running ~= spinning then
      spinning = running
      spinPicture.spin.visible = running
      scr:picture(spinPicture, spinCaption())
      wiz.invalidate()
    elseif running then
      wiz.invalidate()
    end
  end

  local function go(name)
    screen = name
    wiz.rebuild()
  end

  function self.build()
    scr:begin()
    if loadFailed then
      scr:text(T.title, T.loadFailed)
      return scr:row()
    end
    if not loaded then
      scr:text(T.title, T.loading)
      return scr:row()
    end

    if screen == "prepare" then
      scr:text(T.title, T.prepareText, T.prepareWarn)
      scr:step(1, total())
      scr:picture(picture)
      return scr:safety(answers, {{key = "blades", label = T.blades}}, T.start, function()
        go(pwm and "calibrate" or "spin")
      end)
    end

    if screen == "calibrate" and pwm then
      local status = (calib.full and calib.low) and T.confirmed or T.pending
      scr:text(T.title, T.fullText .. " " .. T.battText, nil)
      scr:step(2, total())
      scr:picture(picture)
      local rows = {
        {answer = T.fullBtn, press = function()
          calib.full = true
          wiz.holdMotor(0, 1000, FULL_SECONDS)
          wiz.rebuild()
        end},
        {answer = T.lowBtn, disabled = not calib.full, press = function()
          calib.low = true
          wiz.holdMotor(0, 0, LOW_SECONDS)
          wiz.rebuild()
        end},
        {label = T.cal, value = status},
      }
      local field = scr:checks(rows)
      local rowField = scr:row(function() go("prepare") end, nil,
        {text = T.next, press = function() go("spin") end})
      return field or rowField
    end

    -- The spin test.
    scr:text(T.spinTitle, T.spinText, (pwm and not calib.low) and T.needCalib or nil)
    scr:step(spinStep(), total())
    spinning = isSpinning()
    spinPicture.spin.visible = spinning
    scr:picture(spinPicture, spinCaption())
    -- The blades were confirmed on the safety card, so only the calibration gates the spin.
    local canSpin = not pwm or calib.low
    local rows = {
      {label = T.speed, number = {POWER_MIN, POWER_MAX,
        function() return power end,
        function(v)
          if type(v) == "number" and v >= POWER_MIN and v <= POWER_MAX then power = v end
        end, "%"}},
      {answer = T.spinBtn, disabled = not canSpin, press = function()
        wiz.holdMotor(0, power * 10, SPIN_SECONDS)
        spinUntil = os.clock() + SPIN_SECONDS
        wiz.rebuild()
      end},
      {answer = T.stopBtn, press = function()
        wiz.releaseMotor()
        spinUntil = 0
        wiz.rebuild()
      end},
    }
    local field = scr:checks(rows)
    local rowField = scr:row(function() go(pwm and "calibrate" or "prepare") end)
    return field or rowField
  end

  function self.paint() scr:paint() end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}

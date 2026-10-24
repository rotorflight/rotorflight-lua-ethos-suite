-- Setup Wizard step: Tail rotor. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepTail.svelte (and
-- TailMotorTest.svelte). Two kinds of tail:
--
-- A variable-pitch (servo) tail, four screens, each holding the yaw mixer
-- input with an override (heli.tailRaw(): 1000 = 24 degrees):
--   centre     yaw held at 0: nudge tail_center_trim (degrees, +-25) until
--              the tail blades sit at zero pitch
--   direction  yaw passed through from the stick: push it right and the tail
--              should push the nose right; Wrong reverses the yaw input rate
--   calibrate  yaw held at 22 degrees each way: nudge |rate| (100..5000)
--              until the blades measure 22 degrees
--   limits     yaw held at 60 degrees each way (raw 2500): the CW and CCW
--              limits (yaw input min / max) set where the slider stops
--              short of binding
--
-- A motorised tail (tail_rotor_mode 1 or 2): motor 2 (index 1) spun for a
-- few seconds at a test power, reversed only on a bidirectional tail, and
-- the tail idle (tail_motor_idle, 0.1 %) set. Motor overrides lapse on the
-- FC a second after the last write; the shell re-sends while one runs.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.tal_title)@",
  intro = "@i18n(app.modules.setup_wizard.tal_intro)@",
  centreTitle = "@i18n(app.modules.setup_wizard.tal_centre_title)@",
  centre = "@i18n(app.modules.setup_wizard.tal_centre)@",
  dirTitle = "@i18n(app.modules.setup_wizard.tal_dir_title)@",
  dir = "@i18n(app.modules.setup_wizard.tal_dir)@",
  calTitle = "@i18n(app.modules.setup_wizard.tal_cal_title)@",
  cal = "@i18n(app.modules.setup_wizard.tal_cal)@",
  limTitle = "@i18n(app.modules.setup_wizard.tal_lim_title)@",
  limCw = "@i18n(app.modules.setup_wizard.tal_lim_cw)@",
  limCcw = "@i18n(app.modules.setup_wizard.tal_lim_ccw)@",
  doneTitle = "@i18n(app.modules.setup_wizard.tal_done_title)@",
  done = "@i18n(app.modules.setup_wizard.tal_done)@",
  trim = "@i18n(app.modules.setup_wizard.tal_trim)@",
  rate = "@i18n(app.modules.setup_wizard.tal_rate)@",
  side = "@i18n(app.modules.setup_wizard.tal_side)@",
  cw = "@i18n(app.modules.setup_wizard.tal_cw)@",
  ccw = "@i18n(app.modules.setup_wizard.tal_ccw)@",
  sideCw = "@i18n(app.modules.setup_wizard.fin_cw)@",
  sideCcw = "@i18n(app.modules.setup_wizard.fin_ccw)@",
  reverse = "@i18n(app.modules.setup_wizard.tal_reverse)@",
  ok = "@i18n(app.modules.setup_wizard.tal_ok)@",
  other = "@i18n(app.modules.setup_wizard.tal_other_side)@",
  motorTitle = "@i18n(app.modules.setup_wizard.tal_motor_title)@",
  motor = "@i18n(app.modules.setup_wizard.tal_motor)@",
  noMotor = "@i18n(app.modules.setup_wizard.tal_no_motor)@",
  power = "@i18n(app.modules.setup_wizard.tal_power)@",
  output = "@i18n(app.modules.setup_wizard.tal_output)@",
  spin = "@i18n(app.modules.setup_wizard.tal_spin)@",
  spinRev = "@i18n(app.modules.setup_wizard.tal_spin_rev)@",
  stop = "@i18n(app.modules.setup_wizard.tal_stop)@",
  running = "@i18n(app.modules.setup_wizard.tal_running)@",
  stopped = "@i18n(app.modules.setup_wizard.tal_stopped)@",
  idleTitle = "@i18n(app.modules.setup_wizard.tal_idle_title)@",
  idleText = "@i18n(app.modules.setup_wizard.tal_idle)@",
  idle = "@i18n(app.modules.setup_wizard.tal_idle_value)@",
  useIdle = "@i18n(app.modules.setup_wizard.tal_use_idle)@",
  runIdle = "@i18n(app.modules.setup_wizard.tal_run_idle)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
}

local SERVO_SCREENS = {"centre", "direction", "calibrate", "limit_cw", "limit_ccw"}
local MOTOR_SCREENS = {"motor", "idle"}

local CAL_DEGREES = 22
local LIMIT_DEGREES = 60
local SPIN_SECONDS = 3
local IDLE_RUN_SECONDS = 5
local POWER_MIN, POWER_MAX = 5, 50
local IDLE_MAX = 250            -- tail_motor_idle, 0.1 %

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local motorised = wiz.motorised()
  local bidirectional = (wiz.mixConfig() or {}).tail_rotor_mode == heli.TAIL_BIDIRECTIONAL
  local screens = motorised and MOTOR_SCREENS or SERVO_SCREENS

  local screen = "intro"
  local index = 0
  local calSide = 1               -- +1 / -1: which way the calibrate screen holds
  local heldValue = nil           -- yaw override sent, nil when none
  local power = 10                -- motor test power, %

  -- Live values, compared in wakeup so paint and rows change only when they do.
  local lastCanMove, lastRunning, lastYaw, lastOutput = nil, nil, nil, nil

  local function go(name, i)
    screen = name
    index = i or index
    wiz.rebuild()
  end

  local function goIndex(i)
    if i < 1 then
      go("intro", 0)
    elseif i > #screens then
      go("done", #screens + 1)
    else
      go(screens[i], i)
    end
  end

  -- The yaw override the current screen wants, or nil for none.
  local function wantedHold()
    if screen == "centre" then return 0 end
    if screen == "direction" then return heli.MIXER_PASSTHROUGH end
    if screen == "calibrate" then return calSide * heli.tailRaw(CAL_DEGREES) end
    if screen == "limit_cw" then return -heli.tailRaw(LIMIT_DEGREES) end
    if screen == "limit_ccw" then return heli.tailRaw(LIMIT_DEGREES) end
    return nil
  end

  local function applyHold()
    local want = wantedHold()
    if want == heldValue then return end
    if want == nil then
      wiz.releaseAxes()
      heldValue = nil
    elseif wiz.holdAxis("yaw", want) then
      heldValue = want
    end
  end

  self.liveRc = nil
  self.liveMotors = nil

  local function input() return wiz.inputs.yaw end

  local function nudgeTrim(d)
    wiz.editMix(function(c)
      local deg = heli.clamp(heli.tailTrimDegrees(c.tail_center_trim or 0) + d, -25, 25)
      c.tail_center_trim = heli.tailTrimRaw(deg)
    end)
    wiz.rebuild()
  end

  local function reverseYaw()
    wiz.editInput("yaw", function(i) i.rate = -i.rate end)
    wiz.rebuild()
  end

  local function nudgeRate(d)
    wiz.editInput("yaw", function(i)
      local sign = i.rate < 0 and -1 or 1
      i.rate = sign * heli.clamp(math.abs(i.rate) + d, 100, 5000)
    end)
    wiz.rebuild()
  end

  local function nudgeLimit(field, d)
    wiz.editInput("yaw", function(i)
      local deg = heli.clamp(heli.limitDegrees(i[field], true) + d, 0, LIMIT_DEGREES)
      local raw = heli.limitRaw(deg, true)
      i[field] = (field == "min") and -raw or raw
    end)
    wiz.rebuild()
  end

  local function nudgeIdle(d)
    wiz.editMix(function(c)
      c.tail_motor_idle = heli.clamp((c.tail_motor_idle or 0) + d, 0, IDLE_MAX)
    end)
    wiz.rebuild()
  end

  local function nudgePower(d)
    power = heli.clamp(power + d, POWER_MIN, POWER_MAX)
    wiz.rebuild()
  end

  -- The tail motor picture; its running field follows the motor (wakeup).
  local motorLayout = art.tailMotor(false)

  local function spin(sign)
    motorLayout.reverse = sign < 0
    wiz.holdMotor(1, sign * power * 10, SPIN_SECONDS)
    wiz.rebuild()
  end

  local function nudgeSpecs(values, fn, fmt)
    local specs = {}
    for _, d in ipairs(values) do
      specs[#specs + 1] = {text = string.format(fmt, d > 0 and "+" or "", d), small = true, weight = 0.7,
        press = function() fn(d) end}
    end
    return specs
  end

  local function outputText()
    local v = wiz.motors[2]
    if not v or v == 0 then return "-" end
    return string.format("%d%%", math.floor((v - 1000) / 10 + 0.5))
  end

  -- Yaw stick bar (direction screen) above the tail picture.
  local dirLayout = art.tail("left")
  local function drawDirection(x, y, w, h, colors)
    local gh = math.min(24, math.floor(h * 0.2))
    local yaw = wiz.rcCommand[3] or 0
    ui.gauge(x, y, w, gh, (yaw + 500) / 1000, colors)
    art.draw(dirLayout, x, y + gh + 4, w, h - gh - 4, colors)
  end

  local function buildServo()
    local i = input()
    local back = function() goIndex(index - 1) end
    local forward = {text = T.next, press = function() goIndex(index + 1) end}
    if screen == "centre" then
      local trim = (wiz.mixConfig() or {}).tail_center_trim or 0
      scr:text(T.centreTitle, T.centre)
      scr:rows({{T.trim, string.format("%.1f°", heli.tailTrimDegrees(trim))}})
      scr:picture(art.tail(nil, string.format("%+.1f°", heli.tailTrimDegrees(trim))))
      return scr:row(back, nudgeSpecs({-1, -0.1, 0.1, 1}, nudgeTrim, "%s%.1f"), forward)
    elseif screen == "direction" then
      scr:text(T.dirTitle, T.dir)
      scr:draw(drawDirection)
      return scr:row(back, {
        {text = T.reverse, press = reverseYaw},
        {text = T.ok, primary = true, press = function() goIndex(index + 1) end},
      }, false)
    elseif screen == "calibrate" then
      scr:text(T.calTitle, T.cal)
      scr:rows({
        {T.rate, string.format("%.1f%%", math.abs(i and i.rate or 0) / 10)},
        {T.side, calSide > 0 and T.sideCcw or T.sideCw},
      })
      scr:picture(art.tail(calSide > 0 and "right" or "left", string.format("%d°", CAL_DEGREES)))
      local specs = nudgeSpecs({-10, -1, 1, 10}, nudgeRate, "%s%d")
      specs[#specs + 1] = {text = T.other, small = true, needsMotion = true, press = function()
        calSide = -calSide
        applyHold()
        wiz.rebuild()
      end}
      return scr:row(back, specs, forward)
    else -- limit_cw / limit_ccw
      local cw = screen == "limit_cw"
      local field = cw and "min" or "max"
      scr:text(T.limTitle, cw and T.limCw or T.limCcw)
      scr:rows({{cw and T.cw or T.ccw, string.format("%.1f°", heli.limitDegrees(i and i[field] or 0, true))}})
      scr:picture(art.tail(cw and "left" or "right",
        string.format("%.1f°", heli.limitDegrees(i and i[field] or 0, true))))
      return scr:row(back, nudgeSpecs({-5, -1, 1, 5}, function(d) nudgeLimit(field, d) end, "%s%d"), forward)
    end
  end

  local function buildMotor()
    local back = function() wiz.releaseMotor(); goIndex(index - 1) end
    local forward = {text = T.next, press = function() wiz.releaseMotor(); goIndex(index + 1) end}
    local hasMotor = wiz.motorCount() >= 2
    if screen == "motor" then
      scr:text(T.motorTitle, T.motor, (not hasMotor) and T.noMotor or nil)
      scr:rows({
        {T.power, string.format("%d%%", power)},
        {T.output, wiz.motorRunning() and T.running or T.stopped, wiz.motorRunning()},
      })
      motorLayout.running = wiz.motorRunning()
      scr:picture(motorLayout)
      scr:row(back, nil, forward)
      if not hasMotor then return nil end
      local specs = {
        {text = "-5%", press = function() nudgePower(-5) end},
        {text = "+5%", press = function() nudgePower(5) end},
        {text = T.spin, primary = true, needsMotion = true, press = function() spin(1) end},
      }
      if bidirectional then
        specs[#specs + 1] = {text = T.spinRev, needsMotion = true, press = function() spin(-1) end}
      end
      specs[#specs + 1] = {text = T.stop, press = function() wiz.releaseMotor(); wiz.rebuild() end}
      return scr:grid(specs, 3)
    end
    -- idle
    local idle = (wiz.mixConfig() or {}).tail_motor_idle or 0
    scr:text(T.idleTitle, T.idleText, (not hasMotor) and T.noMotor or nil)
    scr:rows({
      {T.idle, string.format("%.1f%%", idle / 10)},
      {T.output, wiz.motorRunning() and T.running or T.stopped, wiz.motorRunning()},
    })
    motorLayout.running = wiz.motorRunning()
    scr:picture(motorLayout)
    scr:row(back, nil, forward)
    local specs = nudgeSpecs({-10, -1, 1, 10}, nudgeIdle, "%s%d")
    -- The nudges are in 0.1 %: label them in %.
    specs[1].text, specs[2].text, specs[3].text, specs[4].text = "-1%", "-0.1", "+0.1", "+1%"
    specs[#specs + 1] = {text = T.useIdle, press = function() nudgeIdle(math.min(power * 10, IDLE_MAX) - idle) end}
    if hasMotor then
      specs[#specs + 1] = {text = T.runIdle, needsMotion = true, press = function()
        motorLayout.reverse = false
        wiz.holdMotor(1, idle, IDLE_RUN_SECONDS)
        wiz.rebuild()
      end}
      specs[#specs + 1] = {text = T.stop, press = function() wiz.releaseMotor(); wiz.rebuild() end}
    end
    return scr:grid(specs, 4)
  end

  function self.build()
    scr:begin()
    -- The intro is step 1 (index 0), each screen of the tail follows, and the
    -- done screen is the last one.
    scr:step(index + 1, #screens + 2)
    applyHold()
    self.liveRc = (screen == "direction") and "command" or nil
    self.liveMotors = motorised and (screen == "motor" or screen == "idle") or nil
    lastRunning = wiz.motorRunning()
    if screen == "intro" then
      scr:text(T.title, motorised and T.motor or T.intro)
      scr:picture(motorised and art.tailType((wiz.mixConfig() or {}).tail_rotor_mode) or art.tail(nil))
      return scr:row(nil, {{text = T.start, primary = true, press = function() goIndex(1) end}})
    elseif screen == "done" then
      scr:text(T.doneTitle, T.done)
      return scr:row(function() goIndex(#screens) end)
    end
    if motorised then return buildMotor() end
    return buildServo()
  end

  function self.paint() scr:paint() end

  function self.wakeup()
    local canMove = wiz.canMove()
    if canMove ~= lastCanMove then
      lastCanMove = canMove
      if canMove then applyHold() end
      scr:refresh()
    end
    local running = wiz.motorRunning()
    if running ~= lastRunning then
      lastRunning = running
      motorLayout.running = running
      if scr:setRow(2, running and T.running or T.stopped, running) then wiz.invalidate() end
    end
    if screen == "direction" then
      local yaw = wiz.rcCommand[3]
      if yaw ~= lastYaw then
        lastYaw = yaw
        wiz.invalidate()
      end
    elseif self.liveMotors and running then
      local v = wiz.motors[2]
      if v ~= lastOutput then
        lastOutput = v
        if scr:setRow(2, outputText(), true) then wiz.invalidate() end
      end
    end
  end

  function self.released()
    heldValue = nil
    scr:refresh()
  end

  function self.leave()
    heldValue = nil
  end

  return self
end

return {new = new}

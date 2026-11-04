-- Setup Wizard step: Gyro check. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepGyro.svelte, with the EdgeTX suite's pictures. No
-- overrides: the stabiliser drives the swash (the PID loop runs while disarmed too). The pages:
--
--   safety  the motor is unplugged; Start is greyed out until it is answered. Under the answer, what the
--           check is: the helicopter is moved, and the swash (or the tail blades) should push back.
--   roll, pitch, yaw  one page per axis: the EdgeTX picture on the left; on the right a switch between
--           Against the movement and With the movement. No answer is pre-set: each axis starts unanswered,
--           and the way forward waits until the pilot picks Against. With the movement shows the board
--           orientation note and a button to the Sensors step. Yaw only for a servo tail: a motor tail does not
--           turn while disarmed. On the last axis the way forward is Save and continue.
--
-- A wrong answer means the board orientation doesn't match how the board is mounted (the earlier steps
-- already set the servo and mixer directions): go to the Sensors step, and don't reverse anything for it.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.gyr_title)@",
  intro = "@i18n(app.modules.setup_wizard.gyr_intro)@",
  safety = "@i18n(app.modules.setup_wizard.lvl_safety)@",
  motorOff = "@i18n(app.modules.setup_wizard.lvl_motor_off)@",
  wrong = "@i18n(app.modules.setup_wizard.gyr_wrong)@",
  against = "@i18n(app.modules.setup_wizard.gyr_against)@",
  with = "@i18n(app.modules.setup_wizard.gyr_with)@",
  goSensors = "@i18n(app.modules.setup_wizard.gyr_go_sensors)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
}

local PICTURE_W, PICTURE_H = 220, 160

-- picture: the EdgeTX suite's gyro picture for the axis (app/gfx/setup_wizard/).
local CHECKS = {
  {key = "roll", picture = "gyro-roll",
    title = "@i18n(app.modules.setup_wizard.gyr_roll_title)@",
    text = "@i18n(app.modules.setup_wizard.gyr_roll)@"},
  {key = "pitch", picture = "gyro-pitch",
    title = "@i18n(app.modules.setup_wizard.gyr_pitch_title)@",
    text = "@i18n(app.modules.setup_wizard.gyr_pitch)@"},
  {key = "yaw", picture = "gyro-yaw", tail = true,
    title = "@i18n(app.modules.setup_wizard.gyr_yaw_title)@",
    text = "@i18n(app.modules.setup_wizard.gyr_yaw)@"},
}

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local answers = {motor = false}
  local checks = {}
  local layouts = {}
  for _, c in ipairs(CHECKS) do
    if not (c.tail and wiz.motorised()) then
      checks[#checks + 1] = c
      layouts[#checks] = art.image(c.picture, PICTURE_W, PICTURE_H)
    end
  end

  local screen = "safety"
  local ci = 1
  local against = {}          -- per axis: true (the default) when the gyro corrects against the movement

  local function go(name)
    screen = name
    wiz.rebuild()
  end

  local function advance()
    ci = ci + 1
    go("check")
  end

  local function finish()
    wiz.finishStep()
  end

  local function back()
    if ci > 1 then ci = ci - 1; go("check") else go("safety") end
  end

  -- The page of an axis: the picture on the left; on the right the switch between the two answers.
  -- No answer is assumed: an axis starts unanswered (nil), and the way forward waits for an explicit
  -- Against. Only an explicit With shows the wrong-answer note.
  local function buildCheck()
    local c = checks[ci]
    local isAgainst = against[ci] == true
    scr:text(c.title, c.text, nil, string.format(T.progress, ci, #checks))
    scr:step(ci + 1, #checks + 1)
    scr:picture(layouts[ci])
    local rows = {
      {toggle = {
        function() return against[ci] == true end,
        function(v)
          against[ci] = v and true or false
          wiz.rebuild()
        end,
        T.with, T.against}},
    }
    if against[ci] == false then
      rows[#rows + 1] = {note = T.wrong}
      rows[#rows + 1] = {answer = T.goSensors, press = function() wiz.goToStep("sensors") end}
    end
    local field = scr:checks(rows)
    local last = ci >= #checks
    -- The way forward waits for the answer Against; on the last axis it is Save and continue.
    local forward
    if last then
      forward = wiz.forward(finish)
    else
      forward = {text = T.next, press = advance}
    end
    forward.disabled = not isAgainst
    local rowField = scr:row(back, nil, forward)
    return field or rowField
  end

  function self.build()
    scr:begin()
    if screen == "safety" then
      -- The first page: the motor is unplugged before the helicopter is moved about.
      scr:text(T.title, nil)
      scr:step(1, #checks + 1)
      scr:picture(art.image("swash-motion-level", PICTURE_W, PICTURE_H))
      return scr:safety(answers, {{key = "motor", label = T.motorOff}}, T.start, function()
        ci = 1
        go("check")
      end, {{note = T.intro, plain = true}})
    end
    return buildCheck()
  end

  function self.paint() scr:paint() end
  function self.released() scr:refresh() end

  return self
end

return {new = new}

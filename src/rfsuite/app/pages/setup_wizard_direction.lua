-- Setup Wizard step: Control directions. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepDirection.svelte, with the EdgeTX suite's
-- pictures. The step opens with the blades-off question: the servos move with the sticks from here
-- on. Then roll, pitch and collective are put in passthrough (mixer override 2502): the sticks drive
-- the swash straight through the mixer, with no gyro on top.
--
-- One page per axis: the swash picture on the left, with the stick gauge under it (MSP_RC_COMMAND,
-- +-500); on the right the button, the stick position and the way the swash should move. Move the
-- stick as the text says and the swash should move the way the picture shows. The button reverses
-- that mixer input's rate (sent straight away) and says so: pressed again, it takes the reversal
-- back. The arrows at the bottom go on; on the last axis the way forward is Save and continue.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.dir_title)@",
  intro = "@i18n(app.modules.setup_wizard.dir_intro)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  q = "@i18n(app.modules.setup_wizard.dir_q)@",
  reversed = "@i18n(app.modules.setup_wizard.dir_reversed)@",
  normal = "@i18n(app.modules.setup_wizard.srv_normal)@",
  reversedBtn = "@i18n(app.modules.setup_wizard.dir_reversed_btn)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  stick = "@i18n(app.modules.setup_wizard.dir_stick)@",
  expect = "@i18n(app.modules.setup_wizard.dir_expect)@",
}

local PICTURE_W, PICTURE_H = 220, 160

-- rc: index into wiz.rcCommand (roll, pitch, yaw, collective). picture: the EdgeTX suite's swash
-- motion picture (app/gfx/setup_wizard/).
local CHECKS = {
  {axis = "roll", rc = 1, picture = "swash-motion-roll",
    title = "@i18n(app.modules.setup_wizard.dir_roll_title)@",
    text = "@i18n(app.modules.setup_wizard.dir_roll)@",
    expect = "@i18n(app.modules.setup_wizard.dir_exp_roll)@"},
  {axis = "pitch", rc = 2, picture = "swash-motion-pitch",
    title = "@i18n(app.modules.setup_wizard.dir_pitch_title)@",
    text = "@i18n(app.modules.setup_wizard.dir_pitch)@",
    expect = "@i18n(app.modules.setup_wizard.dir_exp_pitch)@"},
  {axis = "collective", rc = 4, picture = "swash-motion-collective", vertical = true,
    title = "@i18n(app.modules.setup_wizard.dir_coll_title)@",
    text = "@i18n(app.modules.setup_wizard.dir_coll)@",
    expect = "@i18n(app.modules.setup_wizard.dir_exp_coll)@"},
}

-- The blades card, then one page per axis.
local PAGES = 1 + #CHECKS
-- The checks' rows on an axis page: the button first, then the stick.
local STICK_ROW = 2

local PASS = heli.MIXER_PASSTHROUGH
local HOLD = {roll = PASS, pitch = PASS, collective = PASS}

-- The stick as percent of its travel, signed: the value the flight controller sees.
local function stickText(v)
  return string.format("%+d %%", math.floor((v or 0) / 5 + 0.5))
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local safetyPicture = art.image("swash-motion-level", PICTURE_W, PICTURE_H)
  local layouts = {}
  for i, c in ipairs(CHECKS) do layouts[i] = art.image(c.picture, PICTURE_W, PICTURE_H) end

  local screen = "prepare"
  local answers = {blades = false}
  local ci = 1
  local reversed = {}          -- per axis: its mixer input is reversed by the button
  local holding = false
  local lastStick = nil

  self.liveRc = nil

  local function hold()
    holding = wiz.holdAxes(HOLD)
  end

  local function go(name)
    screen = name
    self.liveRc = (name == "check") and "command" or nil
    if name == "check" then
      if not holding then hold() end
    else
      wiz.releaseAxes()
      holding = false
    end
    wiz.rebuild()
  end

  -- The last axis is done: the sticks go back to the wizard, and the step ends (save and continue).
  local function finish()
    wiz.releaseAxes()
    holding = false
    self.liveRc = nil
    wiz.finishStep()
  end

  local function nextCheck()
    if ci < #CHECKS then
      ci = ci + 1
      go("check")
    else
      finish()
    end
  end

  -- The button: reverses the axis's mixer input, or takes the reversal back.
  local function toggleReverse()
    wiz.editInput(CHECKS[ci].axis, function(input) input.rate = -input.rate end)
    reversed[ci] = not reversed[ci]
    wiz.rebuild()
  end

  -- Picture above, the stick gauge along the bottom; the collective stick stands up, its gauge at
  -- the left of the picture.
  local function drawCheck(x, y, w, h, colors)
    local c = CHECKS[ci]
    local v = wiz.rcCommand[c.rc] or 0
    if c.vertical then
      local gw = math.min(28, math.floor(w * 0.14))
      ui.vgauge(x, y, gw, h - 4, (v + 500) / 1000, colors, 0.49, 0.51)
      art.draw(layouts[ci], x + gw + 6, y, w - gw - 6, h - 4, colors)
      return
    end
    local gh = math.min(24, math.floor(h * 0.2))
    art.draw(layouts[ci], x, y, w, h - gh - 4, colors)
    ui.gauge(x, y + h - gh, w, gh, (v + 500) / 1000, colors, 0.49, 0.51)
  end

  -- The safety card: the blades must be off before the sticks drive the servos.
  local function buildPrepare()
    scr:text(T.title, T.intro)
    scr:step(1, PAGES)
    scr:picture(safetyPicture)
    return scr:safety(answers, {{key = "blades", label = T.blades}}, T.start, function()
      ci = 1
      go("check")
    end)
  end

  local function buildCheck()
    local c = CHECKS[ci]
    local isReversed = reversed[ci] == true
    scr:text(c.title, c.text .. " " .. T.q, nil, string.format(T.progress, ci, #CHECKS))
    scr:step(ci + 1, PAGES)
    scr:draw(drawCheck)
    local rows = {
      {answer = isReversed and T.reversedBtn or T.normal, press = toggleReverse, needsMotion = true},
      {label = T.stick, value = stickText(wiz.rcCommand[c.rc])},
      {label = T.expect, value = c.expect},
    }
    -- Under Expected, while the axis is reversed: check it again.
    if isReversed then rows[#rows + 1] = {note = T.reversed} end
    local field = scr:checks(rows)
    local back = function()
      if ci > 1 then ci = ci - 1; go("check") else go("prepare") end
    end
    -- Next on every axis but the last; there the footer's way forward, Save and continue.
    local forward = ci < #CHECKS and {text = T.next, press = nextCheck} or wiz.forward(finish)
    local rowField = scr:row(back, nil, forward)
    return field or rowField
  end

  function self.build()
    scr:begin()
    if screen == "prepare" then return buildPrepare() end
    return buildCheck()
  end

  function self.paint() scr:paint() end

  local lastCanMove = nil
  function self.wakeup()
    local canMove = wiz.canMove()
    if canMove ~= lastCanMove then
      lastCanMove = canMove
      if canMove and screen == "check" and not holding then hold() end
      scr:refresh()
    end
    if screen == "check" then
      local v = wiz.rcCommand[CHECKS[ci].rc]
      if v ~= lastStick then
        lastStick = v
        scr:setCheckValue(STICK_ROW, stickText(v))
        wiz.invalidate()
      end
    end
  end

  function self.released()
    holding = false
    lastCanMove = nil
    scr:refresh()
  end

  function self.leave() self.liveRc = nil end

  return self
end

return {new = new}

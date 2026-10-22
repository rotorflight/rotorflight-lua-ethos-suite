-- Setup Wizard step: Control directions. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepDirection.svelte. Roll,
-- pitch and collective are put in passthrough (mixer override 2502): the
-- sticks drive the swash straight through the mixer, with no gyro on top.
-- One check per axis: move the stick as the text says and the swash should
-- move the way the picture shows. Wrong reverses that mixer input's rate
-- (sent straight away) and the check is done again. A gauge shows the stick
-- the flight controller sees (MSP_RC_COMMAND, +-500).

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.dir_title)@",
  intro = "@i18n(app.modules.setup_wizard.dir_intro)@",
  q = "@i18n(app.modules.setup_wizard.dir_q)@",
  reversed = "@i18n(app.modules.setup_wizard.dir_reversed)@",
  correct = "@i18n(app.modules.setup_wizard.dir_correct)@",
  wrong = "@i18n(app.modules.setup_wizard.dir_wrong)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  doneTitle = "@i18n(app.modules.setup_wizard.dir_done_title)@",
  done = "@i18n(app.modules.setup_wizard.dir_done)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  again = "@i18n(app.modules.setup_wizard.btn_again)@",
}

-- rc: index into wiz.rcCommand (roll, pitch, yaw, collective).
local CHECKS = {
  {axis = "roll", rc = 1, view = "rear", motion = "right",
    title = "@i18n(app.modules.setup_wizard.dir_roll_title)@",
    text = "@i18n(app.modules.setup_wizard.dir_roll)@"},
  {axis = "pitch", rc = 2, view = "side", motion = "forward",
    title = "@i18n(app.modules.setup_wizard.dir_pitch_title)@",
    text = "@i18n(app.modules.setup_wizard.dir_pitch)@"},
  {axis = "collective", rc = 4, view = "rear", motion = "up",
    title = "@i18n(app.modules.setup_wizard.dir_coll_title)@",
    text = "@i18n(app.modules.setup_wizard.dir_coll)@"},
}

local PASS = heli.MIXER_PASSTHROUGH
local HOLD = {roll = PASS, pitch = PASS, collective = PASS}

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local layouts = {}
  for i, c in ipairs(CHECKS) do layouts[i] = art.tilt(c.view, c.motion) end

  local screen = "intro"
  local ci = 1
  local reversedNote = false
  local holding = false
  local lastStick = nil

  self.liveRc = nil

  local function hold()
    holding = wiz.holdAxes(HOLD)
  end

  local function go(name)
    screen = name
    reversedNote = false
    self.liveRc = (name == "check") and "command" or nil
    if name == "check" then
      if not holding then hold() end
    else
      wiz.releaseAxes()
      holding = false
    end
    wiz.rebuild()
  end

  local function nextCheck()
    if ci < #CHECKS then
      ci = ci + 1
      go("check")
    else
      go("done")
    end
  end

  local function reverse()
    wiz.editInput(CHECKS[ci].axis, function(input) input.rate = -input.rate end)
    reversedNote = true
    wiz.rebuild()
  end

  -- Picture above, the stick gauge along the bottom.
  local function drawCheck(x, y, w, h, colors)
    local gh = math.min(24, math.floor(h * 0.2))
    art.draw(layouts[ci], x, y, w, h - gh - 4, colors)
    local v = wiz.rcCommand[CHECKS[ci].rc] or 0
    ui.gauge(x, y + h - gh, w, gh, (v + 500) / 1000, colors, 0.49, 0.51)
  end

  function self.build()
    scr:begin()
    if screen == "intro" then
      scr:text(T.title, T.intro)
      scr:picture(art.tilt("rear", "level"))
      return scr:row(nil, {
        {text = T.start, primary = true, needsMotion = true, press = function() ci = 1; go("check") end},
      })
    elseif screen == "check" then
      local c = CHECKS[ci]
      scr:text(c.title, c.text .. " " .. T.q, reversedNote and T.reversed or nil,
        string.format(T.progress, ci, #CHECKS))
      scr:draw(drawCheck)
      return scr:row(function()
        if ci > 1 then ci = ci - 1; go("check") else go("intro") end
      end, {
        {text = T.wrong, needsMotion = true, press = reverse},
        {text = T.correct, primary = true, press = nextCheck},
      }, false)
    end
    scr:text(T.doneTitle, T.done)
    scr:picture(art.tilt("rear", "level"))
    return scr:row(function() ci = #CHECKS; go("check") end, {
      {text = T.again, needsMotion = true, press = function() ci = 1; go("check") end},
    })
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

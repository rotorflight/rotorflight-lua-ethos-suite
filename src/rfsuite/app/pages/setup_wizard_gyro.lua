-- Setup Wizard step: Gyro check. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepGyro.svelte. No
-- overrides: the stabiliser drives the swash (the PID loop runs while
-- disarmed too). One screen per axis: move the helicopter as the text says,
-- and the swash (or the tail blades) should push back against the movement,
-- as the picture shows. Yaw only for a servo tail: a motor tail does not
-- turn while disarmed.
--
-- A wrong answer means the board orientation doesn't match how the board is
-- mounted (the earlier steps already set the servo and mixer directions): go
-- back to the Board orientation step, and don't reverse anything for it.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.gyr_title)@",
  intro = "@i18n(app.modules.setup_wizard.gyr_intro)@",
  wrong = "@i18n(app.modules.setup_wizard.gyr_wrong)@",
  doneTitle = "@i18n(app.modules.setup_wizard.gyr_done_title)@",
  done = "@i18n(app.modules.setup_wizard.gyr_done)@",
  against = "@i18n(app.modules.setup_wizard.gyr_against)@",
  with = "@i18n(app.modules.setup_wizard.gyr_with)@",
  goSensors = "@i18n(app.modules.setup_wizard.gyr_go_sensors)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  again = "@i18n(app.modules.setup_wizard.btn_again)@",
}

local CHECKS = {
  {key = "roll", title = "@i18n(app.modules.setup_wizard.gyr_roll_title)@",
    text = "@i18n(app.modules.setup_wizard.gyr_roll)@", view = "rear", motion = "left"},
  {key = "pitch", title = "@i18n(app.modules.setup_wizard.gyr_pitch_title)@",
    text = "@i18n(app.modules.setup_wizard.gyr_pitch)@", view = "side", motion = "back"},
  {key = "yaw", title = "@i18n(app.modules.setup_wizard.gyr_yaw_title)@",
    text = "@i18n(app.modules.setup_wizard.gyr_yaw)@", tail = true, motion = "right"},
}

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local checks = {}
  for _, c in ipairs(CHECKS) do
    if not (c.tail and wiz.motorised()) then checks[#checks + 1] = c end
  end

  local screen = "intro"
  local ci = 1

  local function go(name)
    screen = name
    wiz.rebuild()
  end

  local function nextCheck()
    if ci < #checks then ci = ci + 1; go("check") else go("done") end
  end

  function self.build()
    scr:begin()
    if screen == "intro" then
      scr:text(T.title, T.intro)
      scr:picture(art.tilt("rear", "level"))
      return scr:row(nil, {
        {text = T.start, primary = true, press = function() ci = 1; go("check") end},
      })
    elseif screen == "check" then
      local c = checks[ci]
      scr:text(c.title, c.text, nil, string.format(T.progress, ci, #checks))
      scr:picture(c.tail and art.tail(c.motion) or art.tilt(c.view, c.motion))
      return scr:row(function()
        if ci > 1 then ci = ci - 1; go("check") else go("intro") end
      end, {
        {text = T.with, press = function() go("wrong") end},
        {text = T.against, primary = true, press = nextCheck},
      }, false)
    elseif screen == "wrong" then
      scr:text(checks[ci].title, T.wrong, nil, true)
      return scr:row(function() go("check") end, {
        {text = T.goSensors, primary = true, press = function() wiz.goToStep("sensors") end},
      }, {text = T.next, press = nextCheck})
    end
    scr:text(T.doneTitle, T.done)
    return scr:row(function() ci = #checks; go("check") end,
      {{text = T.again, press = function() ci = 1; go("check") end}})
  end

  function self.paint() scr:paint() end
  function self.released() scr:refresh() end

  return self
end

return {new = new}

-- Setup Wizard step: Servo direction & centre. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepServos.svelte. Every
-- servo the wizard uses is held at override 0, which puts it exactly at its
-- Mid with nothing from the mixer on top. Then, one servo at a time:
--
--   test    (swash servos) the servo is held 20 degrees up: did the arm move
--           up, towards the swash? No reverses the servo (flags bit 0) and
--           tests again.
--   centre  nudge Mid by -10/-1/+1/+10 us until the arm is level. More than
--           FAR_US from the band's centre (1520, or 760 for a narrow-band
--           servo) is flagged: move the arm a spline instead.
--
-- The tail servo is only centred: its direction is the Tail rotor step's.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")

local T = {
  testText = "@i18n(app.modules.setup_wizard.srv_test_text)@",
  q = "@i18n(app.modules.setup_wizard.srv_test_q)@",
  reversed = "@i18n(app.modules.setup_wizard.srv_reversed)@",
  up = "@i18n(app.modules.setup_wizard.srv_up)@",
  down = "@i18n(app.modules.setup_wizard.srv_down)@",
  centreText = "@i18n(app.modules.setup_wizard.srv_centre_text)@",
  tailText = "@i18n(app.modules.setup_wizard.srv_tail_text)@",
  value = "@i18n(app.modules.setup_wizard.srv_value_fmt)@",
  far = "@i18n(app.modules.setup_wizard.srv_far)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  doneTitle = "@i18n(app.modules.setup_wizard.srv_done_title)@",
  done = "@i18n(app.modules.setup_wizard.srv_done)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
}

local FAR_US = 100
local TEST_RAW = heli.servoRaw(20)
local NUDGES = {-10, -1, 1, 10}

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)

  -- Only the servos the board has.
  local list = {}
  for _, s in ipairs(wiz.servos()) do
    if not s.missing and wiz.configs[s.servo] then list[#list + 1] = s end
  end

  local index = 1
  local screen = "test"  -- "test" | "centre"
  local reversedNote = false
  local holding = false

  local function firstScreen(s)
    return (s and not s.tail) and "test" or "centre"
  end
  screen = firstScreen(list[1])

  -- Every servo at Mid, the one under test 20 degrees up.
  local function holdAll()
    holding = true
    for i, s in ipairs(list) do
      local raw = (i == index and screen == "test") and TEST_RAW or 0
      if not wiz.holdServo(s.servo, raw) then holding = false end
    end
  end

  local function go(newIndex, newScreen)
    index, screen, reversedNote = newIndex, newScreen, false
    local s = list[index]
    if s then
      -- Only the servo whose hold changes.
      for i, o in ipairs(list) do
        if i ~= index then wiz.holdServo(o.servo, 0) end
      end
      wiz.holdServo(s.servo, screen == "test" and TEST_RAW or 0)
    end
    wiz.rebuild()
  end

  local function nextServo()
    if index < #list then
      go(index + 1, firstScreen(list[index + 1]))
    else
      index, screen = #list + 1, "done"
      for _, o in ipairs(list) do wiz.holdServo(o.servo, 0) end
      wiz.rebuild()
    end
  end

  local function reverse()
    local s = list[index]
    wiz.editServo(s.servo, function(config)
      config.flags = math.floor(config.flags or 0) ~ heli.SERVO_FLAG_REVERSE
    end)
    -- Hold it again, so the arm moves the new way.
    wiz.holdServo(s.servo, TEST_RAW)
    reversedNote = true
    wiz.rebuild()
  end

  local function nudge(delta)
    local s = list[index]
    wiz.editServo(s.servo, function(config)
      local centre = heli.bandCentre(config)
      local span = heli.bandOf(config) == "wide" and 400 or 200
      config.mid = heli.clamp(config.mid + delta, centre - span, centre + span)
    end)
    wiz.rebuild()
  end

  local function drawGauge(x, y, w, h, colors)
    local s = list[index]
    local config = s and wiz.configs[s.servo]
    if not config then return end
    local offset = config.mid - heli.bandCentre(config)
    local range = 2 * FAR_US
    local gh = math.min(h, 30)
    ui.gauge(x, y + math.floor((h - gh) / 2), w, gh, (offset + range) / (2 * range), colors,
      (range - FAR_US) / (2 * range), (range + FAR_US) / (2 * range))
  end

  local function back()
    if screen == "centre" and list[index] and not list[index].tail then
      go(index, "test")
    elseif index > 1 then
      go(index - 1, "centre")
    else
      wiz.previousStep()
    end
  end

  function self.build()
    scr:begin()
    if not holding then holdAll() end
    local s = list[index]
    if not s then
      scr:text(T.doneTitle, T.done)
      scr:picture(art.swash(wiz.servos(), nil, nil))
      return scr:row(#list > 0 and function() go(#list, "centre") end or nil)
    end
    local progress = string.format(T.progress, index, #list)
    if screen == "test" then
      scr:text(wiz.servoName(s), T.testText .. " " .. T.q, reversedNote and T.reversed or nil, progress)
      scr:picture(art.swash(wiz.servos(), s.servo, "up"))
      return scr:row(back, {
        {text = T.down, needsMotion = true, press = reverse},
        {text = T.up, primary = true, needsMotion = true, press = function() go(index, "centre") end},
      }, false)
    end
    local config = wiz.configs[s.servo]
    local offset = config.mid - heli.bandCentre(config)
    local body = (s.tail and T.tailText or T.centreText) .. " "
      .. string.format(T.value, config.mid, (offset >= 0 and "+" or "") .. offset)
    scr:text(wiz.servoName(s), body, math.abs(offset) > FAR_US and T.far or nil, progress)
    scr:draw(drawGauge)
    local specs = {}
    for _, d in ipairs(NUDGES) do
      specs[#specs + 1] = {text = (d > 0 and "+" or "") .. d, small = true, weight = 0.7, needsMotion = true,
        press = function() nudge(d) end}
    end
    return scr:row(back, specs, {text = T.next, press = nextServo})
  end

  function self.paint() scr:paint() end

  local lastCanMove = nil
  function self.wakeup()
    local canMove = wiz.canMove()
    if canMove ~= lastCanMove then
      lastCanMove = canMove
      if canMove and not holding then holdAll() end
      scr:refresh()
    end
  end

  function self.released()
    holding = false
    lastCanMove = nil
    scr:refresh()
  end

  return self
end

return {new = new}

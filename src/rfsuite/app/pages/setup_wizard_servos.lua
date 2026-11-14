-- Setup Wizard step: Servo direction & centre. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepServos.svelte. The step opens with two kinds of
-- page:
--
--   arms    the explanation with the servo picture, and the safety question: all blades removed. Start
--           follows once it is ticked, and the servos move on the following pages.
--   servo   one page per servo: the picture on the left, the controls on the right. Every servo the
--           wizard uses is held at override 0, which puts it exactly at its Mid with nothing from the
--           mixer on top. The last page (the tail servo, or the last swash servo) has Save and continue
--           instead of Next: it saves the step and goes on.
--
-- On a servo page:
--
--   Move up 20 degrees  (swash servos) toggles the test: the servo is held 20 degrees up. Did the arm
--                       move up, towards the swash? Reverse flips the servo's direction (flags bit 0),
--                       and the test holds again so the arm moves the new way.
--   Centre              type the Mid value in its field until the arm is level. More than
--                       FAR_US from the band's centre (1520, or 760 for a narrow-band servo) is flagged:
--                       move the arm a spline instead.
--
-- The tail servo is only centred: its direction is the Tail rotor step's, so it has no move or reverse.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")

local T = {
  stepTitle = "@i18n(app.modules.setup_wizard.step_servos)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  armsTitle = "@i18n(app.modules.setup_wizard.srv_arms_title)@",
  armsSub = "@i18n(app.modules.setup_wizard.srv_arms_sub)@",
  armsText = "@i18n(app.modules.setup_wizard.srv_arms_text)@",
  centreText = "@i18n(app.modules.setup_wizard.srv_centre_text)@",
  tailText = "@i18n(app.modules.setup_wizard.srv_tail_text)@",
  moveUp = "@i18n(app.modules.setup_wizard.srv_move_up)@",
  backCentre = "@i18n(app.modules.setup_wizard.srv_back_centre)@",
  reverse = "@i18n(app.modules.setup_wizard.srv_reverse)@",
  normal = "@i18n(app.modules.setup_wizard.srv_normal)@",
  centreLabel = "@i18n(app.modules.setup_wizard.srv_centre_label)@",
  offset = "@i18n(app.modules.setup_wizard.srv_offset)@",
  from = "@i18n(app.modules.setup_wizard.srv_from)@",
  far = "@i18n(app.modules.setup_wizard.srv_far)@",
  doneTitle = "@i18n(app.modules.setup_wizard.srv_done_title)@",
  done = "@i18n(app.modules.setup_wizard.srv_done)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  armed = "@i18n(app.modules.setup_wizard.armed)@",
}

local FAR_US = 100
local TEST_RAW = heli.servoRaw(20)
-- The pages before the servos: the blades card and the arms.
local PAGES_BEFORE = 1

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local picture = art.image("servo-arm", 220, 160)

  -- Only the servos the board has.
  local list = {}
  for _, s in ipairs(wiz.servos()) do
    if not s.missing and wiz.configs[s.servo] then list[#list + 1] = s end
  end

  local phase = "arms"          -- "arms" | "servo" (no servo left: the empty step below)
  local answers = {blades = false}
  local index = 1               -- the servo on show (phase "servo")
  local up = false              -- the test: the servo held 20 degrees up
  local holding = false
  local offsetRow = nil         -- the row that shows the offset from the band centre
  local refused = false         -- the wizard could not move the servo (armed, or no link)
  local shownOffset = nil
  local total = #list + PAGES_BEFORE

  -- Holds a servo; a refused hold is shown on the page, not dropped silently.
  local function hold(servo, raw)
    local ok = wiz.holdServo(servo, raw)
    refused = not ok
    return ok
  end

  -- Every servo at Mid, the one under test held up when its test is on.
  local function holdAll()
    holding = true
    for i, s in ipairs(list) do
      local raw = (phase == "servo" and i == index and up and not s.tail) and TEST_RAW or 0
      if not hold(s.servo, raw) then holding = false end
    end
  end

  local function go(newIndex)
    phase, index, up, offsetRow, shownOffset, refused = "servo", newIndex, false, nil, nil, false
    -- Only the servo whose hold changes.
    for i, o in ipairs(list) do
      if i ~= index then wiz.holdServo(o.servo, 0) end
    end
    local s = list[index]
    if s then wiz.holdServo(s.servo, 0) end
    wiz.rebuild()
  end

  -- Next, from every page but the last. The last page has the footer's Save (wiz.forward()).
  local function nextServo()
    if index < #list then go(index + 1) end
  end

  -- Back from the first servo goes to the arms page, from any other to the servo before it.
  local function back()
    if index > 1 then
      go(index - 1)
    else
      phase, up, offsetRow, shownOffset = "arms", false, nil, nil
      -- Back on the first page the servos are let go, as before Start.
      wiz.releaseServos()
      holding = false
      wiz.rebuild()
    end
  end

  local function toggleUp()
    local s = list[index]
    if not s or s.tail then return end
    up = not up
    hold(s.servo, up and TEST_RAW or 0)
    wiz.rebuild()
  end

  local function reverse()
    local s = list[index]
    if not s or s.tail then return end
    wiz.editServo(s.servo, function(config)
      config.flags = math.floor(config.flags or 0) ~ heli.SERVO_FLAG_REVERSE
    end)
    -- Test it again, so the arm moves the new way: held up.
    up = true
    hold(s.servo, TEST_RAW)
    wiz.rebuild()
  end

  -- Sets Mid to a value, kept inside the band around its centre.
  local function setMid(servo, value)
    wiz.editServo(servo, function(config)
      local centre = heli.bandCentre(config)
      local span = heli.bandOf(config) == "wide" and 400 or 200
      config.mid = heli.clamp(math.floor(value + 0.5), centre - span, centre + span)
    end)
  end

  -- The first page: the explanation with the servo picture, and the safety question (all blades
  -- removed). Start is greyed out until it is ticked.
  local function buildArms()
    local ready = answers.blades == true
    scr:text(T.armsTitle, T.armsSub)
    scr:picture(art.pair(picture, art.swashImage(wiz, 220, 160)))
    scr:step(1, total)
    local field = scr:checks({
      {note = T.armsText, plain = true},
      {label = T.blades, toggle = {
        function() return answers.blades == true end,
        function(v) answers.blades = v and true or false; wiz.rebuild() end}},
    })
    local rowField = scr:row(nil, {{text = T.start, primary = ready, disabled = not ready,
      press = function() go(1) end}})
    return field or rowField
  end

  local function buildServo(s)
    -- One page per servo: its test and its centring together.
    scr:step(index + PAGES_BEFORE, total)
    local servo = s.servo
    local config = wiz.configs[servo]
    local centre = heli.bandCentre(config)
    local offset = config.mid - centre
    scr:text(wiz.servoName(s), s.tail and T.tailText or T.centreText,
      math.abs(offset) > FAR_US and T.far or nil)
    scr:picture(art.pair(picture, art.swashImage(wiz, 220, 160)))

    local rows = {}
    if refused then rows[#rows + 1] = {note = T.armed} end
    if not s.tail then
      -- The buttons show what the next press does: back to centre while the servo is up, normal
      -- once it is reversed.
      local reversed = (math.floor(config.flags or 0) & heli.SERVO_FLAG_REVERSE) ~= 0
      rows[#rows + 1] = {answer = up and T.backCentre or T.moveUp, press = toggleUp, needsMotion = true}
      rows[#rows + 1] = {answer = reversed and T.normal or T.reverse, press = reverse, needsMotion = true}
    end
    local span = heli.bandOf(config) == "wide" and 400 or 200
    rows[#rows + 1] = {label = T.centreLabel, number = {centre - span, centre + span,
      function() return wiz.configs[servo].mid end,
      function(value) setMid(servo, value) end, "us"}}
    shownOffset = string.format(T.from, offset, centre)
    rows[#rows + 1] = {label = T.offset, value = shownOffset}
    offsetRow = #rows

    -- The centre is typed in its field, so the bottom row only moves between the servos.
    local field = scr:checks(rows)
    local forward = index < #list and {text = T.next, press = nextServo} or nil
    local rowField = scr:row(back, nil, forward)
    return field or rowField
  end

  function self.build()
    scr:begin()
    -- The servos move only on the servo pages (after Start): not on the blades question.
    if phase == "servo" and not holding then holdAll() end
    if phase == "arms" then
      offsetRow = nil
      return buildArms()
    end
    local s = list[index]
    if phase ~= "servo" or not s then
      offsetRow = nil
      scr:text(T.doneTitle, T.done)
      scr:picture(art.swash(wiz.servos(), nil, nil))
      return scr:row()
    end
    return buildServo(s)
  end

  function self.paint() scr:paint() end

  local lastCanMove = nil
  function self.wakeup()
    local canMove = wiz.canMove()
    if canMove ~= lastCanMove then
      lastCanMove = canMove
      if canMove and phase == "servo" and not holding then holdAll() end
      scr:refresh()
    end
    -- The offset follows a typed Mid without a rebuild, so the number field keeps its focus.
    local s = list[index]
    if phase == "servo" and s and offsetRow then
      local config = wiz.configs[s.servo]
      if config then
        local centre = heli.bandCentre(config)
        local text = string.format(T.from, config.mid - centre, centre)
        if text ~= shownOffset then
          shownOffset = text
          if scr:setCheckValue(offsetRow, text) then wiz.invalidate() end
        end
      end
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

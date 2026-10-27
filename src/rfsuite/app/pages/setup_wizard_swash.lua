-- Setup Wizard step: Swashplate. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of the EdgeTX suite's helicopter setup swash step, with the
-- same pictures: the Configurator's drawings at 220 x 160 (app/gfx/setup_wizard/
-- swash-*.png, rotor-*.png, tail-*.png). Each screen has the picture on the left
-- and its controls on the right, as the other steps do, the controls being
-- EdgeTX-style drop-downs. One screen each:
--
--   prepare  servos unplugged and blades off, both on before Start
--   type     the swash type (MSP_MIXER_CONFIG swash_type); for 120, 135 and 140
--            also whether servo 1 sits in front of the main shaft or behind it
--            (the picture only: the FC does not store it)
--   dir      the main rotor direction (main_rotor_dir), seen from above
--   tail     the tail type (tail_rotor_mode). A change resets the yaw mixer
--            rate (250 for a pitch tail, 1000 for a motor, keeping its sign)
--            and applies after a restart. The tail pin (SERVO 4 or MOTOR 2,
--            lib/msp_tail_motor_output.lua) is moved to match on save, and
--            Tail Torque Assist follows a change between servo and motor
--            tail on every PID profile, as the configurator's commit does.
--   done     what is set now, with its picture
--
-- Mixer config changes go to the FC straight away (wiz.editMix()).

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()).
local OWNED = ui.notLoaded({"rfsuite.lib.msp_tail_motor_output", "rfsuite.lib.msp_select_profile",
  "rfsuite.lib.msp_governor_profile"})
local tailOutput = requireModule("lib/msp_tail_motor_output.lua")

-- Prepare, type, dir, tail, done.
local STEP_COUNT = 5
local PICTURE_W, PICTURE_H = 220, 160

local T = {
  prepareTitle = "@i18n(app.modules.setup_wizard.rcv_prepare_title)@",
  prepareText = "@i18n(app.modules.setup_wizard.swa_prepare_text)@",
  unplugged = "@i18n(app.modules.setup_wizard.sen_servos_unplugged)@",
  blades = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  photoSide = "@i18n(app.modules.setup_wizard.art_side)@",
  photoFront = "@i18n(app.modules.setup_wizard.art_front)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  typeTitle = "@i18n(app.modules.setup_wizard.swa_type_title)@",
  typeText = "@i18n(app.modules.setup_wizard.swa_type_text)@",
  servo1 = "@i18n(app.modules.setup_wizard.swa_servo1)@",
  servoFront = "@i18n(app.modules.setup_wizard.swa_front)@",
  servoRear = "@i18n(app.modules.setup_wizard.swa_rear)@",
  dirTitle = "@i18n(app.modules.setup_wizard.swa_dir_title)@",
  dirText = "@i18n(app.modules.setup_wizard.swa_dir_text)@",
  cw = "@i18n(app.modules.setup_wizard.swa_cw)@",
  ccw = "@i18n(app.modules.setup_wizard.swa_ccw)@",
  tailTitle = "@i18n(app.modules.setup_wizard.swa_tail_title)@",
  tailText = "@i18n(app.modules.setup_wizard.swa_tail_text)@",
  tailVariable = "@i18n(app.modules.setup_wizard.swa_tail_variable)@",
  tailMotor = "@i18n(app.modules.setup_wizard.swa_tail_motor)@",
  tailBidir = "@i18n(app.modules.setup_wizard.swa_tail_bidir)@",
  pinMove = "@i18n(app.modules.setup_wizard.swa_pin_move)@",
  pinStuck = "@i18n(app.modules.setup_wizard.swa_pin_stuck)@",
  restart = "@i18n(app.modules.setup_wizard.swa_restart)@",
  doneTitle = "@i18n(app.modules.setup_wizard.swa_done_title)@",
  rowType = "@i18n(app.modules.setup_wizard.swa_row_type)@",
  rowDir = "@i18n(app.modules.setup_wizard.swa_row_dir)@",
  rowTail = "@i18n(app.modules.setup_wizard.swa_row_tail)@",
  rowPin = "@i18n(app.modules.setup_wizard.swa_row_pin)@",
  rowServo = "@i18n(app.modules.setup_wizard.swa_row_servo)@",
  servoNone = "@i18n(app.modules.setup_wizard.swa_servo_none)@",
  pinServo = "@i18n(app.modules.setup_wizard.swa_pin_servo)@",
  pinMotor = "@i18n(app.modules.setup_wizard.swa_pin_motor)@",
  pinBoth = "@i18n(app.modules.setup_wizard.swa_pin_both)@",
  pinNone = "@i18n(app.modules.setup_wizard.swa_pin_none)@",
  direct = "@i18n(app.modules.setup_wizard.swa_direct)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
}

local TAIL_NAMES = {
  [heli.TAIL_VARIABLE] = T.tailVariable,
  [heli.TAIL_MOTORIZED] = T.tailMotor,
  [heli.TAIL_BIDIRECTIONAL] = T.tailBidir,
}

-- The drop-down choices: {text, value} pairs, as the controls take them.
local TAIL_VALUES = {}
for _, mode in ipairs({heli.TAIL_VARIABLE, heli.TAIL_MOTORIZED, heli.TAIL_BIDIRECTIONAL}) do
  TAIL_VALUES[#TAIL_VALUES + 1] = {text = TAIL_NAMES[mode], value = mode}
end

local PIN_NAMES = {
  [tailOutput.OUTPUT.SERVO] = T.pinServo,
  [tailOutput.OUTPUT.MOTOR] = T.pinMotor,
  [tailOutput.OUTPUT.BOTH] = T.pinBoth,
  [tailOutput.OUTPUT.NONE] = T.pinNone,
}

-- The picture names (app/gfx/setup_wizard/) by swash type, and the tail picture by tail mode.
local SWASH_PICTURE = {[1] = "direct", [2] = "120", [3] = "135", [4] = "140", [5] = "90l", [6] = "90v"}
local TAIL_PICTURE = {
  [heli.TAIL_VARIABLE] = "tail-servo",
  [heli.TAIL_MOTORIZED] = "tail-motor",
  [heli.TAIL_BIDIRECTIONAL] = "tail-bidirectional",
}

-- The swash picture: the type; servo 1 in front of the shaft or behind it (120,
-- 135 and 140 only); and the tail servo when the tail has one. nil for no swash.
local function swashPicture(swashType, rear, tailServo)
  local base = SWASH_PICTURE[swashType]
  if not base then return nil end
  local name = "swash-" .. base
  if swashType >= 2 and swashType <= 4 then name = name .. (rear and "-rear" or "-front") end
  if tailServo then name = name .. "-tail" end
  return name
end

-- The kind of tail (servo or motor) the FC has saved, across visits to this
-- step in one wizard session: a tail change made, left unsaved and changed
-- again must still set TTA against what is stored. Keyed weakly by the
-- wizard session (`wiz`), so a closed wizard is not kept alive and the next
-- one starts from what the FC has. The same table keeps servo 1's side for
-- the pictures.
local bases = package.loaded["rfsuite.setup_wizard.swash"] or setmetatable({}, {__mode = "k"})
package.loaded["rfsuite.setup_wizard.swash"] = bases

-- The name of a swash type, as the Configurator writes it: 120°, 90° L, ...
local SWASH_LABEL = {[2] = "120°", [3] = "135°", [4] = "140°", [5] = "90° L", [6] = "90° V"}

local function swashName(swashType)
  if swashType == 1 then return T.direct end
  return SWASH_LABEL[swashType] or "-"
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local screen = "prepare"
  local answers = {blades = false, unplugged = false}
  local answered = nil
  local pin = nil          -- {supported =, output =} from the FC, or nil until read

  local base = bases[wiz]
  if not base then
    base = {}
    bases[wiz] = base
  end
  -- Servo 1 behind the shaft is the usual layout: the default until the user picks the other side.
  if base.rear == nil then base.rear = true end
  local mix = wiz.mixConfig()
  if base.motorised == nil and mix then base.motorised = heli.motorised(mix.tail_rotor_mode) end

  -- One picture layout, replaced when the picture changes (one bitmap in memory).
  local picture, pictureName = nil, nil
  local function pictureOf(name)
    if name ~= pictureName then
      picture, pictureName = art.image(name, PICTURE_W, PICTURE_H), name
    end
    return picture
  end
  local bladesPicture = art.photo("heli-remove-blades", T.photoSide, T.photoFront)

  wiz.fetch({
    pin = function(ok, err) return tailOutput.buildReadMessage(ok, err) end,
  }, function(results)
    pin = results.pin or {supported = false}
    wiz.rebuild()
  end)

  local function go(name)
    screen = name
    wiz.rebuild()
  end

  local function setSwash(swashType)
    local m = wiz.mixConfig()
    if not m or m.swash_type == swashType then return end
    wiz.editMix(function(c) c.swash_type = swashType end)
    wiz.requestReboot()
  end

  local function setDirection(dir)
    local m = wiz.mixConfig()
    if not m or m.main_rotor_dir == dir then return end
    wiz.editMix(function(c) c.main_rotor_dir = dir end)
  end

  -- The save-time work for the tail as it is now: the pin, and TTA when the
  -- kind of tail differs from what is stored. A no-op when neither applies
  -- (a later call replaces an earlier one, see wiz.commitOnSave()).
  local function stageTailCommit(motorised)
    local values = {supported = pin and pin.supported or false, output = pin and pin.output, motorised = motorised}
    if base.motorised ~= nil and motorised ~= base.motorised then values.setTta = motorised end
    local needed = values.setTta ~= nil or tailOutput.movable(values, motorised)
    wiz.commitOnSave("tail_pin", function(onDone, onFail)
      if not needed then
        onDone()
        return
      end
      wiz.send(tailOutput.buildWriteMessage(values, function()
        base.motorised = motorised
        -- A refused move does not fail the save: the tail mode still goes to
        -- EEPROM, and the pin is left to the Mixer page's Tail tab.
        onDone()
      end, onFail))
    end)
  end

  local function setTail(mode)
    local m = wiz.mixConfig()
    if not m or m.tail_rotor_mode == mode then return end
    local motorised = heli.motorised(mode)
    wiz.editMix(function(c) c.tail_rotor_mode = mode end)
    wiz.editInput("yaw", function(input)
      local sign = (input.rate or 0) < 0 and -1 or 1
      input.rate = sign * (motorised and 1000 or 250)
    end)
    wiz.requestReboot()
    stageTailCommit(motorised)
  end

  -- What the pin is or will be, for the tail screen and the done screen.
  local function pinText()
    if not pin or not pin.supported then return nil end
    local motorised = wiz.motorised()
    if tailOutput.movable(pin, motorised) then return T.pinMove end
    if not tailOutput.matches(pin.output, motorised) then return T.pinStuck end
    return PIN_NAMES[pin.output]
  end

  -- The tail servo, as the EdgeTX card shows it: SERVO 4 for a pitch tail, none
  -- for a motor. Unlike the pin, it does not wait for the save.
  local function tailServoRow(mode)
    return {label = T.rowServo, value = heli.motorised(mode) and T.servoNone or T.pinServo}
  end

  -- The swash types as drop-down choices, in the order the step offers them.
  local function swashValues()
    local values = {}
    for _, choice in ipairs(heli.SWASH_CHOICES) do
      values[#values + 1] = {text = swashName(choice), value = choice}
    end
    return values
  end

  function self.build()
    scr:begin()

    if screen == "prepare" then
      scr:text(T.prepareTitle, T.prepareText)
      scr:picture(bladesPicture)
      scr:step(1, STEP_COUNT)
      -- Safety confirmation toggles: 1-click toggle buttons (No/Yes). Start follows once both are Yes.
      local function toggle(key, index)
        return {function() return answers[key] == true end, function(v)
          answers[key], answered = v and true or false, index
          wiz.rebuild()
        end}
      end
      local ready = answers.unplugged and answers.blades
      local answerField = scr:checks({
        {label = T.unplugged, toggle = toggle("unplugged", 1)},
        {label = T.blades, toggle = toggle("blades", 2)},
      }, (not ready) and (answered or (not answers.unplugged and 1) or 2) or nil)
      answered = nil
      local rowField = scr:row(nil, {{text = T.start, primary = ready, disabled = not ready,
        press = function() go("type") end}})
      return answerField or rowField
    end

    local m = wiz.mixConfig()
    if not m then
      scr:text(T.typeTitle, "@i18n(app.msg_loading)@")
      return scr:row()
    end

    if screen == "type" then
      local rear = base.rear == true
      scr:text(T.typeTitle, T.typeText)
      scr:step(2, STEP_COUNT)
      local name = swashPicture(m.swash_type, rear, not heli.motorised(m.tail_rotor_mode))
      if name then scr:picture(pictureOf(name)) end
      local rows = {
        {label = T.typeTitle, choice = {values = swashValues(),
          get = function() return m.swash_type end,
          set = function(v) setSwash(v); wiz.rebuild() end}},
      }
      -- Servo 1's side: 120, 135 and 140 only. It changes the picture, not the FC.
      if m.swash_type >= 2 and m.swash_type <= 4 then
        rows[#rows + 1] = {label = T.servo1, choice = {
          values = {{text = T.servoFront, value = 0}, {text = T.servoRear, value = 1}},
          get = function() return rear and 1 or 0 end,
          set = function(v) base.rear = v == 1; wiz.rebuild() end}}
      end
      if wiz.rebootPending() then rows[#rows + 1] = {note = T.restart} end
      local field = scr:checks(rows)
      local rowField = scr:row(function() go("prepare") end, nil, {text = T.next, press = function() go("dir") end})
      return field or rowField

    elseif screen == "dir" then
      scr:text(T.dirTitle, T.dirText)
      scr:step(3, STEP_COUNT)
      scr:picture(pictureOf(m.main_rotor_dir == 1 and "rotor-ccw" or "rotor-cw"))
      local field = scr:checks({
        {label = T.dirTitle, choice = {
          values = {{text = T.cw, value = 0}, {text = T.ccw, value = 1}},
          get = function() return m.main_rotor_dir end,
          set = function(v) setDirection(v); wiz.rebuild() end}},
      })
      local rowField = scr:row(function() go("type") end, nil, {text = T.next, press = function() go("tail") end})
      return field or rowField

    elseif screen == "tail" then
      scr:text(T.tailTitle, T.tailText)
      scr:step(4, STEP_COUNT)
      local tailName = TAIL_PICTURE[m.tail_rotor_mode]
      if tailName then scr:picture(pictureOf(tailName)) end
      local rows = {
        {label = T.tailTitle, choice = {values = TAIL_VALUES,
          get = function() return m.tail_rotor_mode end,
          set = function(v) setTail(v); wiz.rebuild() end}},
      }
      local p = pinText()
      if p then rows[#rows + 1] = {label = T.rowPin, value = p} end
      rows[#rows + 1] = tailServoRow(m.tail_rotor_mode)
      if wiz.rebootPending() then rows[#rows + 1] = {note = T.restart} end
      local field = scr:checks(rows)
      local rowField = scr:row(function() go("dir") end, nil, {text = T.next, press = function() go("done") end})
      return field or rowField
    end

    -- done
    scr:text(T.doneTitle, nil, wiz.rebootPending() and T.restart or nil)
    scr:step(STEP_COUNT, STEP_COUNT)
    -- The picture on the left, the values set on the right, as on the other screens.
    local name = swashPicture(m.swash_type, base.rear == true, not heli.motorised(m.tail_rotor_mode))
    if name then scr:picture(pictureOf(name)) end
    local rows = {
      {label = T.rowType, value = swashName(m.swash_type)},
      {label = T.rowDir, value = m.main_rotor_dir == 1 and T.ccw or T.cw},
      {label = T.rowTail, value = TAIL_NAMES[m.tail_rotor_mode] or "-"},
    }
    local p = pinText()
    if p then rows[#rows + 1] = {label = T.rowPin, value = p} end
    rows[#rows + 1] = tailServoRow(m.tail_rotor_mode)
    if p == T.pinStuck then rows[#rows + 1] = {note = p} end
    local field = scr:checks(rows)
    local rowField = scr:row(function() go("tail") end)
    return field or rowField
  end

  function self.paint() scr:paint() end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}

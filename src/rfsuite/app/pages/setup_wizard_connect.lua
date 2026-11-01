-- Setup Wizard step: Connect the servos. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepConnect.svelte, the
-- gate between the steps that set the outputs up and the ones that move
-- them:
--
--   * A restart still owed (board orientation, swash or tail type, servo
--     rate, motor protocol): the servos stay unplugged, and the footer's way
--     forward is Save and restart (the shell, wiz.forward()). The wizard
--     reopens on this step once the FC is back.
--   * Otherwise two screens. First a safety card for the blades: they stay
--     off until the Finish step, and the battery stays unplugged until the
--     next step says so. Then the outputs: the swashplate picture of
--     the Swashplate step on the left (the same picture, by swash type and
--     servo 1's side), the motor checks on the right (the motor outputs are
--     checked: MSP_MOTOR, 0 means the output is not configured), and the
--     servos plugged in, blades still off.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")

local OWNED = {}

local PICTURE_W, PICTURE_H = 220, 160

-- The Swashplate step's pictures (app/gfx/setup_wizard/swash-*.png) by swash type.
local SWASH_PICTURE = {[1] = "direct", [2] = "120", [3] = "135", [4] = "140", [5] = "90l", [6] = "90v"}

-- The Swashplate step's picture name: the type, servo 1 in front of the shaft or
-- behind it (120, 135 and 140 only), and the tail servo when the tail has one.
local function swashPicture(swashType, rear, tailServo)
  local base = SWASH_PICTURE[swashType]
  if not base then return nil end
  local name = "swash-" .. base
  if swashType >= 2 and swashType <= 4 then name = name .. (rear and "-rear" or "-front") end
  if tailServo then name = name .. "-tail" end
  return name
end

local T = {
  title = "@i18n(app.modules.setup_wizard.con_title)@",
  reboot = "@i18n(app.modules.setup_wizard.con_reboot)@",
  plug = "@i18n(app.modules.setup_wizard.con_plug)@",
  blades = "@i18n(app.modules.setup_wizard.con_blades)@",
  battery = "@i18n(app.modules.setup_wizard.con_battery)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  mainMotor = "@i18n(app.modules.setup_wizard.con_main_motor)@",
  tailMotor = "@i18n(app.modules.setup_wizard.con_tail_motor)@",
  ok = "@i18n(app.modules.setup_wizard.con_ok)@",
  missing = "@i18n(app.modules.setup_wizard.con_missing)@",
  checking = "@i18n(app.modules.setup_wizard.con_checking)@",
  servoMissing = "@i18n(app.modules.setup_wizard.con_servo_missing)@",
}

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local screen = "prepare"
  local answers = {blades = false, battery = false}   -- the safety answers, kept across rebuilds

  -- Motor rows (the checks' row numbers) and the state they show, so wakeup only
  -- touches a row whose answer changed.
  local motorRows = {}
  local shown = {}

  -- The Swashplate step's picture: servo 1's side is kept there for the session, and
  -- rear is the default.
  local function servoRear()
    local swashBases = package.loaded["rfsuite.setup_wizard.swash"]
    local base = swashBases and swashBases[wiz]
    return not (base and base.rear == false)
  end

  local function picture()
    local mix = wiz.mixConfig() or {}
    local tailServo = not wiz.motorised()
    local name = swashPicture(mix.swash_type or 0, servoRear(), tailServo)
    if name then return art.image(name, PICTURE_W, PICTURE_H) end
    return art.image("swash-direct", PICTURE_W, PICTURE_H)
  end

  local function motorState(i)
    local v = wiz.motors[i]
    if v == nil then return nil end
    return v ~= 0
  end

  local function stateText(state)
    if state == nil then return T.checking end
    return state and T.ok or T.missing
  end

  function self.build()
    scr:begin()
    local servos = wiz.servos()

    if wiz.rebootPending() then
      -- Unplugged: the picture shows the outputs' layout, without states.
      self.liveMotors = nil
      scr:text(T.title, T.reboot)
      scr:picture(picture())
      return scr:row()
    end

    if screen == "prepare" then
      scr:text(T.title, nil)
      scr:step(1, 2)
      scr:picture(picture())
      return scr:safety(answers, {{key = "blades", label = T.blades}, {key = "battery", label = T.battery}},
        T.start, function()
        screen = "connect"
        wiz.rebuild()
      end)
    end

    -- The outputs: the motor checks as rows on the right, the picture on the left.
    self.liveMotors = true
    local rows = {}
    motorRows = {}
    local function addMotor(label, index)
      local state = motorState(index)
      rows[#rows + 1] = {label = label, value = stateText(state)}
      motorRows[#motorRows + 1] = {row = #rows, index = index}
      shown[index] = state
    end
    addMotor(T.mainMotor, 1)
    if wiz.motorised() then addMotor(T.tailMotor, 2) end

    local anyMissing = false
    for _, s in ipairs(servos) do
      if s.missing then anyMissing = true end
    end

    scr:text(T.title, T.plug, anyMissing and T.servoMissing or nil)
    scr:step(2, 2)
    scr:picture(picture())
    local field = scr:checks(rows)
    local rowField = scr:row(function()
      screen = "prepare"
      wiz.rebuild()
    end)
    return field or rowField
  end

  function self.paint() scr:paint() end

  function self.wakeup()
    if not self.liveMotors then return end
    local changed = false
    for i = 1, #motorRows do
      local m = motorRows[i]
      local state = motorState(m.index)
      if shown[m.index] ~= state then
        shown[m.index] = state
        if scr:setCheckValue(m.row, stateText(state)) then changed = true end
      end
    end
    if changed then wiz.invalidate() end
  end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}

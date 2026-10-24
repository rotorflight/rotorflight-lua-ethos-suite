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
--   * Otherwise: the motor outputs are checked (MSP_MOTOR: 0 means the
--     output is not configured), the servos the wizard will use are listed,
--     and the pilot plugs them in, blades still off.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")

local OWNED = {}

local T = {
  title = "@i18n(app.modules.setup_wizard.con_title)@",
  reboot = "@i18n(app.modules.setup_wizard.con_reboot)@",
  plug = "@i18n(app.modules.setup_wizard.con_plug)@",
  blades = "@i18n(app.modules.setup_wizard.con_blades)@",
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

  -- Motor rows (index into scr's rows) and the state they show, so wakeup
  -- only touches a row whose answer changed.
  local motorRows = {}
  local shown = {}
  -- The outputs picture: the swash servos (a missing one in red), the main
  -- motor and the tail; its motor states follow the rows (wakeup).
  local map = nil

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
    local tailServo = nil
    for _, s in ipairs(servos) do
      if s.tail then tailServo = s end
    end
    map = art.map(servos, {status = true, dir = (wiz.mixConfig() or {}).main_rotor_dir,
      motorised = wiz.motorised(), tailLabel = tailServo and tostring(tailServo.servo + 1) or nil,
      tailMissing = tailServo and tailServo.missing})
    if wiz.rebootPending() then
      self.liveMotors = nil
      scr:text(T.title, T.reboot)
      -- Unplugged: the picture shows where they go, without states.
      map.status = false
      scr:picture(map)
      return scr:row()
    end
    self.liveMotors = true

    local rows = {}
    motorRows = {}
    local function addMotor(label, index)
      local state = motorState(index)
      rows[#rows + 1] = {label, stateText(state), state == false}
      motorRows[#motorRows + 1] = {row = #rows, index = index}
      shown[index] = state
    end
    addMotor(T.mainMotor, 1)
    if wiz.motorised() then addMotor(T.tailMotor, 2) end
    map.main, map.tail = shown[1], shown[2]

    local anyMissing = false
    for _, s in ipairs(servos) do
      if s.missing then anyMissing = true end
    end

    scr:text(T.title, T.plug .. " " .. T.blades, anyMissing and T.servoMissing or nil)
    scr:rows(rows)
    scr:picture(map)
    return scr:row()
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
        if scr:setRow(m.row, stateText(state), state == false) then changed = true end
        if map then
          if m.index == 1 then map.main = state else map.tail = state end
          changed = true
        end
      end
    end
    if changed then wiz.invalidate() end
  end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}

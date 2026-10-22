-- Setup Wizard step: Swashplate. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepSwash.svelte. One
-- screen each:
--
--   type    the swash type (MSP_MIXER_CONFIG swash_type), as a grid; a new
--           type only applies after a restart
--   show    where that type's servos sit, from above, nose at the top
--   dir     the main rotor direction (main_rotor_dir), seen from above
--   tail    the tail type (tail_rotor_mode). A change resets the yaw mixer
--           rate (250 for a pitch tail, 1000 for a motor, keeping its sign)
--           and applies after a restart. The tail pin (SERVO 4 or MOTOR 2,
--           lib/msp_tail_motor_output.lua) is moved to match on save, and
--           Tail Torque Assist follows a change between servo and motor
--           tail on every PID profile, as the configurator's commit does.
--   done    what is set now
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

local T = {
  typeTitle = "@i18n(app.modules.setup_wizard.swa_type_title)@",
  typeText = "@i18n(app.modules.setup_wizard.swa_type_text)@",
  current = "@i18n(app.modules.setup_wizard.swa_current_fmt)@",
  showText = "@i18n(app.modules.setup_wizard.swa_show_text)@",
  fromAbove = "@i18n(app.modules.setup_wizard.swa_from_above)@",
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
local TAIL_CHOICES = {heli.TAIL_VARIABLE, heli.TAIL_MOTORIZED, heli.TAIL_BIDIRECTIONAL}

local PIN_NAMES = {
  [tailOutput.OUTPUT.SERVO] = T.pinServo,
  [tailOutput.OUTPUT.MOTOR] = T.pinMotor,
  [tailOutput.OUTPUT.BOTH] = T.pinBoth,
  [tailOutput.OUTPUT.NONE] = T.pinNone,
}

-- The kind of tail (servo or motor) the FC has saved, across visits to this
-- step in one wizard session: a tail change made, left unsaved and changed
-- again must still set TTA against what is stored. Keyed weakly by the
-- wizard session (`wiz`), so a closed wizard is not kept alive and the next
-- one starts from what the FC has.
local bases = package.loaded["rfsuite.setup_wizard.swash"] or setmetatable({}, {__mode = "k"})
package.loaded["rfsuite.setup_wizard.swash"] = bases

local function swashName(swashType)
  if swashType == 1 then return T.direct end
  local s = heli.SWASH[swashType]
  return s and s.name or "-"
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local screen = "type"
  local pin = nil          -- {supported =, output =} from the FC, or nil until read

  local base = bases[wiz]
  if not base then
    base = {}
    bases[wiz] = base
  end
  local mix = wiz.mixConfig()
  if base.motorised == nil and mix then base.motorised = heli.motorised(mix.tail_rotor_mode) end

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

  -- What the pin is or will be, for the done screen.
  local function pinText()
    if not pin or not pin.supported then return nil end
    local motorised = wiz.motorised()
    if tailOutput.movable(pin, motorised) then return T.pinMove end
    if not tailOutput.matches(pin.output, motorised) then return T.pinStuck end
    return PIN_NAMES[pin.output]
  end

  function self.build()
    scr:begin()
    local m = wiz.mixConfig()
    if not m then
      scr:text(T.typeTitle, "@i18n(app.msg_loading)@")
      return scr:row()
    end

    if screen == "type" then
      scr:text(T.typeTitle, T.typeText, string.format(T.current, swashName(m.swash_type)))
      if heli.SWASH[m.swash_type] then
        scr:picture(art.swash(heli.wizardServos(m.swash_type, heli.TAIL_MOTORIZED, 8), nil, nil))
      end
      local forward = scr:row(nil, nil, {text = T.next, press = function()
        go(heli.SWASH[m.swash_type] and "show" or "dir")
      end})
      local specs = {}
      for _, choice in ipairs(heli.SWASH_CHOICES) do
        specs[#specs + 1] = {text = swashName(choice), primary = choice == m.swash_type, press = function()
          setSwash(choice)
          go("show")
        end}
      end
      return scr:grid(specs, 3) or forward

    elseif screen == "show" then
      local servos = heli.wizardServos(m.swash_type, heli.TAIL_MOTORIZED, 8)
      scr:text(swashName(m.swash_type), T.showText, wiz.rebootPending() and T.restart or nil)
      scr:picture(art.swash(servos, nil, nil), T.fromAbove)
      return scr:row(function() go("type") end, nil, {text = T.next, press = function() go("dir") end})

    elseif screen == "dir" then
      scr:text(T.dirTitle, T.dirText)
      scr:picture(art.rotor(m.main_rotor_dir), T.fromAbove)
      return scr:row(function() go(heli.SWASH[m.swash_type] and "show" or "type") end, {
        {text = T.cw, primary = m.main_rotor_dir == 0, press = function() setDirection(0); wiz.rebuild() end},
        {text = T.ccw, primary = m.main_rotor_dir == 1, press = function() setDirection(1); wiz.rebuild() end},
      }, {text = T.next, press = function() go("tail") end})

    elseif screen == "tail" then
      scr:text(T.tailTitle, T.tailText, string.format(T.current, TAIL_NAMES[m.tail_rotor_mode] or "-"))
      scr:picture(art.tailType(m.tail_rotor_mode))
      local forward = scr:row(function() go("dir") end, nil, {text = T.next, press = function() go("done") end})
      local specs = {}
      for _, mode in ipairs(TAIL_CHOICES) do
        specs[#specs + 1] = {text = TAIL_NAMES[mode], primary = mode == m.tail_rotor_mode, press = function()
          setTail(mode)
          wiz.rebuild()
        end}
      end
      return scr:grid(specs, #specs) or forward
    end

    -- done
    scr:text(T.doneTitle, nil, wiz.rebootPending() and T.restart or nil)
    local rows = {
      {T.rowType, swashName(m.swash_type)},
      {T.rowDir, m.main_rotor_dir == 1 and T.ccw or T.cw},
      {T.rowTail, TAIL_NAMES[m.tail_rotor_mode] or "-"},
    }
    local p = pinText()
    if p then rows[#rows + 1] = {T.rowPin, p, p == T.pinStuck} end
    scr:rows(rows)
    local servos = heli.wizardServos(m.swash_type, m.tail_rotor_mode, wiz.servoCount())
    local tailServo = nil
    for _, s in ipairs(servos) do
      if s.tail then tailServo = s end
    end
    scr:picture(art.map(servos, {dir = m.main_rotor_dir, motorised = heli.motorised(m.tail_rotor_mode),
      tailLabel = tailServo and tostring(tailServo.servo + 1) or nil}))
    return scr:row(function() go("tail") end)
  end

  function self.paint() scr:paint() end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}

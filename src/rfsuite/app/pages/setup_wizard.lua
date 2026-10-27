-- Wizards -> Model setup (beside Setup on the main menu, as in the EdgeTX suite).
--
-- The radio's copy of rotorflight-configurator's helicopter Setup Wizard
-- (src/tabs/setup_wizard/SetupWizard.svelte; the EdgeTX suite's
-- helicopter_setup ports the same thing). It asks the same questions and
-- fixes things by the same rules, but as a guided sequence for a radio
-- screen: one question per screen, a picture, and big answer buttons (see
-- app/setup_wizard_ui.lua and app/setup_wizard_art.lua).
--
-- This file is the shell: it loads what every step needs, blocks arming
-- while the wizard is open, owns every override a step asks for, and saves,
-- reverts or restarts. Each step is its own file
-- (app/pages/setup_wizard_<step>.lua), loaded when it opens and dropped when
-- it closes, and talks to the shell only through the `wiz` table below -- the
-- counterpart of the configurator's setContext("setupWizard").
--
-- The bench steps only. The radio talks to the flight controller through the
-- receiver, so the receiver protocol and port stay in the Configurator (the
-- Receiver step here does the channel order, sticks and throttle range), and
-- Modes, Profiles, Rates, Governor, the ESC spin test and ESC telemetry have
-- their own pages.
--
-- Safety, as in the configurator:
--   * Arming is blocked while the wizard is open (MSP_SET_ARMING_DISABLED),
--     and the flight controller ignores overrides while armed anyway: an
--     armed model releases everything and the page says why.
--   * Rotorflight's servo and mixer overrides do not time out: they hold
--     until they are released. Every way out (Back, the close key, a step
--     change, closing the tool, arming) releases every override the page may
--     have set, and a link that comes back after a drop is sent the releases
--     again.
--   * Motor overrides lapse on the flight controller a second after the last
--     write, so a motor test is re-sent while it runs and simply stops when
--     the page does.
--
-- Changes a step makes are sent to the flight controller straight away, so
-- the servos move; Save writes them to EEPROM. Every change is registered
-- with wiz.change() first, so Discard can write back what was there.
-- Changes that only apply after a restart (board orientation, swash type,
-- tail type, servo rate, motor protocol) are saved as the wizard goes, and
-- the one restart happens at the Connect the servos step, with the servos
-- still unplugged, as in the configurator.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()

-- Modules only the wizard uses: dispose() frees the ones this visit loaded,
-- as app/page_runtime.lua's unloadPackageKeys does for other pages. This
-- file runs again on every visit (app/menu_container.lua's loadPage()), so
-- the check is per visit. Each step frees its own the same way
-- (app/setup_wizard_ui.lua's notLoaded()).
local SHELL_MODULES = {
  "rfsuite.lib.msp_mixer_input", "rfsuite.lib.msp_mixer_config", "rfsuite.lib.msp_servo_config",
  "rfsuite.lib.msp_servo", "rfsuite.lib.msp_rc_channels", "rfsuite.lib.msp_motor",
  "rfsuite.lib.msp_arming_disabled", "rfsuite.lib.setup_wizard_heli",
  "rfsuite.app.setup_wizard_ui", "rfsuite.app.setup_wizard_art", "rfsuite.lib.heli3d",
}
local shellOwned = {}
for i = 1, #SHELL_MODULES do
  if package.loaded[SHELL_MODULES[i]] == nil then shellOwned[#shellOwned + 1] = SHELL_MODULES[i] end
end

local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local status = requireModule("lib/msp_status.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local reboot = requireModule("lib/msp_reboot.lua")
local mixerInput = requireModule("lib/msp_mixer_input.lua")
local mixerConfig = requireModule("lib/msp_mixer_config.lua")
local servoConfig = requireModule("lib/msp_servo_config.lua")
local servoRead = requireModule("lib/msp_servo.lua")
local servoOverride = requireModule("lib/msp_servo_override.lua")
local mixerOverride = requireModule("lib/msp_mixer_override.lua")
local motorOverride = requireModule("lib/msp_motor_override.lua")
local motorRead = requireModule("lib/msp_motor.lua")
local rcChannels = requireModule("lib/msp_rc_channels.lua")
local armingDisabled = requireModule("lib/msp_arming_disabled.lua")
local heli = requireModule("lib/setup_wizard_heli.lua")
local ui = requireModule("app/setup_wizard_ui.lua")
-- Steps draw with it; loaded here so they share one copy.
requireModule("app/setup_wizard_art.lua")

local PAGE_TITLE = "@i18n(app.modules.setup_wizard.name)@"
local MSG_LOADING_TITLE = "@i18n(app.msg_loading)@"
local MSG_LOADING_BODY = "@i18n(app.msg_loading_from_fbl)@"
local MSG_SAVING_TITLE = "@i18n(app.msg_saving)@"
local MSG_SAVING_BODY = "@i18n(app.msg_saving_settings)@"
local MSG_SAVE_FAILED_TITLE = "@i18n(app.msg_save_failed_title)@"
local MSG_SAVE_FAILED_BODY = "@i18n(app.msg_save_failed_body)@"
local MSG_LOAD_FAILED_TITLE = "@i18n(app.msg_load_failed_title)@"
local MSG_LOAD_FAILED_BODY = "@i18n(app.msg_load_failed_body)@"
local MSG_RESTARTING_TITLE = "@i18n(app.msg_restarting)@"
local MSG_RESTARTING = "@i18n(app.msg_restarting_fc)@"
local MSG_REBOOT_WAIT = "@i18n(app.modules.setup_wizard.reboot_wait_fmt)@"
local STEPS_ICON = "app/gfx/nav/steps.png"
local NEXT = "@i18n(app.modules.setup_wizard.btn_next)@"
local SAVE_NEXT = "@i18n(app.modules.setup_wizard.dir_save_next)@"
local SAVE_FINISH = "@i18n(app.modules.setup_wizard.fin_button)@"
local SAVE_RESTART = "@i18n(app.modules.setup_wizard.btn_save_restart)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"

-- Order is the procedure, as in the configurator's STEPS: each step relies
-- on the ones before it. needsServos: the step works on the swash or tail
-- servos; needsSwash: on the swash servos alone. Either waits for the
-- Swashplate step. gate: the step where a
-- pending restart happens (the servos are still unplugged before it).
local STEPS = {
  {key = "sensors", title = "@i18n(app.modules.setup_wizard.step_sensors)@"},
  {key = "receiver", title = "@i18n(app.modules.setup_wizard.step_receiver)@"},
  -- Assigned while the radio is in hand, as the Configurator; arming stays blocked.
  {key = "modes", title = "@i18n(app.modules.setup_wizard.step_modes)@"},
  {key = "profiles", title = "@i18n(app.modules.setup_wizard.step_profiles)@"},
  {key = "swash", title = "@i18n(app.modules.setup_wizard.step_swash)@"},
  {key = "servotype", title = "@i18n(app.modules.setup_wizard.step_servotype)@", needsServos = true},
  {key = "motor", title = "@i18n(app.modules.setup_wizard.step_motor)@"},
  {key = "connect", title = "@i18n(app.modules.setup_wizard.step_connect)@", gate = true},
  {key = "servos", title = "@i18n(app.modules.setup_wizard.step_servos)@", needsServos = true},
  {key = "direction", title = "@i18n(app.modules.setup_wizard.step_direction)@", needsSwash = true},
  {key = "level", title = "@i18n(app.modules.setup_wizard.step_level)@", needsSwash = true},
  {key = "pitch", title = "@i18n(app.modules.setup_wizard.step_pitch)@", needsSwash = true},
  {key = "tail", title = "@i18n(app.modules.setup_wizard.step_tail)@"},
  {key = "gyro", title = "@i18n(app.modules.setup_wizard.step_gyro)@", needsSwash = true},
  {key = "finish", title = "@i18n(app.modules.setup_wizard.step_finish)@"},
}

-- Where the wizard was, and whether a restart is still owed, for the next
-- time it opens in this session (the configurator keeps the step in
-- localStorage). Survives a flight controller restart, which the page itself
-- sits through.
local memory = package.loaded["rfsuite.setup_wizard.memory"] or {stepKey = nil, rebootPending = false}
package.loaded["rfsuite.setup_wizard.memory"] = memory

local INPUT_AXES = {"roll", "pitch", "yaw", "collective"}

-- Live values, while a step shows them: one read at a time, and a read that
-- has not answered within a second is given up.
-- rc at 0.4 s: a faster poll crowds the telemetry on the same link (FBUS), and
-- the radio announces the telemetry as lost.
-- On S.Port, F.Port and FBUS each MSP reply blanks the FC's sensor telemetry for
-- 250 ms (firmware telemetry/smartport.c, SMARTPORT_MSP_SILENCE_US): a step
-- that reads often can make Ethos report the sensors lost. A step may set its own
-- interval (step.liveRcInterval).
local POLL_INTERVAL = {servo = 0.25, rc = 0.4, raw = 0.6, motor = 0.5}
-- A live read is sent once (maxRetries = 0): a lost reply is not resent, the
-- next poll is the retry. The queue then answers within its 0.8 s window, so
-- this is only a safety net; shorter than the queue's own retries (6 x 0.8 s
-- by default) it stacked new reads behind the unanswered ones.
local POLL_GIVE_UP = 3.0

-- A motor override lapses on the FC after 1 s: re-sent this often.
local MOTOR_RESEND = 0.25

-- Give-up bound for a restart, as app/page_runtime.lua's.
local REBOOT_TIMEOUT_SECONDS = 20

local FORM_RIGHT_PADDING = 8

local function copyDeep(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = copyDeep(v) end
  return out
end

local function stepIndexOf(key)
  for i, s in ipairs(STEPS) do
    if s.key == key then return i end
  end
  return nil
end

local GATE_INDEX = stepIndexOf("connect")

---------------------------------------------------------------------------
-- Text helpers shared with the steps. Ethos static text does not wrap, so
-- longer text is wrapped here, measured in the font it is drawn in (as
-- app/header.lua does).
---------------------------------------------------------------------------

local function windowWidth()
  local w = 480
  if lcd and lcd.getWindowSize then w = lcd.getWindowSize() or w end
  return w
end

local function lineMetrics(line)
  local slots = form.getFieldSlots(line, {0})
  local slot = slots and slots[1] or nil
  return (slot and slot.y) or 0, (slot and slot.h) or 38
end

-- A line that is all text: an empty form line and a rect spanning the window
-- (see app/pages/motor_override.lua's addTextLine()).
local function addTextLine(text)
  local line = form.addLine("")
  local y, h = lineMetrics(line)
  return form.addStaticText(line, {x = 0, y = y, w = windowWidth(), h = h}, text, LEFT)
end

local function wrapLines(text, maxW, font)
  local out, line = {}, ""
  lcd.font(font or FONT_STD)
  for word in text:gmatch("%S+") do
    local candidate = (line == "") and word or (line .. " " .. word)
    if line == "" or lcd.getTextSize(candidate) <= maxW then
      line = candidate
    else
      out[#out + 1] = line
      line = word
    end
  end
  if line ~= "" then out[#out + 1] = line end
  return out
end

-- WRAP_MARGIN keeps the text clear of the form's scroll bar.
local WRAP_MARGIN = 24

local function addWrapped(text)
  local lines = wrapLines(text, windowWidth() - WRAP_MARGIN)
  for i = 1, #lines do addTextLine(lines[i]) end
end

local function open(opts)
  opts = opts or {}

  local disposed = false
  local loaded = false
  local loadFailed = false
  local outstanding = 0

  local servoCount = 0
  local motorCount = 0
  local apiMinor = 0
  local inputCodecs = {}
  for i = 1, #INPUT_AXES do inputCodecs[INPUT_AXES[i]] = mixerInput[INPUT_AXES[i]]() end
  local inputs = {}        -- axis -> {rate =, min =, max =}, signed
  local configs = {}       -- servo (0-based) -> decoded servo config
  local mixConfig = nil    -- decoded MSP_MIXER_CONFIG

  local servos = {}        -- lib/setup_wizard_heli.lua's wizardServos()
  local swashServoCount = 0
  local missingServos = {}
  local positions = {}     -- servo (0-based) -> live output, us
  local rc = {}            -- MSP_RC, by function: rc[1] roll ... rc[6] AUX1
  local rcCommand = {}     -- MSP_RC_COMMAND: roll, pitch, yaw, collective, throttle; +-500
  local rcRaw = {}         -- MSP_RX_CHANNELS, as the receiver sends them
  local motors = {}        -- MSP_MOTOR: motors[1] main ...

  local pending = false    -- unsaved changes on the flight controller
  -- Whether a restart was owed at the last save: Discard puts it back.
  local rebootPendingAtSave = memory.rebootPending == true
  local changes = {}       -- {key =, original =, restore =} in order made
  local changeIndex = {}   -- key -> true
  local commits = {}       -- {key =, run = function(onDone, onFail)} sent before the EEPROM write
  local commitIndex = {}
  local connected = nil
  local armed = nil
  local handshakeDone = nil
  local armingBlocked = false

  local stepIndex = 1
  local step = nil         -- instance of STEPS[stepIndex]
  local stepOwned = nil    -- modules the step loaded for itself, freed when it closes
  local picking = false    -- the step list is showing
  local rebuildWanted = false

  local polls = {servo = {inFlight = false, at = 0}, rc = {inFlight = false, at = 0},
    raw = {inFlight = false, at = 0}, motor = {inFlight = false, at = 0}}
  local fetches = {}       -- {left =, failed =, onDone =} waiting for replies

  local headerHandle = nil
  local noticeField = nil
  local dialog = nil       -- progress dialog
  local messageHandle = nil
  local pendingLeave = false
  local pendingSwitch = nil -- a step chosen with unsaved changes: asked from wakeup
  local saving = false
  local saveRequest = nil  -- {onSaved =} waiting for the next wakeup
  local saveResult = nil   -- "ok" | "failed", set by the EEPROM reply
  local afterSave = nil
  local rebootWait = nil   -- {startedAt =, sawDisconnect =, remaining =, percent =} while restarting

  local heldInputs = {}    -- mixer input -> true
  local heldServos = {}    -- servo -> true
  local heldMotor = nil    -- {index =, value =, untilAt =, sentAt =}

  local sessionHandler = nil
  local wiz
  local beginLoad

  -------------------------------------------------------------------------
  -- Overrides
  -------------------------------------------------------------------------

  local function send(msg) bus.publish("msp.request", msg) end

  local function releaseAxes()
    for input in pairs(heldInputs) do
      heldInputs[input] = nil
      send(mixerOverride.buildWriteMessage(input, heli.MIXER_OFF))
    end
  end

  local function releaseServo(servo)
    if not heldServos[servo] then return end
    heldServos[servo] = nil
    send(servoOverride.buildWriteMessage(servo, heli.SERVO_OFF))
  end

  local function releaseServos()
    for servo in pairs(heldServos) do releaseServo(servo) end
  end

  local function releaseMotor()
    if not heldMotor then return end
    local index = heldMotor.index
    heldMotor = nil
    send(motorOverride.buildWriteMessage(index, motorOverride.OVERRIDE_OFF))
  end

  local function releaseAll()
    releaseAxes()
    releaseServos()
    releaseMotor()
  end

  -- Start from no overrides at all: one left on by another page (or by a
  -- wizard whose link dropped) would hold its servo still and make every
  -- check look wrong.
  local function clearAllOverrides()
    for i = 1, #INPUT_AXES do
      send(mixerOverride.buildWriteMessage(heli.INPUT[INPUT_AXES[i]], heli.MIXER_OFF))
    end
    send(servoOverride.buildWriteAllMessage(heli.SERVO_OFF))
  end

  local function blockArming(blocked)
    if armingBlocked == blocked then return end
    armingBlocked = blocked
    send(armingDisabled.buildWriteMessage(blocked))
  end

  local function canMove()
    return loaded and connected ~= false and armed ~= true and rebootWait == nil
  end

  -------------------------------------------------------------------------
  -- Changes and their undo
  -------------------------------------------------------------------------

  local function markChanged()
    -- The footer's Next becomes Save and continue (wiz.forward()).
    if not pending then rebuildWanted = true end
    pending = true
    if headerHandle and headerHandle.setSaveEnabled then headerHandle.setSaveEnabled(true) end
  end

  -- Registers what `key` was before the first change since the last save,
  -- and how to put it back. Later changes to the same key keep the first.
  local function change(key, original, restore)
    if not changeIndex[key] then
      changeIndex[key] = true
      changes[#changes + 1] = {key = key, original = copyDeep(original), restore = restore}
    end
    markChanged()
  end

  local function recompute()
    local swashType = mixConfig and mixConfig.swash_type or 0
    local tailMode = mixConfig and mixConfig.tail_rotor_mode or 0
    servos = heli.wizardServos(swashType, tailMode, servoCount)
    missingServos = {}
    swashServoCount = 0
    for _, s in ipairs(servos) do
      if s.missing then missingServos[#missingServos + 1] = s.servo + 1 end
      if not s.tail then swashServoCount = swashServoCount + 1 end
    end
  end

  -------------------------------------------------------------------------
  -- The interface a step sees
  -------------------------------------------------------------------------

  wiz = {
    addTextLine = addTextLine,
    addWrapped = addWrapped,
    wrapLines = wrapLines,
    lineMetrics = lineMetrics,
    windowWidth = windowWidth,
    FORM_RIGHT_PADDING = FORM_RIGHT_PADDING,
    positions = positions,
    rc = rc,
    rcCommand = rcCommand,
    rcRaw = rcRaw,
    motors = motors,
    configs = configs,
    inputs = inputs,
    send = send,
  }

  -- The swash and tail servos the wizard works on (see
  -- lib/setup_wizard_heli.lua's wizardServos()), only those present.
  function wiz.servos() return servos end
  function wiz.missingServos() return missingServos end
  function wiz.servoCount() return servoCount end
  function wiz.motorCount() return motorCount end
  function wiz.mixConfig() return mixConfig end
  function wiz.motorised() return heli.motorised(mixConfig and mixConfig.tail_rotor_mode) end
  function wiz.apiAtLeast(minor) return apiMinor >= minor end
  function wiz.canMove() return canMove() end
  function wiz.armed() return armed == true end
  function wiz.change(key, original, restore) change(key, original, restore) end
  function wiz.markChanged() markChanged() end
  function wiz.copy(t) return copyDeep(t) end

  -- Redraw the step's picture.
  function wiz.invalidate()
    if lcd.invalidate then lcd.invalidate() end
  end

  -- values: {roll =, pitch =, yaw =, collective =} as raw mixer override
  -- values (heli.swashRaw(), heli.tailRaw(), or heli.MIXER_PASSTHROUGH). An
  -- axis left out is not touched.
  function wiz.holdAxes(values)
    if not canMove() then return false end
    for axis, value in pairs(values) do
      local input = heli.INPUT[axis]
      if input then
        heldInputs[input] = true
        send(mixerOverride.buildWriteMessage(input, math.floor(value + 0.5)))
      end
    end
    return true
  end

  function wiz.holdAxis(axis, value)
    if not canMove() then return false end
    local input = heli.INPUT[axis]
    heldInputs[input] = true
    send(mixerOverride.buildWriteMessage(input, math.floor(value + 0.5)))
    return true
  end

  wiz.releaseAxes = releaseAxes

  -- raw: -2000..2000 around the servo's Mid (heli.servoRaw()), 0 = Mid.
  function wiz.holdServo(servo, raw)
    if not canMove() then return false end
    if raw < -2000 then raw = -2000 elseif raw > 2000 then raw = 2000 end
    heldServos[servo] = true
    send(servoOverride.buildWriteMessage(servo, math.floor(raw + 0.5)))
    return true
  end

  wiz.releaseServo = releaseServo
  wiz.releaseServos = releaseServos

  -- Runs motor `index` (0 = main, 1 = tail) at `value` (per mille, -1000..1000)
  -- for at most `seconds`; re-sent from wakeup, since the FC drops a motor
  -- override 1 s after the last write.
  function wiz.holdMotor(index, value, seconds)
    if not canMove() then return false end
    local now = os.clock()
    heldMotor = {index = index, value = math.floor(value + 0.5), untilAt = now + (seconds or 5), sentAt = now}
    send(motorOverride.buildWriteMessage(index, heldMotor.value))
    return true
  end

  wiz.releaseMotor = releaseMotor
  function wiz.motorRunning() return heldMotor ~= nil end

  -- Sends configs[servo] as it stands now. original: the config before the
  -- caller changed it (a copy), for Discard.
  local function sendServo(servo, original)
    change("servo_" .. servo, original or configs[servo], function(o)
      configs[servo] = copyDeep(o)
      send(servoConfig.buildWriteMessage(servo, configs[servo]))
    end)
    send(servoConfig.buildWriteMessage(servo, configs[servo]))
  end

  -- Changes a servo's config with fn(config) and sends it, keeping what it
  -- was for Discard. The way steps should change a servo.
  function wiz.editServo(servo, fn)
    if not configs[servo] then return end
    local original = copyDeep(configs[servo])
    fn(configs[servo])
    sendServo(servo, original)
  end

  local function sendInput(axis)
    send(inputCodecs[axis].buildWriteMessage({
      ["rate_stabilized_" .. axis] = inputs[axis].rate,
      ["min_stabilized_" .. axis] = inputs[axis].min,
      ["max_stabilized_" .. axis] = inputs[axis].max,
    }))
  end

  -- Changes a mixer input ({rate =, min =, max =}, signed) with fn(input).
  function wiz.editInput(axis, fn)
    if not inputs[axis] then return end
    change("input_" .. axis, inputs[axis], function(o)
      inputs[axis] = copyDeep(o)
      sendInput(axis)
    end)
    fn(inputs[axis])
    sendInput(axis)
  end

  -- Changes the mixer config with fn(config). Returns the changed config.
  function wiz.editMix(fn)
    if not mixConfig then return nil end
    change("mix", mixConfig, function(o)
      mixConfig = copyDeep(o)
      send(mixerConfig.buildWriteMessage(mixConfig))
      recompute()
    end)
    fn(mixConfig)
    send(mixerConfig.buildWriteMessage(mixConfig))
    recompute()
    return mixConfig
  end

  -- Work that goes to the FC on the next save, before the EEPROM write (the
  -- tail pin, TTA on every profile). run(onDone, onFail) sends it; a later
  -- call with the same key replaces it. Discard drops it unsent.
  function wiz.commitOnSave(key, run)
    if commitIndex[key] then
      commits[commitIndex[key]].run = run
    else
      commits[#commits + 1] = {key = key, run = run}
      commitIndex[key] = #commits
    end
    markChanged()
  end

  -- A change that only applies after a restart: saved as usual, restarted at
  -- the Connect the servos step (or straight away from a step after it).
  function wiz.requestReboot() memory.rebootPending = true end
  function wiz.rebootPending() return memory.rebootPending == true end
  -- Changes not yet saved to EEPROM: the forward button reads Save and continue.
  function wiz.hasPending() return pending == true end
  -- The screen a step reopens on after wiz.saveAndReboot() (the board
  -- orientation check, which needs the new orientation live). Set before the
  -- restart; taken once, by the same step.
  function wiz.setResume(screen)
    memory.resume = {key = STEPS[stepIndex].key, screen = screen}
  end
  function wiz.takeResume()
    local resume = memory.resume
    memory.resume = nil
    if resume and resume.key == STEPS[stepIndex].key then return resume.screen end
    return nil
  end

  -- Reads for a step: specs = {key = function(onData, onError) return msg end}.
  -- onDone(results, failed) runs from the page's wakeup once every reply is
  -- in (never from the reply itself, where Ethos forbids building a form).
  function wiz.fetch(specs, onDone)
    local f = {left = 0, failed = false, results = {}, onDone = onDone}
    for _ in pairs(specs) do f.left = f.left + 1 end
    fetches[#fetches + 1] = f
    for key, build in pairs(specs) do
      send(build(function(data)
        if disposed or not f.onDone then return end
        f.results[key] = data
        f.left = f.left - 1
      end, function()
        if disposed or not f.onDone then return end
        f.failed = true
        f.left = f.left - 1
      end))
    end
    return f
  end

  local ROLE_NAMES = {
    pitch = "@i18n(app.modules.setup_wizard.role_pitch)@",
    roll = "@i18n(app.modules.setup_wizard.role_roll)@",
    collective = "@i18n(app.modules.setup_wizard.role_collective)@",
    centre = "@i18n(app.modules.setup_wizard.role_centre)@",
    left = "@i18n(app.modules.setup_wizard.role_left)@",
    right = "@i18n(app.modules.setup_wizard.role_right)@",
    front = "@i18n(app.modules.setup_wizard.role_front)@",
    front_left = "@i18n(app.modules.setup_wizard.role_front_left)@",
    front_right = "@i18n(app.modules.setup_wizard.role_front_right)@",
    tail = "@i18n(app.modules.setup_wizard.role_tail)@",
  }

  function wiz.roleName(role) return ROLE_NAMES[role] or role end

  -- "Servo 2 (Left)".
  function wiz.servoName(s)
    return string.format("@i18n(app.modules.setup_wizard.servo_role_fmt)@", s.servo + 1,
      ROLE_NAMES[s.role] or s.role)
  end

  -- The step asks for its screen to be built again (on the next wakeup,
  -- never from inside a field callback).
  function wiz.rebuild() rebuildWanted = true end

  -------------------------------------------------------------------------
  -- Building
  -------------------------------------------------------------------------

  local goBack
  local requestSave
  local leaveWizard
  local openStep
  local changeStep
  local startReboot

  local function noticeText()
    if rebootWait then return MSG_RESTARTING end
    if connected == false then return "@i18n(app.modules.setup_wizard.disconnected)@" end
    if armed == true then return "@i18n(app.modules.setup_wizard.armed)@" end
    if memory.rebootPending and GATE_INDEX and stepIndex > GATE_INDEX then
      return "@i18n(app.modules.setup_wizard.reboot_skipped)@"
    end
    return ""
  end

  local function buildHeader(title)
    headerHandle = header.build(title, {
      onBack = ui.action("back", function() goBack() end),
      onSave = ui.action("save", function() requestSave() end),
      -- The tool button opens the step list, so it shows a checklist, not
      -- the default wrench.
      onTool = loaded and not rebootWait and ui.action("tool", function()
        picking = true
        rebuildWanted = true
      end) or nil,
      toolIcon = STEPS_ICON,
    })
    if headerHandle.setSaveEnabled then headerHandle.setSaveEnabled(pending) end
    if headerHandle.setReloadEnabled then headerHandle.setReloadEnabled(false) end
  end

  -- keepHolds: the caller clears every override itself (dispose()), so the
  -- releases are not sent twice into a queue that holds 20 messages.
  local function closeStep(keepHolds)
    ui.releaseActions()
    -- Queued replies may arrive after navigation. Detach their completion
    -- closures now, so neither the queue nor this list pins the old step.
    for i = #fetches, 1, -1 do
      fetches[i].onDone, fetches[i].results = nil, nil
      fetches[i] = nil
    end
    if step and step.leave then step.leave() end
    step = nil
    if stepOwned then
      ui.unload(stepOwned)
      stepOwned = nil
    end
    if not keepHolds then releaseAll() end
  end

  openStep = function(index)
    closeStep()
    picking = false
    stepIndex = index
    memory.stepKey = STEPS[index].key
    local s = STEPS[index]
    if not ((s.needsServos and #servos == 0) or (s.needsSwash and swashServoCount == 0)) then
      local factory = assert(loadfile("app/pages/setup_wizard_" .. STEPS[index].key .. ".lua"))()
      stepOwned = factory.owned
      step = factory.new(wiz)
    end
    rebuildWanted = true
  end

  -- A step that needs the swash servos, on a model with no swash type yet.
  local noServosScreen = ui.new(wiz)

  function wiz.stepNumber() return stepIndex, #STEPS end
  function wiz.isLastStep() return stepIndex >= #STEPS end

  -- A step's last screen: save, then the next step, or leave the wizard after
  -- the last one (as the configurator's Save and continue). At the gate
  -- with a restart owed, Save and restart (the wizard reopens on the gate).
  function wiz.finishStep()
    if STEPS[stepIndex].gate and memory.rebootPending then
      wiz.saveAndReboot()
    elseif stepIndex < #STEPS then
      local target = stepIndex + 1
      requestSave(function() openStep(target) end)
    else
      requestSave(function() leaveWizard() end)
    end
  end

  -- Back to the previous step, from a step's first screen (changes stay
  -- pending, as with Next on an untouched step).
  function wiz.isFirstStep() return stepIndex <= 1 end
  function wiz.previousStep()
    if stepIndex > 1 then changeStep(stepIndex - 1) end
  end

  -- The footer's default way forward (app/setup_wizard_ui.lua's row()):
  -- Next, Save and continue once something changed, Save and restart at the
  -- gate with a restart owed, Save and finish on the last step. press
  -- defaults to wiz.finishStep().
  function wiz.forward(press)
    local text = NEXT
    if STEPS[stepIndex].gate and memory.rebootPending then
      text = SAVE_RESTART
    elseif stepIndex >= #STEPS then
      text = SAVE_FINISH
    elseif pending then
      text = SAVE_NEXT
    end
    return {text = text, press = press or wiz.finishStep}
  end

  function wiz.goToStep(key)
    local index = stepIndexOf(key)
    if index then changeStep(index) end
  end

  local function clearForm()
    ui.releaseActions()
    noticeField, headerHandle = nil, nil
    form.clear()
  end

  local function buildMessagePage(text)
    clearForm()
    buildHeader(PAGE_TITLE)
    addWrapped(text)
    if headerHandle.focusMenu then headerHandle.focusMenu() end
  end

  -- The step list: one button per step.
  local function buildPicker()
    clearForm()
    buildHeader(PAGE_TITLE)
    local width, height = lcd.getWindowSize()
    local gap = 6
    local top = form.height() + gap
    -- Two columns when every row still gets a usable height, else three.
    local cols = 2
    if width >= 700 or math.ceil(#STEPS / 2) * (30 + gap) > height - top then cols = 3 end
    local rows = math.ceil(#STEPS / cols)
    local h = math.max(28, math.floor((height - top - gap * rows) / rows))
    if h > 48 then h = 48 end
    local w = math.floor((width - FORM_RIGHT_PADDING - gap * (cols - 1)) / cols)
    local focus
    for i, s in ipairs(STEPS) do
      local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
      local button = form.addButton(nil, {x = col * (w + gap), y = top + row * (h + gap), w = w, h = h}, {
        text = string.format("%d. %s", i, s.title),
        options = FONT_S + CENTERED,
        press = ui.action(i, function() changeStep(i) end),
      })
      if i == stepIndex then focus = button end
    end
    if focus and focus.focus then focus:focus() end
  end

  local function build()
    rebuildWanted = false
    if picking then
      buildPicker()
      return
    end
    clearForm()
    buildHeader(PAGE_TITLE .. " / " .. string.format("%d. %s", stepIndex, STEPS[stepIndex].title))
    -- Only when there is something to say: a 320 px screen has no row to spare.
    local notice = noticeText()
    noticeField = (notice ~= "") and addTextLine(notice) or nil
    if #missingServos > 0 and (STEPS[stepIndex].needsServos or STEPS[stepIndex].needsSwash) then
      addWrapped(string.format("@i18n(app.modules.setup_wizard.missing_servos_fmt)@",
        table.concat(missingServos, ", ")))
    end
    if not step then
      -- A step that needs the swash servos, before a swash type is set. The
      -- same row as every step, with a button to the Swashplate step.
      addWrapped("@i18n(app.modules.setup_wizard.no_swash)@")
      noServosScreen:begin()
      local button = noServosScreen:row(nil, {
        {text = "@i18n(app.modules.setup_wizard.go_swash)@", primary = true,
          press = function() wiz.goToStep("swash") end},
      })
      if button and button.focus then button:focus() end
      return
    end
    -- The step has the rest of the screen, from form.height() down.
    local focus = step.build()
    if lcd.invalidate then lcd.invalidate() end
    if focus and focus.focus then
      focus:focus()
    elseif headerHandle.focusMenu then
      headerHandle.focusMenu()
    end
  end

  -- Runs from bus callbacks too, so it never builds: a notice that appears or
  -- goes away asks for a rebuild on the next wakeup.
  local function refreshNotice()
    local notice = noticeText()
    if (notice ~= "") ~= (noticeField ~= nil) then
      rebuildWanted = true
    elseif noticeField then
      noticeField:value(notice)
    end
  end

  -------------------------------------------------------------------------
  -- Dialogs, saving, restarting and leaving
  -------------------------------------------------------------------------

  local function closeProgress()
    if not dialog then return end
    local d = dialog
    dialog = nil
    pcall(function() d:value(100) end)
    pcall(function() d:close(true) end)
  end

  local function closeMessage()
    if not messageHandle then return end
    local h = messageHandle
    messageHandle = nil
    pcall(function() h:close() end)
  end

  local function openMessage(title, body, buttons)
    closeMessage()
    messageHandle = form.openDialog({
      title = title,
      message = body,
      buttons = buttons or {{label = BTN_OK, action = function() messageHandle = nil; return true end}},
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end
  wiz.openMessage = openMessage

  -- Writes back everything changed since the last save, newest first. The
  -- writes are queued and go out from the background task, so the page can
  -- close straight after.
  local function revert()
    for i = #changes, 1, -1 do
      changes[i].restore(changes[i].original)
    end
    changes = {}
    changeIndex = {}
    commits = {}
    commitIndex = {}
    pending = false
    memory.rebootPending = rebootPendingAtSave
  end

  local function writeEeprom()
    send(eeprom.buildWriteMessage(function()
      if not disposed then saveResult = "ok" end
    end, function()
      if not disposed then saveResult = "failed" end
    end))
  end

  -- The staged commits, one after another, then the EEPROM write. Runs in
  -- the background task's reply callbacks: no form calls here.
  local function runCommits(index)
    local c = commits[index]
    if not c then
      writeEeprom()
      return
    end
    c.run(function()
      if disposed then return end
      runCommits(index + 1)
    end, function()
      if not disposed then saveResult = "failed" end
    end)
  end

  -- Started from wakeup (see requestSave()): the progress dialog must not be
  -- opened from inside a button or dialog callback.
  local function startSave(onSaved)
    if not pending then
      if onSaved then onSaved() end
      return
    end
    saving = true
    afterSave = onSaved
    -- Nothing may move while the settings are stored.
    releaseAll()
    dialog = progressDialog.open({title = MSG_SAVING_TITLE, message = MSG_SAVING_BODY})
    -- Replies arrive in the background task, where Ethos forbids form
    -- calls: they only record the outcome, and finishSave() acts on it from
    -- the next wakeup.
    runCommits(1)
  end

  local function finishSave(result)
    saving = false
    closeProgress()
    local done = afterSave
    afterSave = nil
    if result == "ok" then
      pending = false
      rebootPendingAtSave = memory.rebootPending == true
      changes = {}
      changeIndex = {}
      commits = {}
      commitIndex = {}
      if headerHandle and headerHandle.setSaveEnabled then headerHandle.setSaveEnabled(false) end
      if done then done() end
    else
      -- The flight controller refuses EEPROM writes while armed; the changes
      -- stay in RAM either way.
      openMessage(MSG_SAVE_FAILED_TITLE, armed and "@i18n(app.msg_please_disarm_to_save_warning)@"
        or MSG_SAVE_FAILED_BODY)
    end
  end

  -- onSaved runs once the EEPROM write is done (straight away when there is
  -- nothing to save); not at all if it fails.
  requestSave = function(onSaved)
    if saving or not loaded or saveRequest then return end
    saveRequest = {onSaved = onSaved}
  end

  -- Save, restart the flight controller, wait for it to come back, and reopen
  -- the same step, as the configurator does. A progress dialog shows the
  -- wait: the bar fills towards the give-up bound and the message counts
  -- down to it. A board that comes back sooner ends it early.
  startReboot = function()
    closeStep()
    memory.rebootPending = false
    rebootPendingAtSave = false
    -- The FC forgets the arming block when it restarts; finishLoad() sends
    -- it again.
    armingBlocked = false
    rebootWait = {startedAt = os.clock(), sawDisconnect = false, remaining = REBOOT_TIMEOUT_SECONDS, percent = 0}
    send(reboot.buildWriteMessage())
    closeProgress()
    dialog = progressDialog.open({
      title = MSG_RESTARTING_TITLE,
      message = string.format(MSG_REBOOT_WAIT, REBOOT_TIMEOUT_SECONDS),
      speed = 0,
    })
    rebuildWanted = true
  end

  function wiz.saveAndReboot()
    if armed or rebootWait then return end
    -- Saved already (or nothing to save): requestSave() runs it straight away.
    pending = pending or memory.rebootPending
    requestSave(startReboot)
  end

  -- page_runtime.lua's two edges: the link must be seen to drop (or the
  -- handshake reset), then come back with a fresh handshake.
  local function updateReboot(now)
    local wait = rebootWait
    if not wait.sawDisconnect and (connected == false or handshakeDone == false) then
      wait.sawDisconnect = true
    end
    local elapsed = now - wait.startedAt
    local remaining = math.max(0, math.ceil(REBOOT_TIMEOUT_SECONDS - elapsed))
    if wait.remaining ~= remaining then
      wait.remaining = remaining
      if dialog then dialog:message(string.format(MSG_REBOOT_WAIT, remaining)) end
    end
    local percent = math.min(99, math.floor(elapsed * 100 / REBOOT_TIMEOUT_SECONDS))
    if wait.percent ~= percent then
      wait.percent = percent
      if dialog then dialog:value(percent) end
    end
    local back = wait.sawDisconnect and connected == true and handshakeDone == true
    if back or elapsed >= REBOOT_TIMEOUT_SECONDS then
      rebootWait = nil
      -- beginLoad() opens its own Loading dialog.
      closeProgress()
      beginLoad()
    end
  end

  local function dispose()
    if disposed then return end
    disposed = true
    closeStep(true)
    heldInputs, heldServos = {}, {}
    releaseMotor()
    if loaded then clearAllOverrides() end
    blockArming(false)
    closeProgress()
    closeMessage()
    if sessionHandler then
      bus.unsubscribe("session.update", sessionHandler)
      sessionHandler = nil
    end
    headerHandle = nil
    noticeField, rebootWait = nil, nil
    afterSave, saveRequest = nil, nil
    pendingSwitch = nil
    for i = #changes, 1, -1 do changes[i] = nil end
    for key in pairs(changeIndex) do changeIndex[key] = nil end
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setPaintHandler then opts.setPaintHandler(nil) end
    ui.unload(shellOwned)
  end

  local function leave()
    dispose()
    if opts.onBack then opts.onBack() end
  end
  leaveWizard = leave

  local function askLeave()
    openMessage("@i18n(app.modules.setup_wizard.leave_title)@", "@i18n(app.modules.setup_wizard.leave_body)@", {
      {label = "@i18n(app.modules.setup_wizard.leave_save)@", action = function()
        messageHandle = nil
        requestSave(leave)
        return true
      end},
      {label = "@i18n(app.modules.setup_wizard.leave_discard)@", action = function()
        messageHandle = nil
        revert()
        leave()
        return true
      end},
      {label = BTN_CANCEL, action = function()
        messageHandle = nil
        return true
      end},
    })
  end

  -- Another step, from the step list, Back on a step's first screen or a
  -- step's own link: with unsaved changes, first save or discard them, as when
  -- leaving the wizard. Otherwise they would stay pending into the next step and
  -- be saved by its Save and continue.
  local function askSwitch(index)
    openMessage("@i18n(app.modules.setup_wizard.leave_title)@", "@i18n(app.modules.setup_wizard.leave_body)@", {
      {label = "@i18n(app.modules.setup_wizard.leave_save)@", action = function()
        messageHandle = nil
        requestSave(function() openStep(index) end)
        return true
      end},
      {label = "@i18n(app.modules.setup_wizard.leave_discard)@", action = function()
        messageHandle = nil
        revert()
        openStep(index)
        return true
      end},
      {label = BTN_CANCEL, action = function()
        messageHandle = nil
        return true
      end},
    })
  end

  changeStep = function(index)
    if disposed then return end
    if index == stepIndex and step then
      -- The step already open: back to it, nothing to ask.
      picking = false
      rebuildWanted = true
      return
    end
    if pending and loaded then
      -- Opened from wakeup, as askLeave(): not from inside a button callback.
      pendingSwitch = index
      return
    end
    openStep(index)
  end

  goBack = function()
    if disposed then return end
    if picking and step then
      -- Back from the step list returns to the step.
      picking = false
      rebuildWanted = true
      return
    end
    if pending and loaded then
      -- Opened from wakeup: a dialog opened inside a button callback is a
      -- failure this suite has hit on hardware (app/pages/motor_override.lua).
      pendingLeave = true
      return
    end
    leave()
  end

  -------------------------------------------------------------------------
  -- Loading
  -------------------------------------------------------------------------

  local function failed()
    if disposed then return end
    loadFailed = true
  end

  local function answered()
    outstanding = outstanding - 1
  end

  local function requestRest()
    outstanding = 1 + #INPUT_AXES + servoCount
    send(mixerConfig.buildReadMessage(function(data)
      if disposed then return end
      mixConfig = data
      answered()
    end, failed))
    for axis, codec in pairs(inputCodecs) do
      send(codec.buildReadMessage(function(data)
        if disposed then return end
        inputs[axis] = {
          rate = heli.signed16(data["rate_stabilized_" .. axis]),
          min = heli.signed16(data["min_stabilized_" .. axis]),
          max = heli.signed16(data["max_stabilized_" .. axis]),
        }
        answered()
      end, failed))
    end
    for servo = 0, servoCount - 1 do
      send(servoConfig.buildReadMessage(servo, function(data)
        if disposed then return end
        configs[servo] = data
        answered()
      end, failed))
    end
  end

  local function finishLoad()
    loaded = true
    recompute()
    closeProgress()
    clearAllOverrides()
    if armed ~= true then blockArming(true) end
    openStep(stepIndexOf(memory.stepKey) or 1)
  end

  -- The core reads every step relies on. Run on open and after a restart.
  beginLoad = function()
    loaded = false
    outstanding = -1
    if not dialog then
      dialog = progressDialog.open({title = MSG_LOADING_TITLE, message = MSG_LOADING_BODY})
    end
    send(status.buildReadMessage(function(data)
      if disposed then return end
      servoCount = heli.pwmServoCount(data and data.servo_count)
      motorCount = tonumber(data and data.motor_count) or 0
      requestRest()
    end, failed))
  end

  -------------------------------------------------------------------------
  -- Wakeup
  -------------------------------------------------------------------------

  local function pollDone(p) return function() p.inFlight = false end end
  local pollDoneFns = {servo = pollDone(polls.servo), rc = pollDone(polls.rc), raw = pollDone(polls.raw),
    motor = pollDone(polls.motor)}

  -- interval: the step's own, slower one (step.liveRcInterval), or nil for the kind's.
  local function poll(kind, now, interval)
    local p = polls[kind]
    if p.inFlight and (now - p.at) < POLL_GIVE_UP then return end
    if (now - p.at) < (interval or POLL_INTERVAL[kind]) then return end
    p.inFlight = true
    p.at = now
    local done = pollDoneFns[kind]
    local msg
    if kind == "servo" then
      msg = servoRead.buildReadMessage(positions, done, done)
    elseif kind == "motor" then
      msg = motorRead.buildReadMessage(motors, done, done)
    else
      local which = step.liveRc
      if which == "raw" then
        msg = rcChannels.buildReadMessage(rcChannels.RX_CHANNELS_COMMAND, rcRaw, done, done)
      elseif which == "command" then
        msg = rcChannels.buildReadMessage(rcChannels.RC_COMMAND_DATA, rcCommand, done, done)
      else
        msg = rcChannels.buildReadMessage(rcChannels.RC_COMMAND, rc, done, done)
      end
    end
    msg.maxRetries = 0
    send(msg)
  end

  local function wakeup()
    if disposed then return end

    if loadFailed then
      loadFailed = false
      closeProgress()
      buildMessagePage(MSG_LOAD_FAILED_BODY)
      openMessage(MSG_LOAD_FAILED_TITLE, MSG_LOAD_FAILED_BODY)
      return
    end

    local now = os.clock()

    if rebootWait then
      if rebuildWanted then
        rebuildWanted = false
        buildMessagePage(MSG_RESTARTING)
      end
      updateReboot(now)
      return
    end

    if not loaded then
      if outstanding == 0 then finishLoad() end
      return
    end

    if saveResult then
      local result = saveResult
      saveResult = nil
      finishSave(result)
      return
    end

    if pendingLeave then
      pendingLeave = false
      askLeave()
      return
    end

    if pendingSwitch then
      local index = pendingSwitch
      pendingSwitch = nil
      askSwitch(index)
      return
    end

    if saveRequest then
      local request = saveRequest
      saveRequest = nil
      startSave(request.onSaved)
      return
    end

    for i = #fetches, 1, -1 do
      local f = fetches[i]
      if f.left <= 0 then
        table.remove(fetches, i)
        local done, results = f.onDone, f.results
        f.onDone, f.results = nil, nil
        if done then done(results, f.failed) end
      end
    end

    if heldMotor then
      if now >= heldMotor.untilAt or not canMove() then
        releaseMotor()
        if step and step.released then step.released() end
      elseif now - heldMotor.sentAt >= MOTOR_RESEND then
        heldMotor.sentAt = now
        send(motorOverride.buildWriteMessage(heldMotor.index, heldMotor.value))
      end
    end

    if rebuildWanted then
      build()
      return
    end

    if step and not picking and canMove() then
      if step.livePositions then poll("servo", now) end
      -- Raw channels (the order and detect screens) poll slower than the mapped ones.
      if step.liveRc then poll(step.liveRc == "raw" and "raw" or "rc", now, step.liveRcInterval) end
      if step.liveMotors then poll("motor", now) end
    end
    if step and not picking and step.wakeup then step.wakeup(now) end
  end

  -------------------------------------------------------------------------
  -- Open
  -------------------------------------------------------------------------

  form.clear()
  buildHeader(PAGE_TITLE)
  form.addLine(MSG_LOADING_TITLE)

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if not closeKey.shouldHandleClose(category, value) then return false end
      goBack()
      return true
    end)
  end

  if opts.setCleanupHandler then
    opts.setCleanupHandler(function() dispose() end)
  end

  if opts.setWakeupHandler then opts.setWakeupHandler(wakeup) end

  -- Steps draw their pictures below the form, from paint.
  if opts.setPaintHandler then
    opts.setPaintHandler(function()
      if disposed or rebuildWanted or picking or rebootWait then return end
      if step and step.paint then step.paint() end
    end)
  end

  -- A model that arms or a link that drops lets go of everything the step
  -- holds. Overrides do not time out on the FC, so a link that comes back is
  -- sent every release again.
  sessionHandler = function(snapshotData)
    local nextConnected = snapshotData and snapshotData.connected == true
    local nextArmed = snapshotData and snapshotData.isArmed == true
    local hs = snapshotData and snapshotData.handshake
    handshakeDone = hs and hs.apiVersion == true
    local minor = snapshotData and tonumber(snapshotData.apiVersionMinor)
    if minor then apiMinor = minor end
    if nextConnected == connected and nextArmed == armed then return end
    local lost = (connected ~= false and nextConnected == false) or (armed ~= true and nextArmed == true)
    local back = connected == false and nextConnected == true
    connected, armed = nextConnected, nextArmed
    if not loaded then return end
    if lost then
      releaseAll()
      if step and step.released then step.released() end
    end
    if back and not rebootWait then
      clearAllOverrides()
      armingBlocked = false
      if armed ~= true then blockArming(true) end
    end
    refreshNotice()
  end
  bus.subscribe("session.update", sessionHandler)

  beginLoad()
end

return {open = open}

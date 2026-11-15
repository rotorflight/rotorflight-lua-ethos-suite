-- Setup Wizard step: Board orientation. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepSensors.svelte, which
-- runs the accelerometer calibration and the automatic board orientation
-- (AutoAlignWizard.svelte). One screen each, in that order:
--
--   intro   blades off, servos unplugged, as the EdgeTX suite's first card: the
--           side view with the blades crossed out, and two Yes/No answers;
--           Start once both are Yes, or Next to leave the step
--   acc     calibrate the accelerometer (MSP_ACC_CALIBRATION, then wait for
--           the FC to clear ARMING_DISABLED_CALIBRATING, lib/acc_calibration_wait.lua)
--   align   MSP2_BOARD_AUTO_ALIGN: level, Start, lift the tail 20 deg; the
--           result is written as the board alignment
--   check   as the EdgeTX suite's last card: a live wireframe turned by
--           MSP_ATTITUDE, and "Direction correct" Yes/No (Next once Yes).
--           The board alignment only applies after a restart: while one is
--           owed the check offers Save and restart (wiz.saveAndReboot(), back
--           on this screen through wiz.setResume()), or Next, which leaves the
--           restart to the Connect the servos step (wiz.requestReboot())
--
-- A board without an accelerometer (sensor_status bit 0, as the
-- configurator's have_sensor()) gets a note and Next only. Firmware without
-- the auto-align command answers it with an error: the step says so.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local ui = requireModule("app/setup_wizard_ui.lua")
local art = requireModule("app/setup_wizard_art.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()).
local OWNED = ui.notLoaded({"rfsuite.lib.msp_acc_calibration", "rfsuite.lib.acc_calibration_wait",
  "rfsuite.lib.msp_board_auto_align", "rfsuite.lib.msp_board_alignment_config", "rfsuite.lib.msp_attitude"})
local status = requireModule("lib/msp_status.lua")
local accCalibration = requireModule("lib/msp_acc_calibration.lua")
local calibrationWait = requireModule("lib/acc_calibration_wait.lua")
local autoAlign = requireModule("lib/msp_board_auto_align.lua")
local boardAlignment = requireModule("lib/msp_board_alignment_config.lua")
local attitudeMsp = requireModule("lib/msp_attitude.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.sen_title)@",
  intro = "@i18n(app.modules.setup_wizard.sen_intro)@",
  noAcc = "@i18n(app.modules.setup_wizard.sen_no_acc)@",
  accTitle = "@i18n(app.modules.setup_wizard.sen_acc_title)@",
  accText = "@i18n(app.modules.setup_wizard.sen_acc_text)@",
  accBusy = "@i18n(app.modules.setup_wizard.sen_acc_busy)@",
  accDone = "@i18n(app.modules.setup_wizard.sen_acc_done)@",
  accFailed = "@i18n(app.modules.setup_wizard.sen_acc_failed)@",
  alignTitle = "@i18n(app.modules.setup_wizard.sen_align_title)@",
  alignText = "@i18n(app.modules.setup_wizard.sen_align_text)@",
  alignLift = "@i18n(app.modules.setup_wizard.sen_align_lift)@",
  alignDone = "@i18n(app.modules.setup_wizard.sen_align_done_fmt)@",
  armed = "@i18n(app.modules.setup_wizard.sen_rejected_armed)@",
  uncalibrated = "@i18n(app.modules.setup_wizard.sen_rejected_uncal)@",
  timeout = "@i18n(app.modules.setup_wizard.sen_timeout)@",
  noMatch = "@i18n(app.modules.setup_wizard.sen_no_match)@",
  unsupported = "@i18n(app.modules.setup_wizard.sen_unsupported)@",
  checkTitle = "@i18n(app.modules.setup_wizard.sen_check_title)@",
  checkText = "@i18n(app.modules.setup_wizard.sen_check_text)@",
  directionOk = "@i18n(app.modules.setup_wizard.sen_direction_ok)@",
  waiting = "@i18n(app.modules.setup_wizard.sen_attitude_waiting)@",
  doneRestart = "@i18n(app.modules.setup_wizard.sen_done_restart)@",
  saveRestart = "@i18n(app.modules.setup_wizard.btn_save_restart)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  again = "@i18n(app.modules.setup_wizard.btn_again)@",
  calibrate = "@i18n(app.modules.setup_wizard.sen_calibrate)@",
  unplugged = "@i18n(app.modules.setup_wizard.sen_servos_unplugged)@",
  bladesOff = "@i18n(app.modules.setup_wizard.sen_blades_removed)@",
  yes = "@i18n(app.modules.setup_wizard.btn_yes)@",
  no = "@i18n(app.modules.setup_wizard.btn_no)@",
  sideView = "@i18n(app.modules.setup_wizard.art_side)@",
  front = "@i18n(app.modules.setup_wizard.art_front)@",
  accelerometer = "@i18n(app.modules.setup_wizard.sen_accelerometer)@",
  available = "@i18n(app.modules.setup_wizard.sen_available)@",
  autoAlign = "@i18n(app.modules.setup_wizard.sen_auto_align)@",
  roll = "@i18n(app.modules.setup_wizard.sen_roll)@",
  pitch = "@i18n(app.modules.setup_wizard.sen_pitch)@",
  yaw = "@i18n(app.modules.setup_wizard.sen_yaw)@",
}

-- Auto align: poll every quarter second while the FC works.
local AUTO_POLL = 0.25
-- Give up on a run the FC never finishes (an FC that ignored the start
-- keeps answering IDLE), as the EdgeTX suite does after 60 s.
local AUTO_GIVE_UP = 60

-- The step's screens in order, for "Step 1 of 4" beside the buttons.
local SCREEN_INDEX = {intro = 1, acc = 2, align = 3, check = 4}
local SCREEN_COUNT = 4

-- Orientation check: ask for the attitude every ATT_POLL, one request at a time
-- (msp_attitude retries for up to 3 x 0.8 s, so a request older than ATT_LOST is
-- given up); a picture older than ATT_STALE is not shown, so no one confirms
-- against an old one. Faster than this crowds the telemetry on the same link
-- (each MSP reply blanks the FC's sensors for 250 ms on S.Port, F.Port and FBUS).
local ATT_POLL = 0.4
-- Above msp_attitude's own retries (3 x 0.8 s): shorter, a new read was queued
-- behind the one still being retried.
local ATT_LOST = 3.0
local ATT_STALE = 2.0

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)

  -- Back from the restart the check asked for: straight to the check.
  local screen = wiz.takeResume() or "intro"
  local hasAcc = nil
  local alignment = nil
  local note, noteAccent = nil, nil   -- result line for the current screen
  local busy = false                  -- a calibration or auto run is going
  local accWait = nil
  local aligning = false              -- polling the auto align
  local autoReply = nil               -- latest decoded auto reply
  local nextPollAt = 0
  local alignStartedAt = 0
  -- Intro: the side view with the blades crossed out, and the two answers
  -- (servos unplugged, blades off) that let Start run.
  local bladesPicture = art.photo("heli-remove-blades", T.sideView, T.front)
  local answers = {unplugged = false, blades = false}
  -- Calibration: the helicopter standing level.
  local levelPicture = art.photo("heli-level", T.sideView, T.front)
  -- Orientation: the tail lifted 20 degrees (the arrow is labelled with it).
  local tailPicture = art.photo("heli-tail-lift", T.sideView, "20°")
  -- Check: the live helicopter, and the answer that lets Next on.
  local attitude = {roll = 0, pitch = 0, yaw = 0, valid = false, readout = T.waiting}
  local yawRef = nil                  -- the heading when the check screen was entered
  local attitudePicture = art.attitude(attitude)
  local attInFlight, attAskedAt, attAt, nextAttAt = false, 0, nil, 0
  local attFresh = false              -- a new attitude to draw (see wakeup)
  local directionOk = false

  wiz.fetch({
    status = function(ok, err) return status.buildReadMessage(ok, err) end,
    alignment = function(ok, err) return boardAlignment.buildReadMessage(ok, err) end,
  }, function(results)
    local flags = results.status and tonumber(results.status.sensor_status) or nil
    hasAcc = flags == nil or (math.floor(flags) & 1) == 1
    alignment = results.alignment
    wiz.rebuild()
  end)

  local function go(name)
    screen, note, noteAccent, busy, aligning, accWait = name, nil, nil, false, false, nil
    if name == "check" then yawRef = nil end
    wiz.rebuild()
  end

  local function startAcc()
    busy = true
    note, noteAccent = T.accBusy, nil
    bus.publish("msp.request", accCalibration.buildWriteMessage(function()
      accWait = calibrationWait.new(os.clock())
    end, function()
      busy, note, noteAccent = false, nil, T.accFailed
      wiz.rebuild()
    end))
    wiz.rebuild()
  end

  local function onAutoData(data) autoReply = data end
  local function onAutoError() autoReply = {state = -1} end

  local function startAlign()
    busy, aligning, autoReply, nextPollAt = true, true, nil, os.clock() + AUTO_POLL
    alignStartedAt = os.clock()
    note, noteAccent = T.alignLift, nil
    bus.publish("msp.request", autoAlign.buildStartMessage(onAutoData, onAutoError))
    wiz.rebuild()
  end

  local function restoreAlignment(o)
    if o then bus.publish("msp.request", boardAlignment.buildWriteMessage(o)) end
  end

  local function writeAlignment(data)
    wiz.change("board_alignment", alignment, restoreAlignment)
    alignment = {roll_degrees = data.roll_degrees, pitch_degrees = data.pitch_degrees, yaw_degrees = data.yaw_degrees}
    bus.publish("msp.request", boardAlignment.buildWriteMessage(alignment))
    wiz.requestReboot()
    directionOk = false
  end

  -- Angles typed in the Roll / Pitch / Yaw fields. A field sends every step
  -- of the encoder, so one write is in flight at a time and the latest angles
  -- follow when it is answered. After the step closes nothing follows: a
  -- Discard has written the originals back by then.
  local alignInFlight, alignDirty, closed = false, false, false
  local sendAlignment
  local function alignSettled()
    alignInFlight = false
    if alignDirty and not closed then sendAlignment() end
  end
  sendAlignment = function()
    alignInFlight, alignDirty = true, false
    bus.publish("msp.request", boardAlignment.buildWriteMessage(alignment, alignSettled, alignSettled))
  end

  local function getAxis(axis)
    return function() return alignment and alignment[axis] or 0 end
  end
  local function setAxis(axis)
    return function(value)
      if not alignment or busy or alignment[axis] == value then return end
      wiz.change("board_alignment", alignment, restoreAlignment)
      alignment[axis] = value
      if alignInFlight then alignDirty = true else sendAlignment() end
      wiz.requestReboot()
      directionOk = false
    end
  end

  -- Attitude replies: roll and pitch come in tenths of a degree. They are
  -- handled in the background task, where lcd.invalidate() does not reach
  -- this page: the redraw is asked for from wakeup (attFresh).
  local function onAttitude(d)
    attInFlight = false
    if closed or screen ~= "check" then return end
    attAt = os.clock()
    local roll, pitch = (d.roll or 0) / 10, (d.pitch or 0) / 10
    local heading = d.yaw or 0
    if yawRef == nil then yawRef = heading end
    local yaw = ((heading - yawRef + 180) % 360) - 180
    if not attitude.valid or roll ~= attitude.roll or pitch ~= attitude.pitch or yaw ~= attitude.yaw then
      attitude.roll, attitude.pitch, attitude.yaw, attitude.valid = roll, pitch, yaw, true
      attitude.readout = string.format("%s %.1f°   %s %.1f°", T.roll, roll, T.pitch, pitch)
      attFresh = true
    end
  end
  local function onAttitudeError() attInFlight = false end

  local function restartAndCheck()
    wiz.setResume("check")
    wiz.saveAndReboot()
  end

  -- An auto align reply, from wakeup. true when the run is over.
  local function onAuto(reply)
    local s = reply.state
    local S = autoAlign.STATE
    if s == S.WAITING_FOR_TAIL_LIFT or s == S.IDLE then return false end
    busy = false
    if s == S.SUCCESS then
      local same = alignment and alignment.roll_degrees == reply.roll_degrees
        and alignment.pitch_degrees == reply.pitch_degrees and alignment.yaw_degrees == reply.yaw_degrees
      if not same then writeAlignment(reply) end
      note = string.format(T.alignDone, reply.roll_degrees, reply.pitch_degrees, reply.yaw_degrees)
    elseif s == S.REJECTED_ARMED then noteAccent = T.armed
    elseif s == S.REJECTED_UNCALIBRATED then noteAccent = T.uncalibrated
    elseif s == S.TIMEOUT then noteAccent = T.timeout
    elseif s == S.NO_MATCH then noteAccent = T.noMatch
    else noteAccent = T.unsupported end
    if noteAccent then note = nil end
    aligning = false
    return true
  end

  function self.build()
    scr:begin()
    if hasAcc == nil then
      scr:text(T.title, "@i18n(app.msg_loading)@")
      return nil
    end

    scr:step(SCREEN_INDEX[screen], SCREEN_COUNT)
    if screen == "intro" then
      scr:text(T.title, T.intro, (not hasAcc) and T.noAcc or nil)
      scr:picture(bladesPicture)
      return scr:safety(answers, {{key = "unplugged", label = T.unplugged}, {key = "blades", label = T.bladesOff}}, hasAcc and T.start or nil, function() go("acc") end)

    elseif screen == "acc" then
      -- As the EdgeTX card: the level helicopter on the left, the calibrate
      -- button and the sensor's state on the right, and under them the result
      -- (busy, done, failed), so the picture stays put when it comes.
      scr:text(T.accTitle, T.accText)
      scr:picture(levelPicture)
      -- Once it has calibrated, the focus moves on to Next.
      local done = note ~= nil and not busy
      local result = noteAccent or note
      local actionField = scr:checks({
        {answer = done and T.again or T.calibrate, needsMotion = true, disabled = busy, press = startAcc},
        {label = T.accelerometer, value = T.available},
        result and {note = result} or nil,
      }, (not done) and 1 or nil)
      local rowField = scr:row(function() go("intro") end, nil,
        {text = T.next, disabled = busy, press = function() go("align") end})
      return actionField or rowField

    elseif screen == "align" then
      -- As the EdgeTX card: the helicopter with its tail lifted 20 degrees on
      -- the left; on the right the detection, the angles it found (which can
      -- also be set by hand) and, under them, the result.
      scr:text(T.alignTitle, T.alignText)
      scr:picture(tailPicture)
      local done = note ~= nil and not busy
      local result = noteAccent or note
      local noAngles = busy or alignment == nil
      local actionField = scr:checks({
        {answer = done and T.again or T.autoAlign, needsMotion = true, disabled = busy, press = startAlign},
        {label = T.roll, number = {-180, 180, getAxis("roll_degrees"), setAxis("roll_degrees"), "°"},
          disabled = noAngles},
        {label = T.pitch, number = {-180, 180, getAxis("pitch_degrees"), setAxis("pitch_degrees"), "°"},
          disabled = noAngles},
        {label = T.yaw, number = {-180, 180, getAxis("yaw_degrees"), setAxis("yaw_degrees"), "°"},
          disabled = noAngles},
        result and {note = result} or nil,
      }, (not done) and 1 or nil)
      local rowField = scr:row(function() go("acc") end, nil,
        {text = T.next, disabled = busy, press = function() go("check") end})
      return actionField or rowField

    else -- check
      scr:text(T.checkTitle, T.checkText)
      local forward = wiz.forward()
      local field
      if wiz.rebootPending() then
        -- The FC still runs on the old orientation: a live picture now would
        -- show that one. Restart first, or leave it to Connect the servos.
        scr:picture(tailPicture)
        field = scr:checks({
          {note = T.doneRestart},
          {answer = T.saveRestart, press = restartAndCheck},
        }, 2)
      else
        attitude.rotorDir = (wiz.mixConfig() or {}).main_rotor_dir
        scr:picture(attitudePicture)
        field = scr:checks({
          -- The same toggle as the safety questions: Next once it is Yes.
          {label = T.directionOk, toggle = {function() return directionOk end, function(v)
            directionOk = v and true or false
            wiz.rebuild()
          end}},
        }, (not directionOk) and 1 or nil)
        forward.disabled = not directionOk
      end
      local rowField = scr:row(function() go("align") end, nil, forward)
      return field or rowField
    end
  end

  function self.paint() scr:paint() end

  function self.wakeup(now)
    if screen == "check" and not wiz.rebootPending() then
      -- The model's next frame is worked out here, not in paint (Ethos stops
      -- a paint that runs too long); paint only replays it.
      if art.service(attitudePicture) then wiz.invalidate() end
      if attFresh then
        attFresh = false
        wiz.invalidate()
      end
      if attitude.valid and attAt and os.clock() - attAt > ATT_STALE then
        attitude.valid, attitude.readout = false, T.waiting
        wiz.invalidate()
      end
      if (not attInFlight or now - attAskedAt > ATT_LOST) and now >= nextAttAt then
        attInFlight, attAskedAt, nextAttAt = true, now, now + ATT_POLL
        bus.publish("msp.request", attitudeMsp.buildReadMessage(onAttitude, onAttitudeError))
      end
    end
    if accWait then
      if calibrationWait.shouldPoll(accWait, now) then
        local waiting = accWait
        bus.publish("msp.request", status.buildReadMessage(function(data)
          if accWait ~= waiting then return end
          local d = calibrationWait.onStatus(waiting, data.arming_disable_flags, os.clock())
          if d ~= "wait" then waiting.result = d end
        end, function()
          if accWait ~= waiting then return end
          local d = calibrationWait.onError(waiting, os.clock())
          if d ~= "wait" then waiting.result = d end
        end))
        accWait.nextPollAt = now + calibrationWait.POLL_INTERVAL
      end
      if accWait.result then
        busy = false
        note = (accWait.result == "done") and T.accDone or nil
        noteAccent = (accWait.result ~= "done") and T.accFailed or nil
        accWait = nil
        wiz.rebuild()
      end
    end
    if aligning then
      if not autoReply and now - alignStartedAt > AUTO_GIVE_UP then
        autoReply = {state = autoAlign.STATE.TIMEOUT}
      end
      if autoReply then
        local reply = autoReply
        autoReply = nil
        if onAuto(reply) then
          wiz.rebuild()
          return
        end
      end
      if now >= nextPollAt then
        nextPollAt = now + AUTO_POLL
        -- A lost poll is not an answer: only the start tells "unsupported".
        bus.publish("msp.request", autoAlign.buildReadMessage(onAutoData))
      end
    end
  end

  function self.released() scr:refresh() end
  function self.leave() accWait, aligning, closed = nil, false, true end

  return self
end

return {new = new, owned = OWNED}

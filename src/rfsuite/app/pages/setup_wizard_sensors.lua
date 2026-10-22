-- Setup Wizard step: Board orientation. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of rotorflight-configurator's StepSensors.svelte, which
-- runs the accelerometer calibration and the automatic board orientation
-- (AutoAlignWizard.svelte). One screen each, in that order:
--
--   intro   blades off, servos unplugged; Start, or Next to leave the step
--   acc     calibrate the accelerometer (MSP_ACC_CALIBRATION, then wait for
--           the FC to clear ARMING_DISABLED_CALIBRATING, lib/acc_calibration_wait.lua)
--   align   MSP2_BOARD_AUTO_ALIGN: level, Start, lift the tail 20 deg; the
--           result is written as the board alignment
--   done    board alignment only applies after a restart, which the wizard
--           does at the Connect the servos step (wiz.requestReboot())
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
  "rfsuite.lib.msp_board_auto_align", "rfsuite.lib.msp_board_alignment_config"})
local status = requireModule("lib/msp_status.lua")
local accCalibration = requireModule("lib/msp_acc_calibration.lua")
local calibrationWait = requireModule("lib/acc_calibration_wait.lua")
local autoAlign = requireModule("lib/msp_board_auto_align.lua")
local boardAlignment = requireModule("lib/msp_board_alignment_config.lua")

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
  doneTitle = "@i18n(app.modules.setup_wizard.sen_done_title)@",
  doneRestart = "@i18n(app.modules.setup_wizard.sen_done_restart)@",
  doneSame = "@i18n(app.modules.setup_wizard.sen_done_same)@",
  progress = "@i18n(app.modules.setup_wizard.progress_fmt)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  again = "@i18n(app.modules.setup_wizard.btn_again)@",
  calibrate = "@i18n(app.modules.setup_wizard.sen_calibrate)@",
}

-- Auto align: poll every quarter second while the FC works.
local AUTO_POLL = 0.25
-- Give up on a run the FC never finishes (an FC that ignored the start
-- keeps answering IDLE), as the EdgeTX suite does after 60 s.
local AUTO_GIVE_UP = 60

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)

  local screen = "intro"
  local hasAcc = nil
  local alignment = nil
  local note, noteAccent = nil, nil   -- result line for the current screen
  local busy = false                  -- a calibration or auto run is going
  local accWait = nil
  local aligning = false              -- polling the auto align
  local autoReply = nil               -- latest decoded auto reply
  local nextPollAt = 0
  local alignStartedAt = 0
  local changed = false
  local picture = art.heli(0)

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

  local function writeAlignment(data)
    wiz.change("board_alignment", alignment, function(o)
      if o then bus.publish("msp.request", boardAlignment.buildWriteMessage(o)) end
    end)
    alignment = {roll_degrees = data.roll_degrees, pitch_degrees = data.pitch_degrees, yaw_degrees = data.yaw_degrees}
    bus.publish("msp.request", boardAlignment.buildWriteMessage(alignment))
    wiz.requestReboot()
    changed = true
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

    if screen == "intro" then
      scr:text(T.title, T.intro, (not hasAcc) and T.noAcc or nil)
      scr:picture(picture)
      return scr:row(nil, hasAcc and {{text = T.start, primary = true, press = function() go("acc") end}} or nil)

    elseif screen == "acc" then
      scr:text(T.accTitle, T.accText, noteAccent or note, string.format(T.progress, 1, 2))
      -- A spirit level: orange while calibrating, green when done, red if not.
      scr:picture(art.bubble(busy and "busy" or (noteAccent and "failed") or (note and "done") or nil))
      -- Once it has calibrated, the focus moves on to Next.
      local done = note ~= nil and not busy
      return scr:row(function() go("intro") end, {
        {text = done and T.again or T.calibrate, primary = not done, needsMotion = true, disabled = busy,
          press = startAcc},
      }, {text = T.next, disabled = busy, press = function() go("align") end})

    elseif screen == "align" then
      scr:text(T.alignTitle, T.alignText, noteAccent or note, string.format(T.progress, 2, 2))
      -- Waiting for the tail lift: the picture lifts the tail, with an arrow.
      scr:picture(aligning and art.heli(20, true) or picture)
      local done = note ~= nil and not busy
      return scr:row(function() go("acc") end, {
        {text = done and T.again or T.start, primary = not done, needsMotion = true, disabled = busy,
          press = startAlign},
      }, {text = T.next, disabled = busy, press = function() go("done") end})

    else -- done
      scr:text(T.doneTitle, (changed or wiz.rebootPending()) and T.doneRestart or T.doneSame)
      scr:picture(picture)
      return scr:row(function() go("align") end)
    end
  end

  function self.paint() scr:paint() end

  function self.wakeup(now)
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
  function self.leave() accWait, aligning = nil, false end

  return self
end

return {new = new, owned = OWNED}

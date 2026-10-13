-- Accelerometer page. Loaded on demand from Setup -> Accelerometer.
--
-- Edits MSP_ACC_TRIM / MSP_SET_ACC_TRIM (cmd 240/239) for roll/pitch
-- trim, matching the original suite's app/modules/accelerometer page.
-- The Tool button sends MSP_ACC_CALIBRATION (cmd 205). The acknowledgement only
-- means the command arrived, so the page then polls MSP_STATUS until the
-- flight controller clears ARMING_DISABLED_CALIBRATING (lib/acc_calibration_wait.lua,
-- issue #2347). Only then it commits with EEPROM_WRITE and plays the shared
-- beep.wav once the EEPROM ack lands.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local accTrim = requireModule("lib/msp_acc_trim.lua")
local accCalibration = requireModule("lib/msp_acc_calibration.lua")
local mspStatus = requireModule("lib/msp_status.lua")
local calibrationWait = requireModule("lib/acc_calibration_wait.lua")

local PAGE_TITLE = "@i18n(app.modules.accelerometer.name)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"

local function open(opts)
  local runtime

  -- Set between the acknowledgement and the decision; nil otherwise.
  local waiting = nil
  local waitingFocus = nil
  local statusInFlight = false

  local function commitCalibration(focusFn)
    bus.publish("msp.request", eeprom.buildWriteMessage(function()
      if not runtime or runtime.disposed then return end
      runtime:setBusy(false)
      runtime:closeDialog(focusFn)
      system.playFile("audio/beep.wav")
    end, function()
      if not runtime or runtime.disposed then return end
      runtime:setBusy(false)
      runtime:closeDialog(focusFn)
    end))
  end

  local function applyDecision(decision)
    local focusFn = waitingFocus
    if decision == "wait" then return end
    waiting = nil
    waitingFocus = nil
    if not runtime or runtime.disposed then return end
    if decision == "done" then
      commitCalibration(focusFn)
      return
    end
    -- "timeout": the flight controller did not finish. Nothing is committed.
    runtime:setBusy(false)
    runtime:closeDialog(focusFn)
    runtime:openMessageDialog({
      title = PAGE_TITLE,
      message = "@i18n(app.modules.accelerometer.msg_calibration_timeout)@",
      buttons = {{label = BTN_OK, action = function() return true end}},
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  -- Called from the page's wakeup tick: one MSP_STATUS read at a time.
  local function pollCalibration()
    if not waiting or statusInFlight then return end
    if not runtime or runtime.disposed then return end
    local now = os.clock()
    if not calibrationWait.shouldPoll(waiting, now) then return end
    statusInFlight = true
    bus.publish("msp.request", mspStatus.buildReadMessage(function(data)
      statusInFlight = false
      if not waiting then return end
      applyDecision(calibrationWait.onStatus(waiting, data.arming_disable_flags, os.clock()))
    end, function()
      statusInFlight = false
      if not waiting then return end
      applyDecision(calibrationWait.onError(waiting, os.clock()))
    end))
  end

  local function runCalibration(focusFn)
    if not runtime or runtime.disposed or runtime.activeDialog then return end
    runtime:setBusy(true)
    runtime:showDialog("@i18n(app.msg_saving)@", "@i18n(app.msg_saving_settings)@")

    bus.publish("msp.request", accCalibration.buildWriteMessage(function()
      if not runtime or runtime.disposed then return end
      -- Acknowledged, not finished: start waiting for the flight controller.
      waiting = calibrationWait.new(os.clock())
      waitingFocus = focusFn
      statusInFlight = false
    end, function()
      if not runtime or runtime.disposed then return end
      runtime:setBusy(false)
      runtime:closeDialog(focusFn)
    end))
  end

  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "accel",
    mspModule = accTrim,
    opts = opts,
    profileField = "none",
    unloadPackageKeys = {
      "rfsuite.lib.msp_acc_trim",
      "rfsuite.lib.msp_acc_calibration",
      "rfsuite.lib.acc_calibration_wait",
    },
    onWakeup = function()
      pollCalibration()
    end,
    onDispose = function()
      -- Leaving the page drops the wait: nothing is committed afterwards.
      waiting = nil
      waitingFocus = nil
      statusInFlight = false
    end,
    onTool = function(focusFn)
      if not runtime.loaded then return end
      form.openDialog({
        title = PAGE_TITLE,
        message = "@i18n(app.modules.accelerometer.msg_calibrate)@",
        buttons = {
          {label = BTN_OK, action = function()
            runCalibration(focusFn)
            return true
          end},
          {label = BTN_CANCEL, action = function()
            if focusFn then focusFn() end
            return true
          end},
        },
        wakeup = function() end,
        paint = function() end,
      })
    end,
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.accelerometer.roll)@", {key = "roll"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.accelerometer.pitch)@", {key = "pitch"})

  runtime:loadInitial()
end

return {open = open}

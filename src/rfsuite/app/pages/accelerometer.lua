-- Accelerometer page. Loaded on demand from Setup -> Accelerometer.
--
-- Edits MSP_ACC_TRIM / MSP_SET_ACC_TRIM (cmd 240/239) for roll/pitch
-- trim, matching the original suite's app/modules/accelerometer page.
-- The Tool button sends MSP_ACC_CALIBRATION (cmd 205), then commits with
-- EEPROM_WRITE and plays the shared beep.wav once the EEPROM ack lands.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local accTrim = requireModule("lib/msp_acc_trim.lua")
local accCalibration = requireModule("lib/msp_acc_calibration.lua")

local PAGE_TITLE = "@i18n(app.modules.accelerometer.name)@"
local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"

local function open(opts)
  local runtime

  local function runCalibration(focusFn)
    if not runtime or runtime.disposed or runtime.activeDialog then return end
    runtime:setBusy(true)
    runtime:showDialog("@i18n(app.msg_saving)@", "@i18n(app.msg_saving_settings)@")

    bus.publish("msp.request", accCalibration.buildWriteMessage(function()
      if not runtime or runtime.disposed then return end
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
    },
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

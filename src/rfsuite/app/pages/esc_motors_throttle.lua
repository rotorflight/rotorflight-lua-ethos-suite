-- Setup -> ESC & Motors -> Throttle page.

local requireModule = assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local motorConfig = requireModule("lib/msp_motor_config.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_motors.throttle)@"

local PWM_RATE = "motor_pwm_rate"
local MINCOMMAND = "mincommand"
local MINTHROTTLE = "minthrottle"
local MAXTHROTTLE = "maxthrottle"
local UNSYNCED = "use_unsynced_pwm"

local function pwmFieldsEnabled(protocol)
  protocol = tonumber(protocol or 10) or 10
  return protocol <= 4 or protocol == 9
end

local function unsyncedEnabled(protocol)
  protocol = tonumber(protocol or 10) or 10
  return protocol >= 1 and protocol <= 4
end

local function refreshProtocolFields(runtime)
  local protocol = tonumber(runtime.data.motor_pwm_protocol or 10) or 10
  local pwmEnabled = runtime.loaded and pwmFieldsEnabled(protocol) and not runtime.activeDialog
  local unsynced = runtime.loaded and unsyncedEnabled(protocol) and not runtime.activeDialog
  if runtime.data.use_unsynced_pwm == nil then runtime.data.use_unsynced_pwm = 0 end
  if runtime.fields[PWM_RATE] then runtime.fields[PWM_RATE]:enable(pwmEnabled) end
  if runtime.fields[MINCOMMAND] then runtime.fields[MINCOMMAND]:enable(pwmEnabled) end
  if runtime.fields[MINTHROTTLE] then runtime.fields[MINTHROTTLE]:enable(pwmEnabled) end
  if runtime.fields[MAXTHROTTLE] then runtime.fields[MAXTHROTTLE]:enable(pwmEnabled) end
  if runtime.fields[UNSYNCED] then runtime.fields[UNSYNCED]:enable(unsynced) end
end

local function open(opts)
  local lastProtocol = nil

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "esc_throttle",
    mspModule = motorConfig,
    opts = opts,
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {"rfsuite.lib.msp_motor_config"},
    onLoaded = function()
      lastProtocol = nil
      refreshProtocolFields(runtime)
    end,
    onWakeup = function(rt)
      local protocol = tonumber(rt.data.motor_pwm_protocol or 10) or 10
      if protocol ~= lastProtocol then
        lastProtocol = protocol
        refreshProtocolFields(rt)
      end
    end,
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.throttle_protocol)@", {
    key = "motor_pwm_protocol",
    choices = motorConfig.PROTOCOL_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.motor_pwm_rate)@", {key = PWM_RATE})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.mincommand)@", {key = MINCOMMAND})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.min_throttle)@", {key = MINTHROTTLE})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.max_throttle)@", {key = MAXTHROTTLE})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.unsynced)@", {
    key = UNSYNCED,
    choices = motorConfig.ON_OFF_CHOICES,
  })

  runtime:loadInitial()
end

return {open = open}

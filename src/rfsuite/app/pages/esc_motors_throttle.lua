-- Setup -> ESC & Motors -> Throttle page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local motorConfig = requireModule("lib/msp_motor_config.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_motors.throttle)@"

local PWM_RATE = "motor_pwm_rate"
local MINCOMMAND = "mincommand"
local MINTHROTTLE = "minthrottle"
local MAXTHROTTLE = "maxthrottle"
local UNSYNCED = "use_unsynced_pwm"

-- The Throttle Protocol values are named, not inlined.
--
-- This file used to spell DISABLED as a bare `10` in four places (here twice, in
-- pwmFieldsEnabled(), and in esc_motors_rpm.lua). Ten is SRXL2 in the firmware's enum
-- -- lib/msp_motor_config.lua's header has the transcription and the history -- so
-- every one of those defaults was quietly wrong, and they agreed with the codec's own
-- wrong DISABLED entry, which is why nothing caught it. A named constant cannot drift
-- from the enum on its own.
local DISABLED = motorConfig.DISABLED_PROTOCOL
local CASTLE = motorConfig.CASTLE_PROTOCOL
local SRXL2 = motorConfig.SRXL2_PROTOCOL

local function protocolOf(runtime)
  return tonumber(runtime.data.motor_pwm_protocol) or DISABLED
end

-- Whether the PWM-rate and throttle-window rows apply.
--
-- 0..4 are the protocols with a PWM rate and a throttle window, 9 and 10 are the two
-- bidirectional serial ones. That is EdgeTX's isPwmRateEnabled()
-- (esc_motors/throttle/page.lua:327-333) with one gap closed: it knows SRXL2, this
-- did not, because SRXL2 was missing from the list this page renders.
--
-- 4 is PWM_TYPE_RESERVED, not a protocol -- see lib/msp_motor_config.lua -- so it is
-- only reachable when the FC already reports it, and then the row state it produces is
-- the truth about that FC rather than an offer.
local function pwmFieldsEnabled(protocol)
  return protocol <= 4 or protocol == CASTLE or protocol == SRXL2
end

local function unsyncedEnabled(protocol)
  return protocol >= 1 and protocol <= 4
end

local function refreshProtocolFields(runtime)
  local protocol = protocolOf(runtime)
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
      local protocol = protocolOf(rt)
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
    -- The FC's own API version decides the list, not a table in this file: SRXL2
    -- needs 12.10 and did not exist before it. runtime.apiVersionMinor is nil until
    -- the first session.update arrives, and nil yields the smaller list, so the
    -- conservative set is what a pilot can see before the handshake has finished.
    choices = motorConfig.protocolChoices(runtime.apiVersionMinor),
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

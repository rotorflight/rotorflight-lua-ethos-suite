-- Setup -> ESC & Motors -> SRXL2 ESC page: the SRXL2 ESC bus settings
-- (MSP2_GET_SRXL2_ESC_CONFIG). Firmware without the message refuses the read,
-- which the runtime shows as a failed load.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local srxl2EscConfig = requireModule("lib/msp_srxl2_esc_config.lua")

local PAGE_TITLE = "@i18n(app.modules.esc_motors.srxl2)@"

local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "esc_srxl2",
    mspModule = srxl2EscConfig,
    opts = opts,
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {"rfsuite.lib.msp_srxl2_esc_config"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.srxl2_telem_interval)@", {
    key = "telem_interval_frames",
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.esc_motors.srxl2_motor2_channel)@", {
    key = "motor2_channel",
    choices = srxl2EscConfig.MOTOR2_CHANNEL_CHOICES,
  })

  runtime:loadInitial()
end

return {open = open}

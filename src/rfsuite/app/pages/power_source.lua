-- Setup -> Power -> Sources page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local batteryConfig = requireModule("lib/msp_battery_config.lua")

local PAGE_TITLE = "@i18n(app.modules.power.source_name)@"

local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "power_source",
    mspModule = batteryConfig,
    opts = opts,
    profileField = "none",
    unloadPackageKeys = {
      "rfsuite.lib.msp_battery_config",
    },
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.power.voltage_meter_source)@", {
    key = "voltageMeterSource",
    choices = batteryConfig.SOURCE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.power.current_meter_source)@", {
    key = "currentMeterSource",
    choices = batteryConfig.SOURCE_CHOICES,
  })

  runtime:loadInitial()
end

return {open = open}

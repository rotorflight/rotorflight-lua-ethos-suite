-- Setup -> Governor -> Ramp Time page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local governorConfig = requireModule("lib/msp_governor_config.lua")

local PAGE_TITLE = "@i18n(app.modules.governor.menu_time)@"

local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "setgovtime",
    mspModule = governorConfig,
    opts = opts,
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {"rfsuite.lib.msp_governor_config"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.startup_time)@", {key = "gov_startup_time"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.spoolup_time)@", {key = "gov_spoolup_time"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.spooldown_time)@", {key = "gov_spooldown_time"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.tracking_time)@", {key = "gov_tracking_time"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.recovery_time)@", {key = "gov_recovery_time"})

  runtime:loadInitial()
end

return {open = open}

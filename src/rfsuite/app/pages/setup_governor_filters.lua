-- Setup -> Governor -> Filters page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local governorConfig = requireModule("lib/msp_governor_config.lua")

local PAGE_TITLE = "@i18n(app.modules.governor.menu_filters)@"

local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "setgovfilt",
    mspModule = governorConfig,
    opts = opts,
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {"rfsuite.lib.msp_governor_config"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.gov_rpm_filter)@", {key = "gov_rpm_filter"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.gov_pwr_filter)@", {key = "gov_pwr_filter"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.gov_tta_filter)@", {key = "gov_tta_filter"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.gov_ff_filter)@", {key = "gov_ff_filter"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.gov_d_filter)@", {key = "gov_d_filter"})

  runtime:loadInitial()
end

return {open = open}

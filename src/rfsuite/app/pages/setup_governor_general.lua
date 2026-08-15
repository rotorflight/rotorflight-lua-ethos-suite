-- Setup -> Governor -> General page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local governorConfig = requireModule("lib/msp_governor_config.lua")

local PAGE_TITLE = "@i18n(app.modules.governor.menu_general)@"

local function refreshModeFields(runtime)
  local mode = tonumber(runtime.data.gov_mode or 0) or 0
  local loaded = runtime.loaded and not runtime.activeDialog
  local enabledBasic = loaded and mode >= 1
  local enabledDirect = loaded and mode >= 2
  local fields = runtime.fields or {}
  if fields.gov_throttle_type then fields.gov_throttle_type:enable(enabledBasic) end
  if fields.governor_idle_throttle then fields.governor_idle_throttle:enable(enabledBasic) end
  if fields.governor_auto_throttle then fields.governor_auto_throttle:enable(enabledBasic) end
  if fields.gov_handover_throttle then fields.gov_handover_throttle:enable(enabledDirect) end
  if fields.gov_throttle_hold_timeout then fields.gov_throttle_hold_timeout:enable(enabledDirect) end
  if fields.gov_autorotation_timeout then fields.gov_autorotation_timeout:enable(enabledDirect) end
end

local function open(opts)
  local lastMode = nil

  local runtime
  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "setgovgen",
    mspModule = governorConfig,
    opts = opts,
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {"rfsuite.lib.msp_governor_config"},
    onLoaded = function()
      lastMode = nil
      refreshModeFields(runtime)
    end,
    onWakeup = function(rt)
      local mode = tonumber(rt.data.gov_mode or 0) or 0
      if mode ~= lastMode then
        lastMode = mode
        refreshModeFields(rt)
      end
    end,
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.mode)@", {
    key = "gov_mode",
    choices = governorConfig.MODE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.throttle_type)@", {
    key = "gov_throttle_type",
    choices = governorConfig.THROTTLE_TYPE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(api.GOVERNOR_CONFIG.governor_idle_throttle)@", {key = "governor_idle_throttle"})
  fieldLayout.buildSingle(runtime, "@i18n(api.GOVERNOR_CONFIG.governor_auto_throttle)@", {key = "governor_auto_throttle"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.handover_throttle)@", {key = "gov_handover_throttle"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.throttle_hold_timeout)@", {key = "gov_throttle_hold_timeout"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.auto_timeout)@", {key = "gov_autorotation_timeout"})

  runtime:loadInitial()
end

return {open = open}

-- Autolevel profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced ->
-- Autolevel -- see app/tool.lua.
--
-- Edits five more MSP_PID_PROFILE fields (cmd 94/95, see
-- lib/msp_pid_profile.lua): acro trainer gain/limit, angle mode gain/
-- limit, and horizon mode gain. Matches the original suite's own
-- app/modules/profile_autolevel/autolevel.lua exactly, including Horizon
-- Mode being a single-field group (no "Max" counterpart -- the firmware
-- struct has no `horizon_level_limit`, only `horizon_level_strength`).
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. Field/row building comes from app/field_layout.lua.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local pidProfile = requireModule("lib/msp_pid_profile.lua")

local PAGE_TITLE = "@i18n(app.modules.autolevel.name)@"

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "autolevel",
    mspModule = pidProfile,
    opts = opts,
    unloadPackageKeys = {"rfsuite.lib.msp_pid_profile"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.autolevel.acro_trainer)@", {
    {title = "@i18n(app.modules.autolevel.gain)@", spec = {key = "trainer_gain"}},
    {title = "@i18n(app.modules.autolevel.max)@", spec = {key = "trainer_angle_limit"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.autolevel.angle_mode)@", {
    {title = "@i18n(app.modules.autolevel.gain)@", spec = {key = "angle_level_strength"}},
    {title = "@i18n(app.modules.autolevel.max)@", spec = {key = "angle_level_limit"}},
  })

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.autolevel.horizon_mode)@",
    {key = "horizon_level_strength"})

  runtime:loadInitial()
end

return {open = open}

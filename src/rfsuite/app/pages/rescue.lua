-- Rescue profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced ->
-- Rescue -- see app/tool.lua.
--
-- Edits MSP_RESCUE_PROFILE (cmd 146/147, see lib/msp_rescue_profile.lua),
-- a new command not shared with any other page in this rebuild.
-- Matches the original suite's own app/modules/profile_rescue/rescue.lua
-- field selection exactly: mode enable, flip-to-upright, pull-up/climb/
-- hover collective+time, flip/exit time, level/flip gains, and max
-- setpoint rate/accel. The wire struct's other 5 fields (an altitude-hold
-- rescue mode: hover_altitude, alt_p/i/d_gain, max_collective) are still
-- read/written unchanged every round-trip -- lib/msp_rescue_profile.lua's
-- codec always handles the full struct -- but never get a widget here,
-- matching the original, which never builds one for them either.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. Field/row building comes from app/field_layout.lua.

local requireModule = assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local rescueProfile = requireModule("lib/msp_rescue_profile.lua")

local PAGE_TITLE = "@i18n(app.modules.rescue.name)@"

local OFF_ON_OPTIONS = {
  {"@i18n(app.modules.rescue.tbl_off)@", 0},
  {"@i18n(app.modules.rescue.tbl_on)@", 1},
}

local FLIP_OPTIONS = {
  {"@i18n(app.modules.rescue.tbl_noflip)@", 0},
  {"@i18n(app.modules.rescue.tbl_flip)@", 1},
}

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "rescue",
    mspModule = rescueProfile,
    opts = opts,
    unloadPackageKeys = {"rfsuite.lib.msp_rescue_profile"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rescue.mode_enable)@",
    {key = "rescue_mode", choices = OFF_ON_OPTIONS})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rescue.flip_upright)@",
    {key = "rescue_flip_mode", choices = FLIP_OPTIONS})

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.rescue.pull_up)@", {
    {title = "@i18n(app.modules.rescue.collective)@", spec = {key = "rescue_pull_up_collective"}},
    {title = "@i18n(app.modules.rescue.time)@", spec = {key = "rescue_pull_up_time"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.rescue.climb)@", {
    {title = "@i18n(app.modules.rescue.collective)@", spec = {key = "rescue_climb_collective"}},
    {title = "@i18n(app.modules.rescue.time)@", spec = {key = "rescue_climb_time"}},
  })

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rescue.hover)@",
    {key = "rescue_hover_collective"})

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.rescue.flip)@", {
    {title = "@i18n(app.modules.rescue.fail_time)@", spec = {key = "rescue_flip_time"}},
    {title = "@i18n(app.modules.rescue.exit_time)@", spec = {key = "rescue_exit_time"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.rescue.gains)@", {
    {title = "@i18n(app.modules.rescue.level_gain)@", spec = {key = "rescue_level_gain"}},
    {title = "@i18n(app.modules.rescue.flip)@", spec = {key = "rescue_flip_gain"}},
  })

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rescue.rate)@",
    {key = "rescue_max_setpoint_rate"})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rescue.accel)@",
    {key = "rescue_max_setpoint_accel"})

  runtime:loadInitial()
end

return {open = open}

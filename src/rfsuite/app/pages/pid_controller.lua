-- PID Controller profile editor page. Loaded on demand (plain loadfile) only when the user opens "PID Controller" from the
-- system tool's main menu -- see app/tool.lua.
--
-- Edits the MSP_PID_PROFILE / MSP_SET_PID_PROFILE command (cmd 94/95, see
-- lib/msp_pid_profile.lua) -- a *different* command from app/pages/pids.lua's
-- MSP_PID_TUNING (cmd 112/202), even though both are scoped to the same
-- active PID profile on the flight controller. Exposes the same field
-- subset as the original suite's app/modules/profile_pidcontroller module:
-- error decay (ground/cyclic), error limit (roll/pitch/yaw), HSI offset
-- limit (roll/pitch), and iterm relax (type + roll/pitch/yaw cutoffs).
-- The other ~30 fields in that MSP command (gyro/dterm/bterm cutoffs, yaw
-- stop gains, angle/horizon/trainer, cross-coupling, inertia precomp,
-- etc.) are still read and written back unchanged every round-trip --
-- lib/msp_pid_profile.lua's codec always handles the full struct -- this
-- page just doesn't build an editable widget for them yet (some of those,
-- e.g. yaw stop gain and inertia precomp, are exposed by
-- app/pages/tail_rotor.lua instead -- the original splits one MSP
-- command's fields across multiple pages by conceptual purpose, and this
-- rebuild follows that). `error_rotation`, `yaw_collective_dynamic_gain`,
-- and `yaw_collective_dynamic_decay` are wire-present but functionally
-- dead in supported firmware (the FC always returns a fixed constant and
-- discards whatever is written) so they never get a widget at all.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. Field/row building (single-field lines, grouped inline
-- label+field rows) comes from app/field_layout.lua, promoted out of this
-- file once app/pages/tail_rotor.lua needed the identical helpers. This
-- file now only owns the MSP_PID_PROFILE codec and which fields to show.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local pidProfile = requireModule("lib/msp_pid_profile.lua")

local PAGE_TITLE = "@i18n(app.modules.pid_controller.name)@"

local ITERM_RELAX_OPTIONS = {
  {"@i18n(app.modules.pid_controller.tbl_off)@", 0},
  {"@i18n(app.modules.pid_controller.tbl_rp)@", 1},
  {"@i18n(app.modules.pid_controller.tbl_rpy)@", 2},
}

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "pidctrl",
    mspModule = pidProfile,
    opts = opts,
    unloadPackageKeys = {"rfsuite.lib.msp_pid_profile"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.pid_controller.ground_error_decay)@",
    {key = "error_decay_time_ground"})

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.pid_controller.inflight_error_decay)@", {
    {title = "@i18n(app.modules.pid_controller.time)@", spec = {key = "error_decay_time_cyclic"}},
    {title = "@i18n(app.modules.pid_controller.limit)@", spec = {key = "error_decay_limit_cyclic"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.pid_controller.error_limit)@", {
    {title = "@i18n(app.modules.pid_controller.roll)@", spec = {key = "error_limit_0"}},
    {title = "@i18n(app.modules.pid_controller.pitch)@", spec = {key = "error_limit_1"}},
    {title = "@i18n(app.modules.pid_controller.yaw)@", spec = {key = "error_limit_2"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.pid_controller.hsi_offset_limit)@", {
    {title = "@i18n(app.modules.pid_controller.roll)@", spec = {key = "offset_limit_0"}},
    {title = "@i18n(app.modules.pid_controller.pitch)@", spec = {key = "offset_limit_1"}},
  })

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.pid_controller.iterm_relax_type)@", {key = "iterm_relax_type", choices = ITERM_RELAX_OPTIONS})

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.pid_controller.iterm_relax_cutoff)@", {
    {title = "@i18n(app.modules.pid_controller.roll)@", spec = {key = "iterm_relax_cutoff_0"}},
    {title = "@i18n(app.modules.pid_controller.pitch)@", spec = {key = "iterm_relax_cutoff_1"}},
    {title = "@i18n(app.modules.pid_controller.yaw)@", spec = {key = "iterm_relax_cutoff_2"}},
  })

  runtime:loadInitial()
end

return {open = open}

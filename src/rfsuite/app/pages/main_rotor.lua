-- Main Rotor profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced -> Main
-- Rotor -- see app/tool.lua.
--
-- Edits four more MSP_PID_PROFILE fields (cmd 94/95, see
-- lib/msp_pid_profile.lua -- the same command app/pages/pid_controller.lua,
-- app/pages/tail_rotor.lua already use, each for a different field
-- subset) that no other page touches yet: `pitch_collective_ff_gain` and
-- the three `cyclic_cross_coupling_*` fields. Matches the original
-- suite's own app/modules/profile_mainrotor/mainrotor.lua.
--
-- Layout simplified vs. the original: its own formdata nests these as
-- one wide "Collective Pitch Comp" row plus three separate rows under a
-- "Cyclic Cross Coupling" label, two of which (`t = ""`) render with no
-- label text of their own -- a multi-row-continuation-under-one-label
-- effect this rebuild's app/field_layout.lua (single field, or several
-- fields sharing *one* line) has no equivalent shape for. Four plain
-- `buildSingle()` rows instead, with the grouping made clear by prefixing
-- the three coupling fields' own labels ("Cyclic Cross Coupling: Gain"
-- etc.) rather than by shared visual nesting.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. Field/row building comes from app/field_layout.lua.

local requireModule = assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local pidProfile = requireModule("lib/msp_pid_profile.lua")

local PAGE_TITLE = "@i18n(app.modules.main_rotor.name)@"

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "mainrotor",
    mspModule = pidProfile,
    opts = opts,
    unloadPackageKeys = {"rfsuite.lib.msp_pid_profile"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.main_rotor.collective_pitch_comp)@",
    {key = "pitch_collective_ff_gain"})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.main_rotor.cyclic_cross_coupling_gain)@",
    {key = "cyclic_cross_coupling_gain"})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.main_rotor.cyclic_cross_coupling_ratio)@",
    {key = "cyclic_cross_coupling_ratio"})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.main_rotor.cyclic_cross_coupling_cutoff)@",
    {key = "cyclic_cross_coupling_cutoff"})

  runtime:loadInitial()
end

return {open = open}

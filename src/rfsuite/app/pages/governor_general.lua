-- Governor "General" profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning ->
-- Governor -> General -- see app/tool.lua.
--
-- Edits the rest of MSP_GOVERNOR_PROFILE (cmd 148/149, see
-- lib/msp_governor_profile.lua) that app/pages/tail_rotor.lua doesn't
-- touch: headspeed, throttle limits, fallback drop, overall gain, and
-- the P/I/D/F/yaw/cyclic/collective gains -- matching the original
-- suite's own app/modules/profile_governor/tools/general.lua. Mirrors
-- how app/pages/pid_controller.lua and app/pages/tail_rotor.lua already
-- split MSP_PID_PROFILE's fields across two pages by conceptual purpose.
-- `governor_flags` (a packed bitmap of ~10 on/off flags) is left for a
-- future "Flags" page (the original's own tools/flags.lua) -- this
-- rebuild has no bit-within-a-shared-field widget type yet (see
-- app/field_layout.lua), and every value this page touches is a plain
-- number, so building that isn't needed just to get this page working.
--
-- Structural note: the original's "Governor" tile at the Flight Tuning
-- top level is itself a submenu (General + Flags), not a leaf page --
-- see app/tool.lua's MENUS.governor_menu. Only General exists here
-- so far; Flags is a real, planned next page, not a placeholder tile.
--
-- Deliberately simplified vs. the original: that page also enables/
-- disables fields based on the FC's *current* governor mode
-- (`rfsuite.session.governorMode`, 0=off/1=passthrough/2=standard) and
-- `governor_flags`'s `tx_precomp_curve` bit (an imperative cross-field
-- enable rule -- see AGENTS.md's i18n/module-survey notes on why this
-- rebuild doesn't have a generic mechanism for that yet). This rebuild
-- has no governor-mode telemetry tracking at all yet, so every field
-- here is simply always editable -- consistent with this project's
-- existing practice of not replicating conditional-enable logic until a
-- page genuinely needs it (see e.g. app/pages/pids.lua's own comment on
-- having no "armed" safety check).
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. Field/row building comes from app/field_layout.lua.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local governorProfile = requireModule("lib/msp_governor_profile.lua")

local PAGE_TITLE = "@i18n(app.modules.governor.name)@"

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "governor",
    mspModule = governorProfile,
    opts = opts,
    unloadPackageKeys = {"rfsuite.lib.msp_governor_profile"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.full_headspeed)@",
    {key = "governor_headspeed"})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.min_throttle)@",
    {key = "governor_min_throttle"})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.max_throttle)@",
    {key = "governor_max_throttle"})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.fallback_drop)@",
    {key = "governor_fallback_drop"})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.gain)@",
    {key = "governor_gain"})

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.governor.gains)@", {
    {title = "@i18n(app.modules.governor.p)@", spec = {key = "governor_p_gain"}},
    {title = "@i18n(app.modules.governor.i)@", spec = {key = "governor_i_gain"}},
    {title = "@i18n(app.modules.governor.d)@", spec = {key = "governor_d_gain"}},
    {title = "@i18n(app.modules.governor.f)@", spec = {key = "governor_f_gain"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.governor.precomp)@", {
    {title = "@i18n(app.modules.governor.yaw)@", spec = {key = "governor_yaw_weight"}},
    {title = "@i18n(app.modules.governor.cyc)@", spec = {key = "governor_cyclic_weight"}},
    {title = "@i18n(app.modules.governor.col)@", spec = {key = "governor_collective_weight"}},
  })

  runtime:loadInitial()
end

return {open = open}

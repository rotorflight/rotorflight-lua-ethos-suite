-- Tail Rotor profile editor page. Loaded on demand (plain loadfile) only when the user opens "Tail Rotor" from the system
-- tool's main menu -- see app/tool.lua.
--
-- First *multi-source* page in this rebuild: mirrors the original
-- suite's own app/modules/profile_tailrotor module, which combines
-- fields from two separate MSP commands on one page -- yaw stop gain/
-- precomp/inertia-precomp come from MSP_PID_PROFILE (cmd 94/95, see
-- lib/msp_pid_profile.lua, already used by app/pages/pid_controller.lua
-- for a *different* subset of the same command's fields), while Tail
-- Torque Assist gain/limit come from MSP_GOVERNOR_PROFILE (cmd 148/149,
-- see lib/msp_governor_profile.lua, new here). Both commands are scoped
-- to the same active PID profile, so this page needs the identical
-- profile-switch-reload handling as every other page here.
--
-- The original gates several of these fields on FC API version
-- (apiversiongte/apiversionlte in its formdata schema) -- e.g. inertia
-- precomp only exists from API 12.0.8, Tail Torque Assist only from
-- 12.0.9, and the two legacy "collective dynamic" fields only apply
-- *below* 12.0.7. This rebuild's floor is API >= 12.09 (see AGENTS.md),
-- above every one of those gates except the legacy one -- so, matching
-- this project's existing "no version branching" rule, there is no
-- runtime checking here at all: inertia precomp and TTA are simply
-- always shown (they're always present on any FC this rebuild connects
-- to), and the legacy collective-dynamic fields are simply never shown
-- (they'd only ever apply to firmware this rebuild doesn't support).
-- Version gates that were runtime conditions in the original collapse to
-- a one-time authoring decision here.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. Field/row building comes from app/field_layout.lua.
-- This file only owns which two MSP codecs to use and which fields to
-- show from each.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local pidProfile = requireModule("lib/msp_pid_profile.lua")
local governorProfile = requireModule("lib/msp_governor_profile.lua")

local PAGE_TITLE = "@i18n(app.modules.tail_rotor.name)@"

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "tailrotor",
    sources = {
      {key = "pid", mspModule = pidProfile},
      {key = "governor", mspModule = governorProfile},
    },
    opts = opts,
    unloadPackageKeys = {"rfsuite.lib.msp_pid_profile", "rfsuite.lib.msp_governor_profile"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.tail_rotor.yaw_stop_gain)@", {
    {title = "@i18n(app.modules.tail_rotor.cw)@", spec = {key = "yaw_cw_stop_gain", source = "pid"}},
    {title = "@i18n(app.modules.tail_rotor.ccw)@", spec = {key = "yaw_ccw_stop_gain", source = "pid"}},
  })

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.tail_rotor.yaw_precomp_cutoff)@",
    {key = "yaw_precomp_cutoff", source = "pid"})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.tail_rotor.yaw_cyclic_ff_gain)@",
    {key = "yaw_cyclic_ff_gain", source = "pid"})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.tail_rotor.yaw_collective_ff_gain)@",
    {key = "yaw_collective_ff_gain", source = "pid"})

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.tail_rotor.inertia_precomp)@", {
    {title = "@i18n(app.modules.tail_rotor.gain)@", spec = {key = "yaw_inertia_precomp_gain", source = "pid"}},
    {title = "@i18n(app.modules.tail_rotor.cutoff)@", spec = {key = "yaw_inertia_precomp_cutoff", source = "pid"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.tail_rotor.tail_torque_assist)@", {
    {title = "@i18n(app.modules.tail_rotor.gain)@", spec = {key = "governor_tta_gain", source = "governor"}},
    {title = "@i18n(app.modules.tail_rotor.limit)@", spec = {key = "governor_tta_limit", source = "governor"}},
  })

  runtime:loadInitial()
end

return {open = open}

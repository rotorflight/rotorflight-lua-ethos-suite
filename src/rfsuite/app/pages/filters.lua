-- Filters profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning -> Advanced ->
-- Filters -- see app/tool.lua.
--
-- First page against MSP_FILTER_CONFIG (cmd 92/93, see
-- lib/msp_filter_config.lua). Matches the original suite's own
-- app/modules/filters/filters.lua field selection exactly: LPF1/LPF2
-- type+cutoff, LPF1 dynamic min/max, two soft notch filters (center+
-- cutoff each), dynamic notch count/Q and min/max range, and RPM filter
-- preset+min Hz -- 15 fields with a widget. `gyro_hardware_lpf` (the
-- struct's 18th... first wire field, legacy/unused in current firmware)
-- still round-trips unchanged every save, matching the original, which
-- never builds a widget for it either.
--
-- Layout simplified vs. the original: that suite's own generic form
-- engine renders this via 12 label rows with several fields packed onto
-- some of them via `inline` position codes -- a shape app/field_layout.lua
-- doesn't have (see AGENTS.md's "Shared page machinery" note on why a
-- fuller declarative engine wasn't built speculatively). Uses
-- buildSingle() for standalone fields and buildGroup() for the pairs the
-- original visually groups anyway (LPF1 dynamic min/max, each notch's
-- center/cutoff, dynamic notch count/Q and min/max) -- same simplification
-- precedent as app/pages/main_rotor.lua's own note on collapsing a
-- shared-label multi-row original layout into plain per-field rows.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. Field/row building comes from app/field_layout.lua.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local filterConfig = requireModule("lib/msp_filter_config.lua")

local PAGE_TITLE = "@i18n(app.modules.filters.name)@"

-- Choice option tables, matching rotorflight-lua-ethos-suite's own
-- FILTER_CONFIG.lua TBL_GYRO_FILTER_TYPE/TBL_RPM_PRESET (same {label,
-- value} shape already used by app/pages/pid_controller.lua's
-- ITERM_RELAX_OPTIONS, app/pages/rescue.lua's OFF_ON_OPTIONS/FLIP_OPTIONS,
-- and app/pages/governor_flags.lua's OFF_ON_OPTIONS).
local FILTER_TYPE_OPTIONS = {
  {"@i18n(app.modules.filters.tbl_none)@", 0},
  {"@i18n(app.modules.filters.tbl_1st)@", 1},
  {"@i18n(app.modules.filters.tbl_2nd)@", 2},
}
local RPM_PRESET_OPTIONS = {
  {"@i18n(app.modules.filters.tbl_custom)@", 0},
  {"@i18n(app.modules.filters.tbl_low)@", 1},
  {"@i18n(app.modules.filters.tbl_medium)@", 2},
  {"@i18n(app.modules.filters.tbl_high)@", 3},
}

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "filters",
    mspModule = filterConfig,
    opts = opts,
    unloadPackageKeys = {"rfsuite.lib.msp_filter_config"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.filters.lpf1_type)@",
    {key = "gyro_lpf1_type", choices = FILTER_TYPE_OPTIONS})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.filters.lpf1_cutoff)@",
    {key = "gyro_lpf1_static_hz"})

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.filters.lpf1_dynamic)@", {
    {title = "@i18n(app.modules.filters.min)@", spec = {key = "gyro_lpf1_dyn_min_hz"}},
    {title = "@i18n(app.modules.filters.max)@", spec = {key = "gyro_lpf1_dyn_max_hz"}},
  })

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.filters.lpf2_type)@",
    {key = "gyro_lpf2_type", choices = FILTER_TYPE_OPTIONS})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.filters.lpf2_cutoff)@",
    {key = "gyro_lpf2_static_hz"})

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.filters.notch_1)@", {
    {title = "@i18n(app.modules.filters.center)@", spec = {key = "gyro_soft_notch_hz_1"}},
    {title = "@i18n(app.modules.filters.cutoff)@", spec = {key = "gyro_soft_notch_cutoff_1"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.filters.notch_2)@", {
    {title = "@i18n(app.modules.filters.center)@", spec = {key = "gyro_soft_notch_hz_2"}},
    {title = "@i18n(app.modules.filters.cutoff)@", spec = {key = "gyro_soft_notch_cutoff_2"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.filters.dyn_notch)@", {
    {title = "@i18n(app.modules.filters.count)@", spec = {key = "dyn_notch_count"}},
    {title = "@i18n(app.modules.filters.q)@", spec = {key = "dyn_notch_q"}},
  })

  fieldLayout.buildGroup(runtime, "@i18n(app.modules.filters.dyn_notch_range)@", {
    {title = "@i18n(app.modules.filters.min)@", spec = {key = "dyn_notch_min_hz"}},
    {title = "@i18n(app.modules.filters.max)@", spec = {key = "dyn_notch_max_hz"}},
  })

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.filters.rpm_preset)@",
    {key = "rpm_preset", choices = RPM_PRESET_OPTIONS})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.filters.rpm_min_hz)@",
    {key = "rpm_min_hz"})

  runtime:loadInitial()
end

return {open = open}

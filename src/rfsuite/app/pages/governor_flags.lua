-- Governor "Flags" profile editor page. Loaded on demand (plain loadfile) only when the user opens Flight Tuning ->
-- Governor -> Flags -- see app/tool.lua.
--
-- Edits four individual bits of MSP_GOVERNOR_PROFILE's `governor_flags`
-- (a packed U16, cmd 148/149, see lib/msp_governor_profile.lua) as
-- separate Off/On choice fields -- matching the original suite's own
-- app/modules/profile_governor/tools/flags.lua, which exposes the same
-- four bits (of ~10 defined ones) via its `apikey = "governor_flags->
-- fallback_precomp"` bitfield syntax. Bit positions cross-checked
-- against rotorflight-firmware's actual bitmap ordering (also visible in
-- the original's own app/modules/profile_governor/tools/general.lua,
-- which decodes the same field locally for its own enable-rule logic):
-- bit2=fallback_precomp, bit3=voltage_comp, bit4=pid_spoolup,
-- bit6=dyn_min_throttle. The other ~6 defined bits (fc_throttle_curve,
-- tx_precomp_curve, hs_adjustment, autorotation, suspend, bypass) are
-- wire-present and round-tripped like every other field this page
-- doesn't touch, but the original doesn't expose them on this page
-- either, so neither does this one.
--
-- First page using app/field_layout.lua's `bit` spec (see its own
-- comment for the arithmetic get/set) -- promoted there instead of kept
-- local specifically because a future page exposing more of this same
-- bitmap, or a different packed field entirely, should reuse it rather
-- than reinventing bit arithmetic per page.
--
-- Deliberately simplified vs. the original, same as app/pages/
-- governor_general.lua: no conditional enable/disable based on governor
-- mode or (for `voltage_comp` specifically) whether the battery's
-- voltage source is ADC-based -- this rebuild has neither governor-mode
-- nor battery-voltage-source telemetry tracked yet. Every field here is
-- simply always editable.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local governorProfile = requireModule("lib/msp_governor_profile.lua")

local PAGE_TITLE = "@i18n(app.modules.governor.name)@"

local OFF_ON_OPTIONS = {
  {"@i18n(app.modules.governor.tbl_off)@", 0},
  {"@i18n(app.modules.governor.tbl_on)@", 1},
}

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "governorflags",
    mspModule = governorProfile,
    opts = opts,
    unloadPackageKeys = {"rfsuite.lib.msp_governor_profile"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.fallback_precomp)@",
    {key = "governor_flags", bit = 2, choices = OFF_ON_OPTIONS})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.pid_spoolup)@",
    {key = "governor_flags", bit = 4, choices = OFF_ON_OPTIONS})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.voltage_comp)@",
    {key = "governor_flags", bit = 3, choices = OFF_ON_OPTIONS})

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.governor.dyn_min_throttle)@",
    {key = "governor_flags", bit = 6, choices = OFF_ON_OPTIONS})

  runtime:loadInitial()
end

return {open = open}

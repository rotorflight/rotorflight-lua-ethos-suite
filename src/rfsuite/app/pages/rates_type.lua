-- Rate Table editor page. Loaded on demand (plain loadfile) only when
-- the user opens Flight Tuning -> Advanced -> Rates Advanced -> Rate
-- Table -- see app/tool.lua.
--
-- The *only* place `rates_type` (None/Betaflight/Raceflight/Kiss/Actual/
-- Quick Rates/Rotorflight) can be changed -- matching the original
-- suite's own separation exactly: app/modules/rates/rates.lua (this
-- rebuild's app/pages/rates.lua) never exposes a rates_type widget of
-- its own; only its Advanced -> Rates Advanced -> Rate Table tool
-- (app/modules/rates_advanced/tools/table.lua) does. Changing which rate
-- table is active changes what every one of app/pages/rates.lua's 12
-- curve fields' raw byte *means* (see lib/rate_curve_scale.lua), so it
-- deliberately isn't a casual edit sitting next to those fields.
--
-- Same MSP_RC_TUNING command as app/pages/rates.lua/rates_advanced.lua/
-- rates_cyclic.lua (cmd 111/204, see lib/msp_rc_tuning.lua), a single
-- field. Every other field still round-trips unchanged on save, same as
-- any page that only edits part of a wire struct (e.g.
-- app/pages/main_rotor.lua's own subset of MSP_PID_PROFILE).
--
-- Deliberately simplified vs. the original's own table.lua: no "reset to
-- this table's defaults" action -- that tool loads an entire default-
-- value table from app/modules/rates/ratetables/*.lua and resets every
-- curve field to it on save whenever rates_type changes, with its own
-- confirmation/warning flow (`extraMsgOnSave`) and a forced full page
-- reload afterward. This rebuild has no equivalent yet: switching
-- rates_type here only changes the byte's *meaning* for
-- app/pages/rates.lua's display -- it does not touch any curve field's
-- stored value, so a pilot who changes types should expect to also
-- revisit and re-tune app/pages/rates.lua's own fields for the new
-- table's conventions, rather than getting sensible defaults for free.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. Field building comes from app/field_layout.lua.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local rcTuning = requireModule("lib/msp_rc_tuning.lua")
local rateCurveScale = requireModule("lib/rate_curve_scale.lua")

local PAGE_TITLE = "@i18n(app.modules.rates_advanced.rate_table)@"

-- {label, value}, matching rotorflight-lua-ethos-suite's own
-- TBL_RATE_TABLE order (None/Betaflight/Raceflight/Kiss/Actual/Quick
-- Rates/Rotorflight, values 0-6) -- same {label, value} options-table
-- shape already used by app/pages/pid_controller.lua/rescue.lua/
-- governor_flags.lua/filters.lua. Names come from lib/rate_curve_scale.lua's
-- own NAMES table (also used by app/pages/rates.lua's status line) rather
-- than a second copy of the same 7 strings.
local RATE_TYPE_OPTIONS = {
  {rateCurveScale.NAMES[0], 0},
  {rateCurveScale.NAMES[1], 1},
  {rateCurveScale.NAMES[2], 2},
  {rateCurveScale.NAMES[3], 3},
  {rateCurveScale.NAMES[4], 4},
  {rateCurveScale.NAMES[5], 5},
  {rateCurveScale.NAMES[6], 6},
}

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler/opts.setCleanupHandler: see
-- app/menu_container.lua and app/tool.lua for how Ethos's
-- event()/wakeup()/close() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "ratestype",
    mspModule = rcTuning,
    opts = opts,
    -- "Rate Table #<profile>" title suffix + auto-reload-on-profile-
    -- switch -- see app/pages/rates.lua's own comment on profileField for
    -- why this is "rateProfile", not the default "pidProfile".
    profileField = "rateProfile",
    unloadPackageKeys = {"rfsuite.lib.msp_rc_tuning"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rates.rate_type)@",
    {key = "rates_type", choices = RATE_TYPE_OPTIONS})

  runtime:loadInitial()
end

return {open = open}

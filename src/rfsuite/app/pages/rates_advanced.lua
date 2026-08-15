-- Rates Advanced editor page. Loaded on demand (plain loadfile) only when
-- the user opens Flight Tuning -> Advanced -> Rates Advanced -> Advanced
-- -- see app/tool.lua.
--
-- Matches the original suite's own app/modules/rates_advanced/tools/
-- advanced.lua field selection: response time, accel limit, and
-- setpoint boost gain/cutoff, all per-axis (Roll/Pitch/Yaw/Collective),
-- plus the three yaw-only dynamic fields (ceiling gain, deadband gain,
-- deadband filter). Same MSP_RC_TUNING command as app/pages/rates.lua
-- (see lib/msp_rc_tuning.lua) and app/pages/rates_cyclic.lua, but a
-- different field subset -- matching how the original splits one
-- command's fields across multiple pages by conceptual purpose (same
-- precedent as MSP_PID_PROFILE across app/pages/pid_controller.lua/
-- tail_rotor.lua/main_rotor.lua/pid_bandwidth.lua/autolevel.lua).
--
-- Unlike app/pages/rates.lua, every field here is a plain raw value with
-- no rates_type-dependent scaling (confirmed against
-- rotorflight-configurator's own src/js/msp/MSPHelper.js, which
-- reads/writes every one of these as a bare integer, no division or
-- multiplier at all).
--
-- **Grid layout, not fieldLayout.buildGroup()/buildSingle()** -- a live
-- screenshot of the original's own equivalent page showed Roll/Pitch/
-- Yaw/Col as a *shared column header row*, each of the 4 per-axis groups
-- (Response Time, Accel Limit, Setpoint Boost Gain/Cutoff) as a plain row
-- underneath it -- the same column-header-once shape app/pages/pids.lua
-- and app/pages/rates.lua's own grids already use, not buildGroup()'s
-- "repeat a mini-label before every single field" shape (which is the
-- right call when a line mixes unrelated fields, e.g.
-- app/pages/governor_general.lua's P/I/D/F gains, but wastes width here
-- where all 4 fields on a row are literally the same axis label repeated).
-- Built directly with form.addLine()/form.getFieldSlots(), same idiom as
-- those two pages, calling fieldLayout.buildField() (the same per-field
-- primitive buildGroup()/buildSingle() themselves call) for each of the
-- 16 grid cells so FIELD_META lookup/decimals/suffix/default all still
-- come from lib/msp_rc_tuning.lua exactly as before -- only the layout
-- around them changed, not how any individual field is built.
--
-- The 3 yaw-only dynamic fields (ceiling gain, deadband gain, deadband
-- filter) sit in the Yaw column specifically (COLUMNS[3]), not full-line
-- width -- matching the original's own screenshot, and matching what the
-- field names themselves say (`yaw_dynamic_ceiling_gain` etc.): these are
-- yaw-axis values, so they align under the same column Yaw's other rows
-- do, with Roll/Pitch/Col left blank on those rows.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local rcTuning = requireModule("lib/msp_rc_tuning.lua")

local PAGE_TITLE = "@i18n(app.modules.rates_advanced.name)@"

-- Column order matches the original's own grid: Roll, Pitch, Yaw,
-- Collective -- same axis order every other per-axis grid in this
-- rebuild uses (app/pages/pids.lua/rates.lua).
local COLUMNS = {
  {title = "@i18n(app.modules.rates_advanced.roll)@", axis = 1},
  {title = "@i18n(app.modules.rates_advanced.pitch)@", axis = 2},
  {title = "@i18n(app.modules.rates_advanced.yaw)@", axis = 3},
  {title = "@i18n(app.modules.rates_advanced.col)@", axis = 4},
}

-- One row: `label` on the left, one field per column, keyed
-- "<keyPrefix>_<axis>" (matches lib/msp_rc_tuning.lua's own field naming,
-- e.g. "response_time_1".."response_time_4").
local function buildAxisRow(runtime, label, keyPrefix)
  local line = form.addLine(label)
  local slots = form.getFieldSlots(line, {0, 0, 0, 0})
  for i, column in ipairs(COLUMNS) do
    fieldLayout.buildField(runtime, line, slots[i], {key = keyPrefix .. "_" .. column.axis})
  end
end

-- Which column index the 3 yaw-only dynamic fields sit under -- see the
-- header comment above. Matches COLUMNS[3] = Yaw.
local YAW_COLUMN = 3

-- One row: `label` on the left, a single field sitting in the Yaw
-- column's slot -- same 4-slot line as buildAxisRow() above, so this
-- field lines up under the Yaw header exactly like the axis rows do,
-- just with the other 3 slots left empty.
local function buildYawOnlyRow(runtime, label, key)
  local line = form.addLine(label)
  local slots = form.getFieldSlots(line, {0, 0, 0, 0})
  fieldLayout.buildField(runtime, line, slots[YAW_COLUMN], {key = key})
end

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup()/close() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "ratesadvanced",
    mspModule = rcTuning,
    opts = opts,
    -- "Rates Advanced #<profile>" title suffix + auto-reload-on-profile-
    -- switch -- see app/pages/rates.lua's own comment on profileField for
    -- why this is "rateProfile", not the default "pidProfile".
    profileField = "rateProfile",
    unloadPackageKeys = {"rfsuite.lib.msp_rc_tuning"},
  })

  form.clear()
  runtime:buildChrome()

  -- Column header line, matching app/pages/pids.lua's own P/I/D/F/O/B
  -- header convention: a blank-but-non-empty label (" ", not "") so this
  -- line reserves the same row-label gutter width as the axis rows below
  -- (an empty "" label reserves none, throwing the 4-slot column math out
  -- of alignment -- see app/pages/pids.lua's own comment for the
  -- confirmed-live original discovery of this).
  local headerLine = form.addLine(" ")
  local headerSlots = form.getFieldSlots(headerLine, {0, 0, 0, 0})
  for i, column in ipairs(COLUMNS) do
    form.addStaticText(headerLine, headerSlots[i], column.title, RIGHT)
  end

  buildAxisRow(runtime, "@i18n(app.modules.rates_advanced.response_time)@", "response_time")
  buildAxisRow(runtime, "@i18n(app.modules.rates_advanced.accel_limit)@", "accel_limit")
  buildAxisRow(runtime, "@i18n(app.modules.rates_advanced.setpoint_boost_gain)@", "setpoint_boost_gain")
  buildAxisRow(runtime, "@i18n(app.modules.rates_advanced.setpoint_boost_cutoff)@", "setpoint_boost_cutoff")

  buildYawOnlyRow(runtime, "@i18n(app.modules.rates_advanced.dyn_ceiling_gain)@",
    "yaw_dynamic_ceiling_gain")

  buildYawOnlyRow(runtime, "@i18n(app.modules.rates_advanced.dyn_deadband_gain)@",
    "yaw_dynamic_deadband_gain")

  buildYawOnlyRow(runtime, "@i18n(app.modules.rates_advanced.dyn_deadband_filter)@",
    "yaw_dynamic_deadband_filter")

  runtime:loadInitial()
end

return {open = open}

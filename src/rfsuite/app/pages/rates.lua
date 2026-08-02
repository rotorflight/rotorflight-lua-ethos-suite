-- Rates profile editor page. Loaded on demand (plain loadfile) only when
-- the user opens Flight Tuning -> Rates -- see app/tool.lua. Top-level
-- Flight Tuning entry (order 2, between PIDs and Governor in the
-- manifest), not part of the Advanced submenu.
--
-- First page against MSP_RC_TUNING (cmd 111/204, see
-- lib/msp_rc_tuning.lua). Exposes the 12 "curve shape" fields
-- (rcRates_N/rcExpo_N/rates_N per axis) the original suite's own
-- app/modules/rates/rates.lua page shows. The rest of MSP_RC_TUNING
-- (response_time/accel_limit/setpoint_boost/yaw_dynamic/cyclic_ring/
-- cyclic_polarity) matches the original's own Advanced -> Rates Advanced
-- submenu instead -- see app/pages/rates_advanced.lua and
-- app/pages/rates_cyclic.lua. `rates_type` itself is read here (it drives
-- which conversion the 12 curve fields use) but never *edited* here --
-- matching the original exactly: rates.lua has no rates_type widget of
-- its own; only its Rate Table tool
-- (app/modules/rates_advanced/tools/table.lua) can change it, since
-- doing so meaningfully changes what every other field's raw byte means.
-- See app/pages/rates_type.lua, this rebuild's equivalent standalone page.
--
-- **The hard, genuinely novel part of this page**: all 7 rate tables
-- (None/Betaflight/Raceflight/Kiss/Actual/Quick Rates/Rotorflight) share
-- the exact same 3 wire fields per axis -- switching `rates_type` doesn't
-- change which MSP fields exist, only how a human-friendly number maps
-- to the raw U8 byte, and how many decimal places that number needs.
-- lib/rate_curve_scale.lua owns both (its `SCALE_TABLE`/`DECIMALS_TABLE`);
-- this page just calls it from each of the 12 curve fields' getter/setter,
-- and from correctGridPrecision() below.
--
-- **Fields are built upfront in open() like every other page (NOT
-- deferred until data loads)** -- an earlier version of this page tried
-- deferring construction (`form.addLine()`/`form.addNumberField()`) until
-- the real rates_type was known, called from pageRuntime.new()'s
-- onLoaded. That didn't render at all, live: onLoaded fires from deep
-- inside loadData()'s MSP-response callback chain, the same "nested
-- inside the background task's own callback, not this tool's own tick"
-- context app/page_runtime.lua's own PageRuntime:openLoadingDialog()
-- comment already flags as unreliable for *spawning new UI* (that
-- comment is specifically about form.openProgressDialog(), but the
-- failure here shows the same restriction extends to form.addLine()/
-- form.addNumberField() -- creating widgets, not just opening a dialog,
-- needs the tool's own tick). Reverted to building every field
-- immediately, with an initial guess (whatever lib/rate_curve_scale.lua's
-- own scaleFor()/decimalsFor() fall back to when rateType is nil --
-- RATE_TYPE_ACTUAL) for its bounds/decimals, same as any other page's
-- fields existing (disabled) before the first read completes.
--
-- **Getting the correct per-type decimals without creating anything
-- new**: onSessionUpdate()'s own comment already established that plain
-- property updates on an *existing* widget -- `:value()`, `:enable()` --
-- work fine from that same nested context; only spawning new UI doesn't.
-- rotorflight-lua-ethos-suite's own app/modules/failsafe/failsafe.lua
-- confirms Ethos number fields support exactly this for bounds too
-- (`formFields[i]:minimum(875)` / `:maximum(2125)`, called after the
-- field already exists). So correctGridPrecision() below -- called from
-- onLoaded, alongside updateRateTableLabel() -- doesn't rebuild anything;
-- it just calls `:minimum()`/`:maximum()`/`:decimals()` again on each of
-- the 12 already-existing fields, now that the real rates_type is known.
-- Runs on *every* successful load (first load, manual Reload, and the
-- automatic profile-switch reload alike), not just the first -- so
-- unlike relying on a fixed construction-time guess, this stays correct
-- even if the pilot changes rates_type (via app/pages/rates_type.lua)
-- and this exact page's data reloads without being closed and reopened.
--
-- One remaining simplification vs. the original: no polar-mode row
-- *relabeling* -- the original hides the Roll row entirely and renumbers
-- Pitch/Yaw/Collective as Cyclic/Yaw/Collective when `cyclic_polarity`
-- is on (app/modules/rates/ratetables/layout.lua), which needs a
-- dynamically rebuildable grid this rebuild's fixed-at-construction one
-- doesn't have (see "Fields are built upfront" above). What *is* ported:
-- the Roll row's 3 fields become non-editable (disabled, matching this
-- page's grayed-out-until-loaded convention) whenever cyclic_polarity is
-- on, same as the original's own hidden/inert Roll row -- the row simply
-- stays visible and labeled "Roll" rather than disappearing. See
-- syncPolarState() below, called from onLoaded alongside
-- correctGridPrecision() for the same reason that one's own comment gives.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. `profileField = "rateProfile"` (see the open()'s own
-- call below), not the default "pidProfile" -- this page's
-- MSP_RC_TUNING is scoped by *rate* profile, tracked the same way
-- tasks/session.lua already tracks pidProfile (its own "rate_profile"
-- telemetry sensor read), giving the same "<title> #<profile>" suffix
-- and auto-reload-on-profile-switch app/pages/pids.lua gets, just keyed
-- off the other profile slot. A different concern from the rate-*type*
-- selector app/pages/rates_type.lua edits -- rateProfile is which of the
-- FC's several rate profile *slots* is active (like pidProfile for
-- PIDs); rates_type is which table convention that slot's raw bytes are
-- interpreted under.

local pageRuntime = assert(loadfile("app/page_runtime.lua"))()
local rcTuning = assert(loadfile("lib/msp_rc_tuning.lua"))()
local rateCurveScale = assert(loadfile("lib/rate_curve_scale.lua"))()

local PAGE_TITLE = "@i18n(app.modules.rates.name)@"

-- Column order matches the original's own grid: RC Rate, then the
-- "shape"/"super rate"/"max rate" column (always the `rates_N` wire
-- field, whatever a given table calls it -- see lib/rate_curve_scale.lua),
-- then RC Expo.
local COLUMNS = {
  {title = "@i18n(app.modules.rates.rc_rate)@", role = "rcRate"},
  {title = "@i18n(app.modules.rates.rate)@", role = "srate"},
  {title = "@i18n(app.modules.rates.rc_expo)@", role = "expo"},
}
local ROWS = {
  {label = "@i18n(app.modules.rates.roll)@", axis = 1, axisClass = "main"},
  {label = "@i18n(app.modules.rates.pitch)@", axis = 2, axisClass = "main"},
  {label = "@i18n(app.modules.rates.yaw)@", axis = 3, axisClass = "main"},
  {label = "@i18n(app.modules.rates.collective)@", axis = 4, axisClass = "col"},
}

local function fieldKeyFor(role, axis)
  if role == "rcRate" then return "rcRates_" .. axis end
  if role == "srate" then return "rates_" .. axis end
  return "rcExpo_" .. axis
end

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler/opts.setCleanupHandler: see
-- app/menu_container.lua and app/tool.lua for how Ethos's
-- event()/wakeup()/close() reach a page.
local function open(opts)
  -- Forward-declared: PageRuntime.new()'s onLoaded callback is built
  -- before updateRateTableLabel()/correctGridPrecision()/syncPolarState()
  -- themselves exist (they need dataRef/the built fields, which aren't
  -- ready until later in this function) -- assigned below, once those do.
  local updateRateTableLabel
  local correctGridPrecision
  local syncPolarState

  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "rates",
    mspModule = rcTuning,
    opts = opts,
    -- "Rates #<profile>" title suffix + auto-reload-on-profile-switch,
    -- same mechanism app/pages/pids.lua gets from the default
    -- "pidProfile" -- this page's MSP_RC_TUNING is scoped by *rate*
    -- profile instead (tasks/session.lua's own rateProfile tracking,
    -- read from the "rate_profile" telemetry sensor).
    profileField = "rateProfile",
    unloadPackageKeys = {"rfsuite.lib.msp_rc_tuning"},
    -- Deterministic: runs exactly when loadData() succeeds (first load,
    -- manual Reload, and the automatic profile-switch reload alike).
    -- Both callees only ever call :value()/:minimum()/:maximum()/
    -- :decimals() on already-existing widgets -- see this file's own
    -- header comment for why that's safe from here (this fires from
    -- inside the MSP response chain, not this tool's own tick) while
    -- creating *new* widgets from here is not.
    onLoaded = function()
      if updateRateTableLabel then
        updateRateTableLabel()
      end
      if correctGridPrecision then
        correctGridPrecision()
      end
      if syncPolarState then
        syncPolarState()
      end
    end,
  })

  form.clear()
  runtime:buildChrome()
  -- Captured once, right after buildChrome() -- every field's getter/
  -- setter closure below captures this small indirection table, not
  -- `runtime` itself, matching app/pages/pids.lua's own convention (see
  -- its comment, and app/page_runtime.lua's PageRuntime:dispose(), for
  -- why: Ethos retains some closures past this page's own lifetime, and
  -- dataRef -- unlike the full runtime -- gets its contents cleared on
  -- dispose, so whatever Ethos keeps alive stays small).
  local dataRef = runtime.dataRef

  -- Column header line, matching app/pages/pids.lua's own P/I/D/F/O/B
  -- header convention: a blank-but-non-empty label (" ", not "") so this
  -- line reserves the same row-label gutter width as the axis rows below
  -- (an empty "" label reserves none, throwing the 3-slot column math out
  -- of alignment -- see app/pages/pids.lua's own comment for the
  -- confirmed-live original discovery of this).
  local headerLine = form.addLine(" ")
  local headerSlots = form.getFieldSlots(headerLine, {0, 0, 0})

  -- Shows the currently active rate table's name in that same row-label
  -- gutter, in place of the blank " " -- matching the original suite's
  -- own app/modules/rates/rates.lua, which renders formdata.name (e.g.
  -- "Rotorflight") at the top-left of this exact header row (its col_0).
  -- headerSlots[1].x is already a known-good boundary (it's what
  -- right-aligns the "RC Rate" title correctly below), so it doubles as
  -- the right edge of this rect -- same "true left edge to the first
  -- known-good boundary" idiom app/header.lua's own buildTitleRect() uses
  -- for the page title, and for the same reason: form.getFieldSlots()'s
  -- own slot 1 x/w is not reliable to use directly for an overlaid static
  -- text (see that file's header comment for the live bug that taught
  -- this). Blank until the first real read completes (dataRef.data.
  -- rates_type is nil until then) -- same "no fake info shown"
  -- convention every field on this page already follows.
  local rateTableRect = {x = 0, y = headerSlots[1].y, w = headerSlots[1].x, h = headerSlots[1].h}
  local rateTableField = form.addStaticText(headerLine, rateTableRect, "", LEFT)
  -- Assigns the forward-declared local from pageRuntime.new()'s onLoaded
  -- above -- see that call's own comment for why this runs from there,
  -- not from a field getter.
  updateRateTableLabel = function()
    rateTableField:value(rateCurveScale.NAMES[dataRef.data.rates_type] or "")
  end

  for i, column in ipairs(COLUMNS) do
    form.addStaticText(headerLine, headerSlots[i], column.title, RIGHT)
  end

  -- Built immediately, same as every other page's fields -- {field=,
  -- role=, axisClass=} per curve field, so correctGridPrecision() below
  -- can re-derive each one's correct bounds/decimals once the real
  -- rates_type is known, without needing to rebuild anything.
  local curveFields = {}
  -- Roll row's 3 fields specifically -- see syncPolarState() below.
  local rollFields = {}

  for _, row in ipairs(ROWS) do
    local line = form.addLine(row.label)
    local slots = form.getFieldSlots(line, {0, 0, 0})
    for colIndex, column in ipairs(COLUMNS) do
      local key = fieldKeyFor(column.role, row.axis)
      -- Initial guess only -- rateType nil falls back to RATE_TYPE_ACTUAL
      -- (see lib/rate_curve_scale.lua's scaleFor()/decimalsFor()), same
      -- as the value shown/edited before the first read completes on
      -- any other page's fields. Corrected for real the moment the real
      -- rates_type is known -- see correctGridPrecision() below.
      local minVal, maxVal, decimals = rateCurveScale.displayBounds(nil, column.role, row.axisClass)
      local field = form.addNumberField(line, slots[colIndex], minVal, maxVal,
        function()
          return rateCurveScale.toDisplayInt(dataRef.data[key], dataRef.data.rates_type, column.role, row.axisClass)
        end,
        function(value)
          runtime:markDirty()
          dataRef.data[key] = rateCurveScale.fromDisplayInt(value, dataRef.data.rates_type, column.role, row.axisClass)
        end)
      field:decimals(decimals)
      if field.step then field:step(rateCurveScale.displayStep(nil, column.role, row.axisClass)) end
      runtime:registerField(key, field)
      curveFields[#curveFields + 1] = {field = field, role = column.role, axisClass = row.axisClass}
      if row.axis == 1 then
        rollFields[#rollFields + 1] = field
      end
    end
  end

  -- Assigns the forward-declared local from pageRuntime.new()'s onLoaded
  -- above. Re-derives every field's bounds/decimals for whichever
  -- rates_type is *actually* active -- see this file's own header
  -- comment for why this, not a rebuild, is how this page gets correct
  -- per-table precision.
  correctGridPrecision = function()
    local rateType = dataRef.data.rates_type
    for _, entry in ipairs(curveFields) do
      local minVal, maxVal, decimals = rateCurveScale.displayBounds(rateType, entry.role, entry.axisClass)
      entry.field:minimum(minVal)
      entry.field:maximum(maxVal)
      entry.field:decimals(decimals)
      if entry.field.step then entry.field:step(rateCurveScale.displayStep(rateType, entry.role, entry.axisClass)) end
    end
  end

  -- Assigns the forward-declared local from pageRuntime.new()'s onLoaded
  -- above. Matches the original's own polar-mode behavior for the Roll
  -- row (see this file's own header comment): a single shared cyclic
  -- axis makes the Roll-specific curve meaningless while
  -- `cyclic_polarity` is on, so its 3 fields go non-editable rather than
  -- silently keeping a value nothing on the FC actually reads through
  -- roll's own control path. Runs on every successful load, same as
  -- correctGridPrecision(), so a live cyclic_polarity change (edited on
  -- app/pages/rates_cyclic.lua, this page's own Reload/profile-switch
  -- picks it up) re-syncs without needing this page closed and reopened.
  syncPolarState = function()
    local polarEnabled = (dataRef.data.cyclic_polarity or 0) == 1
    for _, field in ipairs(rollFields) do
      field:enable(not polarEnabled)
    end
  end

  runtime:loadInitial()
end

return {open = open}

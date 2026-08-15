-- Cyclic Behaviour editor page. Loaded on demand (plain loadfile) only
-- when the user opens Flight Tuning -> Advanced -> Rates Advanced ->
-- Cyclic Behaviour -- see app/tool.lua.
--
-- Matches the original suite's own app/modules/rates_advanced/tools/
-- cyclic_behaviour.lua field selection: `cyclic_polarity` (On/Off) and
-- `cyclic_ring` (%), both on MSP_RC_TUNING (cmd 111/204, see
-- lib/msp_rc_tuning.lua) -- same command as app/pages/rates.lua/
-- rates_advanced.lua, a different field subset.
--
-- Hand-built rather than going through app/field_layout.lua (like
-- app/pages/pids.lua/rates.lua's own grids) because the two fields have
-- a real cross-field relationship the original implements and this
-- rebuild has no generic primitive for yet: toggling `cyclic_polarity`
-- on/off enables/disables the `cyclic_ring` field and resets its value
-- (0 when turned off; a sensible non-zero default when turned back on
-- from 0) -- matching the original's own handleCyclicRingToggle().
--
-- Deliberately simplified vs. the original in one direction only: the
-- original's own syncCyclicRingState() keeps this relationship
-- bidirectional (typing a nonzero value directly into the ring field
-- also flips the polarity toggle on). This page only handles
-- toggle -> ring (the primary interaction this page exists for); typing
-- into the ring field while polarity is off is simply not possible,
-- since the field is disabled in that state -- so the missing direction
-- has no way to matter in practice, it's not a real behavioral gap.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local rcTuning = requireModule("lib/msp_rc_tuning.lua")

local PAGE_TITLE = "@i18n(app.modules.rates_advanced.cyclic_behaviour)@"

-- Matches the original's own CYCLIC_RING_DEFAULT -- the value proposed
-- when the pilot turns polarity ON starting from a ring value of 0 (a
-- freshly-read page, or one where it was previously turned off).
local CYCLIC_RING_DEFAULT = 150

local OFF_ON_OPTIONS = {
  {"@i18n(app.modules.rates_advanced.tbl_off)@", 0},
  {"@i18n(app.modules.rates_advanced.tbl_on)@", 1},
}

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler/opts.setCleanupHandler: see
-- app/menu_container.lua and app/tool.lua for how Ethos's
-- event()/wakeup()/close() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "ratescyclic",
    mspModule = rcTuning,
    opts = opts,
    -- "Cyclic Behaviour #<profile>" title suffix + auto-reload-on-
    -- profile-switch -- see app/pages/rates.lua's own comment on
    -- profileField for why this is "rateProfile", not the default
    -- "pidProfile".
    profileField = "rateProfile",
    unloadPackageKeys = {"rfsuite.lib.msp_rc_tuning"},
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
  -- Same reasoning, for markDirty(): controlRef.runtime gets nilled on
  -- dispose, so a retained closure here only pins this tiny table, never
  -- the disposed PageRuntime itself.
  local controlRef = runtime.controlRef
  local function markDirty()
    local rt = controlRef.runtime
    if rt then rt:markDirty() end
  end

  local ringLine = form.addLine("@i18n(app.modules.rates_advanced.cyclic_ring)@")
  local ringField = form.addNumberField(ringLine, nil, 0, 250,
    function() return dataRef.data.cyclic_ring end,
    function(value) markDirty(); dataRef.data.cyclic_ring = value end)
  ringField:suffix("%")
  ringField:enable(false)
  runtime:registerField("cyclic_ring", ringField)

  -- Re-asserts cyclic_ring's own enable state from the current
  -- cyclic_polarity value. Needed because app/page_runtime.lua's
  -- loadData() unconditionally re-enables *every* registered field on a
  -- successful read/reload (see its own comment) -- which would
  -- otherwise clobber this field's polarity-dependent disabled state
  -- right after every load. Called from the polarity field's own
  -- getter, not just its setter, since Ethos calls a field's getter to
  -- refresh its displayed value on redraw -- including the redraw that
  -- follows loadData()'s bulk re-enable -- so this is what actually
  -- catches and corrects that case. Relies on Ethos calling the getter
  -- at least once after such a redraw, which isn't independently
  -- confirmed here.
  local function syncRingEnabled()
    ringField:enable((dataRef.data.cyclic_polarity or 0) == 1)
  end

  local polarityLine = form.addLine("@i18n(app.modules.rates_advanced.cyclic_polarity)@")
  local polarityField = form.addChoiceField(polarityLine, nil, OFF_ON_OPTIONS,
    function()
      syncRingEnabled()
      return dataRef.data.cyclic_polarity
    end,
    function(value)
      markDirty()
      dataRef.data.cyclic_polarity = value
      if value == 1 and (dataRef.data.cyclic_ring or 0) <= 0 then
        dataRef.data.cyclic_ring = CYCLIC_RING_DEFAULT
      elseif value == 0 then
        dataRef.data.cyclic_ring = 0
      end
      syncRingEnabled()
    end)
  runtime:registerField("cyclic_polarity", polarityField)

  runtime:loadInitial()
end

return {open = open}

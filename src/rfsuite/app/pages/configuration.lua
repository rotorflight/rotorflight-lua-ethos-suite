-- Configuration page. Loaded on demand (plain loadfile) only when the
-- user opens Configuration -> Setup -> Configuration -- see app/tool.lua.
-- First real page under Setup (every tile there besides this one is
-- still a scaffolded empty placeholder -- see app/tool.lua's own
-- comment on ROOT_ENTRIES).
--
-- Matches the original suite's own app/modules/configuration/
-- configuration.lua field selection: craft name, PID loop speed, and
-- three feature toggles (GPS, LED Strip, CMS) -- a small slice of a
-- 4-MSP-command page (NAME, ADVANCED_CONFIG, FEATURE_CONFIG, STATUS),
-- matching that suite's own openPage()/startLoad(), which reads exactly
-- those same four.
--
-- Multi-source (app/page_runtime.lua's `sources`, not `mspModule`) --
-- four independent commands combined onto one page, same precedent as
-- app/pages/tail_rotor.lua. `status` is genuinely **read-only**
-- (MSP_STATUS has no MSP_SET_STATUS in firmware at all -- confirmed
-- against rotorflight-firmware's own src/main/msp/msp.c) -- its
-- lib/msp_status.lua simply has no buildWriteMessage, and
-- app/page_runtime.lua's performSave() now skips writing any source
-- whose mspModule doesn't define one, rather than needing a separate
-- read-only-source config flag. STATUS's own field, task_delta_time_gyro
-- (the live gyro loop period), only feeds the PID loop speed field's own
-- display labels below -- it's never itself shown or edited.
--
-- `profileField = "none"` -- deliberately not "pidProfile" (the shared
-- default): Configuration has nothing to do with the FC's PID/rate
-- profile slots, so the profile-switch-auto-reload/title-suffix
-- machinery every other page gets from app/page_runtime.lua would be
-- pure noise here (worse, a spurious profile-triggered reload could
-- discard an in-progress edit for a reason this page has nothing to do
-- with). "none" is simply a session.update field key that will never
-- exist in the payload tasks/session.lua publishes, so `self.lastProfile`
-- always stays nil and that whole mechanism is permanently inert --
-- reusing the existing generic knob rather than adding a new
-- "disable this" flag to app/page_runtime.lua for a single page.
--
-- `rebootAfterSave = true` -- a PID loop speed change only takes effect
-- after the FC restarts, matching the original's own rebootFc() (called
-- right after its own save's EEPROM_WRITE completes). See
-- app/page_runtime.lua's own config comment and lib/msp_reboot.lua's for
-- the armed-state safety gate on that (skips just the reboot, not the
-- rest of the save, if `tasks/session.lua`'s isArmed is true when the
-- EEPROM write acks).
--
-- **All fields are built once, from onLoaded, not upfront in open()** --
-- the one page in this rebuild that deviates from every other page's
-- "build fields immediately, refresh their values once data arrives"
-- convention, and deliberately so. Craft Name is a plain text field
-- (form.addTextField) -- confirmed against Ethos's own Lua API
-- reference (classTextEdit-members.html) that the object it returns has
-- exactly 3 methods (enable/focus/rect), no `:value()` or equivalent at
-- all, unlike static text/number/choice fields. So unlike
-- app/pages/rates.lua's fields (correctable in place via :value()/
-- :minimum()/:decimals()/:values() once real data arrives), a text
-- field's displayed value genuinely cannot be corrected after
-- construction -- unrecoverable if built before the real craft name is
-- known. **Self-caught crash, found live**: an earlier version of this
-- page built the text field upfront (like every other page) and tried
-- `nameField:value(...)` from onLoaded to correct it once loaded, same
-- idiom as rates.lua -- Ethos's own error log showed "method 'value' is
-- not callable (a nil value)" the instant that ran.
--
-- The original suite's own configuration.lua already avoids this
-- entirely, for exactly this reason: its render() (building every field,
-- including its own addTextField call) never runs until state.loaded is
-- true, called from the tool's own wakeup() -- nothing is built at all
-- while state.loading. This page now does the same: all 5 fields (name,
-- PID loop speed, GPS, LED Strip, CMS) are built together from a single
-- buildFields(), wired through onLoaded (guarded so a later manual
-- Reload firing onLoaded again doesn't try to build a second copy of
-- everything on top of the first) -- which itself is safely deferred to
-- the app tool's own wakeup tick via app/page_runtime.lua's
-- pendingOnLoaded (added for app/pages/rates.lua's own onLoaded uses,
-- see that file's comment) -- the same context the original's own
-- render() already relies on for building fields successfully. Building
-- PID loop speed's real choice list directly at that point (the real
-- gyro rate and current denom are already known) also means it no
-- longer needs rates.lua's own "guess now, correct via :values() later"
-- two-step -- there's nothing to correct, since nothing was built with a
-- guess in the first place.
--
-- Tradeoff vs. every other page: buildFields() only runs on the *first*
-- successful load. A manual Reload firing onLoaded again is a no-op here
-- (the guard), so already-built fields just refresh their own values
-- normally (confirmed working for number/choice fields elsewhere in this
-- rebuild); only PID loop speed's option *labels* (built from whatever
-- gyro rate the first load saw) could go stale if the live gyro rate
-- somehow changed between then and a later reload -- gyro rate
-- essentially never changes mid-session, so this is an accepted,
-- extremely unlikely edge case, not a real gap.
--
-- GPS/LED Strip/CMS reuse app/field_layout.lua's existing `bit` spec
-- (app/pages/governor_flags.lua's own convention, promoted there for
-- exactly this kind of reuse) against `featureConfig.enabledFeatures`,
-- a packed U32 -- bit positions (7/16/19) confirmed against
-- rotorflight-lua-ethos-suite's own FEATURE_CONFIG.lua FEATURES_BITMAP.
-- fieldLayout.buildSingle() doesn't return the field it builds, so
-- re-enabling all 5 fields after this deferred build (loadData()'s own
-- "enable every registered field" loop already ran once, before any of
-- these existed) iterates `runtime.fields` directly rather than
-- threading each field reference back out -- see buildFields()'s own
-- comment.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save -- comes from app/page_runtime.lua, shared with every page.

local pageRuntime = assert(loadfile("app/page_runtime.lua"))()
local fieldLayout = assert(loadfile("app/field_layout.lua"))()
local mspName = assert(loadfile("lib/msp_name.lua"))()
local advancedConfig = assert(loadfile("lib/msp_advanced_config.lua"))()
local featureConfig = assert(loadfile("lib/msp_feature_config.lua"))()
local mspStatus = assert(loadfile("lib/msp_status.lua"))()

local PAGE_TITLE = "@i18n(app.modules.configuration.name)@"

local OFF_ON_OPTIONS = {
  {"@i18n(app.modules.configuration.tbl_off)@", 0},
  {"@i18n(app.modules.configuration.tbl_on)@", 1},
}

-- Matches the original's own PID_LOOP_DENOMS -- the 4 denominators a
-- pilot can choose between; the actual kHz each maps to depends on the
-- live gyro rate (see pidLoopChoices() below).
local PID_LOOP_DENOMS = {1, 2, 3, 4}

local function formatPidLoopKhz(khz)
  local rounded = math.floor(khz * 100 + 0.5) / 100
  local text = string.format("%.2f", rounded):gsub("0+$", ""):gsub("%.$", "")
  if not text:find("%.") and rounded >= 2 then
    text = text .. ".0"
  end
  return text .. " kHz"
end

-- Matches the original's own getPidLoopChoices(): rounds the live gyro
-- rate to the nearest kHz, then labels each of the 4 denominators with
-- the PID loop rate it implies (gyroHz / denom). If `currentValue` isn't
-- one of the 4 (a denom the FC reports that this page's own option list
-- doesn't otherwise include -- unlikely but not impossible), it's added
-- as a 5th option rather than silently coercing the display to a
-- different stored value. `gyroDeltaUs` is always real here (see this
-- file's own header comment: this only ever runs after MSP_STATUS has
-- already loaded), so there's no "before data arrives" guess to fall
-- back to, unlike rates.lua's own construction-time bounds.
local function pidLoopChoices(gyroDeltaUs, currentValue)
  local rawGyroHz = 1000000 / gyroDeltaUs
  local gyroHz = math.floor(rawGyroHz / 1000 + 0.5) * 1000
  local options = {}
  local present = {}
  for _, denom in ipairs(PID_LOOP_DENOMS) do
    options[#options + 1] = {formatPidLoopKhz((gyroHz / denom) / 1000), denom}
    present[denom] = true
  end
  if currentValue and not present[currentValue] then
    options[#options + 1] = {formatPidLoopKhz((gyroHz / currentValue) / 1000), currentValue}
  end
  return options
end

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler/opts.setCleanupHandler: see
-- app/menu_container.lua and app/tool.lua for how Ethos's
-- event()/wakeup()/close() reach a page.
local function open(opts)
  -- Forward-declared: PageRuntime.new()'s onLoaded callback is built
  -- before buildFields() itself exists (it needs dataRef, which isn't
  -- ready until after buildChrome()) -- assigned below, once it is.
  local buildFields

  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "configuration",
    sources = {
      {key = "craftName", mspModule = mspName},
      {key = "advancedConfig", mspModule = advancedConfig},
      {key = "featureConfig", mspModule = featureConfig},
      {key = "status", mspModule = mspStatus},
    },
    opts = opts,
    -- See this file's own header comment for why "none", not the
    -- shared default "pidProfile".
    profileField = "none",
    rebootAfterSave = true,
    unloadPackageKeys = {
      "rfsuite.lib.msp_name",
      "rfsuite.lib.msp_advanced_config",
      "rfsuite.lib.msp_feature_config",
      "rfsuite.lib.msp_status",
    },
    onLoaded = function()
      if buildFields then
        buildFields()
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

  -- Assigns the forward-declared local from pageRuntime.new()'s onLoaded
  -- above -- see this file's own header comment for why every field is
  -- built here, once, instead of upfront.
  local fieldsBuilt = false
  buildFields = function()
    if fieldsBuilt then return end
    fieldsBuilt = true

    -- Craft Name -- a plain text field, hand-built (see this file's own
    -- header comment for why: the first page needing one, and why it
    -- can't be corrected in place like every other field type).
    local nameLine = form.addLine("@i18n(app.modules.configuration.craft_name)@")
    local nameField = form.addTextField(nameLine, nil,
      function()
        local craftName = dataRef.data.craftName
        return craftName and craftName.name or ""
      end,
      function(value)
        runtime:markDirty()
        local craftName = dataRef.data.craftName
        if craftName then craftName.name = value or "" end
      end)
    runtime:registerField("craftName:name", nameField)

    -- PID Loop Speed -- the real gyro rate/current denom are already
    -- known at this point (see this file's own header comment), so its
    -- option list is correct from the very first render, no later
    -- correction needed.
    local status = dataRef.data.status
    local advanced = dataRef.data.advancedConfig
    local gyroDeltaUs = (status and status.task_delta_time_gyro) or 0
    if gyroDeltaUs <= 0 then gyroDeltaUs = 250 end
    local currentValue = advanced and advanced.pid_process_denom

    local pidLoopLine = form.addLine("@i18n(app.modules.configuration.pid_loop_speed)@")
    local pidLoopField = form.addChoiceField(pidLoopLine, nil,
      pidLoopChoices(gyroDeltaUs, currentValue),
      function()
        local adv = dataRef.data.advancedConfig
        return adv and adv.pid_process_denom
      end,
      function(value)
        runtime:markDirty()
        local adv = dataRef.data.advancedConfig
        if adv then adv.pid_process_denom = value end
      end)
    runtime:registerField("advancedConfig:pid_process_denom", pidLoopField)

    fieldLayout.buildSingle(runtime, "@i18n(app.modules.configuration.feature_gps)@",
      {key = "enabledFeatures", source = "featureConfig", bit = featureConfig.FEATURE_BIT_GPS, choices = OFF_ON_OPTIONS})

    fieldLayout.buildSingle(runtime, "@i18n(app.modules.configuration.feature_led_strip)@",
      {key = "enabledFeatures", source = "featureConfig", bit = featureConfig.FEATURE_BIT_LED_STRIP, choices = OFF_ON_OPTIONS})

    fieldLayout.buildSingle(runtime, "@i18n(app.modules.configuration.feature_cms)@",
      {key = "enabledFeatures", source = "featureConfig", bit = featureConfig.FEATURE_BIT_CMS, choices = OFF_ON_OPTIONS})

    -- registerField() disables every field by default (see its own
    -- comment: normally loadData()'s own "enable every registered field"
    -- loop, run right before onLoaded fires, is what turns it back on)
    -- -- but that loop already ran before any of these 5 fields existed,
    -- so they have to be enabled explicitly here instead. Iterates
    -- runtime.fields directly since fieldLayout.buildSingle() doesn't
    -- return the fields it builds (see this file's own header comment).
    for _, field in pairs(runtime.fields) do
      field:enable(true)
    end
  end

  runtime:loadInitial()
end

return {open = open}

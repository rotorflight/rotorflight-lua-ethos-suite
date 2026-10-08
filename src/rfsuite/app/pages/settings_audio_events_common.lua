-- Shared save/chrome helpers for the Settings -> Audio -> Events category
-- pages (settings_audio_events_voltage.lua and its siblings).
--
-- Issue #2308. This file is what that issue's split actually is: every event
-- key below lives in settings_store's `events` table, and the one page that
-- used to hold all of them built every widget for all of them at once. On a
-- 480x320 radio (X18 / X18R) that meant scrolling through twenty fields to
-- change one, and it kept the whole set of form widgets, their callbacks and
-- their label strings resident for as long as the page was open.
--
-- So the categories are separate pages now, and each one builds only its own
-- fields when it opens (the build callback below runs once, at open). The
-- shared half -- the save confirmation, the dirty check against a snapshot,
-- and the dispose that drops every reference this page took -- lives here
-- instead of being copied into six files.
--
-- Same shape as app/pages/settings_activelook_common.lua, which is the
-- established precedent in this tree for a family of Settings subpages. It
-- deliberately does NOT carry a `package.loaded` self-guard of its own:
-- requireModule() (lib/require.lua:75-88) already memoizes this under
-- "rfsuite.app.pages.settings_audio_events_common", so every category page
-- shares one instance and the guard would only duplicate that.
--
-- Not loaded at boot: app/menu_container.lua's loadPage() is the only path
-- that reaches a page file, and it runs on the pilot's tap. So this file and
-- its six callers sit off the boot closure entirely -- see the heap note in
-- the pull request body for the measurement.

local common = {}

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local settingsStore = requireModule("lib/settings_store.lua")

local BTN_OK = "@i18n(app.btn_ok)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"

-- openPage(pageTitle, opts, build)
--
-- pageTitle is the three-segment header title, matching the sibling Settings
-- pages ("Settings / Audio / Timer" in settings_audio_timer.lua:9) rather than
-- repeating "Events" a fourth time: the Events tile is what the pilot just
-- pressed, and a fourth segment overflows the title rect on a 480-wide radio
-- (header.lua's buildTitleRect() spans left edge to the first button and does
-- not shrink text).
--
-- opts is the table app/menu_container.lua hands page.open() -- see its
-- openScreen(): onBack plus the four set*Handler setters. All of them are
-- optional, and every handler this page installs is removed again on dispose
-- so a page that is left does not keep answering the tool's tick.
--
-- build(ctx) adds this category's fields and nothing else. ctx carries:
--   fields      -- the page's own table of created widgets, for the
--                  enable/disable rules that follow a master toggle
--   get         -- (key) -> settings.events[key], for those same rules;
--                  nil once the page is disposed
--   addBool     -- (label, key, afterChange) -> widget
--   addNumber   -- (label, key, spec) -> widget
--   addChoice   -- (label, key, choices, spec) -> widget
--   setEnabled  -- common.setEnabled, re-exported so a page does not have to
--                  reach for this module to grey a dependent field
-- A widget returned by add* is what ctx.fields should hold; the callbacks are
-- the only thing that can write to the snapshot afterwards.
function common.openPage(pageTitle, opts, build)
  opts = opts or {}
  local disposed = false
  local headerHandle
  local settings = settingsStore.load()
  local original = settingsStore.clone(settings)
  -- settingsStore.load() merges DEFAULTS, so `events` is always there for a
  -- store this version wrote. The guard is for a store written by a build that
  -- predates the events table at all -- matching what
  -- settings_activelook_common.lua:22 does for its own table, and cheaper than
  -- making every add* below re-check it.
  settings.events = settings.events or {}

  local function isDirty()
    return not settingsStore.same(settings, original)
  end

  local function updateSaveEnabled()
    if headerHandle then headerHandle.setSaveEnabled(isDirty()) end
  end

  -- Drops every reference this page took. Idempotent, and callable from the
  -- tool's own cleanup handler as well as from goBack() -- app/tool.lua:close()
  -- runs the cleanup handler on the way out, and that path must not write to a
  -- form Ethos has already stopped accepting mutations from (app/tool.lua's own
  -- close() comment says so verbatim).
  local function dispose()
    if disposed then return end
    disposed = true
    if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
    if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
    settings = nil
    original = nil
  end

  local function goBack()
    if disposed then return end
    dispose()
    if opts.onBack then opts.onBack() end
  end

  local function save(focusFn)
    if disposed then return end
    settingsStore.save(settings)
    original = settingsStore.clone(settings)
    bus.publish("settings.update", settingsStore.clone(settings))
    updateSaveEnabled()
    if focusFn then focusFn() end
  end

  local function confirmSave(focusFn)
    if not isDirty() then
      if focusFn then focusFn() end
      return
    end
    form.openDialog({
      title = MSG_SAVE_TITLE,
      message = MSG_SAVE_BODY,
      buttons = {
        {label = BTN_OK, action = function() save(focusFn); return true end},
        {label = BTN_CANCEL, action = function() if focusFn then focusFn() end; return true end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  form.clear()
  headerHandle = header.build(pageTitle, {
    onBack = goBack,
    onSave = function() confirmSave(headerHandle and headerHandle.focusSave) end,
  })

  -- One closure table per page open rather than a module-level one, so nothing
  -- here outlives the screen that built it.
  local ctx = {fields = {}}

  -- Read side for a page's own enable/disable rules. Goes through the same
  -- `settings` upvalue the write callbacks do, so it answers nil after
  -- dispose() rather than reaching into a released snapshot.
  function ctx.get(key)
    return settings and settings.events and settings.events[key]
  end

  function ctx.setEnabled(field, enabled)
    if field and field.enable then field:enable(enabled == true) end
  end

  -- Reads and writes `settings.events[key]`, marking the page dirty on a
  -- change. afterChange is where a page re-runs its own enable/disable rules.
  function ctx.addBool(label, key, afterChange)
    local line = form.addLine(label)
    return form.addBooleanField(line, nil,
      function()
        return settings and settings.events[key] == true
      end,
      function(value)
        if disposed or not settings then return end
        settings.events[key] = value == true
        if afterChange then afterChange() end
        updateSaveEnabled()
      end)
  end

  -- spec = {min=, max=, default=, scale=1, decimals=nil, suffix=nil}
  --
  -- `scale` is the field's own step, not a display setting: the BEC and RX
  -- thresholds are stored as volts (6.5) and the number field counts tenths,
  -- so the getter multiplies by 10 and the setter divides by 10. Kept as an
  -- explicit spec field because the two thresholds are the only fields on the
  -- page that need it, and a shared hard-coded /10 here would silently scale
  -- the plain counts as well.
  function ctx.addNumber(label, key, spec)
    local scale = spec.scale or 1
    local line = form.addLine(label)
    local field = form.addNumberField(line, nil, spec.min, spec.max,
      function()
        local value = settings and settings.events and settings.events[key]
        if value == nil then value = spec.default end
        if value == nil then return nil end
        return math.floor((value * scale) + 0.5)
      end,
      function(value)
        if disposed or not settings then return end
        settings.events[key] = (value or (spec.default * scale)) / scale
        updateSaveEnabled()
      end)
    if field then
      if spec.decimals and field.decimals then field:decimals(spec.decimals) end
      if spec.suffix and field.suffix then field:suffix(spec.suffix) end
    end
    return field
  end

  -- spec = {default=}. `choices` is the {{label, value}, ...} table the page
  -- owns -- see settings_audio_events_fuel.lua's FUEL_CHOICES.
  function ctx.addChoice(label, key, choices, spec)
    local line = form.addLine(label)
    local field = form.addChoiceField(line, nil, choices,
      function()
        local value = settings and settings.events and settings.events[key]
        return value == nil and spec.default or value
      end,
      function(value)
        if disposed or not settings then return end
        settings.events[key] = (value == nil) and spec.default or value
        updateSaveEnabled()
      end)
    return field
  end

  if build then build(ctx) end
  updateSaveEnabled()

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if closeKey.shouldHandleClose(category, value) then
        goBack()
        return true
      end
      return false
    end)
  end
  if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
  if opts.setCleanupHandler then opts.setCleanupHandler(dispose) end
end

return common
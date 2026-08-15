-- Generic tile-grid menu screen: renders a list of entries as icon
-- buttons, and opens either a leaf page (`script`) or another named
-- submenu (`menuId`, looked up from a `menus` table) on press.
--
-- Mirrors the *shape* of rotorflight-lua-ethos-suite's
-- app/lib/menu_container.lua + app/lib/submenu_builder.lua + the
-- return-context-stack half of app/lib/navigation.lua, trimmed to what
-- this rebuild's still-small menu tree needs: no icon-size preferences,
-- no ethosversion/apiversion visibility gating, no per-menu hooksScript
-- overrides, no manifest JSON/codegen step (entries are a
-- plain Lua table literal in app/tool.lua). `menuId` submenus
-- (app/tool.lua's "Advanced" tile, matching the original's own
-- Flight Tuning -> Advanced submenu in app/modules/manifest.lua) are the
-- first real use of this path -- self-caught bug, found reading this
-- file rather than live: the menuId press handler's recursive
-- openScreen() call was missing the setWakeupHandler argument, so
-- line ~92's unconditional setWakeupHandler(nil) would have crashed
-- ("attempt to call a nil value") the instant anyone actually opened a
-- submenu. Fixed before it ever shipped to a submenu tile.
--
-- Entries may carry an optional `group` label (e.g. "Flight Tuning"),
-- rendered as its own line whenever it changes going down the entry
-- list -- matching the original's home screen, which groups its flat
-- tile list under section labels the same way (see
-- app/lib/ui.lua:1596-1605's group-title-line insertion). Entries with
-- no group render inline with no label, and each new group starts a
-- fresh tile row, wrapping to further rows within that group once it
-- fills the screen's width (see numPerRow below).
--
-- Tile sizing/count-per-row: the original computes both from per-radio
-- constants (app/radios.lua) and a pilot `iconsize` preference. This
-- rebuild keeps the useful per-resolution profiles, chosen only from
-- the current screen size so every menu on a given radio is consistent.
--
-- The *first* group is the exception: rather than a generic screen title
-- ("Rotorflight") immediately followed by a same-looking group line
-- right below it, the first group's name becomes the header's own title
-- -- one line, not two. Only the second and later groups get their own
-- separate label line. A screen whose first entry has no group falls
-- back to the plain screen title, unchanged.
--
-- Every screen this renders installs its own physical-Back-key handler
-- via `setEventHandler` (see app/close_key.lua and app/tool.lua,
-- which is what actually receives Ethos's event() callback and forwards
-- to whichever handler is currently installed) -- at the root screen this
-- is `nil`, so the hardware Back key falls through to Ethos's own
-- default (closing the tool), exactly like the original at the true top
-- of its navigation stack.
--
-- Every screen also shows the permanent header/"Menu" button row (see
-- app/header.lua) as row one -- including the root menu, matching the
-- original's persistent top-right nav button. On-screen "Menu" pops the
-- stack (or, if it's already empty, calls system.exit() -- there's
-- nowhere left to go internally, so "Menu" here means leave the tool).
-- This SAME goBack() is also what's handed to a child screen/page as its
-- `onBack` (see below): pressing "Menu" on a page opened from the root
-- must return to the root, not exit -- it's only "nothing left to pop"
-- (an empty stack), never "the current screen happens to be the root",
-- that means exit. See app/navigation.lua's pop() for why those two are
-- deliberately not the same check.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local memstats = requireModule("lib/memstats.lua")
local tileGrid = requireModule("app/tile_grid.lua")

local menu_container = {}

-- Which tile index was last pressed on a given screen -- mirrors the
-- original's own `prefs.menulastselected[moduleKey]` convention (see
-- rotorflight-lua-ethos-suite's app/lib/menu_container.lua), trimmed to
-- in-session-only (no persisted storage; nothing here needs to survive
-- the tool being closed and reopened). Without this, a screen rebuild
-- (initial open, or returning via Back) leaves nothing focused at all --
-- fine for a touchscreen, but a rotary-encoder/arrow-key-only radio then
-- has no widget to move focus *from*, so directional navigation has
-- nowhere to start. Keyed by screenKey() below since a bare `nil` (the
-- root screen) can't itself be a table key.
local lastSelected = {}

local function screenKey(screen)
  return screen or "__root__"
end

-- Leaf pages are deliberately not cached. A page file is loaded for the
-- visit, open(opts) builds the fresh PageRuntime/form closures, and the
-- returned module table is then allowed to die. This keeps "a page only
-- exists while open" literal, which matters more than avoiding a tiny
-- re-parse while we are chasing page-exit RAM retention.
local function loadPage(path)
  package.loaded[path] = nil
  return assert(loadfile(path))()
end

local function canOpenEntry(entry, taskGuard)
  if not taskGuard then return true end
  if not taskGuard.isRunning() then return false end
  return entry.offline == true or taskGuard.isConnected()
end

local function entryGuardAllows(entry, menuGuard)
  if menuGuard and menuGuard.isEntryEnabled then
    return menuGuard.isEntryEnabled(entry) == true
  end
  return true
end

local function isEntryVisible(entry)
  if entry and entry.visibleWhen then
    return entry.visibleWhen() == true
  end
  return true
end

local function isEntryEnabled(entry, taskGuard, menuGuard)
  return canOpenEntry(entry, taskGuard) and entryGuardAllows(entry, menuGuard)
end

local function taskGuardExpired(taskGuard)
  return taskGuard and (not taskGuard.isRunning()) and taskGuard.graceExpired()
end

-- screen: nil = the root menu, otherwise a menuId key into `menus`.
local function openScreen(nav, menus, rootEntries, screen, setEventHandler, setWakeupHandler, setPaintHandler, setCleanupHandler, taskGuard)
  local title, entries, menuGuard
  if screen == nil then
    title, entries = "Rotorflight", rootEntries
  else
    local sub = menus[screen]
    title, entries = sub.title, sub.entries
    menuGuard = sub.guard
  end

-- DISPROVEN, DO NOT RE-ADD without new evidence: a prior version of this
  -- function forced collectgarbage("collect") right here on every
  -- menu-screen (re)build, on the theory that page-reload garbage was
  -- real but simply not being swept fast enough by the background task's
  -- own incremental collectgarbage() calls. A live A/B log disproved
  -- this cleanly: the SAME six-page navigation stretch (Advanced submenu,
  -- pidctrl->pidbandwidth->autolevel->mainrotor->tailrotor->rescue) leaked
  -- essentially the same amount per page with the forced full collect in
  -- place (+44.0/+39.2/+38.2/+61.9/+52.7/+37.1 KB) as without it
  -- (+55.6/+41.5/+37.1/+33.7/+52.1/+46.4 KB) -- statistically
  -- indistinguishable, and the session still ended higher overall (two
  -- tours run this time vs. one). A full, forced collectgarbage("collect")
  -- is a *complete* GC cycle -- if it cannot reclaim this memory, that
  -- memory is genuinely still reachable from a live reference, not
  -- garbage merely waiting to be swept, so calling it more often (here,
  -- on every navigation step instead of only at app.close()) was pure
  -- latency cost with zero benefit. Whatever is actually retaining this
  -- (a real Lua-side reference not yet found, despite lib/bus.lua,
  -- tasks/msp/queue.lua, and tasks/msp/common.lua all being read and
  -- ruled out already -- or, plausibly given growth scales with field/
  -- button count, something Ethos's own `form` widget system itself pins
  -- outside Lua's GC reachability graph entirely) needs to actually stop
  -- being created/retained in the first place; no amount of collecting
  -- can free a live reference. See AGENTS.md's "Memory stats printing"
  -- section for the full trace and current leading hypotheses.
  memstats.print("menu:" .. screenKey(screen))

  local function goBack()
    if menuGuard and menuGuard.close then menuGuard.close() end
    local hadFrame, parentScreen = nav.pop()
    if not hadFrame then
      system.exit()
      return
    end
    openScreen(nav, menus, rootEntries, parentScreen, setEventHandler, setWakeupHandler, setPaintHandler, setCleanupHandler, taskGuard)
  end

  if screen == nil then
    setEventHandler(nil)
  else
    setEventHandler(function(category, value)
      if not closeKey.shouldHandleClose(category, value) then return false end
      goBack()
      return true
    end)
  end
  -- Menu/tile screens never need a per-tick wakeup themselves -- only a
  -- leaf page opted into one (via opts.setWakeupHandler below) keeps it
  -- registered, so clear any leftover handler from whatever page was open
  -- before navigating here.
  setWakeupHandler(nil)
  if setPaintHandler then
    setPaintHandler(nil)
  end
  if setCleanupHandler then
    setCleanupHandler(nil)
  end
  if menuGuard and menuGuard.open then
    menuGuard.open()
  end

  local firstGroup = nil
  for i = 1, #entries do
    if isEntryVisible(entries[i]) then
      firstGroup = entries[i].group
      break
    end
  end

  form.clear()
  local headerHandle = header.build(firstGroup or title, {onBack = goBack})

  -- At least 1 even on an implausibly narrow screen -- a numPerRow of 0
  -- would divide-by-zero-equivalent (infinite tiles on one "row") below.
  local windowWidth, windowHeight = lcd.getWindowSize()
  local numPerRow, tileW, tileH, tilePadding, tileFont = tileGrid.metrics(windowWidth, windowHeight)

  -- form.height() reflects the header line's actual rendered height, so
  -- the tile grid starts right below it regardless of the radio's line
  -- height -- no hardcoded offset to get wrong.
  local x, y = 0, form.height() + tilePadding
  local lastGroup = firstGroup
  local col = 0
  local key = screenKey(screen)
  local tileButtons = {}
  for i, entry in ipairs(entries) do
    if isEntryVisible(entry) and entry.group ~= lastGroup then
      lastGroup = entry.group
      if lastGroup then
        form.addLine(lastGroup)
        y = form.height() + tilePadding
      end
      x = 0
      col = 0
    end

    if isEntryVisible(entry) then
      -- Keep tile labels explicit; Ethos's default font clips long
      -- titles well before the tile's own width would require it.
      tileButtons[i] = form.addButton(nil, {x = x, y = y, w = tileW, h = tileH}, {
        text = entry.title,
        icon = entry.icon,
        options = tileFont,
        press = function()
          if not canOpenEntry(entry, taskGuard) then
            if taskGuard and (not taskGuard.isRunning()) and taskGuard.requestAlert then
              taskGuard.requestAlert()
            end
            return
          end
          if not entryGuardAllows(entry, menuGuard) then return end
          if menuGuard and menuGuard.close then menuGuard.close() end
          lastSelected[key] = i
          nav.push(screen)
          if entry.menuId then
            openScreen(nav, menus, rootEntries, entry.menuId, setEventHandler, setWakeupHandler, setPaintHandler, setCleanupHandler, taskGuard)
          elseif entry.script then
            local page = loadPage(entry.script)
            page.open({
              onBack = goBack,
              setEventHandler = setEventHandler,
              setWakeupHandler = setWakeupHandler,
              setPaintHandler = setPaintHandler,
              setCleanupHandler = setCleanupHandler,
            })
          end
        end,
      })

      col = col + 1
      if col >= numPerRow then
        col = 0
        x = 0
        y = y + tileH + tilePadding
      else
        x = x + tileW + tilePadding
      end
    end
  end

  -- Restore focus to whichever tile was pressed last time this screen was
  -- open (matches the original's own `prefs.menulastselected` + `:focus()`
  -- convention -- see the comment on `lastSelected` above), so Back
  -- returns a rotary/arrow-key user to the same spot they left. Nothing
  -- recorded yet (first-ever visit to this screen) falls back to
  -- focusing the header's Menu button, exactly like the original's own
  -- fallback when no tile is selected.
  local function focusEnabledTile()
    local selectedIndex = lastSelected[key]
    if selectedIndex and tileButtons[selectedIndex] and isEntryEnabled(entries[selectedIndex], taskGuard, menuGuard) then
      tileButtons[selectedIndex]:focus()
      return
    end
    for i = 1, #entries do
      local button = tileButtons[i]
      if button and isEntryEnabled(entries[i], taskGuard, menuGuard) then
        button:focus()
        return
      end
    end
    headerHandle.focusMenu()
  end

  focusEnabledTile()

  if taskGuard or menuGuard then
    local lastEnabled = {}
    local function updateMenuState()
      local guardChanged = false
      if menuGuard and menuGuard.wakeup then
        guardChanged = menuGuard.wakeup() == true
      end

      local selectedStillEnabled = false
      local changed = guardChanged
      local selectedIndex = lastSelected[key]
      for i = 1, #entries do
        local button = tileButtons[i]
        local enabled = isEntryEnabled(entries[i], taskGuard, menuGuard)
        if selectedIndex == i and enabled then selectedStillEnabled = true end
        if button and button.enable and enabled ~= lastEnabled[i] then
          lastEnabled[i] = enabled
          button:enable(enabled)
          changed = true
        end
      end

      if changed and not selectedStillEnabled then
        focusEnabledTile()
      end

      if taskGuardExpired(taskGuard) and taskGuard.requestAlert then
        taskGuard.requestAlert()
      end
    end
    updateMenuState()
    setWakeupHandler(updateMenuState)
  end
end

-- nav: an app/navigation.lua instance (owned by the caller).
-- rootEntries: this tool's top-level tile list, {title=, icon=, script=|menuId=}.
-- setEventHandler(fn|nil): installs the function app/tool.lua's
--   event() callback forwards physical-key events to.
-- setWakeupHandler(fn|nil): installs the function app/tool.lua's own
--   wakeup() callback forwards to -- see its comment for why a page needs
--   this distinct from the background task's wakeup.
-- setPaintHandler(fn|nil): installs the function app/tool.lua's own
--   paint() callback forwards to, for pages with custom drawing.
-- setCleanupHandler(fn|nil): installs a page-owned cleanup function that
--   app/tool.lua calls if Ethos closes the whole tool while a page is open.
-- menus: optional {menuId -> {title=, entries={...}}} for `menuId` entries.
function menu_container.openRoot(nav, rootEntries, setEventHandler, setWakeupHandler, setPaintHandler, setCleanupHandler, menus, taskGuard)
  openScreen(nav, menus or {}, rootEntries, nil, setEventHandler, setWakeupHandler, setPaintHandler, setCleanupHandler, taskGuard)
end

return menu_container

-- Standard page header: a title on the left, a permanent "Menu" (back)
-- button, and Save/Reload/Tool buttons for leaf pages -- shown as row one
-- on every screen (root menu, submenus, leaf pages alike), matching
-- rotorflight-lua-ethos-suite's persistent top-right nav-button row.
-- Left-to-right within the button cluster: Menu, Save, Reload, Tool
-- (matching that suite's own nav button order -- menu, save, reload,
-- tool, help; Help is left out since nothing implements a help-content
-- system yet).
--
-- Matches the original's actual behaviour, not just its look: Save/
-- Reload/Tool are always PRESENT on a leaf page's header (occupying
-- their slot) but individually ENABLED only if that specific page
-- provides a handler for them -- e.g. app/pages/pids.lua provides
-- onSave/onReload but no onTool, so its Tool button is visibly there but
-- disabled, same as the original's own pids.lua (which never defines
-- onToolMenu, and navButtons defaults tool=false unless a page opts in).
-- A screen that provides none of onSave/onReload/onTool (menu/tile
-- screens, see app/menu_container.lua) gets a Menu-only header instead --
-- matching the original forcing MENU_ONLY_NAV_BUTTONS on submenu/tile
-- screens.
--
-- Built entirely from the same proven idiom already used elsewhere in
-- this app (see app/pages/pids.lua's grid: form.addLine(label) +
-- form.getFieldSlots() + form.addButton(line, slot, {...})) rather than
-- the original suite's raw absolute-pixel form.addButton() math, which
-- depends on per-radio template constants (rfsuite.app.radio.*) this
-- rebuild doesn't have and isn't something to guess at without a live
-- render to check it against.
--
-- Self-caught gap, found live (the same one app/menu_container.lua's
-- tiles had, fixed there first): nav buttons used to build with
-- form.addTextButton(line, rect, text, press) -- deprecated in favor of
-- form.addButton, and with no font/options control at all, so Ethos
-- rendered them at its larger default font instead of the original's own
-- explicit FONT_S. addNavButton() below switches to form.addButton(line,
-- rect, {text=, options=FONT_S, press=}) -- the exact call shape
-- app/menu_container.lua's tile buttons already use successfully, not a
-- new unverified API.
--
-- Button slots are sized to fit their own label text, not "whatever's
-- left after the title" -- so each button is exactly the same width on
-- every screen regardless of how long that screen's title is. Padded
-- with a few extra spaces on each side so the slot comes out comfortably
-- larger than the bare glyphs (the padding is only a sizing hint passed
-- to getFieldSlots; the button itself still shows the plain label).
--
-- The title itself is a `form.addStaticText` overlay on a blank
-- `form.addLine("")`, not text baked into addLine's own title parameter --
-- matching the original suite's own app/lib/ui.lua setHeaderTitle(), which
-- does the same specifically so the title can be updated later via
-- `:value(...)` without rebuilding the row. app/pages/pids.lua uses this
-- for the "PIDs #<profile>" suffix, updated live on a profile-switch event
-- rather than requiring a full page reload just to change one line of
-- text.
--
-- Self-caught bug, found live (twice): the title rendered butted up
-- against the Menu button on every screen, including the main menu.
-- First guess was a missing LEFT alignment flag on addStaticText -- wrong,
-- passing LEFT changed nothing, which only makes sense if the box itself
-- is already shrink-wrapped to the text (so left- vs right-alignment
-- inside it is invisible). So the leading `0` entry in the
-- getFieldSlots() hint list does NOT mean "whatever's left of the full
-- line" once mixed with the other slots' content-fit string hints --
-- likely "whatever's left of some narrower reserved field region," not
-- the line's full width. Rather than guess further at that undocumented
-- interaction, buildTitleRect() below sidesteps it: it takes the y/h off
-- getFieldSlots()' own slot 1 (not in question) and overrides x/w itself
-- using slot 2's x as the right boundary -- i.e. "start at the true left
-- edge, end exactly where the first button begins" -- which only depends
-- on the button slots, already confirmed correctly positioned.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- every page reloads this file fresh via loadfile() on every open, but
-- header.build() takes all its state as fresh call arguments and returns
-- fresh closures each time, so there's nothing page-specific baked in at
-- module level; re-parsing/re-executing this chunk on every navigation
-- was pure waste. One of several such caches added after a live memory
-- investigation confirmed the *bulk* of this rebuild's observed RAM
-- growth is an Ethos platform trait (the `form` widget system itself
-- retaining something per created button/field, outside Lua's own GC
-- reachability -- confirmed by checking that rotorflight-lua-ethos-suite
-- shows the same symptom) that no script-side change can eliminate --
-- but redundant reloading of stateless shared modules like this one is a
-- separate, real, avoidable cost. See AGENTS.md's "Memory stats
-- printing" section for the full trace.
if package.loaded["rfsuite.app.header"] then
  return package.loaded["rfsuite.app.header"]
end

local header = {}
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local themeBridge = requireModule("app/theme_bridge.lua")

-- i18n tags (the "@i18n(KEY)" + "@" syntax, split here so this comment
-- itself doesn't get matched and flagged unresolved by the resolver
-- below) are replaced by a build-time text substitution -- see
-- .vscode/scripts/resolve_i18n_tags.py -- not at Lua runtime, so every
-- occurrence of the same tag string resolves to the same text. Storing
-- each label once and reusing it for both the button's actual text and
-- its sizingHint() width calculation guarantees they can never drift out
-- of sync with each other, even once a translation's word length differs
-- from English's. Wording matches rotorflight-lua-ethos-suite's own nav
-- button labels exactly (all-caps SAVE/RELOAD/BACK, not this rebuild's
-- earlier Save/Reload/Menu).
local MENU_LABEL = "@i18n(app.navigation_menu)@"
local SAVE_LABEL = "@i18n(app.navigation_save)@"
local RELOAD_LABEL = "@i18n(app.navigation_reload)@"
local TOOL_LABEL = "@i18n(app.navigation_tools)@"

local function sizingHint(label)
  return "   " .. label .. "   "
end

local function noop() end

-- See the header comment above: form.addButton() with an explicit
-- options=FONT_S, not the deprecated, font-less form.addTextButton().
-- CENTERED added on top so the label sits centered within the button
-- box rather than at whatever form.addButton's own default alignment
-- is -- flags combine with `+` the same way lcd.drawText's do.
local function addNavButton(line, rect, label, press)
  return form.addButton(line, rect, {
    text = label,
    options = FONT_S + CENTERED,
    press = press,
  })
end

-- See the header comment above: overrides the ambiguous flex-width slot 1
-- with an explicit rect spanning the true left edge of the line through to
-- exactly where the first button (slot 2) starts.
local function buildTitleRect(slots)
  return {x = 0, y = slots[1].y, w = slots[2].x, h = slots[1].h}
end

-- opts: {
--   onBack = function() ... end,   -- required; the permanent "Menu" button
--   onSave = function() ... end,   -- optional; enables the "Save" button
--   onReload = function() ... end, -- optional; enables the "Reload" button
--   onTool = function() ... end,   -- optional; enables the "Tool" button
-- }
-- Returns {setTitle = fn(text), setSaveEnabled = fn(enabled),
-- setReloadEnabled = fn(enabled), focusMenu = fn(), focusSave = fn(),
-- focusReload = fn(), focusTool = fn()}.
-- Each focus* re-focuses that specific button -- Ethos has a bug where a
-- form loses focus entirely once a form.openProgressDialog closes, so
-- callers should call the appropriate one right after closing one (see
-- app/pages/pids.lua's closeDialog()): whichever button the pilot
-- actually pressed to trigger that dialog, or focusMenu() as the fallback
-- when nothing specific pressed it (e.g. the page's initial load).
function header.build(title, opts)
  themeBridge.clearPage()
  local line = form.addLine("")

  local isLeafPage = (opts.onSave ~= nil) or (opts.onReload ~= nil) or (opts.onTool ~= nil)

  if not isLeafPage then
    local slots = form.getFieldSlots(line, {0, sizingHint(MENU_LABEL)})
    local titleRect = buildTitleRect(slots)
    local titleField = form.addStaticText(line, titleRect, title, LEFT)
    themeBridge.registerHeaderRect(titleRect)
    themeBridge.styleStaticText(titleField, "accent")
    local menuButton = addNavButton(line, slots[2], MENU_LABEL, opts.onBack)
    themeBridge.registerNavigationRect(slots[2], "menu")
    return {
      setTitle = function(newTitle) titleField:value(newTitle) end,
      setSaveEnabled = noop,
      setReloadEnabled = noop,
      focusMenu = function() menuButton:focus() end,
      focusSave = noop,
      focusReload = noop,
      focusTool = noop,
    }
  end

  -- Tool is deliberately compact, matching the original's own label for
  -- this button ("*", i18n key app.navigation_tools) -- a single
  -- character sizes to roughly half the width of a word-length button
  -- for free, through the same content-fit slot sizing every other
  -- button uses.
  local slots = form.getFieldSlots(line, {
    0, sizingHint(MENU_LABEL), sizingHint(SAVE_LABEL), sizingHint(RELOAD_LABEL), sizingHint(TOOL_LABEL),
  })

  local titleRect = buildTitleRect(slots)
  local titleField = form.addStaticText(line, titleRect, title, LEFT)
  themeBridge.registerHeaderRect(titleRect)
  themeBridge.styleStaticText(titleField, "accent")
  local menuButton = addNavButton(line, slots[2], MENU_LABEL, opts.onBack)
  themeBridge.registerNavigationRect(slots[2], "menu")

  local saveButton = addNavButton(line, slots[3], SAVE_LABEL, opts.onSave or noop)
  themeBridge.registerNavigationRect(slots[3], "save")
  saveButton:enable(opts.onSave ~= nil)

  local reloadButton = addNavButton(line, slots[4], RELOAD_LABEL, opts.onReload or noop)
  themeBridge.registerNavigationRect(slots[4], "reload")
  reloadButton:enable(opts.onReload ~= nil)

  local toolButton = addNavButton(line, slots[5], TOOL_LABEL, opts.onTool or noop)
  themeBridge.registerNavigationRect(slots[5], "tool")
  toolButton:enable(opts.onTool ~= nil)

  return {
    setTitle = function(newTitle) titleField:value(newTitle) end,
    setSaveEnabled = function(enabled)
      saveButton:enable(opts.onSave ~= nil and enabled)
    end,
    setReloadEnabled = function(enabled)
      reloadButton:enable(opts.onReload ~= nil and enabled)
    end,
    focusMenu = function() menuButton:focus() end,
    focusSave = function() saveButton:focus() end,
    focusReload = function() reloadButton:focus() end,
    focusTool = function() toolButton:focus() end,
  }
end

package.loaded["rfsuite.app.header"] = header
return header

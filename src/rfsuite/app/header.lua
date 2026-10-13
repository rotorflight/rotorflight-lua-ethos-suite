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
-- The nav buttons are icon-only: form.addButton(line, rect, {icon=mask,
-- press=}) with no `text`, which Ethos draws as the mask centered in the
-- button and recolours for the focused and disabled states the same way it
-- does a label. Icons instead of the old SAVE/RELOAD/BACK words keep the
-- buttons narrow, so the title keeps more of the row on a 480x320 radio,
-- and need no translation. Checked in the simulator on X20 (800x480) and
-- X18 (480x320): one 32x32 mask set fits both button heights.
--
-- Every button slot is sized from the same fixed hint, not "whatever's
-- left after the title" -- so each button is exactly the same width on
-- every screen regardless of how long that screen's title is. The hint is
-- only passed to getFieldSlots for sizing; it is never drawn.
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
--
-- A title wider than that rect is cut at the first button, mid-word: most
-- page titles are "Section / Group / Page" breadcrumbs, and on a 480x320
-- radio the leaf header leaves the title about 178px. fitTitle() below
-- drops leading breadcrumb levels first ("... / Audio / ESC temp", then
-- "... / ESC temp", then "ESC temp" alone), because the page's own name is
-- the part the pilot needs; only if that still does not fit is the name
-- itself cut with an ellipsis.

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

-- Loaded once per module lifetime (this file self-caches above), so
-- building a header on every page open costs no mask loads.
local MENU_ICON = lcd.loadMask("app/gfx/nav/back.png")
local SAVE_ICON = lcd.loadMask("app/gfx/nav/save.png")
local RELOAD_ICON = lcd.loadMask("app/gfx/nav/reload.png")
local TOOL_ICON = lcd.loadMask("app/gfx/nav/tool.png")

-- Width hint for every icon button slot (see the header comment above).
local SLOT_HINT = "  WWW  "

local function noop() end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local tileGrid = requireModule("app/tile_grid.lua")

-- The static text's own font (form.addStaticText takes no font option).
local TITLE_FONT = FONT_STD
local ELLIPSIS = "..."
local SEPARATOR = " / "

local function textWidth(text)
  return lcd.getTextSize(text)
end

-- See the header comment above. Runs when a header is built or its title
-- changes, never from wakeup or paint.
local function fitTitle(title, maxW)
  if type(title) ~= "string" or not (lcd and lcd.getTextSize and lcd.font) then return title end
  lcd.font(TITLE_FONT)
  if textWidth(title) <= maxW then return title end
  local rest = title
  while true do
    local cut = rest:find(SEPARATOR, 1, true)
    if not cut then break end
    rest = rest:sub(cut + #SEPARATOR)
    local candidate = ELLIPSIS .. SEPARATOR .. rest
    if textWidth(candidate) <= maxW then return candidate end
  end
  return tileGrid.fitText(rest, maxW, TITLE_FONT)
end

-- Non-blocking footer banner. A short message drawn over the bottom edge of
-- the screen for a couple of seconds, in place of a modal form.openDialog()
-- that seizes the whole form and waits for an OK press. #2303: the "the flight
-- controller did not commit your save while armed" case is not a failure the
-- pilot has to acknowledge -- the per-page MSP_SET_* writes landed and the FC
-- commits them on disarm -- so it must not interrupt flying.
--
-- Drawn from a paint handler (the way the dashboard's own footer alerts are,
-- widgets/dashboard.lua's drawFooterBanner()) rather than built as a form
-- line. A form line would reserve a row for the whole life of the page even
-- though the banner is up for two seconds, and a 480x320 radio cannot spare a
-- row for a message that is usually not there.
local BANNER_SECONDS = 2.5

local function drawBanner(text)
  local w, h = lcd.getWindowSize()
  lcd.font(w <= 640 and FONT_XS or FONT_S)
  local _, textH = lcd.getTextSize(text)
  local pad = (w <= 640) and 8 or 12
  local bannerH = textH + pad
  local bannerY = h - bannerH
  lcd.color(lcd.RGB(180, 20, 20, 1))
  lcd.drawFilledRectangle(0, bannerY, w, bannerH)
  lcd.color(lcd.RGB(255, 255, 255, 1))
  lcd.drawText(w * 0.5, bannerY + (bannerH - textH) * 0.5, text, CENTERED)
end

-- One banner per header, shared by both header shapes (Menu-only and the
-- leaf-page row) so neither duplicates the timing/haptic body. The caller
-- drives it from its own paint and wakeup handlers: paint() draws while the
-- window is open, update() is the wakeup tick that closes it and reports the
-- transition so the caller can invalidate one last time (a radio does not
-- repaint on its own when a timer elapses).
local function newBanner()
  local text, expiresAt = nil, 0

  local function show(newText)
    if not newText or newText == "" then return end
    text = newText
    expiresAt = os.clock() + BANNER_SECONDS
    if system and system.playHaptic then system.playHaptic(". . . .") end
  end

  local function update()
    if text and os.clock() >= expiresAt then
      text = nil
      return true
    end
    return false
  end

  local function paint()
    if text then drawBanner(text) end
  end

  return show, update, paint
end

-- See the header comment above: an icon-only form.addButton().
local function addNavButton(line, rect, icon, press)
  return form.addButton(line, rect, {
    icon = icon,
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
-- focusReload = fn(), focusTool = fn(), showBanner = fn(text),
-- updateBanner = fn() -> bool, paintBanner = fn()}.
-- Each focus* re-focuses that specific button -- Ethos has a bug where a
-- form loses focus entirely once a form.openProgressDialog closes, so
-- callers should call the appropriate one right after closing one (see
-- app/pages/pids.lua's closeDialog()): whichever button the pilot
-- actually pressed to trigger that dialog, or focusMenu() as the fallback
-- when nothing specific pressed it (e.g. the page's initial load).
-- showBanner(text) raises the transient non-blocking footer banner (see its
-- own comment above); a caller with a paint/wakeup tick calls paintBanner()
-- from paint and updateBanner() from wakeup, the latter returning true once as
-- the banner expires so the caller can lcd.invalidate() for the clearing frame.
function header.build(title, opts)
  local line = form.addLine("")
  local showBanner, updateBanner, paintBanner = newBanner()

  local isLeafPage = (opts.onSave ~= nil) or (opts.onReload ~= nil) or (opts.onTool ~= nil)

  if not isLeafPage then
    local slots = form.getFieldSlots(line, {0, SLOT_HINT})
    local titleRect = buildTitleRect(slots)
    local titleField = form.addStaticText(line, titleRect, fitTitle(title, titleRect.w), LEFT)
    local menuButton = addNavButton(line, slots[2], MENU_ICON, opts.onBack)
    return {
      setTitle = function(newTitle) titleField:value(fitTitle(newTitle, titleRect.w)) end,
      setSaveEnabled = noop,
      setReloadEnabled = noop,
      focusMenu = function() menuButton:focus() end,
      focusSave = noop,
      focusReload = noop,
      focusTool = noop,
      showBanner = showBanner,
      updateBanner = updateBanner,
      paintBanner = paintBanner,
    }
  end

  local slots = form.getFieldSlots(line, {0, SLOT_HINT, SLOT_HINT, SLOT_HINT, SLOT_HINT})

  local titleRect = buildTitleRect(slots)
  local titleField = form.addStaticText(line, titleRect, fitTitle(title, titleRect.w), LEFT)
  local menuButton = addNavButton(line, slots[2], MENU_ICON, opts.onBack)

  local saveButton = addNavButton(line, slots[3], SAVE_ICON, opts.onSave or noop)
  saveButton:enable(opts.onSave ~= nil)

  local reloadButton = addNavButton(line, slots[4], RELOAD_ICON, opts.onReload or noop)
  reloadButton:enable(opts.onReload ~= nil)

  local toolButton = addNavButton(line, slots[5], TOOL_ICON, opts.onTool or noop)
  toolButton:enable(opts.onTool ~= nil)

  return {
    setTitle = function(newTitle) titleField:value(fitTitle(newTitle, titleRect.w)) end,
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
    showBanner = showBanner,
    updateBanner = updateBanner,
    paintBanner = paintBanner,
  }
end

package.loaded["rfsuite.app.header"] = header
return header

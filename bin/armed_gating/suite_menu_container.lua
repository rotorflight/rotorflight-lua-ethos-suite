-- Standalone behaviour tests for Issue #2302 menu tile badging / gating.
--
-- Run (through bin/armed_gating/verify_armed_gating.lua): lua5.4 bin/armed_gating/verify_armed_gating.lua
--
-- Loads the REAL app/menu_container.lua and the REAL app/tile_grid.lua
-- under a stubbed form/lcd/system, so the badge text, the press refusal and
-- the arm/disarm rebuild are exercised as written rather than described.
-- app/header.lua is stubbed (its setTitle is what the notice drives) but
-- records every title it is given, so the flash and its restore are checked.

local ROOT = arg and arg[1] or "."
package.path = ROOT .. "/src/?.lua;" .. package.path

local passed, failed = 0, 0
local failures = {}
local function check(name, cond, detail)
  if cond then passed = passed + 1
  else
    failed = failed + 1
    failures[#failures + 1] = name .. (detail and (" -- " .. tostring(detail)) or "")
  end
end
local function eq(name, a, b)
  check(name, a == b, string.format("expected %s, got %s", tostring(b), tostring(a)))
end

-- 6 px per character. Picked so a short label fits a tile and a long one
-- does not, which forces tile_grid's ellipsis path to run.
local CHAR_W = 6

--------------------------------------------------------------------
-- Recorded state (single declaration each -- duplicate locals here would
-- silently split the closures that reset() and registerPage() capture)
--------------------------------------------------------------------

local haptics = {}
local exitCalls = 0
local headerTitles = {}
local buttons = {}
local pushCount = 0
local openedPages = {}
local lineCount = 0
local wakeupHandler = nil

--------------------------------------------------------------------
-- Stubs
--------------------------------------------------------------------

local function headerStub()
  return {
    build = function(title, opts)
      headerTitles = {title}
      local handle = {opts = opts}
      -- menu_container calls setTitle with a dot and header.lua defines it
      -- as a single-argument closure, so the stub must take one argument
      -- too -- a two-parameter stub would swallow the title into a phantom
      -- parameter and every title write would silently vanish.
      handle.setTitle = function(t) headerTitles[#headerTitles + 1] = t end
      handle.focusMenu = function() end
      handle.focusSave = function() end
      handle.focusReload = function() end
      handle.focusTool = function() end
      handle.setSaveEnabled = function() end
      handle.setReloadEnabled = function() end
      return handle
    end,
  }
end

local formStub = {
  clear = function() buttons = {} end,
  height = function() return 20 + lineCount * 18 end,
  addLine = function() lineCount = lineCount + 1 return {} end,
  addButton = function(_, rect, opts)
    local b = {rect = rect, text = opts.text, icon = opts.icon, press = opts.press, enabled = true}
    function b:enable(v) self.enabled = v end
    function b:focus() self.focused = true end
    buttons[#buttons + 1] = b
    return b
  end,
}

local lcdStub = {
  getWindowSize = function() return 800, 480 end,
  loadMask = function() return {} end,
  getTextSize = function(t) return #t * CHAR_W end,
  font = function() end,
}

local systemStub = {
  playHaptic = function(p) haptics[#haptics + 1] = p end,
  exit = function() exitCalls = exitCalls + 1 end,
  getVersion = function() return {simulation = true} end,
}

-- menu_container's loadPage() does `package.loaded[path] = nil` and then
-- loadfile()s the path on every visit -- leaf pages are deliberately never
-- cached (see its own comment). Fake pages therefore have to be served from
-- loadfile; parking them in package.loaded would be wiped on first use.
local pageRegistry = {}
local function registerPage(path)
  pageRegistry[path] = function()
    return {open = function() openedPages[#openedPages + 1] = path end}
  end
end
registerPage("app/pages/long.lua")
registerPage("app/pages/short.lua")

local globals = {
  form = formStub, lcd = lcdStub, system = systemStub,
  package = package, os = os, math = math, string = string, table = table,
  io = io, tonumber = tonumber, tostring = tostring, type = type,
  pcall = pcall, pairs = pairs, ipairs = ipairs, print = print,
  assert = assert, setmetatable = setmetatable, getmetatable = getmetatable,
  rawget = rawget, rawset = rawset, unpack = table.unpack, error = error,
  loadfile = function(path) return pageRegistry[path] end,
}

local stubIndex
local stubTable
stubIndex = {
  __index = function(t, k)
    local fn = function() return stubTable() end
    rawset(t, k, fn)
    return fn
  end,
}
stubTable = function() return setmetatable({}, stubIndex) end

-- __index consults the real globals first and only then falls back to an
-- auto-stub. A chunk loaded with a custom env resolves BARE names (package,
-- form, lcd) against the env itself -- _G is only the value the chunk's own
-- _G upvalue points at -- so the globals have to hang off the env directly.
local env = setmetatable({_G = globals}, {__index = function(t, k)
  local v = globals[k]
  if v ~= nil then return v end
  local fn = function() return stubTable() end
  rawset(t, k, fn)
  return fn
end})

-- The REAL tile_grid, but under the same stub env: its fitText() early-returns
-- the text unchanged when `lcd.getTextSize` is absent, so loading it under
-- the global env would silently disable the very truncation the badge has to
-- survive and the budget assertion below would pass vacuously.
local realTileGrid = assert(loadfile(ROOT .. "/src/rfsuite/app/tile_grid.lua", "t", env))()
local realHeader = headerStub()

local moduleStubs = {}
local function stubModule(path)
  if path == "app/tile_grid.lua" then return realTileGrid end
  if path == "app/header.lua" then return realHeader end
  if path == "app/close_key.lua" then return {shouldHandleClose = function() return true end} end
  if path == "lib/memstats.lua" then return {print = function() end} end
  if not moduleStubs[path] then moduleStubs[path] = setmetatable({}, stubIndex) end
  return moduleStubs[path]
end
package.loaded["rfsuite.lib.require"] = stubModule

local menuContainer = assert(loadfile(ROOT .. "/src/rfsuite/app/menu_container.lua", "t", env))()
check("menu_container loads under stubs", type(menuContainer.openRoot) == "function")

--------------------------------------------------------------------
-- Harness
--------------------------------------------------------------------

local armed = false
local function armedState() return armed end

local taskGuard = {isRunning = function() return true end, isConnected = function() return true end}

local nav = {
  -- Counted, not appended: nav.push(screen) is called with screen == nil at
  -- the root menu, and `t[#t + 1] = nil` would silently grow nothing.
  push = function() pushCount = pushCount + 1 end,
  pop = function() return false, nil end,
  clear = function() end,
}

local LONG = "Extremely long configuration label"
local SHORT = "PIDs"
local ROOT_TITLE = "Rotorflight"

local function reset()
  buttons = {}; pushCount = 0; openedPages = {}; headerTitles = {}
  haptics = {}; exitCalls = 0; lineCount = 0; wakeupHandler = nil
end

local function build(entries, guard)
  reset()
  menuContainer.openRoot(nav, entries,
    function() end,
    function(h) wakeupHandler = h end,
    function() end,
    function() end,
    {}, guard, armedState)
end

local function twoTiles()
  return {
    {title = LONG, script = "app/pages/long.lua", lockedWhileArmed = true},
    {title = SHORT, script = "app/pages/short.lua"},
  }
end

--------------------------------------------------------------------
-- 1. Disarmed: no badge, navigation works
--------------------------------------------------------------------

build(twoTiles(), taskGuard)
eq("disarmed: two tiles built", #buttons, 2)
check("disarmed: locked tile carries no badge", buttons[1].text:sub(1, 1) ~= "!", buttons[1].text)
buttons[1].press()
eq("disarmed: press navigates", pushCount, 1)
eq("disarmed: press opens the page", openedPages[1], "app/pages/long.lua")
eq("disarmed: no haptic", #haptics, 0)

--------------------------------------------------------------------
-- 2. Armed: a locked tile is disabled, shows the forbidden icon, and does nothing
--------------------------------------------------------------------

armed = true
build(twoTiles(), taskGuard)
eq("armed: two tiles built", #buttons, 2)
check("armed: locked tile carries no badge", buttons[1].text:sub(1, 1) ~= "!", buttons[1].text)
check("armed: locked tile is disabled", buttons[1].enabled == false)
check("armed: unlocked tile stays enabled", buttons[2].enabled == true)
check("armed: locked tile shows the forbidden icon", buttons[1].icon ~= nil and buttons[1].icon ~= buttons[2].icon)
local armedIcon = buttons[1].icon

-- A disabled tile must not open its page, buzz or change the header. The press
-- handler is kept as a silent guard for the case Ethos delivers it anyway.
buttons[1].press()
eq("armed: press on a disabled tile does not navigate", pushCount, 0)
eq("armed: press on a disabled tile does not open the page", #openedPages, 0)
eq("armed: press on a disabled tile does not buzz", #haptics, 0)
eq("armed: header title is unchanged", headerTitles[#headerTitles], ROOT_TITLE)

-- An unlocked tile must still work while armed.
buttons[2].press()
eq("armed: unlocked tile still navigates", pushCount, 1)
eq("armed: unlocked tile opens its page", openedPages[1], "app/pages/short.lua")

--------------------------------------------------------------------
-- 4. Arm/disarm transition rebuilds the grid
--------------------------------------------------------------------

armed = false
if wakeupHandler then wakeupHandler() end
check("disarm: grid rebuilt", #buttons > 0)
check("disarm: locked tile enabled again", buttons[1].enabled == true)
check("disarm: forbidden icon gone", buttons[1].icon ~= armedIcon)
buttons[1].press()
eq("disarm: press navigates again", pushCount, 2)

armed = true
if wakeupHandler then wakeupHandler() end
check("re-arm: locked tile disabled again", buttons[1].enabled == false)

--------------------------------------------------------------------
-- 5. Wakeup handler installation
--------------------------------------------------------------------

-- A screen with a gated entry MUST install one, or the badge could never
-- appear or disappear without the pilot navigating away and back.
build(twoTiles(), nil)
check("gated entry, no taskGuard: wakeup handler installed", type(wakeupHandler) == "function")

-- A screen with nothing gated and no guard must install none -- that is the
-- pre-existing "only poll when something needs polling" behaviour, and
-- #2302 must not make every static screen pay a wakeup.
build({{title = SHORT, script = "app/pages/short.lua"}}, nil)
eq("no gated entries, no taskGuard: no wakeup handler", wakeupHandler, nil)

-- ...but a container that is itself open while its CHILDREN are gated still
-- has to poll: its badges live one level down, and without a handler they
-- would never appear. This is the Setup-menu shape (open itself, gated
-- children) and the reason screenHasArmedGating walks submenus.
local menus = {
  container = {entries = {
    {title = "gated child", script = "app/pages/short.lua", lockedWhileArmed = true},
  }},
}
reset()
menuContainer.openRoot(nav, {{title = "Container", menuId = "container"}},
  function() end, function(h) wakeupHandler = h end,
  function() end, function() end, menus, nil, armedState)
check("open container with gated children: wakeup handler installed",
      type(wakeupHandler) == "function")

--------------------------------------------------------------------
-- 6. No armedState at all -> gating is inert, not broken
--------------------------------------------------------------------

-- Omitting armedState entirely must leave gating inert rather than broken:
-- every tile stays unbadged and every press still navigates.
reset()
menuContainer.openRoot(nav, {{title = LONG, script = "app/pages/long.lua", lockedWhileArmed = true}},
  function() end, function(h) wakeupHandler = h end,
  function() end, function() end, {}, taskGuard, nil)check("no armedState: tile built", #buttons == 1)
check("no armedState: no badge", buttons[1].text:sub(1, 1) ~= "!", buttons[1].text)
buttons[1].press()
eq("no armedState: press still navigates", pushCount, 1)

--------------------------------------------------------------------
-- 7. The armed state disables locked tiles and swaps only their icon
--------------------------------------------------------------------

-- The tile keeps its title. While armed a locked tile gets the forbidden sign
-- instead of its module icon, and it is disabled. Disarmed, both come back.
do
  local marker = {moduleIcon = true}
  local entries = {
    {title = SHORT, script = "app/pages/long.lua", lockedWhileArmed = true, icon = marker},
    {title = SHORT, script = "app/pages/short.lua", icon = marker},
  }

  armed = false
  build(entries, taskGuard)
  check("disarmed: locked tile keeps its own icon", buttons[1].icon == marker)
  check("disarmed: locked tile is enabled", buttons[1].enabled == true)

  armed = true
  build(entries, taskGuard)
  check("armed: locked tile no longer has its own icon", buttons[1].icon ~= marker)
  check("armed: unlocked tile keeps its icon", buttons[2].icon == marker)
  check("armed: the label is the plain title", buttons[1].text == buttons[2].text,
        string.format("%q vs %q", buttons[1].text, buttons[2].text))
end

--------------------------------------------------------------------
-- Result
--------------------------------------------------------------------

print(string.format("passed: %d   failed: %d", passed, failed))
if failed > 0 then
  for i = 1, #failures do print("  FAIL  " .. failures[i]) end
  os.exit(1)
end
os.exit(0)

-- Behaviour check for the physical Back/Close key at the ROOT menu (#2429).
--
-- Run it:
--     lua5.4 bin/tool_ui/verify_root_close_key.lua
--     lua5.4 bin/tool_ui/verify_root_close_key.lua --self-test
--
-- What it drives, and why:
--   * The real src/rfsuite/app/tool.lua, so the chain under test is the whole
--     one a radio runs: system.registerSystemTool -> create() -> event(), with
--     the real app/menu_container.lua, app/navigation.lua, app/header.lua,
--     app/tile_grid.lua and app/close_key.lua behind it. Nothing here reaches
--     into menu_container to call openRoot() directly -- tool.lua's forwarding
--     is part of what is being pinned, so the harness goes through it rather
--     than around it.
--   * The background task and the link are announced over the REAL bus, not
--     stubbed, exactly as bin/tool_ui/verify_no_extra_msp.lua does: without
--     both, taskGuard.isRunning() is false, every root tile is disabled, and
--     there is no submenu to press into -- the guarded path would go untested.
--
-- The defect:
--   menu_container.lua installed a close handler on every screen EXCEPT the
--   root, where it called setEventHandler(nil) and let the physical RTN fall
--   through to Ethos's own default. That default needs two presses -- the
--   first drops the form's input focus, the second closes -- while the
--   on-screen Menu button reached goBack() directly in one. Two ways out of one
--   screen, and they disagreed. Every case marked ROOT below goes red on the
--   pre-fix file; --self-test proves that rather than asserting it.
--
-- What is NOT settled here, deliberately:
--   Whether a short RTN is merely *visually* de-selected by the form layer or
--   actually consumed before the tool's event() sees it. Nothing in this
--   repository can decide that -- it is Ethos's own dispatch order, and the
--   issue records it as unverified. So this harness pins what the SUITE owes
--   Ethos: a handler on every screen, RTN routed through the same goBack() as
--   the back button, and no false positives on keys that are not close keys.
--   It says nothing about whether one radio keypress is then enough. The
--   second half of #2429 -- the "where was I" tile marker currently being an
--   input focus (menu_container.lua's focusEnabledTile) rather than a paint --
--   is a separate change and is deliberately not touched here.

local SELF_TEST = false
local VERBOSE = false
for _, arg in ipairs(arg or {}) do
  if arg == "--self-test" then SELF_TEST = true end
  if arg == "--verbose" then VERBOSE = true end
end

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0
local failedLabels = {}

-- The real print, held in a local BEFORE _G.print is replaced below.
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
    return true
  end
  failures = failures + 1
  failedLabels[label] = true
  out(string.format("  FAIL  %s", label))
  if detail then out("        " .. tostring(detail)) end
  return false
end

-- ---------------------------------------------------------------------------
-- Ethos stubs
-- ---------------------------------------------------------------------------
package.path = SUITE .. "/?.lua;" .. package.path

-- The suite resolves its own modules through EAGERLY built paths that carry no
-- directory part (tool.lua calls loadfile("lib/require.lua")). On the radio the
-- working directory is the root script's path; this prefix gives the harness the
-- same route. Same pattern as bin/tool_ui/verify_tool_ui_lazy.lua.
local LOCAL_PREFIX = SUITE .. "/"

-- Set by the self-test: the module path the redirect matches on, and the file to
-- serve instead of it. Two separate values on purpose -- they are different
-- files, and one variable used for both loads the REAL file while reporting a
-- hit, which is indistinguishable from a sabotage that did not work.
local REPLACE_MATCH = nil
local REPLACE_FILE = nil
local replaceHits = 0

local realLoadfile = loadfile

_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (LOCAL_PREFIX .. path)
    if REPLACE_MATCH and absolute == REPLACE_MATCH then
      replaceHits = replaceHits + 1
      return realLoadfile(REPLACE_FILE, ...)
    end
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

-- system.exit() is the observable this whole file is about: goBack() calls it
-- when there is nothing left to pop. Counting it is how "one press closed the
-- suite" is told apart from "one press did nothing".
local exitCalls = 0

local registeredTool = nil
_G.system = {
  getVersion = function() return {simulation = false, radio = {name = "stub"}} end,
  registerSystemTool = function(tool) registeredTool = tool return tool end,
  getMemoryUsage = function() return {} end,
  formatBytes = function(n) return tostring(n) end,
  exit = function() exitCalls = exitCalls + 1 end,
}

_G.lcd = {
  loadMask = function(p) return {path = p} end,
  loadImage = function(p) return {path = p} end,
  getWindowSize = function() return 480, 320 end,
  drawRectangle = function() end,
  drawText = function() end,
  drawBitmap = function() end,
  drawLine = function() end,
  setColor = function() end,
  setFgColor = function() end,
  setBgColor = function() end,
  font = function() return 1 end,
  color = function() end,
  text = function() end,
  box = function() end,
  line = function() end,
  circle = function() end,
  invalidate = function() end,
  getTextSize = function(t) return #t, 12 end,
  CONSOLE = {WHITE = 0, BLACK = 1, YELLOW = 2, GREEN = 3, BLUE = 4},
}
_G.model = {get = function() return 0 end, name = function() return "stub" end}
_G.os = os
_G.math = math
_G.string = string
_G.table = table

-- The suite prints through memstats on every menu build; a silent print stub is
-- installed so that is harmless. The real print was captured above.
_G.print = function() end

-- form: real widgets, not enough of them to render anything. What the chain
-- under test actually calls is addLine, getFieldSlots, addStaticText, addButton
-- (header and tiles), clear and height.
--
-- Every button records its options, so the harness can invoke the header's Menu
-- button and a tile's press() by hand. That is not a shortcut around the code
-- under test: on the radio those two closures are exactly what a touch and an
-- ENTER press run, so calling them is the same call -- and it is the only way
-- to compare "RTN" against "the back button" on one screen.
local buttons = {}

local function fieldStub(slot, opts)
  return {
    slot = slot,
    opts = opts or {},
    focus = function() end,
    enable = function() end,
    value = function() end,
    show = function() end,
    hide = function() end,
    default = function() end,
    suffix = function() end,
    help = function() end,
  }
end

local function slotList(n, width)
  width = width or 480
  local w = width / math.max(n, 1)
  local list = {}
  for i = 1, n do
    list[i] = {x = (i - 1) * w, y = 0, w = w, h = 30}
  end
  return list
end

_G.form = {
  addLine = function() return 1 end,
  clear = function() buttons = {} end,
  height = function() return 30 end,
  invalidate = function() end,
  getFieldSlots = function(_, hints)
    -- header.lua asks for 2 slots on a menu screen and 5 on a leaf page; follow
    -- the hints it passes rather than guessing a fixed count.
    return slotList(type(hints) == "table" and #hints or 6)
  end,
  addStaticText = function(_, rect) return fieldStub(rect) end,
  addTextButton = function(_, slot) return fieldStub(slot) end,
  addButton = function(_, slot, opts)
    buttons[#buttons + 1] = opts
    return fieldStub(slot, opts)
  end,
  openProgressDialog = function() return {close = function() end} end,
  openDialog = function() return {close = function() end} end,
  openWaitDialog = function() return {close = function() end} end,
}

-- Ethos globals the menu chain uses as values. header.lua computes
-- options = FONT_S + CENTERED, so they are numbers, not strings.
_G.TIME_LEFT = 1
_G.TEXT_LEFT = 2
_G.LEFT = 3
_G.CENTERED = 4
_G.RIGHT = 5
_G.TOP_LEFT = 6
_G.FONT_XS = 10
_G.FONT_S = 20
_G.FONT_M = 30
_G.FONT_L = 40
_G.FONT_XL = 50

-- Key events. Values are the ones the existing harnesses already pin, so this
-- file does not introduce a third numbering.
_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02
_G.EVT_EXIT_BREAK = 0x03
_G.EVT_KEY_DOWN_BREAK = 0x04
_G.KEY_ENTER_LONG = 0x05
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07

local EVT_TOUCH = 0x05
local KEY_MODEL_BREAK = 0x21

-- ---------------------------------------------------------------------------
-- the check sequence
-- ---------------------------------------------------------------------------
-- One function, run twice: once against the real menu_container.lua, and -- in
-- --self-test -- once against a copy with the pre-fix root branch put back. Both
-- runs execute identical code, so a difference in the outcome can only come from
-- the file under test.
local function runChecks()
  buttons = {}

  -- A fresh tool instance per run: the suite caches its modules in
  -- package.loaded, and the second run must not inherit the first run's
  -- menu_container.
  --
  -- Collected first, then cleared. Assigning nil to the key pairs() is currently
  -- visiting is undefined behaviour in Lua -- entries get skipped, silently --
  -- and a skipped clear looks exactly like a sabotage that did not work.
  local stale = {}
  for key in pairs(package.loaded) do
    if type(key) == "string" and key:match("^rfsuite%.") then stale[#stale + 1] = key end
  end
  for _, key in ipairs(stale) do package.loaded[key] = nil end
  if VERBOSE then
    out(string.format("  cleared %d rfsuite.* entries from package.loaded", #stale))
  end
  exitCalls = 0

  registeredTool = nil
  local tool = dofile(SUITE .. "/app/tool.lua")
  tool.init()
  if not check("init() registers a tool with an event() callback",
      type(registeredTool) == "table" and type(registeredTool.event) == "function") then
    return
  end

  -- The guards are announced over the real bus so that the root tiles are
  -- enabled and the path a pilot actually walks -- root tile, then submenu --
  -- is reachable.
  local bus = package.loaded["rfsuite.lib.bus"]
  if bus then
    bus.publish("task.status", {running = true, updatedAt = os.clock()})
    bus.publish("session.update", {connected = true, apiVersionSupported = true})
  end

  registeredTool.create()

  -- menu_container calls form.clear() on every screen build, so `buttons` always
  -- holds exactly one screen: its header Menu button first, then its tiles.
  local function headerButton() return buttons[1] end
  local function tileButtons()
    local tiles = {}
    for i = 2, #buttons do tiles[#tiles + 1] = buttons[i] end
    return tiles
  end

  local function fire(category, value)
    exitCalls = 0
    local handled = registeredTool.event(nil, category, value, 0, 0)
    return handled, exitCalls
  end

  out("")
  out("root menu: the physical close key must reach the suite's own goBack()")

  local handled, exits = fire(EVT_CLOSE, 0)
  check("ROOT: RTN as EVT_CLOSE is handled", handled == true,
    string.format("event() returned %s", tostring(handled)))
  check("ROOT: RTN as EVT_CLOSE closes the suite in one keypress", exits == 1,
    string.format("system.exit() called %d times, expected 1", exits))

  handled, exits = fire(EVT_KEY, KEY_RTN_BREAK)
  check("ROOT: RTN as EVT_KEY/KEY_RTN_BREAK is handled", handled == true,
    string.format("event() returned %s", tostring(handled)))
  check("ROOT: RTN as EVT_KEY/KEY_RTN_BREAK closes the suite in one keypress", exits == 1,
    string.format("system.exit() called %d times, expected 1", exits))

  handled, exits = fire(EVT_KEY, KEY_EXIT_BREAK)
  check("ROOT: EXIT as EVT_KEY/KEY_EXIT_BREAK is handled", handled == true,
    string.format("event() returned %s", tostring(handled)))
  check("ROOT: EXIT as EVT_KEY/KEY_EXIT_BREAK closes the suite in one keypress", exits == 1,
    string.format("system.exit() called %d times, expected 1", exits))

  out("")
  out("root menu: keys that are not close keys must be left alone")
  -- A false positive here is worse than the bug: swallowing ENTER would make a
  -- focused tile unactivatable, and swallowing a model key would break the
  -- radio.
  for _, case in ipairs({
    {label = "a long ENTER is left to Ethos", category = EVT_KEY, value = KEY_ENTER_LONG},
    {label = "a model key is passed through", category = EVT_KEY, value = KEY_MODEL_BREAK},
    {label = "a touch event is passed through", category = EVT_TOUCH, value = 0},
  }) do
    handled, exits = fire(case.category, case.value)
    check(case.label, handled == false and exits == 0,
      string.format("event() returned %s, system.exit() called %d times",
        tostring(handled), exits))
  end

  out("")
  out("root menu: RTN and the back button must be the same path")

  local menu = headerButton()
  check("the root screen built a header Menu button",
    menu ~= nil and type(menu.press) == "function",
    "buttons[1] carries no press()")

  if menu and menu.press then
    exitCalls = 0
    menu.press()
    check("pressing the back button closes the suite", exitCalls == 1,
      string.format("system.exit() called %d times, expected 1", exitCalls))
  end

  out("")
  out("submenu: RTN pops one level and stays in the suite")

  -- The first root tile is a submenu (tool.lua's ROOT_ENTRIES, "Flight Tuning"
  -- -> flight_tuning_menu), so pressing it is the real drill-down.
  local rootTiles = tileButtons()
  check("the root menu built tiles to press", #rootTiles > 0,
    string.format("found %d tiles", #rootTiles))

  if #rootTiles > 0 and rootTiles[1].press then
    exitCalls = 0
    rootTiles[1].press()
    check("pressing the first tile opens a submenu instead of exiting", exitCalls == 0,
      "system.exit() was called while drilling into a submenu")

    handled, exits = fire(EVT_KEY, KEY_RTN_BREAK)
    check("SUBMENU: RTN is handled", handled == true,
      string.format("event() returned %s", tostring(handled)))
    check("SUBMENU: RTN pops one level and does NOT close the suite", exits == 0,
      string.format("system.exit() called %d times, expected 0", exits))

    -- Back at the root the stack is empty again, so RTN has to close. That is
    -- the case that fails without the fix: the root installed no handler.
    handled, exits = fire(EVT_KEY, KEY_RTN_BREAK)
    check("ROOT: RTN back at the root closes the suite", handled == true and exits == 1,
      string.format("handled=%s, system.exit() called %d times",
        tostring(handled), exits))
  end
end

-- Labels that describe the root-screen close path, and therefore have to go red
-- when the pre-fix root branch is back. A label that stays green on the pre-fix
-- file is a check that cannot detect the defect it names.
local ROOT_CLOSE_LABELS = {
  "ROOT: RTN as EVT_CLOSE is handled",
  "ROOT: RTN as EVT_CLOSE closes the suite in one keypress",
  "ROOT: RTN as EVT_KEY/KEY_RTN_BREAK is handled",
  "ROOT: RTN as EVT_KEY/KEY_RTN_BREAK closes the suite in one keypress",
  "ROOT: EXIT as EVT_KEY/KEY_EXIT_BREAK is handled",
  "ROOT: EXIT as EVT_KEY/KEY_EXIT_BREAK closes the suite in one keypress",
  "ROOT: RTN back at the root closes the suite",
}

-- ---------------------------------------------------------------------------
-- pass 1: the real tree
-- ---------------------------------------------------------------------------
out("pass 1: the real app/menu_container.lua")
runChecks()

local pass1Checks, pass1Failures = checks, failures

-- ---------------------------------------------------------------------------
-- self-test: the same sequence against the pre-fix file
-- ---------------------------------------------------------------------------
if SELF_TEST then
  out("")
  out(string.rep("=", 60))
  out("self-test: the root close-key checks must go red without the fix")
  out(string.rep("=", 60))

  local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local content = f:read("*a")
    f:close()
    return content
  end

  local function writeFile(path, content)
    local f = assert(io.open(path, "wb"))
    f:write(content)
    f:close()
  end

  local source = readFile(SUITE .. "/app/menu_container.lua")
  -- core.autocrlf=true and no .gitattributes, so the checkout is CRLF. Detect
  -- rather than assume; a mismatch would make the plain find below miss.
  local nl = source:find("\r\n", 1, true) and "\r\n" or "\n"

  local FIXED = table.concat({
    "  setEventHandler(function(category, value)",
    "    if not closeKey.shouldHandleClose(category, value) then return false end",
    "    goBack()",
    "    return true",
    "  end)",
  }, nl)

  -- _G.__sabotageOpenScreen counts how often the sabotaged branch actually ran.
  -- If it stays 0 the redirect served the file but nothing used it, and pass 2
  -- would be pass 1 wearing a disguise.
  local PRE_FIX = table.concat({
    "  if screen == nil then",
    "    _G.__sabotageOpenScreen = (_G.__sabotageOpenScreen or 0) + 1",
    "    setEventHandler(nil)",
    "  else",
    "    _G.__sabotageOpenScreen = (_G.__sabotageOpenScreen or 0) + 1",
    "    setEventHandler(function(category, value)",
    "      if not closeKey.shouldHandleClose(category, value) then return false end",
    "      goBack()",
    "      return true",
    "    end)",
    "  end",
  }, nl)

  -- Plain find, not a pattern: the block contains '(' and ')', which are magic
  -- in a Lua pattern and silently change what matches.
  local first, last = source:find(FIXED, 1, true)
  if not first then
    out("  FAIL  could not locate the setEventHandler block in menu_container.lua")
    out("        the sabotage has to be updated when that call changes shape")
    os.exit(1)
  end

  local tmp = os.tmpname()
  local sabotaged = source:sub(1, first - 1) .. PRE_FIX .. source:sub(last + 1)
  writeFile(tmp, sabotaged)

  -- Read it straight back. A temp file that kept stale contents would make the
  -- whole self-test vacuous: every check would stay green for the wrong reason.
  do
    local probe = assert(io.open(tmp, "rb"))
    local readBack = probe:read("*a")
    probe:close()
    if readBack ~= sabotaged then
      out(string.format("  FAIL  the sabotage file does not read back (%d written, %d read)",
        #sabotaged, #readBack))
      os.exit(1)
    end
    out(string.format("  sabotage file: %d bytes, verified by read-back", #readBack))
  end

  REPLACE_MATCH = SUITE .. "/app/menu_container.lua"
  REPLACE_FILE = tmp

  checks, failures = 0, 0
  failedLabels = {}
  replaceHits = 0
  out("")
  out("pass 2: the same sequence against the pre-fix root branch")
  runChecks()

  os.remove(tmp)
  REPLACE_MATCH = nil
  REPLACE_FILE = nil

  local ran = _G.__sabotageOpenScreen or 0
  out(string.format("  (sabotaged chunk served %d time(s), its branch ran %d time(s))",
    replaceHits, ran))
  if replaceHits == 0 or ran == 0 then
    out("  FAIL  the sabotaged file never ran -- pass 2 proved nothing")
    os.exit(1)
  end

  out("")
  out("self-test verdict:")
  local wentRed = true
  for _, label in ipairs(ROOT_CLOSE_LABELS) do
    local red = failedLabels[label] == true
    if not red then wentRed = false end
    out(string.format("  %s  %s", red and "goes red " or "STAYS GREEN", label))
  end
  out("")
  if not wentRed then
    out("SELF-TEST FAILED -- at least one root close-key check cannot detect the defect")
    os.exit(1)
  end
  out("SELF-TEST PASSED -- every root close-key check goes red without the fix")
  out(string.format("pass 1 against the real tree: %d checks, %d failures",
    pass1Checks, pass1Failures))
end

-- The verdict below is pass 1's: without --self-test, pass 2 never ran, and with
-- it pass 2's red is the expected outcome rather than a failure of this tree.
checks, failures = pass1Checks, pass1Failures
out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

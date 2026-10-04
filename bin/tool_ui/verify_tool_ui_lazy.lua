-- Behaviour check for the load timing of the tool's UI subtree (#2421).
--
-- Run it:
--     lua5.4 bin/tool_ui/verify_tool_ui_lazy.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/tool.lua under an Ethos stub environment:
--     loadfile, bus, settings store, system.registerSystemTool and an
--     lcd.loadMask that costs nothing. The point is not to test the tool -- it
--     is to establish WHICH modules appear in package.loaded, and WHEN.
--   * This file resolves its module paths against src/rfsuite, not against src,
--     because that is what the suite itself does: main.lua:52 loads
--     "lib/require.lua" and lives in src/rfsuite/. Same pattern as
--     bin/storage/verify_atomic_writes.lua.
--
-- Four cases, each against a false expectation:
--   1. After loading tool.lua (init has not run yet) NONE of the tool's UI
--      subtree modules are in package.loaded.
--   2. After create() they are ALL there.
--   3. close() loads nothing that was not there before.
--   4. A second create() loads nothing again (requireModule caches).
--
-- Against the pre-change file case 1 must go RED -- there the requireModule
-- calls sit in column 1 and the modules are present immediately.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0

-- The real print, held in a local BEFORE _G.print is replaced below.
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
  else
    failures = failures + 1
    out(string.format("  FAIL  %s", label))
    if detail then out("        " .. tostring(detail)) end
  end
end

-- ── Ethos stubs ─────────────────────────────────────────────────────────────
local loadedInOrder = {}
local loadOrder = {}

package.path = SUITE .. "/?.lua;" .. package.path

-- The suite loads its modules through EAGERLY resolved paths that carry no
-- directory part: tool.lua:36 calls loadfile("lib/require.lua"), and
-- requireModule() inside it calls loadfile("lib/bus.lua"). On the radio the
-- working directory is the root script's path (src/rfsuite). The prefix below
-- gives this harness the same resolution route. It is in effect while the
-- traces run, but not in the module names that get counted.
local LOCAL_PREFIX = SUITE .. "/"
_G.PREFIX = LOCAL_PREFIX

local realLoadfile = loadfile

-- loadfile is what lib/require.lua calls; the redirect hooks in there.
-- The prefix turns the suite's own "lib/require.lua" into an absolute path --
-- identical for the load itself, but cleaned up again on evaluation so
-- countUnder() sees the real module paths.
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (LOCAL_PREFIX .. path)
    loadedInOrder[absolute] = (loadedInOrder[absolute] or 0) + 1
    loadOrder[#loadOrder + 1] = absolute
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

_G.package = package
_G.package.loaded = package.loaded

-- sys table: Ethos supplies it; the tool needs it for init().
local registeredTool = nil
_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
  registerSystemTool = function(tool) registeredTool = tool return tool end,
  getMemoryUsage = function() return {} end,
  formatBytes = function(n) return tostring(n) end,
}

-- lcd: loadMask is the most expensive thing in the real code (the bitmap
-- arena). Here it only counts calls, so that a failure does not hinge on it.
local maskCalls = 0
_G.lcd = {
  loadMask = function(p) maskCalls = maskCalls + 1; return { path = p } end,
  loadImage = function(p) return { path = p } end,
  getWindowSize = function() return 480, 320 end,
  drawRectangle = function() end,
  drawText = function() end,
  drawBitmap = function() end,
  setColor = function() end,
  setFgColor = function() end,
  setBgColor = function() end,
  font = function() return 1 end,
  color = function() end,
  text = function() end,
  box = function() end,
  line = function() end,
  circle = function() end,
  CONSOLE = { WHITE = 0, BLACK = 1, YELLOW = 2, GREEN = 3, BLUE = 4 },
}
_G.model = { get = function() return 0 end, name = function() return "stub" end }

-- The suite calls print() throughout, so a silent stub has to be installed --
-- and the real print was captured above, before this line, so that the stub
-- does not swallow this harness's own output. That happened once: the first
-- green run returned exit code 0 without a single line.
_G.print = function() end

-- form: the menu path builds real widgets. Here it only has to run through.
-- The actual form work is not part of this check; it is covered elsewhere
-- (bin/storage, bin/flight_record).
--
-- form.getFieldSlots(line, hints) returns a list of rectangles; header.lua:131
-- reads slots[1].y, slots[2].x and slots[1].h from it. A numeric return value
-- would abort this harness at that point -- the schema is tested here, not
-- guessed.
local function slotsStub(width)
  width = width or 480
  local n = 6
  local w = width / n
  local out = {}
  for i = 1, n do
    out[i] = { x = (i - 1) * w, y = 0, w = w, h = 30 }
  end
  return out
end

-- Ethos widgets: form.addButton/addStaticText return objects with methods.
-- The menu path calls :focus() (header.lua:162/198-201,
-- menu_container.lua:289/295); everything else is only read. The fields are
-- deliberately minimal -- any extra method would be an assumption about
-- behaviour that this check does not make.
local function fieldStub(slot)
  return {
    slot = slot,
    focus = function() end,
    setText = function() end,
    setEnabled = function() end,
    setValue = function() end,
    getValue = function() return nil end,
    show = function() end,
    hide = function() end,
    isShown = function() return true end,
    isEnabled = function() return true end,
  }
end

_G.form = {
  addButton = function(_, slot) return fieldStub(slot) end,
  addLine = function() return 1 end,
  addStaticText = function(_, rect) return fieldStub(rect) end,
  addTextButton = function(_, slot) return fieldStub(slot) end,
  clear = function() end,
  getFieldSlots = function(_, hints)
    -- The slot count follows the hints header.lua passes in.
    local n = type(hints) == "table" and #hints or 6
    local w = 480 / math.max(n, 1)
    local out = {}
    for i = 1, n do
      out[i] = { x = (i - 1) * w, y = 0, w = w, h = 30 }
    end
    return out
  end,
  height = function() return 320 end,
  openProgressDialog = function() return { close = function() end } end,
}
_G.lcd.getTextSize = function(t) return #t, 12 end
_G.os = os
_G.math = math
_G.string = string
_G.table = table

-- Ethos globals the menu chain uses as VALUES. They are not defined in the repo
-- (compare activelook.lua:24, where FONT_PX is its own table) -- they come from
-- the platform, exactly like TIME_LEFT.
--
-- Numbers, not strings: header.lua:122 computes `options = FONT_S + CENTERED`,
-- so font and alignment are added. Read off the source, not guessed.
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

-- key events; close_key.lua filters on these
_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02
_G.EVT_EXIT_BREAK = 0x03
_G.EVT_KEY_DOWN_BREAK = 0x04
_G.KEY_ENTER_LONG = 0x05
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07

-- i18n tags: the sources contain @i18n(... )@ placeholders, translated at
-- runtime. Irrelevant here, and empty strings are harmless.
local UNDER_TEST = {
  "app/menu_container.lua",
  "app/navigation.lua",
  "app/header.lua",
  "app/tile_grid.lua",
  "app/close_key.lua",
  "app/esc_protocol_guard.lua",
  "app/servo_bus_guard.lua",
  "lib/memstats.lua",
  "lib/msp_esc_sensor_config.lua",
  "lib/msp_serial_config.lua",
}

local function countUnder(name)
  local target = SUITE .. "/" .. name
  local n = 0
  for _, path in ipairs(loadOrder) do
    if path == target then n = n + 1 end
  end
  return n
end

local function moduleLoaded(name)
  -- lib/require.lua caches under "rfsuite." .. path without .lua
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  return package.loaded[key] ~= nil
end

out("loading app/tool.lua ...")
local tool = dofile(SUITE .. "/app/tool.lua")
local handle = tool.init()
check("init() returns a handle", handle ~= nil)

out("")
out("case 1: after loading, before create() -- nothing may be loaded")
for _, name in ipairs(UNDER_TEST) do
  check(string.format("%-34s not loaded", name),
    not moduleLoaded(name) and countUnder(name) == 0,
    string.format("loaded=%s, loadfile calls=%d",
      tostring(moduleLoaded(name)), countUnder(name)))
end

out("")
out("case 2: after create() -- the tool's UI subtree must be complete")
registeredTool.create()
for _, name in ipairs(UNDER_TEST) do
  check(string.format("%-34s loaded", name), moduleLoaded(name),
    "still not loaded after create()")
end

out("")
out("case 3: close() loads nothing further and emits memstats")
local before = {}
for _, name in ipairs(UNDER_TEST) do before[name] = countUnder(name) end

local memstatsPrints = {}
local memstatsMod = package.loaded["rfsuite.lib.memstats"]
local origMemstatsPrint = memstatsMod and memstatsMod.print
if memstatsMod then
  memstatsMod.print = function(tag)
    memstatsPrints[#memstatsPrints + 1] = tag
    return origMemstatsPrint(tag)
  end
end

registeredTool.close()

if memstatsMod then
  memstatsMod.print = origMemstatsPrint
end

for _, name in ipairs(UNDER_TEST) do
  check(string.format("%-34s unchanged", name), countUnder(name) == before[name],
    string.format("newly loaded: %d", countUnder(name) - before[name]))
end
check("close() logged app.close (start)", memstatsPrints[1] == "app.close (start)",
  string.format("got %s", tostring(memstatsPrints[1])))
check("close() logged app.close (end)", memstatsPrints[2] == "app.close (end)",
  string.format("got %s", tostring(memstatsPrints[2])))

out("")
out("case 4: a second create() loads nothing again")
for _, name in ipairs(UNDER_TEST) do before[name] = countUnder(name) end
registeredTool.create()
for _, name in ipairs(UNDER_TEST) do
  check(string.format("%-34s no second load", name), countUnder(name) == before[name],
    string.format("loaded again: %d", countUnder(name) - before[name]))
end

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
out("lcd.loadMask calls: " .. maskCalls)
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

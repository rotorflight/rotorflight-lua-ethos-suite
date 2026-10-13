-- Retention check across repeated tool open/close cycles (#2425).
--
-- Run it:
--     lua5.4 bin/tool_ui/verify_tool_lifecycle_retention.lua
--     lua5.4 bin/tool_ui/verify_tool_lifecycle_retention.lua --self-test
--
-- What it drives, and why:
--   * The real src/rfsuite/app/tool.lua, so the whole chain a radio runs is
--     under test: system.registerSystemTool -> create() -> the real
--     app/menu_container.lua / app/header.lua / app/tile_grid.lua /
--     app/close_key.lua / app/navigation.lua, and a real leaf page
--     (app/pages/esc_forward_hw5.lua -> app/pages/esc_forward_vendor.lua ->
--     app/page_runtime.lua -> app/field_layout.lua). The Ethos widgets, the
--     clock and the LCD are stubbed; the page's MSP read is answered from the
--     codec's own simulatorResponse, so the editor actually builds -- including
--     page_runtime and every field_layout field -- rather than stopping on the
--     page's preload shell.
--   * The cycle is the one #2425 measured: open the tool, drill into the ESC
--     menus (Hardware -> ESC & Motors -> ESC Tools), open one ESC vendor page,
--     let it build, return, close.
--
-- What #2425 established, and what this file adds:
--   #2425 measured ~30 kB retained per cycle on an X18RS, surviving a forced
--   full collect, and left the live reference unidentified. The issue's own
--   suggested investigation is to count at the source rather than observe the
--   result. This harness does that. After every cycle it reports:
--     * the number of tables and strings REACHABLE from _G and package.loaded
--       (the sharp check -- an exact integer, and what "a live reference holds
--       it" would necessarily move);
--     * the Lua heap read after a forced full collect (the same figure the
--       radio's "app.close (end)" marker prints), as a coarse backstop;
--     * live bus subscribers, rfsuite.* entries in package.loaded, the
--       field_layout pool size, and how many form widgets the cycle built.
--   It requires every one of those to be flat from the second cycle on; only
--   the heap byte count carries a small tolerance (see below).
--
--   The result on this suite's own Lua tree is that ALL of them are flat: the
--   tool's create()/close() lifecycle, the menu rebuilds and the page visit
--   (editor and all) retain no reachable Lua object and no growing population
--   of them. That is the finding this file records: the ~30 kB #2425 measured
--   is not reachable from Lua, which is consistent with
--   docs/memory-and-module-lifecycle.md section 8 (Ethos's own form widget
--   system retains widget/callback allocations past form.clear(), outside
--   Lua's GC reachability graph). It is a platform trait, not a leak this
--   repository can fix by dropping references. The byte count stays within a
--   small tolerance -- the harness no longer grows its own metric arrays inside
--   the region it measures (see newMetrics() below), but the exact figure still
--   shifts by a fraction of a KB between Lua builds -- so it is a backstop, not
--   a check. The census is the check to read: exact integers that allocator
--   accounting cannot perturb.
--
--   The harness is still worth having: it is the regression guard. If a future
--   change adds a module-level table that grows per screen rebuild, or stops
--   unsubscribing a page handler, the flat-from-cycle-2 property goes red.
--
-- --self-test proves that property has teeth. It plants the exact failure mode
-- section 8 describes -- every form widget's options table is retained per
-- cycle, as a live Ethos widget would retain it -- and requires the census
-- checks to go red. A check that cannot detect retention is worthless.

local SELF_TEST = false
for _, arg in ipairs(arg or {}) do
  if arg == "--self-test" then SELF_TEST = true end
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

-- ── Ethos stubs ─────────────────────────────────────────────────────────────
-- Same shape as bin/tool_ui/verify_root_close_key.lua, which is the other
-- harness that drives the tool through its real registerSystemTool lifecycle.
package.path = SUITE .. "/?.lua;" .. package.path

local LOCAL_PREFIX = SUITE .. "/"
local realLoadfile = loadfile
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (LOCAL_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

local registeredTool = nil
_G.system = {
  -- simulation = true selects the same branch the Ethos simulator takes, and
  -- it is load-bearing here: app/esc_protocol_guard.lua gates every ESC menu
  -- tile on the family the FC reports, and the codec's own simulatorResponse
  -- reports protocol 0 (NONE), which disables all of them -- so without this
  -- the ESC Tools tile press below is a no-op and the page never opens. The
  -- guard's own isSimulation() branch enables every tile and sends no read.
  getVersion = function() return {simulation = true, radio = {name = "stub"}} end,
  registerSystemTool = function(tool) registeredTool = tool return tool end,
  getMemoryUsage = function() return {} end,
  formatBytes = function(n) return tostring(n) end,
  exit = function() end,
  killEvents = function() end,
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
_G.print = function() end

-- form: real widgets, not enough of them to render anything. Every add* call
-- is counted, so "how many widgets did this cycle build" is a fact about the
-- code under test rather than an estimate.
local widgetCount = 0
local tiles = {}

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
    decimals = function() end,
    step = function() end,
  }
end

local function slotList(n, width)
  width = width or 480
  local w = width / math.max(n, 1)
  local list = {}
  for i = 1, n do list[i] = {x = (i - 1) * w, y = 0, w = w, h = 30} end
  return list
end

_G.form = {
  addLine = function() widgetCount = widgetCount + 1 return 1 end,
  clear = function() tiles = {} end,
  height = function() return 30 end,
  invalidate = function() end,
  getFieldSlots = function(_, hints) return slotList(type(hints) == "table" and #hints or 6) end,
  addStaticText = function(_, rect)
    widgetCount = widgetCount + 1
    return fieldStub(rect)
  end,
  addTextButton = function(_, slot)
    widgetCount = widgetCount + 1
    return fieldStub(slot)
  end,
  addNumberField = function(_, slot)
    widgetCount = widgetCount + 1
    return fieldStub(slot)
  end,
  addChoiceField = function(_, slot)
    widgetCount = widgetCount + 1
    return fieldStub(slot)
  end,
  addExpansionPanel = function()
    widgetCount = widgetCount + 1
    return {open = function() end, addLine = function() return 1 end}
  end,
  addButton = function(_, slot, opts)
    widgetCount = widgetCount + 1
    tiles[#tiles + 1] = {
      slot = slot,
      icon = opts and opts.icon and opts.icon.path,
      press = opts and opts.press,
    }
    return fieldStub(slot, opts)
  end,
  openProgressDialog = function() return {value = function() end, close = function() end} end,
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

_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02
_G.EVT_EXIT_BREAK = 0x03
_G.EVT_KEY_DOWN_BREAK = 0x04
_G.KEY_ENTER_LONG = 0x05
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07

-- ── Bus: the real one, with subscribe/unsubscribe counted ───────────────────
-- Loaded before the tool so the tool's own module-level subscriptions are
-- counted too. The wrapper is installed on the shared table, so every holder
-- (the tool, the guards, every page) uses it.
local bus = assert(realLoadfile(LOCAL_PREFIX .. "lib/bus.lua")())
package.loaded["rfsuite.lib.bus"] = bus
package.loaded["rfsuite.bus"] = bus

local liveSubscribers = {}
local realSubscribe = bus.subscribe
local realUnsubscribe = bus.unsubscribe
bus.subscribe = function(topic, handler)
  liveSubscribers[topic] = (liveSubscribers[topic] or 0) + 1
  return realSubscribe(topic, handler)
end
bus.unsubscribe = function(topic, handler)
  if (liveSubscribers[topic] or 0) > 0 then
    liveSubscribers[topic] = liveSubscribers[topic] - 1
  end
  return realUnsubscribe(topic, handler)
end

-- ── MSP: answer the read, the way tasks/msp/queue.lua does ──────────────────
-- The ESC vendor page issues one MSP read on open, and builds the editor from
-- the reply on its next wakeup tick. Left unanswered, the page stops on its
-- preload shell: page_runtime and field_layout are never reached, and the
-- field_layout pool check below would pass on a flat 0 that means nothing. The
-- reply is the codec's own simulatorResponse, delivered exactly as the queue
-- delivers it -- a fresh buffer with offset 1 (see queue.lua's _deliver()).
local mspAnswers = 0
local realPublish = bus.publish
bus.publish = function(topic, message)
  if topic == "msp.request" and type(message) == "table" and message.simulatorResponse then
    local buf = {}
    for i = 1, #message.simulatorResponse do buf[i] = message.simulatorResponse[i] end
    buf.offset = 1
    mspAnswers = mspAnswers + 1
    if message.processReply then message.processReply(nil, buf) end
  end
  return realPublish(topic, message)
end

local function subscriberTotal()
  local n = 0
  for _, v in pairs(liveSubscribers) do n = n + v end
  return n
end

-- ── Counters ────────────────────────────────────────────────────────────────
local function rfsuiteKeyCount()
  local n = 0
  for k in pairs(package.loaded) do
    if type(k) == "string" and k:match("^rfsuite%.") then n = n + 1 end
  end
  return n
end

local function poolSize()
  local fl = package.loaded["rfsuite.app.field_layout"]
  if fl and fl.poolStats then
    local count, live = fl.poolStats()
    return count, live
  end
  return 0, 0
end

-- The sharp instrument: count the tables and strings actually REACHABLE from
-- _G and package.loaded, following table values. A live reference to a table --
-- a module-level cache that grows per screen rebuild, a page's handler that
-- stopped unsubscribing, a global that keeps a screen's widget options --
-- keeps that table and everything in it reachable, so the count rises with it.
-- Unlike collectgarbage("count") this is an exact integer that allocator
-- accounting cannot perturb.
--
-- Deliberately does NOT follow function upvalues: debug.getupvalue traversal
-- reaches live state through closures whose reachability depends on the last
-- cycle in ways that make the count vary between runs (measured), which is
-- noise, not signal. Every container this check exists to catch is a table on
-- the path from _G or package.loaded, so a table-value walk sees it. Retained
-- closures with no table behind them are the platform's business (section 8),
-- and nothing here could act on them anyway.
local function census()
  local seen = {}
  local tables, strings = 0, 0
  local function walk(value, depth)
    if depth > 12 then return end
    local kind = type(value)
    if kind == "table" then
      if seen[value] then return end
      seen[value] = true
      tables = tables + 1
      for k, v in pairs(value) do
        walk(k, depth + 1)
        walk(v, depth + 1)
      end
    elseif kind == "string" then
      strings = strings + 1
    end
  end
  walk(_G, 0)
  for k, v in pairs(package.loaded) do
    walk(k, 0)
    walk(v, 0)
  end
  return tables, strings
end

-- collectgarbage("count") reports the live heap *plus* whatever the collector
-- has not yet reclaimed, and two forced cycles can still leave a few hundred
-- bytes of allocator-internal slack. Settle instead of guessing: collect until
-- the reading stops moving (or a bound is hit). This cannot hide retention --
-- a live reference is not reclaimed by collecting more, so a real per-cycle
-- leak keeps the reading rising.
local function heapKB()
  local previous = -1
  for _ = 1, 8 do
    collectgarbage("collect")
    local current = collectgarbage("count")
    if current == previous then return current end
    previous = current
  end
  return collectgarbage("count")
end

-- ── The tool ────────────────────────────────────────────────────────────────
local tool = dofile(SUITE .. "/app/tool.lua")
tool.init()

-- The guards only request while the background task runs AND the link is up
-- (tool.lua:469/475). Both are announced over the real bus, so the suite's own
-- state machine runs -- and the ESC vendor page's read is actually published
-- (unanswered; the page still builds).
bus.publish("task.status", {running = true, updatedAt = os.clock()})
bus.publish("session.update", {connected = true, apiVersionSupported = true, pidProfile = 1})

-- ── Navigation ──────────────────────────────────────────────────────────────
local HW = "app/gfx/hardware.png"
local ESC_MOTORS = "app/gfx/esc_motors.png"
local ESC_TOOLS = "app/gfx/esc_tools.png"
local HW5 = "app/gfx/esc_mfg_hw5.png"

-- The newest tile with this icon: after every form.clear() the screen's tiles
-- are appended at the end of the list.
local function press(icon)
  for i = #tiles, 1, -1 do
    if tiles[i].icon == icon and tiles[i].press then
      tiles[i].press()
      return true
    end
  end
  return false
end

-- Every screen (menu or page) builds its header first, so tiles[1] is always
-- the header's Menu/Back button, whose press is the screen's own onBack.
local function header()
  if tiles[1] and tiles[1].press then
    tiles[1].press()
    return true
  end
  return false
end

local navigated = {press = 0, header = 0}

local function navigate()
  local before = widgetCount
  if not press(HW) then error("setup tile not found") end
  if not press(ESC_MOTORS) then error("ESC & Motors tile not found") end
  if not press(ESC_TOOLS) then error("ESC Tools tile not found") end
  if not press(HW5) then error("HW5 tile not found") end
  -- The page published its read synchronously in open(), and the reply wrapper
  -- above already answered it, so one wakeup tick builds the editor
  -- (page_runtime + every field_layout field) before we leave the page.
  registeredTool.wakeup({})
  -- page -> esc_forward_menu -> esc_motors_menu -> setup_menu -> root
  for _ = 1, 4 do
    if not header() then error("header button not found") end
  end
  navigated.press = navigated.press + 1
  return widgetCount - before
end

-- Measurement buffers, allocated once per run. The harness must not allocate
-- inside the region it measures, or it reports its own bookkeeping as
-- retention. That is what the "empty table grown in a loop" version did: a
-- fresh `{}` grows its array part as indices 1..n are assigned (1, 2, 4, 8
-- slots), and that growth lands in the post-collect reading of the *next*
-- cycle -- ~0.2 KB/cycle that was entirely the harness, not the tool. Filling
-- every array to n up front means the measured cycles never reallocate.
local function newMetrics(n)
  local m = {
    heap = {}, widgets = {}, subscribers = {}, keys = {},
    pool = {}, poolLive = {}, tables = {}, strings = {},
  }
  for _, t in pairs(m) do
    for i = 1, n do t[i] = 0 end
  end
  return m
end

-- One full open -> navigate -> close cycle. Returns how many form widgets the
-- cycle built -- a per-cycle figure, not the running total.
local function cycle()
  local before = widgetCount
  registeredTool.create()
  navigate()
  registeredTool.close()
  return widgetCount - before
end

-- ── The check sequence ──────────────────────────────────────────────────────
local function runCycles(n)
  local m = newMetrics(n)
  -- Warm-up: the first create() loads the tool's UI subtree and the first
  -- visit loads the page modules. Those are one-time costs and are not the
  -- growth #2425 is about. Also run the census and counter functions once so
  -- allocator and hash structures are primed before cycle 1 is recorded.
  cycle()
  poolSize()
  census()
  subscriberTotal()
  rfsuiteKeyCount()
  heapKB()

  for i = 1, n do
    local widgetDelta = cycle()
    local count, live = poolSize()
    m.tables[i], m.strings[i] = census()
    m.widgets[i] = widgetDelta
    m.subscribers[i] = subscriberTotal()
    m.keys[i] = rfsuiteKeyCount()
    m.pool[i] = count
    m.poolLive[i] = live
    m.heap[i] = heapKB()
  end
  return m
end

local CYCLES = 6
-- With the metric arrays pre-sized (see newMetrics) the harness does not grow
-- its own bookkeeping inside the region it measures, and after a forced collect
-- the byte count is nearly flat across cycles. "Nearly" is the honest word: the
-- exact figure moves by a fraction of a KB between Lua builds -- measured 0.00
-- KB on 5.4.3 locally and +0.53 KB on CI's 5.4.x -- because
-- collectgarbage("count") includes the allocator's own internal state. This is
-- therefore a coarse backstop with room for that drift, still an order of
-- magnitude below the ~30 kB/cycle #2425 measured. The object census above is
-- the exact check and the one a review should read: it is the same to the
-- object on every build.
local HEAP_GROWTH_TOLERANCE_KB = 2.0

local function reportSnapshots(label, m, n)
  out(label)
  out(string.format("  %-6s %9s %9s %10s %7s %6s %6s",
    "cycle", "tables", "strings", "heap KB", "subs", "keys", "pool"))
  for i = 1, n do
    out(string.format("  %-6d %9d %9d %10.2f %7d %6d %6d",
      i, m.tables[i], m.strings[i], m.heap[i], m.subscribers[i], m.keys[i], m.pool[i]))
  end
  out("")
end

local function analyse(m, n)
  for i = 2, n do
    check(string.format("cycle %d  no new reachable tables (%d)", i, m.tables[i]),
      m.tables[i] == m.tables[1],
      string.format("%d -> %d", m.tables[1], m.tables[i]))
    check(string.format("cycle %d  no new reachable strings (%d)", i, m.strings[i]),
      m.strings[i] == m.strings[1],
      string.format("%d -> %d", m.strings[1], m.strings[i]))
    check(string.format("cycle %d  no new bus subscribers (%d)", i, m.subscribers[i]),
      m.subscribers[i] == m.subscribers[1],
      string.format("%d -> %d", m.subscribers[1], m.subscribers[i]))
    check(string.format("cycle %d  no new package.loaded entries (%d)", i, m.keys[i]),
      m.keys[i] == m.keys[1],
      string.format("%d -> %d", m.keys[1], m.keys[i]))
    check(string.format("cycle %d  field_layout pool is stable (%d)", i, m.pool[i]),
      m.pool[i] == m.pool[1],
      string.format("%d -> %d", m.pool[1], m.pool[i]))
    check(string.format("cycle %d  same widget count built (%d)", i, m.widgets[i]),
      m.widgets[i] == m.widgets[1],
      string.format("%d -> %d", m.widgets[1], m.widgets[i]))
  end
  local growth = m.heap[n] - m.heap[1]
  check(string.format("Lua heap does not grow over %d cycles (%+.2f KB)", n - 1, growth),
    growth <= HEAP_GROWTH_TOLERANCE_KB,
    string.format("heap %.2f -> %.2f KB over %d cycles", m.heap[1], m.heap[n], n))
end

-- ---------------------------------------------------------------------------
-- pass 1: the real tree
-- ---------------------------------------------------------------------------
out("pass 1: the real app/tool.lua over " .. CYCLES .. " open/close cycles")
local metrics = runCycles(CYCLES)
reportSnapshots("counters after each cycle:", metrics, CYCLES)
analyse(metrics, CYCLES)

local pass1Checks, pass1Failures = checks, failures

-- ---------------------------------------------------------------------------
-- self-test: plant the retention section 8 describes
-- ---------------------------------------------------------------------------
if SELF_TEST then
  out("")
  out(string.rep("=", 60))
  out("self-test: a retained form widget must turn the heap check red")
  out(string.rep("=", 60))

  -- Section 8's finding is that Ethos keeps some form widget/callback
  -- allocations after form.clear(). Model exactly that: retain every options
  -- table a form widget is built from, so the widget (and anything it closes
  -- over) stays reachable from a global, precisely as a live Ethos widget
  -- keeps its callback closure. If the harness's heap checks cannot see this,
  -- they cannot see a real leak either.
  _G.__retainedWidgets = {}
  local realAddButton = _G.form.addButton
  local realAddNumberField = _G.form.addNumberField
  local realAddChoiceField = _G.form.addChoiceField
  _G.form.addButton = function(...)
    local slot, opts = select(2, ...), select(3, ...)
    _G.__retainedWidgets[#_G.__retainedWidgets + 1] = {slot, opts}
    return realAddButton(...)
  end
  _G.form.addNumberField = function(...)
    _G.__retainedWidgets[#_G.__retainedWidgets + 1] = {select(2, ...)}
    return realAddNumberField(...)
  end
  _G.form.addChoiceField = function(...)
    _G.__retainedWidgets[#_G.__retainedWidgets + 1] = {select(2, ...)}
    return realAddChoiceField(...)
  end

  checks, failures = 0, 0
  failedLabels = {}
  out("")
  out("pass 2: the same cycles with the widget retention planted")
  local metrics2 = runCycles(CYCLES)
  reportSnapshots("counters after each cycle:", metrics2, CYCLES)
  analyse(metrics2, CYCLES)

  local pass2Failures = failures
  local grew = metrics2.heap[CYCLES] - metrics2.heap[1]
  local retained = #_G.__retainedWidgets
  _G.__retainedWidgets = nil

  local censusCaughtIt = false
  for label in pairs(failedLabels) do
    if label:find("no new reachable tables", 1, true) then censusCaughtIt = true end
  end

  out("")
  out("self-test verdict:")
  out(string.format("  retained widget tables: %d", retained))
  out(string.format("  reachable tables: %d -> %d", metrics2.tables[1], metrics2.tables[CYCLES]))
  out(string.format("  Lua heap first -> last cycle: %.2f -> %.2f KB (%+.2f KB)",
    metrics2.heap[1], metrics2.heap[CYCLES], grew))
  out(string.format("  pass 1 against the real tree: %d checks, %d failures",
    pass1Checks, pass1Failures))
  out(string.format("  pass 2 with the retention planted: %d checks, %d failures",
    checks, pass2Failures))

  if pass2Failures == 0 or not censusCaughtIt then
    out("")
    out("SELF-TEST FAILED -- the retention was planted and the leak checks stayed green")
    os.exit(1)
  end
  out("SELF-TEST PASSED -- the census checks go red when form widget allocations are retained")

  checks, failures = pass1Checks, pass1Failures
end

-- The verdict is pass 1's: without --self-test, pass 2 never ran; with it,
-- pass 2's red is the expected outcome rather than a failure of this tree.
out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

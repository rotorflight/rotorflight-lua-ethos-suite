-- Behaviour check for the MSP request pattern of the tool (#2421).
--
-- Run it:
--     lua5.3 bin/tool_ui/verify_no_extra_msp.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/tool.lua, including both real guards. Only the
--     Ethos widgets, the background task and the link are stubbed. The last two
--     have to report "running" and "connected", because the guards only request
--     then (tool.lua:469/475) -- without them the run passes on 0 == 0.
--   * Requests are counted at bus.publish, the source, with the real bus left
--     in place. That is stricter than watching the wire: the run is a fixed
--     sequence, so the trace can be compared byte for byte between two builds.
--   * Every request is answered the way a live FC would answer it. This is
--     load-bearing, not decoration. Without a reply state.pending stays true,
--     and pending blocks every repeat no matter what the `attempted` latch
--     does. A first version of this harness had no answering stub and stayed
--     GREEN after the guard's latch had been deliberately removed -- it was
--     measuring nothing. With the stub, that same sabotage yields 309 requests
--     instead of 6 and this file goes red.
--
-- The path deliberately enters BOTH guarded menus:
--   root -> Hardware -> Servos            (servo_bus_guard,    MSP 54)
--   root -> Hardware -> ESC & Motors -> ESC Tools
--                                          (esc_protocol_guard, MSP 123)
-- A run that skipped them would measure nothing. The tick block matters for the
-- same reason: a retry storm can only arrive through wakeup(), which
-- menu_container.lua:305-306 forwards to the guards.
--
-- The 98 lcd.loadMask calls in tool.lua are a different budget (the bitmap
-- arena) and are not exercised here.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local arg1 = ...
local ROOT = (arg1 or (scriptDir() .. "/../..")):gsub("\\", "/")
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0

-- The real print, held in a local BEFORE _G.print is replaced below. The suite
-- calls out() everywhere, so a silent stub has to be installed -- and if this
-- file then calls the global print, it silences itself as well. That happened
-- once already: the harness reported exit code 0 and not a single line.
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

-- ── Ethos stubs ──────────────────────────────────────────────────────────────
package.path = SUITE .. "/?.lua;" .. package.path

local realLoadfile = loadfile
local SUITE_PREFIX = SUITE .. "/"
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (SUITE_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

local registeredTool = nil
_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
  registerSystemTool = function(tool) registeredTool = tool return tool end,
  getMemoryUsage = function() return {} end,
  formatBytes = function(n) return tostring(n) end,
}

_G.lcd = {
  loadMask = function(p) return { path = p } end,
  loadImage = function(p) return { path = p } end,
  getWindowSize = function() return 480, 320 end,
  getTextSize = function(t) return #t, 12 end,
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

-- The suite calls out() throughout; a silent stub would swallow this
-- harness's own output as well.
_G.print = function() end

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

-- Every tile is recorded here. Navigation goes through the press callback that
-- menu_container.lua:242-265 builds -- the same path a button press takes, just
-- without a key. A tile is identified by its icon path, which comes from the
-- menu data and therefore does not have to be guessed.
local tiles = {}
_G.form = {
  addButton = function(_, slot, button)
    tiles[#tiles + 1] = {
      slot = slot,
      icon = button and button.icon and button.icon.path,
      press = button and button.press,
    }
    return fieldStub(slot)
  end,
  addLine = function() return 1 end,
  addStaticText = function(_, rect) return fieldStub(rect) end,
  addTextButton = function(_, slot) return fieldStub(slot) end,
  clear = function() end,
  getFieldSlots = function(_, hints)
    local n = type(hints) == "table" and #hints or 6
    local w = 480 / math.max(n, 1)
    local out = {}
    for i = 1, n do out[i] = { x = (i - 1) * w, y = 0, w = w, h = 30 } end
    return out
  end,
  height = function() return 320 end,
  openProgressDialog = function() return { close = function() end } end,
}

_G.os = os
_G.math = math
_G.string = string
_G.table = table
_G.TIME_LEFT, _G.TEXT_LEFT, _G.LEFT = 1, 2, 3
_G.CENTERED, _G.RIGHT, _G.TOP_LEFT = 4, 5, 6
_G.FONT_XS, _G.FONT_S, _G.FONT_M, _G.FONT_L, _G.FONT_XL = 10, 20, 30, 40, 50
_G.EVT_CLOSE, _G.EVT_KEY, _G.EVT_EXIT_BREAK = 0x01, 0x02, 0x03
_G.EVT_KEY_DOWN_BREAK, _G.KEY_ENTER_LONG = 0x04, 0x05
_G.KEY_RTN_BREAK, _G.KEY_EXIT_BREAK = 0x06, 0x07

-- ── MSP counting at the source ──────────────────────────────────────────────
-- The real bus is loaded BEFORE the tool and its publish is wrapped afterwards.
-- Every holder of that table sees the wrapper, so it stays the real bus with a
-- counter in front of it.
local bus = assert(realLoadfile(SUITE_PREFIX .. "lib/bus.lua")())

-- Byte layouts come from the real decoders, not from guesswork:
--   123  msp_esc_sensor_config.decode -- 14 fields
--        (U8,U8,U16,U16,U16,U8,U8,S8,S8,U16)
--   54   msp_serial_config.decode     -- 9-byte record (U8,U32,U8,U8,U8,U8)
local REPLY = {
  [123] = function() return { 1, 0, 200, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } end,
  [54] = function() return { 1, 0, 0, 0, 0, 0, 0, 0, 0 } end,
}

local trace = {}
local realPublish = bus.publish
bus.publish = function(topic, message)
  if topic == "msp.request" and type(message) == "table" then
    trace[#trace + 1] = message.command or "?"
    local reply = REPLY[message.command]
    if reply and message.processReply then
      local buf = reply()
      buf.offset = 1
      message.processReply(nil, buf)
    end
  end
  return realPublish(topic, message)
end

-- ── Run ─────────────────────────────────────────────────────────────────────
local ESC_ICON = "app/gfx/esc_tools.png"
local SERVO_ICON = "app/gfx/servos.png"
local HW_ICON = "app/gfx/hardware.png"
local ESC_MOTORS_ICON = "app/gfx/esc_motors.png"

-- The newest tile with this icon: after every menu change the tiles of the new
-- screen are at the end of the list.
local function press(iconPath)
  for i = #tiles, 1, -1 do
    if tiles[i].icon == iconPath and tiles[i].press then
      tiles[i].press()
      return true
    end
  end
  return false
end

local function traceCount() return #trace end

local function traceSince(from)
  local out = {}
  for i = from + 1, #trace do out[#out + 1] = tostring(trace[i]) end
  return table.concat(out, ",")
end

out("loading app/tool.lua ...")
local tool = dofile(SUITE .. "/app/tool.lua")
local handle = tool.init()
check("init() returns a handle", handle ~= nil)

-- The guards only request while the background task runs AND the link is up
-- (tool.lua:469/475). Both are announced over the real bus -- not stubbed -- so
-- the suite's own state machine runs the way it does in operation.
bus.publish("task.status", { running = true, updatedAt = os.clock() })
bus.publish("session.update", { connected = true, apiVersionSupported = true })

local CYCLES = 3
local tracePerCycle = {}

for cycle = 1, CYCLES do
  registeredTool.create()

  -- The trace sections are captured as text IMMEDIATELY, not at the end of the
  -- cycle. Otherwise the Servos section reports the reply the ESC step appended
  -- afterwards, and the report counts two requests where there was one.
  local markServos = traceCount()
  check(string.format("cycle %d  Hardware menu is reachable", cycle), press(HW_ICON))
  check(string.format("cycle %d  Servos menu is reachable", cycle), press(SERVO_ICON))
  local afterServos = traceCount() - markServos
  local textServos = traceSince(markServos)

  local markEsc = traceCount()
  check(string.format("cycle %d  ESC & Motors menu is reachable", cycle), press(ESC_MOTORS_ICON))
  check(string.format("cycle %d  ESC Tools menu is reachable", cycle), press(ESC_ICON))
  local afterEsc = traceCount() - markEsc
  local textEsc = traceSince(markEsc)

  -- The tick. This is the only route a retry storm could take: Ethos calls
  -- wakeup() continuously, menu_container.lua:305-306 hands it to the guard,
  -- and the guard calls request(). Without this block the file would only test
  -- entering the menu -- exactly the case in which nothing can accumulate.
  local markTick = traceCount()
  local TICKS = 100
  for _ = 1, TICKS do
    registeredTool.wakeup({})
  end
  local inTick = traceCount() - markTick

  registeredTool.close()

  tracePerCycle[#tracePerCycle + 1] = string.format("Servos=%d(%s) ESC=%d(%s) Tick=%d",
    afterServos, textServos, afterEsc, textEsc, inTick)
end

-- ── Verdict ─────────────────────────────────────────────────────────────────
local ESC_READ = 123      -- msp_esc_sensor_config.READ_COMMAND
local SERIAL_READ = 54    -- msp_serial_config.READ_COMMAND

out("")
out("trace per cycle:")
for i, t in ipairs(tracePerCycle) do
  out(string.format("  %d  %s", i, t))
end
out("")

-- Each guarded menu issues exactly ONE request on entry: the guard reads once
-- and holds the answer (attempted). More than that is the storm this file is
-- here to catch.
for i = 1, #tracePerCycle do
  local t = tracePerCycle[i]
  check(string.format("cycle %d  exactly one Servos read (MSP %d)", i, SERIAL_READ),
    t:find("Servos=1%(" .. SERIAL_READ .. "%)") ~= nil, t)
  check(string.format("cycle %d  exactly one ESC read (MSP %d)", i, ESC_READ),
    t:find("ESC=1%(" .. ESC_READ .. "%)") ~= nil, t)
end

-- And the property that matters: the trace must be the same in EVERY cycle. If
-- it grows, something is accumulating -- which is the concern under test.
for i = 2, #tracePerCycle do
  check(string.format("cycle %d is identical to cycle 1", i),
    tracePerCycle[i] == tracePerCycle[1],
    string.format("%s  vs.  %s", tracePerCycle[i], tracePerCycle[1]))
end

-- 100 ticks inside a guarded menu must not produce a single request. The guard
-- reads once and holds the result; if it sent on every tick, that is the storm.
check("100 ticks inside the ESC menu produce no request",
  tracePerCycle[1]:find("Tick=0$") ~= nil, tracePerCycle[1])

check("the same total number of requests in every cycle",
  #trace == 2 * #tracePerCycle,
  "trace holds " .. #trace .. " entries for " .. #tracePerCycle .. " cycles")

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
out("MSP requests total: " .. #trace .. "   trace: " .. traceSince(0))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

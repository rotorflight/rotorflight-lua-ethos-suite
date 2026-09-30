-- Behaviour check for the C-stack bounds added in response to the stack
-- question raised on rotorflight/rotorflight-lua-ethos-suite#2420.
--
-- Run it:
--     lua5.3 bin/stack/verify_stack_bounds.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/lib/bus.lua and the real
--     src/rfsuite/lib/stack_probe.lua, loaded the way the suite loads them
--     (requireModule from lib/require.lua, literal paths relative to
--     src/rfsuite -- see background.lua:52 / main.lua). The point is not to
--     test the bus's routing; it is to establish what happens when a handler
--     publishes from inside a handler, because that is the only unbounded term
--     left in this suite and a runaway one does not raise a catchable Lua
--     error -- it eats the C stack of the task the radio is running it on.
--
-- Six cases, each against a stated expectation:
--   1. Ordinary cross-topic nesting runs both handlers, in order, at depth 2.
--   2. A handler cycle TERMINATES and is reported once, naming the limit.
--   3. That termination is not a "stack overflow" -- i.e. the guard fired, not
--      the VM running out of C stack.
--   4. The depth counter unwinds: a publish after the cycle still reaches its
--      handler and does not push maxPublishDepth any higher. A guard that
--      leaks its counter would silently break the bus after N publishes.
--   5. The minimum tracker holds the smallest value, ignores a missing or
--      non-numeric field, and can still record a real zero.
--   6. reset() clears the window.
--
-- Cases 2, 3 and 4 go RED against pre-change master: there the cycle runs
-- until the VM itself raises "stack overflow" (once per level, through the
-- pcall in publish), and the bus has no maxPublishDepth at all. Case 5 and 6
-- go red there too, because lib/stack_probe.lua does not exist. That is the
-- point of running this: a gate that cannot go red proves nothing.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0

-- The real print, held in a local BEFORE _G.print is wrapped below.
--
-- Do NOT replace _G.print with a no-op here. A previous harness in this repo
-- did, and the first run exited 0 having printed not one line: a silent stub
-- is exactly as bad a test outcome as a silent suite. This wrapper RECORDS
-- the suite's own output and still forwards everything to the terminal.
local out = print
local captured = {}

_G.print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  captured[#captured + 1] = table.concat(parts, " ")
  out(...)
end

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

local function capturedMatching(pattern)
  local hits = 0
  for i = 1, #captured do
    if captured[i]:find(pattern) then hits = hits + 1 end
  end
  return hits
end

local function clearCaptured()
  for i = #captured, 1, -1 do captured[i] = nil end
end

-- ── Load the real modules ───────────────────────────────────────────────────
-- Same resolution route the suite has on the radio: lib/bus.lua and
-- lib/stack_probe.lua are loadfile()'d with literal paths that carry no
-- directory part, relative to the root script's own directory. The prefix
-- gives this harness that route without changing the names under test.
package.path = SUITE .. "/?.lua;" .. package.path
local LOCAL_PREFIX = SUITE .. "/"
_G.PREFIX = LOCAL_PREFIX

local realLoadfile = loadfile
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (LOCAL_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")

-- Loaded defensively. Against pre-change master lib/stack_probe.lua does not
-- exist, and a bare requireModule() would abort the whole run on the missing
-- file -- which is a red, but one that reports a stack trace instead of the
-- five assertions that actually describe what is missing.
local probeOk, stackProbe = pcall(function()
  return requireModule("lib/stack_probe.lua")
end)
if not probeOk then stackProbe = nil end

out("")
out("bus and stack_probe, " .. ((bus._version == 3) and "post-change" or "PRE-CHANGE") .. " (BUS_VERSION " .. tostring(bus._version) .. ")")
out("stack_probe: " .. (stackProbe and "loaded" or "ABSENT"))
out("")

-- ── 1. Ordinary cross-topic nesting ─────────────────────────────────────────
do
  local order = {}
  bus.subscribe("t.a", function()
    order[#order + 1] = "a"
    bus.publish("t.b", "from-a")
  end)
  bus.subscribe("t.b", function() order[#order + 1] = "b" end)

  bus.publish("t.a", "go")

  check("cross-topic nesting runs both handlers, in order",
    order[1] == "a" and order[2] == "b" and #order == 2,
    "order = " .. table.concat(order, ","))
end

-- ── 2 + 3. A handler cycle terminates, once, and is not a stack overflow ───
do
  local calls = 0
  bus.subscribe("t.cycle", function()
    calls = calls + 1
    bus.publish("t.cycle", "again")
  end)

  clearCaptured()
  bus.publish("t.cycle", "go")
  local guardReports = capturedMatching("recursion limit reached")
  local overflows = capturedMatching("stack overflow")

  check("a handler cycle terminates instead of recursing forever",
    calls > 0 and calls <= 64,
    "handler ran " .. calls .. " times")
  check("the cycle is reported, naming the limit",
    guardReports >= 1,
    "guard reports = " .. guardReports)
  check("termination came from the guard, not from a C stack overflow",
    overflows == 0,
    "stack-overflow reports = " .. overflows .. " (on pre-change master the VM raises this instead)")
end

-- ── 4. The counter unwinds ─────────────────────────────────────────────────
do
  local before = bus.maxPublishDepth and bus.maxPublishDepth() or nil
  clearCaptured()

  local reached = false
  bus.subscribe("t.after", function() reached = true end)
  bus.publish("t.after", "go")

  local after = bus.maxPublishDepth and bus.maxPublishDepth() or nil

  check("a publish after the cycle still reaches its handler",
    reached,
    "handler did not run")
  check("the bus reports a maximum publish depth", before ~= nil,
    "bus.maxPublishDepth is missing -- this file predates the guard")
  check("the counter unwound, it did not stay latched at the limit",
    after == before,
    "maxPublishDepth " .. tostring(before) .. " -> " .. tostring(after))
end

-- ── 5 + 6. The minimum tracker ─────────────────────────────────────────────
check("lib/stack_probe.lua is present", stackProbe ~= nil,
  "module did not load -- pre-change master has no such file")
if stackProbe then
  check("no minimum before anything is noted",
    stackProbe.minimum() == nil,
    "minimum = " .. tostring(stackProbe.minimum()))

  stackProbe.note(5000)
  stackProbe.note(3000)
  stackProbe.note(9000)
  check("the smallest value is held",
    stackProbe.minimum() == 3000,
    "minimum = " .. tostring(stackProbe.minimum()))

  stackProbe.note(nil)
  check("a missing field is ignored, not coerced to zero",
    stackProbe.minimum() == 3000,
    "minimum = " .. tostring(stackProbe.minimum()))

  stackProbe.note("not a number")
  check("a non-numeric field is ignored",
    stackProbe.minimum() == 3000,
    "minimum = " .. tostring(stackProbe.minimum()))

  stackProbe.note(0)
  check("a real zero IS recorded, distinct from 'never reported'",
    stackProbe.minimum() == 0,
    "minimum = " .. tostring(stackProbe.minimum()))

  stackProbe.reset()
  check("reset() clears the window",
    stackProbe.minimum() == nil,
    "minimum = " .. tostring(stackProbe.minimum()))

  -- The shipped rendering, not a copy of it. tasks/background.lua:73-85 builds
  -- its [bgtask mem] line around exactly this string.
  check("no reading yet renders both extremes as '-', not as numbers",
    stackProbe.formatStackFields(0) == "stackMin=- stackMax=- pubMax=0",
    "got: " .. stackProbe.formatStackFields(0))

  -- The exact integers, NOT "%.1fKB". 0 bytes and 51 bytes both render as
  -- "0.0KB", and that is precisely the pair this instrument exists to
  -- distinguish. Ethos derives the field as 4 * STACK_AVAILABLE_WORDS, so the
  -- real values arrive as multiples of 4.
  stackProbe.note(9296)
  check("a single high reading fills both extremes",
    stackProbe.formatStackFields(0) == "stackMin=9296B stackMax=9296B pubMax=0",
    "got: " .. stackProbe.formatStackFields(0))

  -- The case the whole pair exists for: the same field read 9 296 in one place
  -- and 0 in another. A minimum alone cannot say whether that is a Main task
  -- at the edge or a deep call site; the maximum beside it can.
  stackProbe.note(4)
  check("a low reading moves the minimum and leaves the maximum standing",
    stackProbe.formatStackFields(0) == "stackMin=4B stackMax=9296B pubMax=0",
    "got: " .. stackProbe.formatStackFields(0))
  check("maximum() reports it directly, not only through the format",
    stackProbe.maximum() == 9296,
    "maximum = " .. tostring(stackProbe.maximum()))

  stackProbe.note(0)
  check("a genuine zero renders as 0B on the minimum, distinct from '-'",
    stackProbe.formatStackFields(3) == "stackMin=0B stackMax=9296B pubMax=3",
    "got: " .. stackProbe.formatStackFields(3))

  stackProbe.note(12000)
  check("a later higher reading raises the maximum and not the minimum",
    stackProbe.formatStackFields(0) == "stackMin=0B stackMax=12000B pubMax=0",
    "got: " .. stackProbe.formatStackFields(0))

  stackProbe.reset()
  check("reset() clears BOTH extremes",
    stackProbe.minimum() == nil and stackProbe.maximum() == nil,
    "min = " .. tostring(stackProbe.minimum()) ..
    " max = " .. tostring(stackProbe.maximum()))
  check("after reset the line renders as never-measured again",
    stackProbe.formatStackFields(0) == "stackMin=- stackMax=- pubMax=0",
    "got: " .. stackProbe.formatStackFields(0))
end

-- ── 7. The second sample point ─────────────────────────────────────────────
-- The case the first channel cannot decide. A single fixed call site has a
-- fixed depth, so its minimum, maximum and latest value are the same
-- measurement three times over: none of them knows how deep that call site
-- is. Only a second position can say it. These assertions are about that
-- channel being independent of the first, and about not lying when it has not
-- been read yet.
do
  if stackProbe == nil then
    -- Pre-change master has no such module at all. Report it as a failing
    -- check rather than indexing nil: a red that dies on a stack trace tells
    -- the reader nothing about which assertion failed.
    check("the paint channel exists", false,
      "lib/stack_probe.lua is absent -- pre-change master")
  else
    check("the paint channel starts unmeasured, and says so",
      stackProbe.formatPaintFields() == "paintNow=- paintMin=- paintMax=-",
      "got: " .. stackProbe.formatPaintFields())

    stackProbe.notePaint(9296)
    check("a paint reading is independent of the task's own zero",
      stackProbe.formatPaintFields() == "paintNow=9296B paintMin=9296B paintMax=9296B",
      "got: " .. stackProbe.formatPaintFields())
    check("and it did not move the task channel",
      stackProbe.formatStackFields(0) == "stackMin=- stackMax=- pubMax=0",
      "got: " .. stackProbe.formatStackFields(0))

    stackProbe.notePaint(0)
    check("the two channels can disagree, which is the whole point",
      stackProbe.formatPaintFields() == "paintNow=0B paintMin=0B paintMax=9296B",
      "got: " .. stackProbe.formatPaintFields())

    stackProbe.notePaint(nil)
    check("a missing field leaves the last paint reading standing",
      stackProbe.formatPaintFields() == "paintNow=0B paintMin=0B paintMax=9296B",
      "got: " .. stackProbe.formatPaintFields())

    stackProbe.reset()
    check("reset() clears the paint channel too, from the task's side",
      stackProbe.formatPaintFields() == "paintNow=- paintMin=- paintMax=-",
      "got: " .. stackProbe.formatPaintFields())
  end
end


out("")
out(string.format("%d checks, %d failed", checks, failures))
if failures > 0 then
  os.exit(1)
end

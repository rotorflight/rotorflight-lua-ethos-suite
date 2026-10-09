-- Behaviour check for the error isolation of the MSP queue (issue #2363).
--
-- Run it from the repository root:
--     lua5.4 bin/msp_queue/verify_queue_callback_guard.lua
--
-- What it drives, and why:
--   * The real tasks/msp/common.lua and tasks/msp/queue.lua, with a transport
--     stub that can be told to fail and a controllable clock. In the simulator
--     path a reply is delivered in the same tick it is queued, which makes the
--     callback cases deterministic; the transport case needs the real path.
--
-- Why a harness at all: a page's processReply/errorHandler runs inside the
-- background task's wakeup, and an error that leaves it is not reported to the
-- page -- it leaves the task. Nothing in the build or the package step reaches
-- that, and the failure is quiet: a page bug on one reply would stop the audio
-- alerts, the telemetry and the flight record with nothing to show for it.
--
-- Pinned:
--   * a processReply that raises does not escape, is printed, tells the page
--     through its errorHandler ("callback_error"), and the next message is
--     delivered;
--   * an errorHandler that raises does not escape either, and is printed;
--   * Queue:clear() tells every dropped message even if the first handler
--     raises;
--   * an error from the transport leaves Queue:wakeup() quietly, retires the
--     message with "queue_error", and the next message goes out -- which also
--     needs the TX buffer handed back;
--   * a callback that fails on every poll is printed once a second, with the
--     count of lines held back;
--   * a reply that does not fail behaves as before: delivered once, no error,
--     nothing printed;
--   * tasks/background.lua calls Queue:wakeup(), not processQueue() directly.
--
-- A check that cannot fail proves nothing, so three copies of the queue with one
-- guard stripped each are loaded and each has to let its error escape. If one of
-- those stops turning red, the instrument has gone blind.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"
local MSP = SUITE .. "/tasks/msp"

local checks, failures = 0, 0
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

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local content = f:read("*a")
  f:close()
  return (content:gsub("\r\n", "\n"))
end

-- Everything the queue prints, so the harness can say what was reported.
local lines = {}
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
  lines[#lines + 1] = table.concat(parts, " ")
end

local function linesMatching(text)
  local n = 0
  for _, line in ipairs(lines) do
    if line:find(text, 1, true) then n = n + 1 end
  end
  return n
end

-- Advances a little on every call so common.lua's bounded poll loops end;
-- jump() makes the explicit wall-clock steps.
local clock = {now = 0.0}
os.clock = function()
  local t = clock.now
  clock.now = t + 0.001
  return t
end

package.loaded["rfsuite.lib.require"] = function(name)
  if name == "lib/debug_log.lua" then
    return {
      print = function() end,
      mspEnabled = function() return false end,
      msp = function() end,
    }
  end
  error("unexpected dependency: " .. tostring(name))
end

-- A fresh module graph per scenario: common.lua keeps its buffers in upvalues,
-- and queue.lua reads the simulator flag once while being loaded.
local function newRig(opts)
  opts = opts or {}
  system = {getVersion = function() return {simulation = opts.sim == true} end}
  local common = dofile(MSP .. "/common.lua")
  local Queue
  if opts.source then
    Queue = assert(load(opts.source, "@" .. MSP .. "/queue.lua"))()
  else
    Queue = dofile(MSP .. "/queue.lua")
  end
  local transport = {maxTxBufferSize = 6, maxRxBufferSize = 6, sent = {}, failSend = false}
  function transport.mspSend(payload)
    if transport.failSend then error("transport exploded") end
    transport.sent[#transport.sent + 1] = payload
    return true
  end
  function transport.mspPoll() return nil end
  common.setTransport(transport)
  clock.now = 0.0
  lines = {}
  return {queue = Queue.new(common), transport = transport}
end

-- A message whose callbacks can be told to raise. In the simulator path it is
-- answered at once; without simulatorResponse it is refused, which is the
-- errorHandler path.
local function newMessage(cmd, opts)
  opts = opts or {}
  local m = {command = cmd, payload = {}, replies = {}, errors = {}}
  if not opts.noReply then m.simulatorResponse = {1, 2, 3} end
  m.processReply = function(_, buf)
    m.replies[#m.replies + 1] = buf
    if opts.failReply then error("page bug: nil index") end
  end
  m.errorHandler = function(reason)
    m.errors[#m.errors + 1] = reason
    if opts.failHandler then error("handler bug") end
  end
  return m
end

local function escapes(fn, ...)
  local ok = pcall(fn, ...)
  return not ok
end

out("MSP queue error isolation (issue #2363)")

-- A failing processReply.
do
  local rig = newRig({sim = true})
  local m1 = newMessage(1, {failReply = true})
  local m2 = newMessage(2)
  rig.queue:add(m1)
  rig.queue:add(m2)
  check("a processReply that raises does not escape",
    not escapes(rig.queue.processQueue, rig.queue))
  check("it is printed with its message",
    linesMatching("processReply failed: ") == 1 and linesMatching("page bug") == 1,
    table.concat(lines, " | "))
  check("the page is told through its errorHandler",
    #m1.errors == 1 and m1.errors[1] == "callback_error",
    "errors: " .. table.concat(m1.errors, ","))
  check("the next message is delivered on the next tick",
    not escapes(rig.queue.processQueue, rig.queue) and #m2.replies == 1 and #m2.errors == 0,
    #m2.replies .. " repl(ies), " .. #m2.errors .. " error(s)")
  check("and the queue is idle afterwards", rig.queue:isProcessed())
end

-- A failing errorHandler.
do
  local rig = newRig({sim = true})
  local m = newMessage(3, {noReply = true, failHandler = true})
  rig.queue:add(m)
  check("an errorHandler that raises does not escape",
    not escapes(rig.queue.processQueue, rig.queue))
  check("it is printed",
    linesMatching("errorHandler failed: ") == 1 and linesMatching("handler bug") == 1,
    table.concat(lines, " | "))
  check("the message was refused and the queue is idle",
    m.errors[1] == "no_response" and rig.queue:isProcessed(),
    "errors: " .. table.concat(m.errors, ","))
end

-- clear() with a first handler that raises.
do
  local rig = newRig({sim = true})
  local m1 = newMessage(4, {failHandler = true})
  local m2 = newMessage(5)
  local m3 = newMessage(6)
  rig.queue:add(m1); rig.queue:add(m2); rig.queue:add(m3)
  check("clear() does not escape a raising handler", not escapes(rig.queue.clear, rig.queue))
  check("every dropped message is still told",
    m1.errors[1] == "cleared" and m2.errors[1] == "cleared" and m3.errors[1] == "cleared",
    m1.errors[1] .. "/" .. tostring(m2.errors[1]) .. "/" .. tostring(m3.errors[1]))
  check("and the queue is empty", rig.queue:isProcessed())
end

-- An error from the transport.
do
  local rig = newRig({sim = false})
  local m1 = newMessage(7)
  local m2 = newMessage(8)
  rig.transport.failSend = true
  rig.queue:add(m1)
  check("a transport error does not escape Queue:wakeup()",
    not escapes(rig.queue.wakeup, rig.queue))
  check("it is printed",
    linesMatching("processQueue failed: ") == 1 and linesMatching("transport exploded") == 1,
    table.concat(lines, " | "))
  check("the message in flight is retired with queue_error",
    #m1.errors == 1 and m1.errors[1] == "queue_error" and rig.queue.current == nil,
    "errors: " .. table.concat(m1.errors, ","))
  rig.transport.failSend = false
  rig.queue:add(m2)
  rig.queue:wakeup()
  check("the next message goes out, so the TX buffer was handed back",
    #rig.transport.sent >= 1 and rig.queue.current == m2,
    #rig.transport.sent .. " frame(s) sent")
end

-- A callback that fails on every poll.
do
  local rig = newRig({sim = true})
  for i = 1, 5 do rig.queue:add(newMessage(10 + i, {failReply = true})) end
  for _ = 1, 5 do rig.queue:processQueue() end
  check("five failing replies in one second print one line",
    linesMatching("processReply failed: ") == 1, linesMatching("processReply failed: ") .. " line(s)")
  clock.now = clock.now + 2
  rig.queue:add(newMessage(20, {failReply = true}))
  rig.queue:processQueue()
  check("the next one after a second says how many were held back",
    linesMatching("processReply failed: ") == 2 and linesMatching("(+4 suppressed)") == 1,
    table.concat(lines, " | "))
end

-- A reply that does not fail.
do
  local rig = newRig({sim = true})
  local m = newMessage(30)
  rig.queue:add(m)
  rig.queue:wakeup()
  check("a reply that does not fail is delivered once, with no error",
    #m.replies == 1 and #m.errors == 0, #m.replies .. " repl(ies), " .. #m.errors .. " error(s)")
  check("and nothing is printed", #lines == 0, table.concat(lines, " | "))
end

-- The background task goes through the guarded entry point.
do
  local source = readFile(SUITE .. "/tasks/background.lua")
  check("tasks/background.lua calls Queue:wakeup()", source:find("mspQueue:wakeup()", 1, true) ~= nil)
  check("and no longer calls processQueue() directly",
    source:find("mspQueue:processQueue()", 1, true) == nil)
end

-- Can-fail: each guard stripped from a copy of the queue has to let its error out.
do
  local source = readFile(MSP .. "/queue.lua")

  local noReplyGuard = source:gsub("pcall%(msg%.processReply, msg, buf%)",
    "true, msg.processReply(msg, buf)", 1)
  check("the processReply guard could be located", noReplyGuard ~= source)
  local rig = newRig({sim = true, source = noReplyGuard})
  rig.queue:add(newMessage(40, {failReply = true}))
  check("without the processReply guard the error escapes (this check can go red)",
    escapes(rig.queue.processQueue, rig.queue))

  local noHandlerGuard = source:gsub("pcall%(handler, reason%)", "true, handler(reason)", 1)
  check("the errorHandler guard could be located", noHandlerGuard ~= source)
  rig = newRig({sim = true, source = noHandlerGuard})
  rig.queue:add(newMessage(41, {noReply = true, failHandler = true}))
  check("without the errorHandler guard the error escapes (this check can go red)",
    escapes(rig.queue.processQueue, rig.queue))

  local noWakeupGuard = source:gsub("pcall%(self%.processQueue, self%)",
    "true, self:processQueue()", 1)
  check("the wakeup guard could be located", noWakeupGuard ~= source)
  rig = newRig({sim = false, source = noWakeupGuard})
  rig.transport.failSend = true
  rig.queue:add(newMessage(42))
  check("without the wakeup guard the transport error escapes (this check can go red)",
    escapes(rig.queue.wakeup, rig.queue))
end

print = out
out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

-- Behaviour check for the background-task heartbeat shown on Diagnostics / Info (#2518).
--
-- Run it from the repository root:
--     lua5.4 bin/bgtask_status/verify_bgtask_status.lua
--
-- What it drives, and why:
--   * lib/bgtask_status.lua is the whole decision -- running, stale or none,
--     the heartbeat age and the revival count -- and has no dependency at all:
--     no form, no bus, no os.clock. The page only wires it to the bus and the
--     field values, so every case runs here rather than on a radio.
--   * The stale threshold is a second copy of app/tool.lua's TASK_STATUS_TIMEOUT.
--     The last check reads that file, so the page and the one-shot alert cannot
--     disagree about what "stale" means without this check going red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."

local failures = 0
local checks = 0

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local status = dofile(ROOT .. "/src/rfsuite/lib/bgtask_status.lua")

local NOW = 100.0

print("state")

check("no status yet is none", status.state(nil, NOW) == "none")
check("a status without an updatedAt is none", status.state({running = true}, NOW) == "none")
check("a recent heartbeat is running", status.state({running = true, updatedAt = NOW - 0.4}, NOW) == "running")
check("a heartbeat exactly at the threshold is still running",
  status.state({running = true, updatedAt = NOW - 3.0}, NOW) == "running")
check("a heartbeat older than the threshold is stale",
  status.state({running = true, updatedAt = NOW - 3.5}, NOW) == "stale")
check("a string updatedAt is read as a number",
  status.state({running = true, updatedAt = tostring(NOW - 0.1)}, NOW) == "running")
check("a heartbeat in the future counts as fresh",
  status.state({running = true, updatedAt = NOW + 0.2}, NOW) == "running")

print("heartbeat text")

check("no status shows a dash", status.heartbeatText(nil, NOW) == "-", status.heartbeatText(nil, NOW))
check("a 0.4 s old heartbeat shows one decimal",
  status.heartbeatText({updatedAt = NOW - 0.4}, NOW) == "0.4 s", status.heartbeatText({updatedAt = NOW - 0.4}, NOW))
check("a 12.0 s old heartbeat shows one decimal",
  status.heartbeatText({updatedAt = NOW - 12.0}, NOW) == "12.0 s",
  status.heartbeatText({updatedAt = NOW - 12.0}, NOW))
check("a future heartbeat shows zero, not a negative age",
  status.heartbeatText({updatedAt = NOW + 0.2}, NOW) == "0.0 s", status.heartbeatText({updatedAt = NOW + 0.2}, NOW))

print("revivals text")

check("no status shows a dash", status.revivalsText(nil) == "-")
check("a status without a revivals field shows a dash", status.revivalsText({running = true}) == "-")
check("zero revivals shows zero", status.revivalsText({revivals = 0}) == "0")
check("seven revivals shows seven", status.revivalsText({revivals = 7}) == "7")
check("a float count is shown as a whole number", status.revivalsText({revivals = 2.0}) == "2",
  status.revivalsText({revivals = 2.0}))

print("threshold agrees with app/tool.lua")

do
  local tool = io.open(ROOT .. "/src/rfsuite/app/tool.lua", "rb")
  local text = tool and tool:read("*a") or ""
  if tool then tool:close() end
  check("the stale threshold is the tool's TASK_STATUS_TIMEOUT",
    text:find("TASK_STATUS_TIMEOUT = " .. tostring(status.STALE_SECONDS), 1, true) ~= nil,
    "app/tool.lua does not declare TASK_STATUS_TIMEOUT = " .. tostring(status.STALE_SECONDS))
end

print("info page wiring")

-- Runs the real page against the real bus, with form and header stubbed, and a
-- clock the check steps by hand. Everything the harness replaces is put back.
do
  local SRC = ROOT .. "/src/rfsuite"
  local realClock = os.clock
  local savedForm, savedSystem = form, system
  local savedRequire = package.loaded["rfsuite.lib.require"]
  local clock = 10.0
  local widgets = {}
  local headerOpts = nil
  local backed = false

  os.clock = function() return clock end
  form = {
    clear = function() widgets = {} end,
    addLine = function(label) return {label = label} end,
    addStaticText = function(line, _, text)
      local w = {label = line.label, text = text}
      function w:value(v) if v ~= nil then self.text = v end; return self.text end
      widgets[#widgets + 1] = w
      return w
    end,
  }
  system = {getVersion = function() return {} end}
  local function requireModule(name)
    if name == "app/header.lua" then
      return {build = function(_, opts) headerOpts = opts; return {focusReload = function() end} end}
    elseif name == "app/close_key.lua" then
      return {shouldHandleClose = function() return false end}
    end
    return assert(loadfile(SRC .. "/" .. name))()
  end
  package.loaded["rfsuite.lib.require"] = requireModule
  local bus = requireModule("lib/bus.lua")

  local function value(tag)
    for _, w in ipairs(widgets) do
      if w.label == tag then return w.text end
    end
    return "<no widget>"
  end

  -- The bus keeps its subscriber lists in an upvalue of subscribe(); reading it
  -- is the only way to see whether a page removed its handler.
  local function subscriberCount(topic)
    local i = 1
    while true do
      local name, val = debug.getupvalue(bus.subscribe, i)
      if not name then return nil end
      if name == "subscribers" then return #(val[topic] or {}) end
      i = i + 1
    end
  end

  local NAME = "@i18n(app.modules.info.bgtask_name)@"
  local HB = "@i18n(app.modules.info.bgtask_heartbeat)@"
  local REV = "@i18n(app.modules.info.bgtask_revivals)@"
  local RUN = "@i18n(app.modules.info.bgtask_running)@"
  local STALE = "@i18n(app.modules.info.bgtask_stale)@"

  -- A heartbeat published before the page opens is replayed on subscribe.
  bus.publish("task.status", {running = true, updatedAt = 9.8, revivals = 3})
  local beforeOpen = subscriberCount("task.status")

  local info = assert(loadfile(SRC .. "/app/pages/diagnostics_info.lua"))()
  local wake = nil
  info.open({
    setWakeupHandler = function(fn) wake = fn end,
    setCleanupHandler = function() end,
    onBack = function() backed = true end,
  })

  check("opening adds exactly one task.status subscriber", subscriberCount("task.status") == beforeOpen + 1,
    subscriberCount("task.status"))
  check("a replayed heartbeat shows running", value(NAME) == RUN, value(NAME))
  check("a replayed heartbeat shows its age", value(HB) == "0.2 s", value(HB))
  check("a replayed heartbeat shows its revivals", value(REV) == "3", value(REV))

  clock = 11.0
  wake()
  check("wakeup refreshes the age without an event", value(HB) == "1.2 s", value(HB))

  clock = 15.0
  wake()
  check("no heartbeat for over 3 s turns the state stale", value(NAME) == STALE, value(NAME))
  check("the age keeps counting while stale", value(HB) == "5.2 s", value(HB))

  bus.publish("task.status", {running = true, updatedAt = 15.0, revivals = 4})
  check("a fresh event brings the state back to running", value(NAME) == RUN, value(NAME))
  check("a fresh event updates the revivals", value(REV) == "4", value(REV))
  check("a fresh event resets the age", value(HB) == "0.0 s", value(HB))

  -- Leaving through the header's back action must remove the page's handler,
  -- so a later heartbeat is not written into a page nobody is looking at.
  check("the header back action is wired", headerOpts ~= nil and type(headerOpts.onBack) == "function")
  headerOpts.onBack()
  check("the page reports back", backed)
  check("leaving removes the task.status subscriber", subscriberCount("task.status") == beforeOpen,
    subscriberCount("task.status"))
  bus.publish("task.status", {running = true, updatedAt = 17.0, revivals = 9})
  check("after leaving, a new revival count is not written", value(REV) == "4", value(REV))

  os.clock = realClock
  form, system = savedForm, savedSystem
  package.loaded["rfsuite.lib.require"] = savedRequire
end

print(string.rep("-", 60))
print(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  print("")
  print("FAILED")
  os.exit(1)
end
print("ALL CHECKS PASSED")

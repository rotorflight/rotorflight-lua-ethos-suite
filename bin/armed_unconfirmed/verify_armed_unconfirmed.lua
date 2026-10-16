-- Behaviour check for #2548: a nil isArmed is "not known yet", not "disarmed".
--
-- Run it:
--     lua5.4 bin/armed_unconfirmed/verify_armed_unconfirmed.lua
--     lua5.4 bin/armed_unconfirmed/verify_armed_unconfirmed.lua --self-test
--
-- What it drives, and why:
--   * The real src/rfsuite/tasks/session.lua, through session.wakeup() and the
--     session.update snapshot it publishes. A disconnect sets isArmed to nil;
--     the latch armedUnconfirmed must carry "the model was armed" across that
--     window and clear only on a fresh "disarmed" answer.
--   * The real src/rfsuite/app/page_runtime.lua, through PageRuntime.canSave().
--     The reboot-after-save gate in performSave() uses the same predicate, but
--     performSave() is not driven here: it needs the whole save flow. That gate
--     is covered by reading the code, not by this harness.
--
-- Which checks are gates, and how --self-test proves it:
--   * The latch checks go red on a session.lua with the latch assignment
--     removed.
--   * The canSave check goes red on a page_runtime.lua whose gate is spliced
--     back to `self.isArmed == true`.
--   Controls: an FC that never reports arm flags stays usable, and a page that
--   was never armed saves normally.
--
-- Not covered here: syncStatsWithFc() is a local function in session.lua with
-- no exported seam. Its gate uses the same armedOrUnconfirmed() predicate, and
-- that predicate is exercised by the session checks below, but the stats write
-- itself is not driven.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local TASKS = SUITE .. "/tasks"
local APP = SUITE .. "/app"

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

-- ---------------------------------------------------------------------------
-- Environment shared by session.lua and page_runtime.lua.
-- ---------------------------------------------------------------------------

local SUITE_PREFIX = SUITE .. "/"
package.path = SUITE_PREFIX .. "?.lua;" .. package.path
_G.PREFIX = SUITE_PREFIX

local realLoadfile = loadfile
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (SUITE_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

_G.package = package
_G.os = os
_G.math = math
_G.string = string
_G.table = table
_G.model = { name = function() return "Test" end, set = function() end, get = function() return 0 end }
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }
_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
  getSource = function() return { state = function() return nil end } end,
}
CATEGORY_SYSTEM_EVENT, TELEMETRY_ACTIVE = 2, 0
SMARTFUEL_APP_ID, UNIT_PERCENT = 0x1A00, "%"

-- Anything that is not a module under test: a table whose every field is a
-- function returning an empty table. Load-time code only stores these.
local function anyStub()
  return setmetatable({}, { __index = function() return function() return {} end end })
end

local published = {}
local function installRequireStub()
  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/bus.lua" then
      return {
        publish = function(topic, payload) published[#published + 1] = { topic, payload } end,
        subscribe = function() end,
      }
    elseif name == "lib/debug_log.lua" then
      return { print = function() end, msp = function() end, format = function() end }
    elseif name == "tasks/flight_timer.lua" then
      return dofile(TASKS .. "/flight_timer.lua")
    elseif name == "lib/settings_store.lua" then
      return {
        load = function() return {} end,
        simulatedApiVersionMode = function() return false end,
        syncNameEnabled = function() return false end,
      }
    elseif name == "lib/model_preferences.lua" then
      return {
        load = function() return {} end, save = function() end,
        setSmartfuelModelType = function() end, setStats = function() end,
        setTimerTarget = function() end,
        smartfuelModelType = function() return 0 end,
        stats = function() return {} end, timerTarget = function() return 300 end,
      }
    elseif name == "lib/smartfuel_calc.lua" or name == "lib/diy_sensor.lua" then
      -- setConnected()'s disconnect branch resets these instances.
      return { new = function() return { reset = function() end, set = function() end } end }
    elseif name == "lib/battery_profile_index.lua" then
      return { fromTelemetrySensor = function() return nil end, index0 = function() return nil end }
    end
    return anyStub()
  end
end

-- ---------------------------------------------------------------------------
-- Part A: the session latch, through the real session.lua.
-- ---------------------------------------------------------------------------

-- `source` lets --self-test load a spliced copy of session.lua.
local function loadSession(source)
  installRequireStub()
  published = {}
  local spyQueue = {
    add = function() return true end,
    clear = function() end,
  }
  local armflags = nil
  local telemetryActive = false
  -- session.wakeup() reads the link through system.getSource(...):state(), and
  -- resolves that source when it loads, so the stub must exist before the load.
  system.getSource = function() return { state = function() return telemetryActive end } end

  local session
  if source then
    session = assert(load(source, "@session_under_test"))()
  else
    session = dofile(TASKS .. "/session.lua")
  end
  session.setTelemetrySensors({
    getValue = function(_, name)
      if name == "armflags" then return armflags end
      return nil
    end,
    reset = function() end,
  })

  local function lastSnapshot()
    for i = #published, 1, -1 do
      if published[i][1] == "session.update" then return published[i][2] end
    end
    return nil
  end

  return {
    setArmflags = function(value) armflags = value end,
    tick = function(active)
      telemetryActive = active
      session.wakeup(spyQueue, "sport", nil, { telemetryState = function() return active end })
    end,
    snapshot = lastSnapshot,
  }
end

local function runSessionChecks(source)
  -- A1: armed, then disconnected. The window must keep "armed" latched.
  do
    local rig = loadSession(source)
    rig.setArmflags(1)
    rig.tick(true)
    local s = rig.snapshot()
    check("A1 armed read: isArmed is true and the latch is set",
      s and s.isArmed == true and s.armedUnconfirmed == true,
      s and ("isArmed=" .. tostring(s.isArmed) .. " latch=" .. tostring(s.armedUnconfirmed)) or "no snapshot")

    rig.tick(false)
    s = rig.snapshot()
    check("A2 disconnect: isArmed is nil but the latch still says armed (#2548)",
      s and s.isArmed == nil and s.armedUnconfirmed == true,
      s and ("isArmed=" .. tostring(s.isArmed) .. " latch=" .. tostring(s.armedUnconfirmed)) or "no snapshot")

    -- Reconnect, arm flags not answered yet: still unknown, latch unchanged.
    rig.setArmflags(nil)
    rig.tick(true)
    s = rig.snapshot()
    check("A3 reconnect without an answer: latch survives",
      s and s.isArmed == nil and s.armedUnconfirmed == true,
      s and ("isArmed=" .. tostring(s.isArmed) .. " latch=" .. tostring(s.armedUnconfirmed)) or "no snapshot")

    -- A fresh disarmed answer clears the latch.
    rig.setArmflags(0)
    rig.tick(true)
    s = rig.snapshot()
    check("A4 a fresh disarmed answer clears the latch",
      s and s.isArmed == false and s.armedUnconfirmed == false,
      s and ("isArmed=" .. tostring(s.isArmed) .. " latch=" .. tostring(s.armedUnconfirmed)) or "no snapshot")
  end

  -- A5 control: an FC that never reports arm flags is never latched, so a
  -- disconnect does not lock it out of the writes.
  do
    local rig = loadSession(source)
    rig.setArmflags(nil)
    rig.tick(true)
    rig.tick(false)
    local s = rig.snapshot()
    -- "not latched" means false or absent: the control checks behaviour, not
    -- whether the field exists, so it stays green on a tree without the latch.
    check("A5 control: an FC that never reports arm flags is not latched",
      s and s.isArmed == nil and not s.armedUnconfirmed,
      s and ("isArmed=" .. tostring(s.isArmed) .. " latch=" .. tostring(s.armedUnconfirmed)) or "no snapshot")
  end
end

-- ---------------------------------------------------------------------------
-- Part B: the page gate, through the real page_runtime.lua.
-- ---------------------------------------------------------------------------

local function loadPageRuntime(source)
  installRequireStub()
  if source then
    return assert(load(source, "@page_runtime_under_test"))()
  end
  return dofile(APP .. "/page_runtime.lua")
end

local function runPageChecks(PageRuntime)
  local function page(fields)
    local p = {
      isMspPage = true, localSettings = false,
      loaded = true, dirty = true, busy = false,
      disposed = false, activeDialog = nil,
    }
    for k, v in pairs(fields) do p[k] = v end
    return p
  end

  -- B1 is the #2548 case: nil is not "disarmed" once the latch is set.
  check("B1 a disconnected armed page is not saveable (#2548)",
    PageRuntime.canSave(page({ isArmed = nil, armedUnconfirmed = true })) == false)
  check("B2 an armed page is not saveable",
    PageRuntime.canSave(page({ isArmed = true, armedUnconfirmed = true })) == false)
  check("B3 control: a disarmed page is saveable",
    PageRuntime.canSave(page({ isArmed = false, armedUnconfirmed = false })) == true)
  check("B4 control: an FC that never reported arm flags is saveable",
    PageRuntime.canSave(page({ isArmed = nil, armedUnconfirmed = false })) == true)
  check("B5 control: a local-settings page stays saveable while armed",
    PageRuntime.canSave(page({ isArmed = true, armedUnconfirmed = true, localSettings = true })) == true)
end

-- ---------------------------------------------------------------------------
-- Run.
-- ---------------------------------------------------------------------------

local function readFile(path)
  local f = assert(io.open(path, "r"))
  local source = f:read("*a")
  f:close()
  return source
end

local selfTest = false
for _, arg in ipairs(arg or {}) do
  if arg == "--self-test" then selfTest = true end
end

print("part A: session latch (tasks/session.lua)")
runSessionChecks(nil)

print("part B: page save gate (app/page_runtime.lua)")
runPageChecks(loadPageRuntime(nil))

if selfTest then
  print("")
  print("--self-test: the gates below must be able to go red")

  -- Remove the latch assignment in updateArmState: A1..A4 must go red.
  local sessionSource = readFile(TASKS .. "/session.lua")
  -- Lua sources are CRLF (.gitattributes: *.lua text eol=crlf).
  local spliced, n = sessionSource:gsub("session%.armedUnconfirmed = true\r\n", "-- spliced\r\n", 1)
  assert(n == 1, "session splice did not apply")
  print("self-test: session without the latch set")
  local before = failures
  runSessionChecks(spliced)
  local redSession = failures > before
  failures = before -- the red checks above are expected, so they are not counted
  check("the latch checks go red without the latch set", redSession)

  -- Put the pre-fix gate back into canSave: B1 must go red.
  local runtimeSource = readFile(APP .. "/page_runtime.lua")
  local splicedRuntime, m = runtimeSource:gsub(
    "and armedOrUnconfirmed%(self%) then", "and self.isArmed == true then", 1)
  assert(m == 1, "page_runtime splice did not apply")
  print("self-test: page_runtime with the pre-fix gate")
  package.loaded["rfsuite.app.page_runtime"] = nil
  local preFix = loadPageRuntime(splicedRuntime)
  local beforePage = failures
  runPageChecks(preFix)
  local redPage = failures > beforePage
  failures = beforePage -- the red checks above are expected, so they are not counted
  check("the save-gate check goes red on the pre-fix gate", redPage)
  print("self-test done: expected FAIL lines above are not counted")
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end

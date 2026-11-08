-- Behaviour check for the flight controller's silence, as tasks/session.lua decides
-- it (#2664): the RF link is up, and the flight controller has stopped sending.
--
-- Run it:
--     lua5.4 bin/fc_silence/verify_fc_silence.lua
--     lua5.4 bin/fc_silence/verify_fc_silence.lua --self-test
--
-- The claim: with CRSF, session.telemetryFcSilent is set once no flight controller
-- frame has arrived for TELEMETRY_QUIET_SECONDS (6 s) while the link is up, cleared
-- by the next frame, and published on each edge only. Nothing is watched on a
-- protocol other than CRSF, and the silence is counted from the link's first wakeup
-- when no frame has arrived at all.
--
-- How it is measured: tasks/session.lua is loaded with its Ethos globals and its
-- module loader stubbed (as bin/handshake_gate does). The real session runs; the
-- CRSF drain (tasks/elrs_sensors.lua) is a stand-in that returns the time it last
-- took a frame, which is what the real drain returns. A tick is one wakeup of the
-- session, and the clock is controlled.
--
-- --self-test removes the 6 s from a copy of session.lua and requires the silence
-- check to go red on it.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local TASKS = SRC .. "/tasks"
local SESSION_PATH = TASKS .. "/session.lua"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  print(string.format("  %s  %s%s", ok and "ok  " or "FAIL", label, (not ok and detail) and ("  (" .. detail .. ")") or ""))
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

-- Modules the session loads for real, so the command ids and builders are the
-- production ones. Everything else is a stand-in.
local REAL = {
  ["lib/mspcodec.lua"] = true,
  ["lib/msp_api_version.lua"] = true,
  ["lib/msp_handshake.lua"] = true,
  ["lib/msp_battery.lua"] = true,
  ["lib/msp_governor_config.lua"] = true,
  ["lib/msp_rx_map.lua"] = true,
  ["lib/msp_telemetry_config.lua"] = true,
  ["lib/msp_dataflash_summary.lua"] = true,
  ["lib/msp_flight_stats.lua"] = true,
  ["lib/msp_eeprom.lua"] = true,
  ["tasks/flight_timer.lua"] = true,
}

-- The session's clock. Each call advances it a little, as the handshake harness does.
local clock = {now = 100.0, step = 0.001}
local realClock = os.clock
os.clock = function()
  local t = clock.now
  clock.now = t + clock.step
  return t
end

local function newRig(opts)
  opts = opts or {}
  local active = true
  local published = {}
  local spyQueue = {
    added = {},
    add = function(self, message) self.added[#self.added + 1] = message; return true end,
    clear = function() end,
  }

  -- The CRSF drain stand-in: it returns the time it last took a frame, as the real
  -- tasks/elrs_sensors.lua wakeup() does. `pending` is set by the test when a frame
  -- arrives in the tick that follows.
  local drain = {pending = nil, wakeups = 0}
  function drain.wakeup()
    drain.wakeups = drain.wakeups + 1
    local at = drain.pending
    drain.pending = nil
    return false, at
  end
  function drain.reset() end

  local realModules = {}
  local function realModule(name)
    if realModules[name] == nil then
      realModules[name] = assert(loadfile(SRC .. "/" .. name))()
    end
    return realModules[name]
  end

  package.loaded["rfsuite.lib.require"] = function(name)
    if name == "lib/flight_stats.lua" then return dofile(TASKS .. "/../lib/flight_stats.lua") end
    if REAL[name] then return realModule(name) end
    if name == "tasks/elrs_sensors.lua" then return drain end
    if name == "lib/bus.lua" then
      return {
        publish = function(topic, payload) published[#published + 1] = {topic, payload} end,
        subscribe = function() end,
      }
    elseif name == "lib/debug_log.lua" then
      return {print = function() end, msp = function() end, format = function() end,
        mspEnabled = function() return false end}
    elseif name == "lib/settings_store.lua" then
      return {
        load = function() return {} end,
        simulatedApiVersionMode = function() return false end,
        syncNameEnabled = function() return false end,
      }
    elseif name == "lib/battery_profile_index.lua" then
      return {fromTelemetrySensor = function() return nil end, index0 = function() return nil end}
    elseif name == "lib/smartfuel_reserve.lua" then
      return {applyPercent = function() end}
    elseif name == "lib/smartfuel_calc.lua" or name == "lib/diy_sensor.lua" then
      return {new = function() return {reset = function() end} end}
    elseif name == "lib/model_preferences.lua" then
      return {
        load = function() return {} end, save = function() end,
        setSmartfuelModelType = function() end, setStats = function() end,
        setTimerTarget = function() end,
        smartfuelModelType = function() return 0 end,
        stats = function() return {} end, timerTarget = function() return 300 end,
      }
    end
    -- Everything else contributes builders the session only passes to the queue.
    return setmetatable({}, {__index = function()
      return function()
        return {command = 0, payload = {}, processReply = function() end, errorHandler = function() end}
      end
    end})
  end

  CATEGORY_SYSTEM_EVENT, TELEMETRY_ACTIVE = 2, 0
  SMARTFUEL_APP_ID, UNIT_PERCENT = 0x1A00, "%"
  system = {
    getVersion = function() return {simulation = false} end,
    getSource = function() return {state = function() return active end} end,
    playFile = function() end,
    playHaptic = function() end,
  }
  model = {name = function() return "Test" end, set = function() end}

  local source = opts.source or readFile(SESSION_PATH)
  local session = assert(load(source, "@" .. SESSION_PATH))()
  session.setTelemetrySensors({getValue = function() return nil end, reset = function() end})

  local transport = {}
  local rig = {session = session, queue = spyQueue, drain = drain}
  -- One wakeup of the session. `value` is the RF link state the tick sees (omitted
  -- keeps the previous one); `protocol` is the telemetry protocol.
  function rig.tick(value, protocol)
    if value ~= nil then active = value end
    session.wakeup(spyQueue, protocol or "crsf", transport, {telemetryState = function() return active end})
  end
  -- A flight controller frame arrives now: the next tick's drain takes it.
  function rig.frame() drain.pending = clock.now end
  function rig.advance(seconds) clock.now = clock.now + seconds end
  function rig.now() return clock.now end
  -- The session's latest published snapshot.
  function rig.lastSnapshot()
    for i = #published, 1, -1 do
      if published[i][1] == "session.update" then return published[i][2] end
    end
    return nil
  end
  function rig.publishedCount() return #published end
  return rig
end

local function silent(rig)
  local snap = rig.lastSnapshot()
  return snap ~= nil and snap.telemetryFcSilent == true
end

-- ---------------------------------------------------------------------------
-- 1. Silence from the link's own start, and the 6 s bound.
-- ---------------------------------------------------------------------------
print("the silence and its 6 s bound")
do
  local rig = newRig()
  rig.tick(true)                       -- the link comes up
  rig.advance(5.0)
  rig.tick()
  check("5 s after the link came up with no frame, not yet silent", not silent(rig),
    "silent at 5 s")
  rig.advance(1.5)
  rig.tick()
  check("6 s after the link came up with no frame, silent", silent(rig),
    "not silent at 6.5 s")
end

-- ---------------------------------------------------------------------------
-- 2. Frames keep it awake.
-- ---------------------------------------------------------------------------
do
  local rig = newRig()
  rig.tick(true)
  local everSilent = false
  for _ = 1, 30 do
    rig.frame()
    rig.advance(1.0)
    rig.tick()
    if silent(rig) then everSilent = true end
  end
  check("a frame at least every second keeps it awake for 30 s", not everSilent)
end

-- ---------------------------------------------------------------------------
-- 3. The next frame ends a silence, and is published as the edge.
-- ---------------------------------------------------------------------------
do
  local rig = newRig()
  rig.tick(true)
  rig.advance(7.0)
  rig.tick()
  check("silent after 7 s with no frame", silent(rig))
  rig.frame()
  rig.advance(0.5)
  rig.tick()
  check("the next frame ends the silence", not silent(rig),
    "still silent")
  local snap = rig.lastSnapshot()
  check("the end of the silence is published as cleared",
    snap ~= nil and snap.telemetryFcSilent == nil, "snapshot flag=" .. tostring(snap and snap.telemetryFcSilent))
end

-- ---------------------------------------------------------------------------
-- 4. The silence is published on its edge, and not on every tick it stands.
-- ---------------------------------------------------------------------------
do
  local rig = newRig()
  rig.tick(true)
  rig.advance(6.5)
  rig.tick()
  local before = rig.publishedCount()
  for _ = 1, 10 do
    rig.advance(1.0)
    rig.tick()
  end
  check("a silence that stands for 10 more seconds does not publish again",
    rig.publishedCount() == before, "publications during the silence: " .. (rig.publishedCount() - before))
end

-- ---------------------------------------------------------------------------
-- 5. Only CRSF is watched: another protocol never reads as silent.
-- ---------------------------------------------------------------------------
do
  local rig = newRig()
  rig.tick(true, "sport")
  rig.advance(20.0)
  rig.tick(nil, "sport")
  check("on a protocol other than CRSF no silence is ever reported", not silent(rig))
end

-- ---------------------------------------------------------------------------
-- 6. A link that drops clears the silence; a reconnect counts from its own start.
-- ---------------------------------------------------------------------------
do
  local rig = newRig()
  rig.tick(true)
  rig.advance(7.0)
  rig.tick()
  check("silent before the link drops", silent(rig))
  rig.tick(false)
  check("a link that drops clears the silence", not silent(rig),
    "still silent after the drop")
  rig.tick(true)
  rig.advance(3.0)
  rig.tick()
  check("3 s after a reconnect, with no frame yet, not silent again", not silent(rig),
    "silent 3 s after reconnect")
  rig.advance(3.5)
  rig.tick()
  check("6 s after the reconnect, with no frame, silent again", silent(rig),
    "not silent 6.5 s after reconnect")
end

-- ---------------------------------------------------------------------------
-- self-test: the silence check must be able to go red.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the silence check must go red without the bound")
  local source = readFile(SESSION_PATH)
  local mutated, replacements = source:gsub("local TELEMETRY_QUIET_SECONDS = 6\r?\n", "local TELEMETRY_QUIET_SECONDS = 1e9\n", 1)
  check("self-test: the silence bound was found in session.lua exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    local rig = newRig({source = mutated})
    rig.tick(true)
    rig.advance(7.0)
    rig.tick()
    check("self-test: without the bound the silence is never reported", not silent(rig),
      "silent on the sabotaged copy")
  end
end

os.clock = realClock
print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

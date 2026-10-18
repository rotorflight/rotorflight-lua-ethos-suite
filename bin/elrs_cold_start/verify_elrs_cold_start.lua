-- Behaviour check for the ELRS cold start (issue #2436).
--
-- Run it:
--     lua5.4 bin/elrs_cold_start/verify_elrs_cold_start.lua
--
-- What it drives, and why:
--   * tasks/elrs_sensors.lua is loaded fresh for each scenario (dofile), with
--     every dependency stubbed: the decoder table is a factory that counts its
--     loads and can be told to fail, the sensors record what they are given,
--     and the transport hands back a queued backlog of real frame bytes.
--   * The cold start is the first wakeup after a connection. Before the fix it
--     loaded lib/elrs_sensor_table.lua and popped in the same pass, so the
--     module load sat inside the drain budget. The fix makes that pass a load
--     only; decoding starts on the next wakeup.
--
-- What it pins:
--   * the cold-start pass loads the table once and pops nothing;
--   * the next pass decodes the backlog, and the relevant-SID set is in place
--     before its first pop, so an irrelevant SID is not published;
--   * steady state is unchanged: a backlog still drains at most
--     MAX_FRAMES_PER_WAKEUP frames per wakeup and asks for a retry;
--   * a table load that fails is asked for again on the next wakeup;
--   * can-fail: a copy of the module with the cold-start return removed pops
--     on its first pass, and the cold-start check goes red for it.
--
-- The desktop Lua clock is real here: the frame cap, not the deadline, bounds
-- every drain below, so the checks do not depend on how fast the host is.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local TASKS = ROOT .. "/src/rfsuite/tasks"

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
-- Environment
-- ---------------------------------------------------------------------------

local RELEVANT_SLOT = 0x0A01
local RELEVANT_SID = 0x1030
local OTHER_SID = 0x1031

-- Stands in for lib/elrs_sid_lookup.lua: a telemetry slot maps to its SIDs.
local sidLookup = { [RELEVANT_SLOT] = { RELEVANT_SID } }

local tableLoads = 0
local tableFailuresLeft = 0
local published = {}

local DiySensor = {}
DiySensor.__index = DiySensor
function DiySensor.new(appId)
  return setmetatable({ appId = appId }, DiySensor)
end
function DiySensor:set(value)
  published[#published + 1] = { appId = self.appId, value = value }
end
function DiySensor:refresh() end
function DiySensor:reset() end

-- A frame is 2 address bytes, a frame id, then (U16 sid, one value byte).
local function frame(sid, value)
  return { 0x00, 0x00, 0x11, (sid >> 8) & 0xFF, sid & 0xFF, value }
end

-- A (U16 sid, value) pair is all parseFrame() needs from the decode primitives.
local decodePrimitives = {
  decU16 = function(data, pos)
    return (data[pos] or 0) * 256 + (data[pos + 1] or 0), pos + 2
  end,
}

local function decodeOneByte(data, pos)
  return data[pos], pos + 1
end

package.loaded["rfsuite.lib.require"] = function(name)
  if name == "lib/debug_log.lua" then
    return { print = function() end }
  end
  if name == "lib/elrs_sid_lookup.lua" then
    return sidLookup
  end
  if name == "lib/elrs_decode_primitives.lua" then
    return decodePrimitives
  end
  if name == "lib/diy_sensor.lua" then
    return DiySensor
  end
  if name == "lib/elrs_sensor_table.lua" then
    return function()
      tableLoads = tableLoads + 1
      if tableFailuresLeft > 0 then
        tableFailuresLeft = tableFailuresLeft - 1
        error("simulated table load failure")
      end
      return {
        [RELEVANT_SID] = { name = "Relevant", unit = 0, prec = 0, dec = decodeOneByte },
        [OTHER_SID] = { name = "Other", unit = 0, prec = 0, dec = decodeOneByte },
      }
    end
  end
  error("unexpected dependency: " .. tostring(name))
end

local function freshModule()
  tableLoads = 0
  tableFailuresLeft = 0
  published = {}
  return dofile(TASKS .. "/elrs_sensors.lua")
end

-- A transport whose custom-telemetry queue is a list of frames.
local function newTransport(frames)
  local t = { queue = frames, pops = 0 }
  function t.popCustomTelemetryFrame()
    if #t.queue == 0 then return nil end
    t.pops = t.pops + 1
    return 0x88, table.remove(t.queue, 1)
  end
  return t
end

local function backlog(sid, n)
  local frames = {}
  for i = 1, n do frames[i] = frame(sid, i) end
  return frames
end

local SLOTS = { RELEVANT_SLOT }

-- ---------------------------------------------------------------------------
-- 1. The cold start loads the table and pops nothing
-- ---------------------------------------------------------------------------

local MAX_FRAMES = 6

do
  local elrs = freshModule()
  local transport = newTransport(backlog(RELEVANT_SID, 3))
  local retry = elrs.wakeup(transport, SLOTS)

  check("the cold-start pass asks for no retry", retry == false, tostring(retry))
  check("the cold-start pass pops nothing", transport.pops == 0,
    "pops=" .. transport.pops)
  check("the cold-start pass loads the decoder table once", tableLoads == 1,
    "loads=" .. tableLoads)
  check("the cold-start pass publishes nothing", #published == 0,
    "published=" .. #published)
  check("the backlog waits in the queue for the next pass", #transport.queue == 3,
    "queued=" .. #transport.queue)
end

-- ---------------------------------------------------------------------------
-- 2. The next pass decodes the backlog
-- ---------------------------------------------------------------------------

do
  local elrs = freshModule()
  local transport = newTransport(backlog(RELEVANT_SID, 3))
  elrs.wakeup(transport, SLOTS)
  local retry = elrs.wakeup(transport, SLOTS)

  check("the next pass decodes the whole backlog",
    transport.pops == 3 and #published == 3,
    "pops=" .. transport.pops .. " published=" .. #published)
  check("the next pass asks for no retry once the queue is empty", retry == false)
  check("the table is not loaded a second time", tableLoads == 1,
    "loads=" .. tableLoads)
end

-- ---------------------------------------------------------------------------
-- 3. The relevant-SID set is in place before the first decode
-- ---------------------------------------------------------------------------

-- Without the set, every SID is published. The first decoding pass runs right
-- after the cold start, so the set must already be built by then.
do
  local elrs = freshModule()
  local frames = {}
  for i = 1, 3 do
    frames[#frames + 1] = frame(RELEVANT_SID, i)
    frames[#frames + 1] = frame(OTHER_SID, i)
  end
  local transport = newTransport(frames)
  elrs.wakeup(transport, SLOTS)
  elrs.wakeup(transport, SLOTS)

  local onlyRelevant = #published == 3
  for _, p in ipairs(published) do
    if p.appId ~= RELEVANT_SID then onlyRelevant = false end
  end
  check("the first decoding pass publishes only the telemetry slots' SIDs",
    onlyRelevant and transport.pops == 6,
    "pops=" .. transport.pops .. " published=" .. #published)
end

-- ---------------------------------------------------------------------------
-- 4. Steady state keeps its per-wakeup cap
-- ---------------------------------------------------------------------------

do
  local elrs = freshModule()
  local cap = elrs.MAX_FRAMES_PER_WAKEUP or MAX_FRAMES
  local transport = newTransport(backlog(RELEVANT_SID, 20))
  elrs.wakeup(transport, SLOTS)
  transport.pops = 0
  local retry = elrs.wakeup(transport, SLOTS)

  check("a steady-state pass pops at most its frame cap",
    transport.pops == cap,
    "pops=" .. transport.pops .. " cap=" .. cap)
  check("a steady-state pass at the cap asks for a retry",
    retry == true)
  check("the rest of the backlog stays queued",
    #transport.queue == 20 - cap,
    "queued=" .. #transport.queue)
end

-- ---------------------------------------------------------------------------
-- 5. A failed table load is asked for again on the next wakeup
-- ---------------------------------------------------------------------------

do
  local elrs = freshModule()
  tableFailuresLeft = 1
  local transport = newTransport(backlog(RELEVANT_SID, 2))

  local ok = pcall(elrs.wakeup, transport, SLOTS)
  check("a failed table load raises, as it did before", ok == false)
  check("the failed load pops nothing", transport.pops == 0,
    "pops=" .. transport.pops)

  elrs.wakeup(transport, SLOTS) -- second attempt loads the table
  check("the next wakeup asks for the table again", tableLoads == 2,
    "loads=" .. tableLoads)
  check("the wakeup after a successful load pops the backlog",
    elrs.wakeup(transport, SLOTS) == false and transport.pops == 2,
    "pops=" .. transport.pops)
end

-- ---------------------------------------------------------------------------
-- 6. Can-fail: a copy without the cold-start return must go red
-- ---------------------------------------------------------------------------

-- The cold-start return is taken out of a copy of the module, and the same
-- pop count is measured on that copy. The copy has to pop on its first pass,
-- otherwise the check above would not notice a regression.
do
  local handle = assert(io.open(TASKS .. "/elrs_sensors.lua", "rb"))
  -- The checkout may use CRLF (.gitattributes: *.lua eol=crlf); the pattern is LF.
  local source = handle:read("a"):gsub("\r\n", "\n")
  handle:close()

  local mutated, n = source:gsub(
    "    buildSensorTable%(%)\n    return false\n",
    "    buildSensorTable()\n", 1)
  check("the cold-start return is present in the module to be copied", n == 1,
    "matches=" .. n)

  local chunk = assert(load(mutated, "=elrs_sensors_without_cold_start", "t"))
  local elrs = chunk()
  local transport = newTransport(backlog(RELEVANT_SID, 3))
  elrs.wakeup(transport, SLOTS)
  check("a copy without the cold-start return pops on its first pass (the check can go red)",
    transport.pops > 0, "pops=" .. transport.pops)
end

print()
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.exit(1)

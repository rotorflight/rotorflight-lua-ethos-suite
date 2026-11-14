-- Behaviour check for the simulated sensors (tasks/sim_sensors.lua): a wakeup refreshes
-- a few sensors, and a pass over all of them takes less than two seconds.
--
-- Run it:
--     lua5.4 bin/sim_sensors/verify_sim_sensors.lua
--     lua5.4 bin/sim_sensors/verify_sim_sensors.lua --self-test
--
-- The task used to read every sim/sensors/*.lua file in one wakeup, about 30 loadfile()
-- calls. When the app opened in the same tick the background task ran out of
-- instructions: "[scheduler] sim_sensors failed: ... Max instructions count reached".
--
-- Drives the real tasks/sim_sensors.lua. lib/diy_sensor.lua and loadfile() are stubs
-- that record what is set and which files are read.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local TASK_PATH = scriptDir() .. "/../../src/rfsuite/tasks/sim_sensors.lua"
local MAX_PER_WAKEUP = 4

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

-- ---------------------------------------------------------------------------
-- Stubs
-- ---------------------------------------------------------------------------
local sets = {}        -- uid of each sensor set, in order
local values = {}      -- uid -> last value set
local sensorCount = 0
local DiySensor = {
  new = function(uid)
    sensorCount = sensorCount + 1
    return {
      set = function(_, value) sets[#sets + 1] = uid; values[uid] = value end,
      reset = function() end,
    }
  end,
}
package.loaded["rfsuite.lib.require"] = function(name)
  assert(name == "lib/diy_sensor.lua", "unexpected module " .. tostring(name))
  return DiySensor
end

-- What the sensor files return. Every other file returns 1.
local files = {armflags = 1, governor = 2, simevent_telemetry_state = 0}
local reads = {}       -- key of each sim/sensors file read, in order
local realLoadfile = loadfile
loadfile = function(path)
  local key = path:match("^sim/sensors/(.+)%.lua$")
  if not key then return realLoadfile(path) end
  reads[#reads + 1] = key
  return function() return files[key] or 1 end
end

local function countReads(key)
  local n = 0
  for _, read in ipairs(reads) do if read == key then n = n + 1 end end
  return n
end

-- The checks, run on the task built by `chunk`. Returns how many of them failed.
local function run(chunk, report)
  local failed = 0
  local function expect(label, ok, detail)
    if not ok then failed = failed + 1 end
    if report then check(label, ok, detail) end
  end

  sets, values, reads, sensorCount = {}, {}, {}, 0
  local task = chunk()
  expect("the task has sensors to refresh", sensorCount > MAX_PER_WAKEUP, "sensors=" .. sensorCount)
  expect("the task gives its wakeup interval", type(task.interval) == "number" and task.interval > 0,
    "interval=" .. tostring(task.interval))

  -- One pass: wakeups until every sensor has been set.
  local wakeups, most = 0, 0
  while #sets < sensorCount and wakeups < 1000 do
    local before = #sets
    task.wakeup()
    wakeups = wakeups + 1
    if #sets - before > most then most = #sets - before end
  end
  expect("a wakeup refreshes at most " .. MAX_PER_WAKEUP .. " sensors", most <= MAX_PER_WAKEUP, "most=" .. most)
  local seen, twice = {}, 0
  for _, uid in ipairs(sets) do
    if seen[uid] then twice = twice + 1 end
    seen[uid] = true
  end
  expect("a pass sets every sensor once", #sets == sensorCount and twice == 0,
    "sets=" .. #sets .. " sensors=" .. sensorCount .. " twice=" .. twice)
  local passSeconds = wakeups * (task.interval or 0)
  expect("a pass takes less than 2 seconds", passSeconds > 0 and passSeconds <= 2,
    string.format("%d wakeups x %ss = %.2fs", wakeups, tostring(task.interval), passSeconds))
  expect("the telemetry state is read once per pass", countReads("simevent_telemetry_state") == 1,
    "reads=" .. countReads("simevent_telemetry_state"))
  expect("the telemetry state file says enabled", task.telemetryState() == true)
  -- armed (bit 0) and governor state 2 (from bit 25): 1 | 2 << 25.
  expect("the packed system status holds the arm flag and the governor state", values[0x5031] == 67108865,
    "value=" .. tostring(values[0x5031]))

  -- The next pass starts again from the first sensor.
  local first = sets[1]
  task.wakeup()
  expect("the next pass starts with the first sensor again", sets[sensorCount + 1] == first)
  expect("and reads the telemetry state again", countReads("simevent_telemetry_state") == 2,
    "reads=" .. countReads("simevent_telemetry_state"))
  return failed
end

print("simulated sensors")
run(assert(realLoadfile(TASK_PATH)), true)

-- ---------------------------------------------------------------------------
-- self-test: with every sensor read in one wakeup again, the checks must go red.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the checks must go red when one wakeup reads every sensor")
  local source = readFile(TASK_PATH)
  local mutated, replacements = source:gsub("local SLICE = 4", "local SLICE = 1000", 1)
  check("self-test: the slice size was found in sim_sensors.lua", replacements == 1, "replacements=" .. replacements)
  if replacements == 1 then
    local failed = run(assert(load(mutated, "@" .. TASK_PATH)), false)
    check("self-test: with one slice for everything, checks fail", failed > 0, "failed=" .. failed)
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

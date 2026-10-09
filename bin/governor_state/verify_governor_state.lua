-- Behaviour check for the dashboard's governor label in stateless modes (#2353).
--
-- Run it:
--     lua5.4 bin/governor_state/verify_governor_state.lua
--     lua5.4 bin/governor_state/verify_governor_state.lua --self-test
--
-- The firmware (rotorflight-firmware, src/main/flight/governor.c) never leaves
-- THROTTLE_OFF in gov_mode NONE (governorUpdate() default branch) or LIMIT
-- (govUpdateLimitedThrottle() only sets throttleOutput), so gov.state stays 0
-- there. The enum is src/main/pg/governor.h: NONE=0, LIMIT=1, DIRECT=2,
-- ELECTRIC=3, NITRO=4. In DIRECT and the governed modes 0 is a real OFF.
--
-- What it drives: the real widgets/dashboard/context.lua, its
-- utils.getGovernorState(), with a fake telemetry sensor table and the
-- session fields the widget copies into context.session.
--
-- --self-test replaces the new condition with `false` (the pre-fix behaviour)
-- and requires the NONE case to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"
local SELF_TEST = arg and arg[1] == "--self-test"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then
    f:close()
    return name
  end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then path = resolvePath(path) end
  if env ~= nil then return realLoadfile(path, mode, env) end
  if mode ~= nil then return realLoadfile(path, mode) end
  return realLoadfile(path)
end

local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(resolvePath(name))
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
  return ok
end

-- Loads context.lua. In self-test the new condition is swapped for `false`
-- in a copy held in memory, so the pre-fix label is what gets measured.
local function loadContext(preFix)
  local text
  if preFix then
    local f = assert(io.open(resolvePath("widgets/dashboard/context.lua"), "r"))
    text = f:read("a")
    f:close()
    local n
    text, n = text:gsub("local stateless = session and session%.governorModeKnown == true\n%s*and %(session%.governorMode == 0 or session%.governorMode == 1%)",
      "local stateless = false")
    assert(n == 1, "self-test could not find the condition to remove")
    local chunk, err = load(text, "=context-prefix", "t")
    if not chunk then error(err) end
    return chunk()
  end
  return assert(loadfile(resolvePath("widgets/dashboard/context.lua")))()
end

local sensors = {}
local function setSensors(state)
  sensors.governor = state
  sensors.armflags = nil
  sensors.armdisableflags = nil
end

local function run(context, label, mode, known, raw, armed)
  context.session.governorMode = mode
  context.session.governorModeKnown = known
  setSensors(raw)
  sensors.armflags = armed and 1 or 0
  return context.utils.getGovernorState(raw)
end

local function runCases(context)
  -- Sensors: the governor value comes back from telemetry; armflags bit 0
  -- says armed. Every case is armed unless it says otherwise.
  context.tasks.telemetry.getSensor = function(name) return sensors[name] end

  check("NONE (0), mode read, state 0 reads PASSTHRU, not OFF",
    run(context, "", 0, true, 0, true) == "PASSTHRU",
    "got " .. tostring(run(context, "", 0, true, 0, true)))
  check("LIMIT (1), mode read, state 0 reads PASSTHRU",
    run(context, "", 1, true, 0, true) == "PASSTHRU",
    "got " .. tostring(run(context, "", 1, true, 0, true)))
  check("DIRECT (2), state 0 is a real OFF (the state machine runs)",
    run(context, "", 2, true, 0, true) == "OFF")
  check("ELECTRIC (3), state 0 is a real OFF",
    run(context, "", 3, true, 0, true) == "OFF")
  check("NONE, state ACTIVE (4) is ACTIVE, not PASSTHRU",
    run(context, "", 0, true, 4, true) == "ACTIVE")
  check("LIMIT, state 0 while disarmed reads DISARMED, not PASSTHRU",
    run(context, "", 1, true, 0, false) == "DISARMED",
    "got " .. tostring(run(context, "", 1, true, 0, false)))
  check("NONE but the mode was never read (fallback) reads OFF, not PASSTHRU",
    run(context, "", 0, false, 0, true) == "OFF",
    "got " .. tostring(run(context, "", 0, false, 0, true)))
  check("mode never set at all reads OFF",
    run(context, "", nil, nil, 0, true) == "OFF")
end

if SELF_TEST then
  -- The pre-fix condition: the NONE case must be red, or the check proves nothing.
  local context = loadContext(true)
  context.tasks.telemetry.getSensor = function(name) return sensors[name] end
  sensors.armflags = 1
  sensors.governor = 0
  context.session.governorMode = 0
  context.session.governorModeKnown = true
  local label = context.utils.getGovernorState(0)
  local redOnNone = label ~= "PASSTHRU"
  print(string.format("\nself-test: the pre-fix label is %s; NONE case %s",
    tostring(label), redOnNone and "is caught" or "is NOT caught"))
  print(string.format("%d checks, %d failed", checks, failures))
  os.exit(redOnNone and 0 or 1)
end

print("Governor label: widgets/dashboard/context.lua")
local context = loadContext(false)
runCases(context)

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

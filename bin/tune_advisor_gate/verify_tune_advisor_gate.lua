-- Behaviour check for the Tune Advisor firmware gate (issue #2579).
--
-- Run it:
--     lua5.4 bin/tune_advisor_gate/verify_tune_advisor_gate.lua
--
-- The claim: firmware without the Tune Advisor (4.6.0) gets no Tune Advisor MSP
-- request from the background capture, and a version that is not known yet gets
-- none either. Firmware that has it (4.7.0 and later) still gets the capture.
--
-- What it drives:
--   * lib/msp_tune_advisor.lua supportFor() on version strings.
--   * The real tasks/tune_history.lua through the session.update bus, with a
--     recording msp.request subscriber. A disarm is fed the way session.lua feeds it.
--
-- Not covered here: the Tune Advisor page (app/pages/tune_advisor.lua). It is a
-- UI module that needs the form and header stubs; it is checked on the simulator.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

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

-- rfsuite.lib.require is loadfile() against Ethos' path prefixes on a radio.
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

-- ---------------------------------------------------------------------------
-- 1. Version support
-- ---------------------------------------------------------------------------
local tuneAdvisor = requireModule("lib/msp_tune_advisor.lua")

check("4.6.0 has no Tune Advisor", tuneAdvisor.supportFor("4.6.0") == false)
check("4.6.9 has no Tune Advisor", tuneAdvisor.supportFor("4.6.9") == false)
check("3.9.9 has no Tune Advisor", tuneAdvisor.supportFor("3.9.9") == false)
check("4.7.0 has the Tune Advisor", tuneAdvisor.supportFor("4.7.0") == true)
check("4.7.0 with a snapshot suffix has the Tune Advisor", tuneAdvisor.supportFor("4.7.0-a88bec8") == true)
check("4.7.1 has the Tune Advisor", tuneAdvisor.supportFor("4.7.1") == true)
check("4.10.0 has the Tune Advisor (numeric, not text, compare)", tuneAdvisor.supportFor("4.10.0") == true)
check("5.0.0 has the Tune Advisor", tuneAdvisor.supportFor("5.0.0") == true)
check("unknown version is nil", tuneAdvisor.supportFor(nil) == nil)
check("unparseable version is nil", tuneAdvisor.supportFor("garbage") == nil)

-- ---------------------------------------------------------------------------
-- 2. The background capture sends nothing without the command
-- ---------------------------------------------------------------------------
local bus = requireModule("lib/bus.lua")
local sent = 0
local clock = 0
os.clock = function() return clock end
bus.subscribe("msp.request", function() sent = sent + 1 end)
requireModule("tasks/tune_history.lua")

local function session(fields)
  local snapshot = {connected = true, mcuId = "bench-1", apiVersionSupported = true, craftName = "Test"}
  for k, v in pairs(fields) do snapshot[k] = v end
  bus.publish("session.update", snapshot)
end

-- One flight: arm, then disarm. The disarm is what starts a capture; the
-- first read goes out once the start wait has passed.
local function flightWith(fcVersion)
  sent = 0
  clock = clock + 60
  session({isArmed = true, fcVersion = fcVersion})
  session({isArmed = false, fcVersion = fcVersion})
  clock = clock + 5
  session({isArmed = false, fcVersion = fcVersion})
  return sent
end

check("4.6.0: a disarm sends no Tune Advisor request", flightWith("4.6.0") == 0,
  "requests sent: " .. tostring(sent))
check("4.6.0: a second disarm also sends nothing", flightWith("4.6.0") == 0)
check("version not known yet: a disarm sends nothing", flightWith(nil) == 0)
check("4.7.0: a disarm sends the capture read", flightWith("4.7.0") == 1,
  "requests sent: " .. tostring(sent))

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

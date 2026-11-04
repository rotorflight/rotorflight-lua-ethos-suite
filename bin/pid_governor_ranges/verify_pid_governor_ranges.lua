-- Behaviour check for the firmware ranges of the inflight error decay limit and
-- the governor throttle limits (issue #2656).

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\\\][^/\\\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local SELF_TEST = arg and arg[1] == "--self-test"

local function readFile(p)
  local f = io.open(p, "r"); assert(f, p)
  local s = f:read("*a"); f:close(); return s
end

local function contains(s, needle)
  return s:find(needle, 1, true) ~= nil
end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then print(string.format("  ok    %s", label))
  else failures = failures + 1; print(string.format("  FAIL  %s", label)); if detail then print("        " .. tostring(detail)) end end
  return ok
end

local pidSrc = readFile(ROOT .. "/src/rfsuite/lib/msp_pid_profile.lua")
local govSrc = readFile(ROOT .. "/src/rfsuite/lib/msp_governor_profile.lua")

local pidNeedle = SELF_TEST and "max = 25," or "max = 250,"
local govMaxNeedle = SELF_TEST and "governor_max_throttle = {min = 0," or "governor_max_throttle = {min = 10,"
local govMinNeedle = SELF_TEST and "governor_min_throttle = {min = 0," or "governor_min_throttle = {min = 10,"

check("error_decay_limit_cyclic range 0-250", contains(pidSrc, pidNeedle))
check("governor_max_throttle min 10", contains(govSrc, govMaxNeedle))
check("governor_min_throttle min 10", contains(govSrc, govMinNeedle))

if failures > 0 then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
else
  print(string.format("\n%d checks passed", checks))
end

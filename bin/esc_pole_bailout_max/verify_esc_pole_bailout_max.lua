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
local function contains(s, needle) return s:find(needle, 1, true) ~= nil end

local failures, checks = 0, 0
local function check(label, ok)
  checks = checks + 1
  if ok then print("  ok    " .. label) else failures = failures + 1; print("  FAIL  " .. label) end
  return ok
end

local motorSrc = readFile(ROOT .. "/src/rfsuite/lib/msp_motor_config.lua")
local scorpSrc = readFile(ROOT .. "/src/rfsuite/lib/msp_esc_parameters_scorpion.lua")

local poleNeedle = SELF_TEST and "motor_pole_count_0 = {min = 2, max = 256" or "motor_pole_count_0 = {min = 2, max = 255"
local bailNeedle = SELF_TEST and "bailout = {min = 0, max = 100000" or "bailout = {min = 0, max = 65535"

check("motor pole count max 255", contains(motorSrc, poleNeedle))
check("scorpion bailout max 65535", contains(scorpSrc, bailNeedle))

if failures > 0 then print(string.format("\n%d of %d checks failed", failures, checks)); os.exit(1)
else print(string.format("\n%d checks passed", checks)) end

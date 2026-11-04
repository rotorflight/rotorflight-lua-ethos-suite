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

local src = readFile(ROOT .. "/src/rfsuite/app/pages/setup_wizard_rescue.lua")
local needle = SELF_TEST and "local MAX_PROFILES = 3" or "local MAX_PROFILES = 6"
check("rescue covers up to 6 profiles", contains(src, needle))

if failures > 0 then print(string.format("\n%d of %d checks failed", failures, checks)); os.exit(1)
else print(string.format("\n%d checks passed", checks)) end

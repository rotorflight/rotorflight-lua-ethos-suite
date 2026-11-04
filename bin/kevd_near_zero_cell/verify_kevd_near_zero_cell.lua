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

for _, f in ipairs({"inflight.lua", "postflight.lua"}) do
  local src = readFile(ROOT .. "/src/rfsuite/widgets/dashboard/themes/kevd/" .. f)
  local needle = SELF_TEST and "if voltage < 2 then return 0 end XXX" or "if voltage < 2 then return 0 end"
  check("near-zero guard in " .. f, contains(src, needle))
end

if failures > 0 then print(string.format("\n%d of %d checks failed", failures, checks)); os.exit(1)
else print(string.format("\n%d checks passed", checks)) end

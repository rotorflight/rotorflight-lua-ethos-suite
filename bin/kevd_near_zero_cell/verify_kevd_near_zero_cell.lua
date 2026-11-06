-- Behaviour check for issue #2660: the KevD theme gives no cell count for a
-- near-zero pack voltage, where the auto-detect used to report 1S.
--
-- Run it:
--     lua5.4 bin/kevd_near_zero_cell/verify_kevd_near_zero_cell.lua
--
-- What it drives, and why:
--   * estimateCellCountFromVoltage is local to each KevD screen (inflight.lua,
--     postflight.lua), so the check takes the function from each theme file and
--     runs that code, not a copy. Both screens must carry the same function.
--   * The old code returned 1 for every voltage from 0.5 V up to about 3.2 V;
--     those are the cases this check pins.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local THEMES = ROOT .. "/src/rfsuite/widgets/dashboard/themes/kevd/"

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

local function readFile(p)
  local f = io.open(p, "r")
  assert(f, p)
  local s = f:read("*a")
  f:close()
  -- The working copy may carry CRLF line endings; the function's end is found by "\nend\n".
  return (s:gsub("\r\n", "\n"))
end

-- The estimator's source, from its first line to the column-0 "end".
local function estimatorSource(path)
  return readFile(path):match("(local function estimateCellCountFromVoltage.-\nend\n)")
end

-- Runs the extracted function with only the globals it uses.
local function loadEstimator(source, name)
  local chunk, err = load(source .. "\nreturn estimateCellCountFromVoltage", name, "t",
    {floor = math.floor, tonumber = tonumber})
  if not chunk then return nil, err end
  return chunk()
end

local sources = {}
for _, f in ipairs({"inflight.lua", "postflight.lua"}) do
  local src = estimatorSource(THEMES .. f)
  check("estimator found in " .. f, src ~= nil)
  if src then sources[f] = src end
end
if not (sources["inflight.lua"] and sources["postflight.lua"]) then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
end

check("both screens carry the same estimator",
  sources["inflight.lua"] == sources["postflight.lua"])

-- { pack voltage, expected cell count }
local CASES = {
  {-1, 0}, {0, 0}, {0.5, 0}, {1.5, 0}, {1.99, 0},
  {2.0, 1}, {3.5, 1}, {4.2, 1},
  {8.4, 2}, {12.6, 3},
}

for _, f in ipairs({"inflight.lua", "postflight.lua"}) do
  local estimate, err = loadEstimator(sources[f], f)
  if not estimate then
    check("estimator loads from " .. f, false, err)
  else
    for _, case in ipairs(CASES) do
      local voltage, expected = case[1], case[2]
      local got = estimate(voltage)
      check(string.format("%s: %.2f V gives %d cells", f, voltage, expected), got == expected,
        string.format("got %s", tostring(got)))
    end
  end
end

if failures > 0 then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
end
print(string.format("\n%d checks passed", checks))

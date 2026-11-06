-- Behaviour check for issue #2660: the KevD theme gives no cell count for a
-- near-zero pack voltage, and draws the cell row as "-" where the auto-detect
-- used to report 1S.
--
-- Run it:
--     lua5.4 bin/kevd_near_zero_cell/verify_kevd_near_zero_cell.lua
--
-- What it drives, and why:
--   * estimateCellCountFromVoltage and formatCellVoltageAndCount are local to
--     each KevD screen (inflight.lua, postflight.lua). The check takes both
--     functions from each theme file and runs that code, not a copy.
--   * The cell row is checked as the text the screen draws. The configured
--     cell count comes from a stub of utils.getBatteryCellCount.
--   * The negative control runs the same cases against a copy of the estimator
--     without its guard. Those cases must catch it.

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
  -- The working copy may carry CRLF line endings; the function ends are found by "\nend\n".
  return (s:gsub("\r\n", "\n"))
end

-- A top-level local function, from its first line to the column-0 "end".
local function functionSource(src, name)
  return src:match("(local function " .. name .. "%(.-\nend\n)")
end

-- Builds one screen's two functions from their source, with only the globals
-- they use. `estimator` is passed in so the negative control can use a copy.
local function loadScreen(estimator, formatter, name)
  local stub = {cells = 0}
  local env = {
    floor = math.floor,
    tonumber = tonumber,
    format = string.format,
    utils = {getBatteryCellCount = function() return stub.cells end},
  }
  local chunk, err = load(estimator .. "\n" .. formatter
    .. "\nreturn estimateCellCountFromVoltage, formatCellVoltageAndCount\n", name, "t", env)
  if not chunk then return nil, err end
  local estimate, format = chunk()
  return {estimate = estimate, format = format, stub = stub}
end

local estimators, formatters = {}, {}
for _, f in ipairs({"inflight.lua", "postflight.lua"}) do
  local src = readFile(THEMES .. f)
  estimators[f] = functionSource(src, "estimateCellCountFromVoltage")
  formatters[f] = functionSource(src, "formatCellVoltageAndCount")
  check("estimator found in " .. f, estimators[f] ~= nil)
  check("formatter found in " .. f, formatters[f] ~= nil)
end
if not (estimators["inflight.lua"] and estimators["postflight.lua"]
    and formatters["inflight.lua"] and formatters["postflight.lua"]) then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
end

check("both screens carry the same estimator",
  estimators["inflight.lua"] == estimators["postflight.lua"])
check("both screens carry the same cell formatter",
  formatters["inflight.lua"] == formatters["postflight.lua"])

-- Estimator: { pack voltage, expected cell count }
local ESTIMATES = {
  {-1, 0}, {0, 0}, {0.5, 0}, {1.5, 0}, {1.99, 0},
  {2.0, 1}, {3.5, 1}, {4.2, 1},
  {8.4, 2}, {12.6, 3},
}

-- Cell row as drawn: { configured cell count, pack voltage, expected text }
local ROWS = {
  {0, 0.4, "-"}, {0, 1.99, "-"}, {0, 0, "-"},
  {0, 2.0, "2.00V (1S)"}, {0, 8.4, "4.20V (2S)"},
  {6, 0.4, "0.07V (6S)"}, {6, 0, "--.--V (--S)"},
}

for _, f in ipairs({"inflight.lua", "postflight.lua"}) do
  local screen, err = loadScreen(estimators[f], formatters[f], f)
  if not screen then
    check("screen loads from " .. f, false, err)
  else
    for _, case in ipairs(ESTIMATES) do
      local voltage, expected = case[1], case[2]
      local got = screen.estimate(voltage)
      check(string.format("%s: estimate %.2f V gives %d cells", f, voltage, expected),
        got == expected, string.format("got %s", tostring(got)))
    end
    for _, case in ipairs(ROWS) do
      local configured, voltage, expected = case[1], case[2], case[3]
      screen.stub.cells = configured
      local got = screen.format(voltage)
      check(string.format("%s: %d cells configured, %.2f V draws %q", f, configured, voltage, expected),
        got == expected, string.format("got %q", tostring(got)))
    end
  end
end

-- Negative control: the same cases must fail without the guard.
local GUARD = "\n[ ]*if voltage < 2 then return 0 end"
local unguarded, n = estimators["inflight.lua"]:gsub(GUARD, "", 1)
check("negative control removes the guard", n == 1)
local control = loadScreen(unguarded, formatters["inflight.lua"], "unguarded")
check("without the guard, 0.5 V gives a cell count (the cases above catch it)",
  control ~= nil and control.estimate(0.5) ~= 0)

if failures > 0 then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
end
print(string.format("\n%d checks passed", checks))

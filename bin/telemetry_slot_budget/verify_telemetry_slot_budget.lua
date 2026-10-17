-- Behaviour check for the 40-slot budget of the Telemetry page (issue #2499).
--
-- Run it from the repository root:
--     lua5.4 bin/telemetry_slot_budget/verify_telemetry_slot_budget.lua
--
-- What it drives, and why:
--   * lib/telemetry_slot_budget.lua is the whole arithmetic, with no dependency
--     on form, catalog or runtime. The page asks it in two places: the save check
--     ("would the write overflow the slots?") and the toggle gate ("would one more
--     selection overflow?"). Both now go through it, so they cannot disagree.
--   * The last check reads the page and requires both call sites to use the
--     shared functions, and not the old gate that counted only the switches.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."

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

local budget = dofile(ROOT .. "/src/rfsuite/lib/telemetry_slot_budget.lua")
local LIMIT = 40

print("save check")

check("39 managed and nothing kept fits", budget.overflows(39, 0, LIMIT) == false)
check("40 managed and nothing kept fits exactly", budget.overflows(40, 0, LIMIT) == false)
check("41 managed does not fit", budget.overflows(41, 0, LIMIT) == true)
check("37 managed with 3 kept native slots fits exactly", budget.overflows(37, 3, LIMIT) == false)
check("38 managed with 3 kept native slots does not fit", budget.overflows(38, 3, LIMIT) == true)

print("toggle gate, one more selection")

check("the 40th switch is allowed when 39 are on", budget.overflowsWithOneMore(39, 0, LIMIT) == false)
check("the 41st switch is refused when 40 are on", budget.overflowsWithOneMore(40, 0, LIMIT) == true)

-- The case from the issue: three native slots are kept. With 39 switches on the
-- save would refuse the 40th, so the gate has to refuse it too.
check("with 3 kept native slots, the switch that the save would refuse is refused by the gate",
  budget.overflowsWithOneMore(39, 3, LIMIT) == true)
check("with 3 kept native slots, the switch the save would accept is allowed",
  budget.overflowsWithOneMore(36, 3, LIMIT) == false)

print("gate and save agree")

do
  local disagreements = 0
  for managed = 0, 45 do
    for unmanaged = 0, 5 do
      -- The gate on the state before a switch is the save on the state after it.
      if budget.overflowsWithOneMore(managed, unmanaged, LIMIT)
          ~= budget.overflows(managed + 1, unmanaged, LIMIT) then
        disagreements = disagreements + 1
      end
    end
  end
  check("for every count of switches and kept slots, the gate matches the save", disagreements == 0,
    disagreements .. " disagreements")
end

print("both call sites use the shared budget")

do
  local f = io.open(ROOT .. "/src/rfsuite/app/pages/telemetry.lua", "rb")
  local text = f and f:read("*a") or ""
  if f then f:close() end
  check("the page loads lib/telemetry_slot_budget.lua",
    text:find('requireModule("lib/telemetry_slot_budget.lua")', 1, true) ~= nil)
  check("the save check asks overflows()",
    text:find("slotBudget.overflows(#ordered, unmanaged, telemetryConfig.SLOT_COUNT)", 1, true) ~= nil)
  check("the toggle gate asks overflowsWithOneMore() with the same managed count",
    text:find("slotBudget.overflowsWithOneMore(", 1, true) ~= nil)
  check("the old gate, which counted only the switches, is gone",
    text:find("countSelected(selected) >= telemetryConfig.SLOT_COUNT", 1, true) == nil)
end

print(string.rep("-", 60))
print(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  print("")
  print("FAILED")
  os.exit(1)
end
print("ALL CHECKS PASSED")

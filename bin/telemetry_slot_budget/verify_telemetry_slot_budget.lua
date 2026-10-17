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

print("page behaviour, toggle and save together")

-- The real page, with the form and the page runtime stubbed. The page builds its
-- switches with form.addBooleanField; the stub keeps each setter by sensor name,
-- so the check can tap a switch exactly as the pilot does. The save is not run:
-- the refusal at the tap is the decision under test.
do
  local SRC = ROOT .. "/src/rfsuite"
  local savedForm = form
  local savedRequire = package.loaded["rfsuite.lib.require"]
  local catalog = dofile(SRC .. "/lib/telemetry_sensor_catalog.lua")

  -- Sensors that take part in no conflict, so a tap changes nothing else.
  local inConflict = {}
  for parent, children in pairs(catalog.NOT_AT_SAME_TIME) do
    inConflict[parent] = true
    for _, child in ipairs(children) do inConflict[child] = true end
  end
  local candidates = {}
  for _, id in ipairs(catalog.SENSOR_IDS) do
    if not inConflict[id] and catalog.SENSOR_LIST[id] then candidates[#candidates + 1] = id end
  end

  local CUSTOM = 1
  local pageSource = io.open(SRC .. "/app/pages/telemetry.lua", "rb"):read("*a")

  -- Opens the page with `managed` switches on and `unmanaged` native slots kept,
  -- then taps one more switch. Returns true when the tap was refused, and the
  -- number of dialogs that opened.
  local function tapOneMore(managed, unmanaged, source)
    local slots = {}
    for i = 1, managed do slots[i] = candidates[i] end
    for i = 1, unmanaged do slots[managed + i] = 500 + i end -- not in the catalog
    for i = #slots + 1, 40 do slots[i] = 0 end

    local spec, setters, dialogs = nil, {}, 0
    local data = {telemetry = {crsf_telemetry_mode = CUSTOM, slots = slots}, feature = {}}
    local stubs = {
      form = {
        clear = function() end,
        openDialog = function() dialogs = dialogs + 1 end,
        addExpansionPanel = function()
          return {open = function() end,
            addLine = function(_, name) return {label = name} end}
        end,
        addBooleanField = function(line, _, _, setter)
          setters[line.label] = setter
          return {enable = function() end}
        end,
      },
    }
    form = setmetatable({}, {__index = stubs.form})
    package.loaded["rfsuite.lib.require"] = function(name)
      if name == "app/page_runtime.lua" then
        return {new = function(s)
          spec = s
          -- A firmware new enough to offer every sensor in the catalog. The chrome
          -- and the dirty flag are not what is under test, so they do nothing.
          local rt = setmetatable({data = data, apiVersionMinor = 99, controlRef = {}}, {
            -- Any other method of the runtime does nothing here.
            __index = function() return function() end end,
          })
          rt.controlRef.runtime = rt
          return rt
        end}
      end
      return assert(loadfile(SRC .. "/" .. name))()
    end

    local chunk = assert(load(source, "@telemetry-page"))
    local page = chunk()
    page.open({})
    spec.onLoaded()

    local target = catalog.SENSOR_LIST[candidates[managed + 1]].name
    local accepted = setters[target](true)
    return accepted == false, dialogs
  end

  -- The page as shipped.
  local refused, dialogs = tapOneMore(37, 3, pageSource)
  check("37 switches with 3 native slots kept: the 38th tap is refused (the save would refuse it)",
    refused and dialogs == 1, "refused=" .. tostring(refused) .. " dialogs=" .. dialogs)
  refused, dialogs = tapOneMore(36, 3, pageSource)
  check("36 switches with 3 native slots kept: the 37th tap is accepted (the save fits exactly)",
    (not refused) and dialogs == 0, "refused=" .. tostring(refused) .. " dialogs=" .. dialogs)
  refused, dialogs = tapOneMore(39, 0, pageSource)
  check("39 switches and nothing kept: the 40th tap is accepted", (not refused) and dialogs == 0)
  refused, dialogs = tapOneMore(40, 0, pageSource)
  check("40 switches and nothing kept: the 41st tap is refused", refused and dialogs == 1)

  -- Can-fail: the same page with the old gate, which counted only the switches.
  -- The 38th tap must then be accepted, and this check goes red if the gate
  -- ever stops counting the kept slots.
  local oldGate = pageSource
    :gsub("#collectSelected%(selected, crsfMode%),",
      "(function() local n = 0 for _, id in ipairs(catalog.SENSOR_IDS) do if selected[id] == true then n = n + 1 end end return n end)(),", 1)
    :gsub("countUnmanaged%(runtime%.data%.telemetry and runtime%.data%.telemetry%.slots%),", "0,", 1)
  check("the old gate can be reproduced from the page text", oldGate ~= pageSource)
  refused, dialogs = tapOneMore(37, 3, oldGate)
  check("the old gate accepts the 38th tap (this check can go red)", (not refused) and dialogs == 0,
    "refused=" .. tostring(refused) .. " dialogs=" .. dialogs)

  form = savedForm
  package.loaded["rfsuite.lib.require"] = savedRequire
end

print(string.rep("-", 60))
print(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  print("")
  print("FAILED")
  os.exit(1)
end
print("ALL CHECKS PASSED")

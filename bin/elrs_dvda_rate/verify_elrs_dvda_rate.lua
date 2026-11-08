-- Behaviour check for the ELRS link's packet rate (Issue #2669): a DVDA mode runs at its air rate,
-- not the number in its label. The telemetry ratio and the rate written to the flight
-- controller are counted at that rate.
--
-- Run it:
--     lua5.4 bin/elrs_dvda_rate/verify_elrs_dvda_rate.lua
--     lua5.4 bin/elrs_dvda_rate/verify_elrs_dvda_rate.lua --self-test
--
-- D250, D500, DK250 and DK500 run at 1000 Hz on air, D50Hz at 200 Hz (ExpressLRS
-- common.cpp), so their Std telemetry ratios are 128 and 64. The label's number was
-- used before: D250 got 1:64 and D50 got 1:16.
--
-- Drives the real lib/elrslink_task.lua. Its finalize() and the helpers it uses are
-- reached through debug upvalues, as bin/elrs/verify_link_rates.lua does in the EdgeTX
-- suite. Only the bus, the telemetry config and the debug log are stubbed.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local MODULE_PATH = SRC .. "/lib/elrslink_task.lua"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  print(string.format("  %s  %s%s", ok and "ok  " or "FAIL", label, (not ok and detail) and ("  (" .. detail .. ")") or ""))
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

-- ---------------------------------------------------------------------------
-- Stubs
-- ---------------------------------------------------------------------------
local stubs = {
  ["lib/bus.lua"] = {publish = function() end, subscribe = function() end, unsubscribe = function() end},
  ["lib/msp_telemetry_config.lua"] = {
    buildReadConfigMessage = function() return {} end,
    buildWriteMessage = function() return {} end,
  },
  ["lib/msp_eeprom.lua"] = {buildWriteMessage = function() return {} end},
  ["lib/debug_log.lua"] = {print = function() end, format = function() end, msp = function() end},
}

local cache = {}
package.loaded["rfsuite.lib.require"] = function(name)
  if stubs[name] then return stubs[name] end
  if cache[name] == nil then
    cache[name] = assert(loadfile(SRC .. "/" .. name))()
  end
  return cache[name]
end

-- ---------------------------------------------------------------------------
-- Reach the production helpers through upvalues.
-- ---------------------------------------------------------------------------
local function upvalue(fn, name)
  for i = 1, 200 do
    local key, value = debug.getupvalue(fn, i)
    if not key then break end
    if key == name then return value, i end
  end
  return nil
end

local function setUpvalue(fn, name, value)
  for i = 1, 200 do
    local key = debug.getupvalue(fn, i)
    if not key then break end
    if key == name then
      debug.setupvalue(fn, i, value)
      return true
    end
  end
  return false
end

local task = assert(loadfile(MODULE_PATH))()
local finalize = upvalue(task.wakeup, "finalize")
local packetRateFromLabel = finalize and upvalue(finalize, "packetRateFromLabel")
local resolveEffectiveRatio = finalize and upvalue(finalize, "resolveEffectiveRatio")
local parseRatioLabel = finalize and upvalue(finalize, "parseRatioLabel")
check("the production helpers are reachable", finalize ~= nil and packetRateFromLabel ~= nil
  and resolveEffectiveRatio ~= nil and parseRatioLabel ~= nil,
  "finalize=" .. tostring(finalize) .. " packetRateFromLabel=" .. tostring(packetRateFromLabel))
if not packetRateFromLabel then
  print(string.format("\n%d checks, %d failed", checks, failures))
  os.exit(1)
end

-- ---------------------------------------------------------------------------
-- 1. DVDA labels run at their air rate.
-- ---------------------------------------------------------------------------
print("DVDA labels")
local DVDA = {
  {"D250(-104dBm)", 1000}, {"D500(-104dBm)", 1000}, {"DK250(-103dBm)", 1000}, {"DK500(-103dBm)", 1000},
  {"D50Hz(-112dBm)", 200}, {" dK500(-103dBm)", 1000}, {"d50HZ(-112dBm)", 200}, {"D500-extra", 1000},
}
for _, item in ipairs(DVDA) do
  local got = packetRateFromLabel(item[1])
  check(string.format("%-18s -> %d Hz on air", item[1], item[2]), got == item[2], "got " .. tostring(got))
end

-- ---------------------------------------------------------------------------
-- 2. Every other label reads as before.
-- ---------------------------------------------------------------------------
print("other labels, unchanged")
local OTHER = {
  {"500Hz(-105dBm)", 500}, {"F1000(-104dBm)", 1000}, {"K1000 Full(-101dBm)", 1000}, {"F500(-104dBm)", 500},
  {"D500X", 500}, {"D125(-100dBm)", 125}, {"DK333(-100dBm)", 333}, {"50Hz", 50},
  {"2.4GHz", 2}, -- the first number, as before; no DVDA label has a point in it
  {"", nil}, {nil, nil},
}
for _, item in ipairs(OTHER) do
  local got = packetRateFromLabel(item[1])
  check(string.format("%-18s -> %s", tostring(item[1]), tostring(item[2])), got == item[2], "got " .. tostring(got))
end

-- ---------------------------------------------------------------------------
-- 3. The Std telemetry ratio is taken at the air rate.
-- ---------------------------------------------------------------------------
print("Std telemetry ratio")
do
  local explicit, kind = parseRatioLabel("Std")
  local cases = {{"D500(-104dBm)", 128}, {"D250(-104dBm)", 128}, {"D50Hz(-112dBm)", 64}}
  for _, item in ipairs(cases) do
    local ratio = resolveEffectiveRatio(packetRateFromLabel(item[1]), kind, explicit)
    check(string.format("%s with Std -> 1:%d", item[1], item[2]), ratio == item[2], "got " .. tostring(ratio))
  end
end

-- ---------------------------------------------------------------------------
-- 4. End to end: finalize() takes the module's labels and publishes the air rate.
-- ---------------------------------------------------------------------------
print("the link summary")
do
  -- finalize() reads the module's labels from these module locals.
  setUpvalue(finalize, "moduleRateLabel", "D250(-104dBm)")
  setUpvalue(finalize, "moduleRatioLabel", "Std")
  local ok, err = pcall(finalize)
  local summary = task.getLinkSummary()
  check("finalize runs on a D250 module", ok, tostring(err))
  check("the summary carries the air rate (1000 Hz), not the label's 250",
    summary and summary.packetRate == 1000, "packetRate=" .. tostring(summary and summary.packetRate))
  check("and the Std ratio at that rate (1:128)",
    summary and summary.telemetryRatio == 128, "telemetryRatio=" .. tostring(summary and summary.telemetryRatio))
  check("the label is still shown as the module names it",
    summary and summary.packetRateLabel == "D250(-104dBm)", "label=" .. tostring(summary and summary.packetRateLabel))
end

-- ---------------------------------------------------------------------------
-- self-test: with the label's number, D250 gets 1:64, which is the reported fault.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the air rate check must go red with the label's number")
  local source = readFile(MODULE_PATH)
  local mutated, replacements = source:gsub("local moduleRate = packetRateFromLabel%(moduleRateLabel%)",
    "local moduleRate = extractFirstInteger(moduleRateLabel)", 1)
  check("self-test: the rate line was found in finalize() exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    -- The module returns its cached copy when it is already loaded, so the sabotaged one
    -- is loaded with the cache cleared.
    package.loaded["rfsuite.lib.elrslink_task"] = nil
    local copy = assert(load(mutated, "@" .. MODULE_PATH))()
    local fin = upvalue(copy.wakeup, "finalize")
    setUpvalue(fin, "moduleRateLabel", "D250(-104dBm)")
    setUpvalue(fin, "moduleRatioLabel", "Std")
    pcall(fin)
    local summary = copy.getLinkSummary()
    check("self-test: with the label's number D250 gets 1:64 (the check above goes red)",
      summary and summary.telemetryRatio == 64, "telemetryRatio=" .. tostring(summary and summary.telemetryRatio))
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

-- Behaviour check for the battery save (#2651): Setup > Power > Battery also writes the
-- SmartFuel configuration in the same save, after the battery configuration, so that new
-- cell voltages reach SmartFuel at once instead of after the next power-up.
--
-- Run it:
--     lua5.4 bin/battery_smartfuel_save/verify_battery_smartfuel_save.lua
--     lua5.4 bin/battery_smartfuel_save/verify_battery_smartfuel_save.lua --self-test
--
-- The firmware takes the cell voltages into SmartFuel only in smartFuelInit(), which
-- MSP2_SET_SMARTFUEL_CONFIG calls and MSP_SET_BATTERY_CONFIG does not. The page runtime
-- writes its sources in the order they are declared, and then the EEPROM. So the page must
-- declare the SmartFuel source after the battery source.
--
-- Drives the real app/pages/power_battery.lua and the real SmartFuel codec. The page runtime
-- is a stand-in that records the page's sources. Each source is then written the way the
-- runtime writes it: its buildWriteMessage(values) in order.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local PAGE_PATH = SRC .. "/app/pages/power_battery.lua"

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

local captured = nil
local pageRuntime = {
  new = function(config)
    captured = config
    return {controlRef = {}, fields = {}, dataRef = {data = {}}}
  end,
}

local cache = {}
local stubs = {
  ["app/page_runtime.lua"] = pageRuntime,
  ["app/field_layout.lua"] = {buildSingle = function() end},
  ["lib/bus.lua"] = {publish = function() end, subscribe = function() end, unsubscribe = function() end},
}
package.loaded["rfsuite.lib.require"] = function(name)
  if stubs[name] then return stubs[name] end
  if cache[name] == nil then
    cache[name] = assert(loadfile(SRC .. "/" .. name))()
  end
  return cache[name]
end

local function openPage(source)
  captured = nil
  local page = source and (assert(load(source, "@" .. PAGE_PATH))()) or dofile(PAGE_PATH)
  -- Opening can fail on the form API this harness does not stub; the sources are read first.
  pcall(page.open, {})
  return captured
end

local function keysOf(config)
  local keys = {}
  for i, source in ipairs(config and config.sources or {}) do keys[i] = source.key end
  return table.concat(keys, ",")
end

local function indexOf(config, key)
  for i, source in ipairs(config and config.sources or {}) do
    if source.key == key then return i end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- 1. The sources, in the order they are written.
-- ---------------------------------------------------------------------------
print("the save order")
do
  local config = openPage()
  check("the page has the battery, profile and SmartFuel sources, in that order",
    keysOf(config) == "battery,profile,smartfuel", "sources=" .. keysOf(config))
  local battery, smartfuel = indexOf(config, "battery"), indexOf(config, "smartfuel")
  check("the SmartFuel write comes after the battery write", battery ~= nil and smartfuel ~= nil and battery < smartfuel)
end

-- ---------------------------------------------------------------------------
-- 2. The SmartFuel write sends the values it read, unchanged, as MSP2_SET_SMARTFUEL_CONFIG.
-- ---------------------------------------------------------------------------
print("the SmartFuel write")
do
  local config = openPage()
  local source = config and config.sources[indexOf(config, "smartfuel") or 0]
  check("the SmartFuel source can read and write", source ~= nil and source.mspModule.buildReadMessage ~= nil
    and source.mspModule.buildWriteMessage ~= nil)
  if source then
    local read = nil
    source.mspModule.buildReadMessage(function(data) read = data end).processReply(nil, {1, 10, 50, 40})
    check("the read decodes the four SmartFuel values", read ~= nil and read.smartfuel_mode == 1
      and read.voltage_drop_rate == 10 and read.charge_drop_rate == 50 and read.sag_gain == 40)
    local written = source.mspModule.buildWriteMessage(read, function() end)
    check("the write is MSP2_SET_SMARTFUEL_CONFIG (0x4001)", written ~= nil and written.command == 0x4001,
      "command=" .. tostring(written and written.command))
    check("and sends the same four values back", written ~= nil and written.payload ~= nil
      and written.payload[1] == 1 and written.payload[2] == 10 and written.payload[3] == 50 and written.payload[4] == 40,
      "payload=" .. (written and written.payload and table.concat(written.payload, ",") or "nil"))
  end
end

-- ---------------------------------------------------------------------------
-- self-test: without the SmartFuel source the save does not write SmartFuel.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the order check must go red without the SmartFuel source")
  local source = readFile(PAGE_PATH)
  local mutated, replacements = source:gsub('      {key = "smartfuel", mspModule = smartfuelConfig},\r?\n', "", 1)
  check("self-test: the SmartFuel source was found in the page exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    local config = openPage(mutated)
    check("self-test: without the source the page writes no SmartFuel (the checks above go red)",
      indexOf(config, "smartfuel") == nil, "sources=" .. keysOf(config))
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

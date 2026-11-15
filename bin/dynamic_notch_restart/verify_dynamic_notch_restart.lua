-- Behaviour check for Setup > Filters (#2655): a save that changes a dynamic notch value restarts
-- the flight controller, because the firmware sets the dynamic notch up only at start-up. A save
-- that changes only the other filters does not.
--
-- Run it:
--     lua5.4 bin/dynamic_notch_restart/verify_dynamic_notch_restart.lua
--     lua5.4 bin/dynamic_notch_restart/verify_dynamic_notch_restart.lua --self-test
--
-- Drives the real app/pages/filters.lua with a stand-in page runtime. The runtime's save runs
-- onSaved() and then asks rebootAfterSave, in that order (app/page_runtime.lua's commitSave()),
-- and the harness does the same.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local PAGE_PATH = SRC .. "/app/pages/filters.lua"

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

local preparedData = nil
local config = nil
local runtime = nil

local runtimeClass = {}
runtimeClass.__index = runtimeClass
function runtimeClass:buildChrome() end
function runtimeClass:loadInitial()
  self.loaded = true
  self.data = preparedData
  if config.onLoaded then config.onLoaded() end
end

-- The runtime's save, in its order: the saved hook, then the restart decision.
local function save()
  if config.onSaved then config.onSaved(runtime) end
  local reboot = config.rebootAfterSave
  if type(reboot) == "function" then reboot = reboot(runtime) end
  return reboot == true
end

local pageRuntime = {
  new = function(cfg)
    config = cfg
    runtime = setmetatable({fields = {}, data = {}, controlRef = {}}, runtimeClass)
    return runtime
  end,
}

local stubs = {
  ["app/page_runtime.lua"] = pageRuntime,
  ["app/field_layout.lua"] = {buildSingle = function() end, buildGroup = function() end},
}
local cache = {}
package.loaded["rfsuite.lib.require"] = function(name)
  if stubs[name] then return stubs[name] end
  if cache[name] == nil then
    cache[name] = assert(loadfile(SRC .. "/" .. name))()
  end
  return cache[name]
end

form = {clear = function() end}

local function open(source)
  preparedData = {
    dyn_notch_count = 3, dyn_notch_q = 100, dyn_notch_min_hz = 80, dyn_notch_max_hz = 600,
    gyro_lpf1_static_hz = 200, gyro_lpf2_static_hz = 300,
  }
  local page = source and (assert(load(source, "@" .. PAGE_PATH))()) or dofile(PAGE_PATH)
  page.open({})
end

print("a change to a dynamic notch value")
do
  open()
  runtime.data.dyn_notch_q = 120
  check("changing the notch Q restarts the FC on save", save() == true)
  check("a second save with nothing changed does not restart", save() == false)
  runtime.data.dyn_notch_min_hz = 90
  check("changing the notch minimum frequency restarts the FC on save", save() == true)
  runtime.data.dyn_notch_count = 2
  check("changing the notch count restarts the FC on save", save() == true)
  runtime.data.dyn_notch_max_hz = 500
  check("changing the notch maximum frequency restarts the FC on save", save() == true)
end

print("a change to the other filters")
do
  open()
  runtime.data.gyro_lpf1_static_hz = 250
  check("changing the LPF1 cutoff does not restart the FC (its filter is re-initialised by the write)",
    save() == false)
  runtime.data.gyro_lpf2_static_hz = 350
  check("changing the LPF2 cutoff does not restart the FC either", save() == false)
end

print("a save that reverts a change")
do
  open()
  runtime.data.dyn_notch_q = 120
  save()
  runtime.data.dyn_notch_q = 100
  check("changing a notch value back to what the FC holds restarts the FC (the FC now holds 120)",
    save() == true)
end

-- ---------------------------------------------------------------------------
-- self-test: without the comparison a notch change does not restart the FC.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the notch check must go red without the comparison")
  local source = readFile(PAGE_PATH)
  local mutated, replacements = source:gsub("if rt%.data%[key%] ~= savedNotch%[key%] then notchChanged = true end",
    "", 1)
  check("self-test: the comparison was found in the page exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    open(mutated)
    runtime.data.dyn_notch_q = 120
    check("self-test: without the comparison a notch change does not restart (the checks above go red)",
      save() == false, "restart requested")
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

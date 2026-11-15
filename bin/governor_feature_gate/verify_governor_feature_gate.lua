-- Behaviour check for Setup > Governor > General (#2649): the governor mode is shown and used
-- only while the GOVERNOR feature is on, and a picked mode sets the feature to match.
--
-- Run it:
--     lua5.4 bin/governor_feature_gate/verify_governor_feature_gate.lua
--     lua5.4 bin/governor_feature_gate/verify_governor_feature_gate.lua --self-test
--
-- The firmware starts the governor only with FEATURE_GOVERNOR (BIT 26, src/main/config/feature.h,
-- and src/main/fc/init.c). With the feature off, a stored mode such as ELECTRIC was shown and its
-- fields enabled, although no governor runs.
--
-- Drives the real app/pages/setup_governor_general.lua with a stand-in page runtime that loads
-- the test's governor and feature data, runs the page's own onLoaded(), and then runs the save
-- steps the way the runtime does: beforeSave, and the reboot decision. The form widgets record
-- their getters, setters and enable state.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local PAGE_PATH = SRC .. "/app/pages/setup_governor_general.lua"

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

local FEATURE_GOVERNOR = 2 ^ 26 -- BIT(26)

-- ---------------------------------------------------------------------------
-- The page runtime stand-in.
-- ---------------------------------------------------------------------------
local preparedData = nil
local config = nil
local runtime = nil

local runtimeClass = {}
runtimeClass.__index = runtimeClass
function runtimeClass:buildChrome() end
function runtimeClass:registerField(key, field) self.fields[key] = field end
function runtimeClass:markDirty() self.dirty = true end
function runtimeClass:loadInitial()
  self.loaded = true
  self.data = preparedData
  config.onLoaded()
end

local pageRuntime = {
  new = function(cfg)
    config = cfg
    runtime = setmetatable({fields = {}, data = {}, controlRef = {}}, runtimeClass)
    runtime.controlRef.runtime = runtime
    return runtime
  end,
}

local choiceFields = {}
form = {
  clear = function() end,
  addLine = function(label) return {label = label} end,
  addChoiceField = function(_, _, choices, getter, setter)
    local field = {choices = choices, get = getter, set = setter}
    function field:enable(on) self.enabled = on end
    choiceFields[#choiceFields + 1] = field
    return field
  end,
}

local stubs = {
  ["app/page_runtime.lua"] = pageRuntime,
  ["app/field_layout.lua"] = {
    buildSingle = function(rt, _, spec)
      local key = (spec.source and (spec.source .. ":") or "") .. spec.key
      local field = {}
      function field:enable(on) self.enabled = on end
      rt.fields[key] = field
    end,
  },
}

local cache = {}
package.loaded["rfsuite.lib.require"] = function(name)
  if stubs[name] then return stubs[name] end
  if cache[name] == nil then
    cache[name] = assert(loadfile(SRC .. "/" .. name))()
  end
  return cache[name]
end

-- Opens the page with a stored mode and a feature state, and returns the mode field.
local function open(storedMode, featureOn, source)
  choiceFields = {}
  preparedData = {
    governor = {gov_mode = storedMode},
    feature = {enabledFeatures = featureOn and FEATURE_GOVERNOR or 0},
  }
  local page = source and (assert(load(source, "@" .. PAGE_PATH))()) or dofile(PAGE_PATH)
  page.open({})
  return choiceFields[1]
end

-- The save steps the runtime runs: beforeSave, then the reboot decision.
local function save()
  config.beforeSave(runtime)
  local reboot = config.rebootAfterSave
  if type(reboot) == "function" then reboot = reboot(runtime) end
  return reboot == true
end

local function featureBit()
  return math.floor(runtime.data.feature.enabledFeatures / FEATURE_GOVERNOR) % 2 == 1
end

-- ---------------------------------------------------------------------------
-- 1. Feature off, a stored mode: shown as OFF, its fields stay off.
-- ---------------------------------------------------------------------------
print("feature off, stored ELECTRIC")
do
  local field = open(1, false)
  check("the mode shows OFF", field and field.get() == 0, "shown=" .. tostring(field and field.get()))
  check("the mode fields are not enabled for the shown OFF",
    (runtime.fields["governor:gov_throttle_type"] or {}).enabled ~= true, "enabled")
end

-- ---------------------------------------------------------------------------
-- 2. Feature on, the same stored mode: shown as stored, its fields enabled.
-- ---------------------------------------------------------------------------
print("feature on, stored ELECTRIC")
do
  local field = open(1, true)
  check("the mode shows the stored ELECTRIC", field and field.get() == 1, "shown=" .. tostring(field and field.get()))
  check("the basic mode fields are enabled", (runtime.fields["governor:gov_throttle_type"] or {}).enabled == true)
end

-- ---------------------------------------------------------------------------
-- 3. Feature off, untouched save: nothing changes, no restart.
-- ---------------------------------------------------------------------------
print("feature off, untouched save")
do
  open(1, false)
  local reboot = save()
  check("the stored mode is not changed", runtime.data.governor.gov_mode == 1,
    "stored=" .. tostring(runtime.data.governor.gov_mode))
  check("the feature bit is not set by a save that did not pick a mode", not featureBit())
  check("and the save does not restart the FC", reboot == false)
end

-- ---------------------------------------------------------------------------
-- 4. Feature off, a mode picked: the feature is set with it, and the save restarts the FC.
-- ---------------------------------------------------------------------------
print("feature off, ELECTRIC picked")
do
  local field = open(0, false)
  field.set(1)
  check("the picked mode is shown", field.get() == 1, "shown=" .. tostring(field.get()))
  local reboot = save()
  check("the picked mode is stored", runtime.data.governor.gov_mode == 1)
  check("the feature bit is set to match it", featureBit())
  check("and the save restarts the FC, as the feature changed", reboot == true)
end

-- ---------------------------------------------------------------------------
-- 5. Feature on, OFF picked: the feature is cleared, and the save restarts the FC.
-- ---------------------------------------------------------------------------
print("feature on, OFF picked")
do
  local field = open(1, true)
  field.set(0)
  local reboot = save()
  check("the feature bit is cleared to match OFF", not featureBit())
  check("and the save restarts the FC, as the feature changed", reboot == true)
end

-- ---------------------------------------------------------------------------
-- 6. Feature on, a different mode picked: the feature stays on, and no restart.
-- ---------------------------------------------------------------------------
print("feature on, another mode picked")
do
  local field = open(1, true)
  field.set(2)
  local reboot = save()
  check("the feature stays on", featureBit())
  check("and the save does not restart the FC", reboot == false)
end

-- ---------------------------------------------------------------------------
-- self-test: without the feature check the page shows the stored mode with the feature off.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the feature check must go red without the feature test")
  local source = readFile(PAGE_PATH)
  local mutated, replacements = source:gsub("  if state%.picked or governorFeatureOn%(runtime%) then return storedMode%(runtime%) end",
    "  if true then return storedMode(runtime) end", 1)
  check("self-test: the feature test was found in the page exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    local field = open(1, false, mutated)
    check("self-test: without the feature test a feature-off board shows ELECTRIC (the check above goes red)",
      field and field.get() == 1, "shown=" .. tostring(field and field.get()))
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

-- Behaviour check for the native CRSF sensor lock on Setup > Telemetry (#2670): the lock
-- on Altitude, Attitude (Combined) and Flight Mode applies only when the receiver is CRSF.
--
-- Run it:
--     lua5.4 bin/telemetry_native_lock/verify_telemetry_native_lock.lua
--     lua5.4 bin/telemetry_native_lock/verify_telemetry_native_lock.lua --self-test
--
-- A flight controller in native CRSF telemetry mode (the default on 4.6) sends those
-- sensors whatever the page does. That holds only when a CRSF receiver carries the
-- telemetry: on SmartPort, F.Port, FBUS or SBUS the page used to lock the switches
-- anyway, and the first save wrote them into the sensor slots.
--
-- Drives the real app/pages/telemetry.lua and its catalog. The page runtime is a stand-in
-- that loads the test's data and then runs the page's own onLoaded(), as the real runtime
-- does after its reads. The form widgets record their labels, tags and enable state.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local PAGE_PATH = SRC .. "/app/pages/telemetry.lua"

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
-- The page runtime stand-in.
-- ---------------------------------------------------------------------------
local preparedData = nil
local runtimeConfig = nil

local fakeRuntimeClass = {}
fakeRuntimeClass.__index = fakeRuntimeClass
function fakeRuntimeClass:buildChrome() end
function fakeRuntimeClass:registerField() end
function fakeRuntimeClass:markDirty() end
function fakeRuntimeClass:loadInitial()
  self.data = preparedData
  self.loaded = true
  runtimeConfig.onLoaded()
end
function fakeRuntimeClass:dispose() end

local pageRuntimeStub = {
  new = function(config)
    runtimeConfig = config
    return setmetatable({controlRef = {}, apiVersionMinor = 10, data = {}}, fakeRuntimeClass)
  end,
}

-- The form: panels, lines, static tags and boolean switches are recorded by their label.
local lines, tags, switches
local function resetForm()
  lines, tags, switches = {}, {}, {}
end
resetForm()

form = {
  clear = function() end,
  invalidate = function() end,
  openDialog = function() end,
  getFieldSlots = function() return {0, 1, 2} end,
  addExpansionPanel = function()
    return {open = function() end, addLine = function(_, label)
      local line = {label = label}
      lines[#lines + 1] = line
      return line
    end}
  end,
  addStaticText = function(line, _, text)
    local tag = {line = line, text = text}
    function tag:value(v) self.text = v end
    tags[#tags + 1] = tag
    return tag
  end,
  addBooleanField = function(line, _, getter, setter)
    local field = {line = line, get = getter, set = setter}
    function field:enable(on) self.enabled = on end
    switches[#switches + 1] = field
    return field
  end,
}

local stubs = {
  ["app/page_runtime.lua"] = pageRuntimeStub,
}

local cache = {}
package.loaded["rfsuite.lib.require"] = function(name)
  if stubs[name] then return stubs[name] end
  if cache[name] == nil then
    cache[name] = assert(loadfile(SRC .. "/" .. name))()
  end
  return cache[name]
end

-- The catalog, for the names and the native-locked ids the page works from.
local catalog = assert(loadfile(SRC .. "/lib/telemetry_sensor_catalog.lua"))()
local NATIVE_TAG = "@i18n(app.modules.elrs_telemetry.mode_native)@"

local function nativeIds()
  local names = {}
  for id in pairs(catalog.NATIVE_LOCKED_IDS) do
    names[#names + 1] = catalog.SENSOR_LIST[id].name
  end
  table.sort(names)
  return names
end

-- Opens the page with a telemetry mode and a receiver provider, and returns the state
-- of the native rows: whether each one shows the native tag, and whether its switch is
-- free to change.
local function openWith(crsfMode, provider)
  resetForm()
  preparedData = {
    telemetry = {crsf_telemetry_mode = crsfMode, slots = {}},
    rx = {serialrx_provider = provider},
  }
  local page = dofile(PAGE_PATH)
  page.open({})
  local rows = {}
  for _, name in ipairs(nativeIds()) do
    local tagged, free = false, false
    for _, tag in ipairs(tags) do
      if tag.line.label == name and tag.text == NATIVE_TAG then tagged = true end
    end
    for _, field in ipairs(switches) do
      if field.line.label == name then free = field.enabled == true end
    end
    rows[name] = {tagged = tagged, free = free}
  end
  return rows
end

local CRSF = 9
local SBUS = 2
local CRSF_NATIVE, CRSF_CUSTOM = 0, 1

-- ---------------------------------------------------------------------------
-- 1. A CRSF receiver in native mode: the lock applies.
-- ---------------------------------------------------------------------------
print("CRSF receiver, native mode")
do
  local rows = openWith(CRSF_NATIVE, CRSF)
  local names = nativeIds()
  check("the native sensors are listed (" .. table.concat(names, ", ") .. ")", #names >= 1)
  for _, name in ipairs(names) do
    check(name .. " shows the native tag and is locked", rows[name] and rows[name].tagged and not rows[name].free,
      "tagged=" .. tostring(rows[name] and rows[name].tagged) .. " free=" .. tostring(rows[name] and rows[name].free))
  end
end

-- ---------------------------------------------------------------------------
-- 2. Other receivers in native mode: no lock, the sensors are ordinary switches.
-- ---------------------------------------------------------------------------
print("SBUS receiver, native mode")
do
  local rows = openWith(CRSF_NATIVE, SBUS)
  for _, name in ipairs(nativeIds()) do
    check(name .. " shows no native tag and its switch is free",
      rows[name] and not rows[name].tagged and rows[name].free,
      "tagged=" .. tostring(rows[name] and rows[name].tagged) .. " free=" .. tostring(rows[name] and rows[name].free))
  end
end

print("CRSF receiver, custom mode")
do
  local rows = openWith(CRSF_CUSTOM, CRSF)
  for _, name in ipairs(nativeIds()) do
    check(name .. " is an ordinary switch in custom mode",
      rows[name] and not rows[name].tagged and rows[name].free,
      "tagged=" .. tostring(rows[name] and rows[name].tagged) .. " free=" .. tostring(rows[name] and rows[name].free))
  end
end

-- ---------------------------------------------------------------------------
-- self-test: with the receiver ignored, an SBUS model in native mode is locked again.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the receiver check must go red without the receiver test")
  local source = readFile(PAGE_PATH)
  local mutated, replacements = source:gsub(
    "crsfMode = crsfReceiver and telemetry%.crsf_telemetry_mode or nil",
    "crsfMode = telemetry.crsf_telemetry_mode", 1)
  check("self-test: the receiver test was found in the page exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    resetForm()
    preparedData = {telemetry = {crsf_telemetry_mode = CRSF_NATIVE, slots = {}}, rx = {serialrx_provider = SBUS}}
    local page = assert(load(mutated, "@" .. PAGE_PATH))()
    page.open({})
    local anyTagged = false
    for _, tag in ipairs(tags) do
      if tag.text == NATIVE_TAG then anyTagged = true end
    end
    check("self-test: without the receiver test an SBUS model in native mode is locked (the checks above go red)",
      anyTagged, "no native tag on the sabotaged copy")
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

-- Behaviour check for the settings schema (issue #2325): what the suite reads from the settings file
-- is what the schema defines, and what it writes is the same.
--
-- Run it:
--     lua5.4 bin/settings_schema/verify_settings_schema.lua
--
-- What it drives, and why:
--   * lib/settings_store.lua, real, with its schema defaults. The file itself is replaced: a load
--     returns the table the scenario wrote, and a save records the table it was given.
--   * A key an older release wrote, and a section the suite no longer has, are dropped on load.
--   * A key the schema defines is kept, a missing one is filled from the schema, and a value of the
--     wrong type is taken back to the schema's default.
--   * The activelook section keeps its own keys: activelook_config.lua decides them.
--   * A save writes the pruned settings, so a stale key leaves the file the next time it is saved.
--
-- Against unpatched master the stale key and the unknown section are kept, so those checks fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then f:close() return name end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then path = resolvePath(path) end
  if env ~= nil then return realLoadfile(path, mode, env)
  elseif mode ~= nil then return realLoadfile(path, mode)
  else return realLoadfile(path) end
end

local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(resolvePath(name))
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

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
end

local function anyStub()
  return setmetatable({}, {__index = function() return function() return anyStub() end end,
    __call = function() return anyStub() end})
end
lcd = anyStub()
local function noop() end
system = setmetatable({getVersion = function() return {simulation = false} end}, {__index = function() return noop end})
model = anyStub()

-- The file: a load returns what the scenario sets, a save records what it was given.
local ini = requireModule("lib/ini.lua")
local onDisk = nil
local saved = nil
ini.load_ini_file = function()
  if onDisk == nil then return nil end
  local copy = {}
  for section, values in pairs(onDisk) do
    copy[section] = {}
    for k, v in pairs(values) do copy[section][k] = v end
  end
  return copy
end
ini.save_ini_file = function(_, tbl) saved = tbl; return true end

local store = requireModule("lib/settings_store.lua")

-- ---------------------------------------------------------------------------
-- 1. What is read: stale keys and sections are dropped
-- ---------------------------------------------------------------------------

print("load: what the schema defines")
do
  local read = store.withDefaults({
    events = {voltage = false, legacy_beep = true},
    old_section = {x = 1},
  })
  check("a key an older release wrote is dropped", read.events.legacy_beep == nil,
    "legacy_beep=" .. tostring(read.events.legacy_beep))
  check("a section the suite no longer has is dropped", read.old_section == nil,
    "old_section=" .. tostring(read.old_section))
  check("a key the schema defines is kept", read.events.voltage == false,
    "voltage=" .. tostring(read.events.voltage))
end

print("load: missing and wrong values")
do
  local read = store.withDefaults({general = {syncname = true}, events = {voltage = "maybe"}})
  check("a key the file does not have is filled from the schema", read.general.telemetry_logging == true,
    "telemetry_logging=" .. tostring(read.general.telemetry_logging))
  check("a value of the wrong type is taken back to the schema's default", read.events.voltage == true,
    "voltage=" .. tostring(read.events.voltage))
  check("a key the file sets is kept", read.general.syncname == true)
end

print("activelook keeps its own keys")
do
  local activelook = requireModule("lib/activelook_config.lua")
  -- A value of the module's own type that differs from its default, so it can only come back if kept.
  local ownKey, probe = nil, nil
  for k, def in pairs(activelook.DEFAULTS) do
    if type(def) == "number" then ownKey, probe = k, def + 1; break end
  end
  local read = store.withDefaults({activelook = {[ownKey or "x"] = probe}})
  check("an activelook key the module defines survives the schema check",
    ownKey ~= nil and read.activelook[ownKey] == probe,
    "key=" .. tostring(ownKey) .. " kept=" .. tostring(ownKey and read.activelook[ownKey]) .. " sent=" .. tostring(probe))
end

-- ---------------------------------------------------------------------------
-- 2. What is written: a save drops what the schema does not define
-- ---------------------------------------------------------------------------

print("save writes the pruned settings")
do
  saved = nil
  store.save({events = {voltage = true, legacy_beep = true}, old_section = {x = 1}})
  check("the file is written", saved ~= nil)
  check("the save leaves out a stale key", saved and saved.events and saved.events.legacy_beep == nil,
    "legacy_beep=" .. tostring(saved and saved.events and saved.events.legacy_beep))
  check("the save leaves out an unknown section", saved and saved.old_section == nil)
  check("the save keeps the schema's keys", saved and saved.events and saved.events.voltage == true)
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

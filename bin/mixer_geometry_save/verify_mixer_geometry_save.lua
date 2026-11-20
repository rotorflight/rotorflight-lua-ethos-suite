-- Behaviour check for Mixer > Geometry (#2792): a save writes the raw fields behind the values
-- the pilot changed and keeps every other raw field as read.
--
-- Run it:
--     lua5.4 bin/mixer_geometry_save/verify_mixer_geometry_save.lua
--     lua5.4 bin/mixer_geometry_save/verify_mixer_geometry_save.lua --self-test
--
-- The page shows rounded values (cyclic and collective limits as round(raw * 12 / 100) tenths of a
-- degree, geo correction as raw * 2) and its beforeSave rebuilt every raw field from them: a raw
-- limit of 1001 was written back as 1000, the roll limits were replaced by the pitch limit, and
-- each minimum was rewritten as -max, on any save.
--
-- Drives the real app/pages/mixer_geometry.lua with a stand-in page runtime that loads the test's
-- raw MSP data, runs the page's onLoaded(), lets the test set fields the way the pilot does and
-- runs beforeSave the way the runtime does. --self-test makes the cyclic limit write
-- unconditional again and requires the untouched checks to fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local PAGE_PATH = SRC .. "/app/pages/mixer_geometry.lua"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print("  ok    " .. label)
  else
    failures = failures + 1
    print("  FAIL  " .. label)
    if detail then print("        " .. tostring(detail)) end
  end
end

-- Ethos stand-ins: only what the page touches
TEXT_LEFT = 0
form = {
  clear = function() end,
  invalidate = function() end,
  openDialog = function() end,
  addLine = function(label) return {label = label} end,
}
local numberFields = {}
form.addNumberField = function(_, _, _, _, getter, setter)
  local field = {get = getter, set = setter}
  for _, m in ipairs({"suffix", "decimals", "default", "enableInstantChange"}) do field[m] = function() end end
  numberFields[#numberFields + 1] = field
  return field
end

local config, runtime
local pageRuntime = {
  new = function(cfg)
    config = cfg
    runtime = {data = {}, controlRef = {}, sources = cfg.sources, loaded = true}
    runtime.controlRef.runtime = runtime
    runtime.beforeSave = cfg.beforeSave
    function runtime:buildChrome() end
    function runtime:registerField() end
    function runtime:loadInitial() end
    function runtime:markDirty() self.dirty = true end
    return runtime
  end,
}

local noop = function() end
local stubs = {
  ["app/page_runtime.lua"] = pageRuntime,
  ["lib/bus.lua"] = {publish = noop, subscribe = noop, unsubscribe = noop},
  ["lib/msp_mixer_config.lua"] = {},
  ["lib/msp_mixer_input.lua"] = {pitch = function() return {} end, roll = function() return {} end,
    collective = function() return {} end},
  ["lib/msp_mixer_override.lua"] = {buildWriteMessage = function() return {} end, OVERRIDE_OFF = 0, OVERRIDE_PASSTHROUGH = 1},
}
package.loaded["rfsuite.lib.require"] = function(name)
  if stubs[name] then return stubs[name] end
  return assert(loadfile(SRC .. "/" .. name))()
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("a")
  f:close()
  return s
end

local function u16(v) return v < 0 and v + 0x10000 or v end

-- Raw values a configurator could have stored: limits that do not round-trip through tenths of a
-- degree, a roll limit unlike pitch, minimums that are not -max.
local function rawData()
  return {
    mixer = {swash_geo_correction = 3, swash_pitch_limit = 1001, swash_phase = 15,
      collective_tilt_correction_pos = 5, collective_tilt_correction_neg = 10},
    pitch = {rate_stabilized_pitch = 401, max_stabilized_pitch = 1001, min_stabilized_pitch = u16(-998)},
    roll = {rate_stabilized_roll = u16(-405), max_stabilized_roll = 1003, min_stabilized_roll = u16(-1003)},
    collective = {rate_stabilized_collective = 399, max_stabilized_collective = 1001,
      min_stabilized_collective = u16(-1001)},
  }
end

local function same(a, b)
  for src, fields in pairs(a) do
    for k, v in pairs(fields) do
      if b[src][k] ~= v then return false, src .. "." .. k .. " " .. tostring(v) .. " -> " .. tostring(b[src][k]) end
    end
  end
  return true
end

local FIELD = {cyclic_calibration = 1, collective_calibration = 2, geo_correction = 3, cyclic_pitch_limit = 4,
  collective_pitch_limit = 5, swash_pitch_limit = 6, swash_phase = 7}

local function open(source)
  numberFields = {}
  local page = source and assert(load(source, "@" .. PAGE_PATH))() or dofile(PAGE_PATH)
  page.open({})
  runtime.data = rawData()
  config.onLoaded()
end

local function runChecks(source)
  local results = {}

  open(source)
  config.beforeSave(runtime)
  local ok, why = same(rawData(), runtime.data)
  results.unchanged = ok
  check("a save that changes nothing keeps every raw field as read", ok, why)

  open(source)
  numberFields[FIELD.swash_phase].set(30)
  config.beforeSave(runtime)
  local expected = rawData()
  expected.mixer.swash_phase = 30
  ok, why = same(expected, runtime.data)
  results.other = ok
  check("editing the phase writes the phase and nothing else", ok, why)

  open(source)
  numberFields[FIELD.cyclic_pitch_limit].set(110)   -- 11.0 degrees
  config.beforeSave(runtime)
  local d = runtime.data
  check("an edited cyclic limit is written to pitch and roll, as +/- the limit",
    d.pitch.max_stabilized_pitch == 917 and d.pitch.min_stabilized_pitch == u16(-917)
      and d.roll.max_stabilized_roll == 917 and d.roll.min_stabilized_roll == u16(-917),
    tostring(d.pitch.max_stabilized_pitch) .. "/" .. tostring(d.roll.max_stabilized_roll))
  check("and the collective limit is kept", d.collective.max_stabilized_collective == 1001)

  open(source)
  numberFields[FIELD.cyclic_calibration].set(500)
  config.beforeSave(runtime)
  d = runtime.data
  check("an edited cyclic rate keeps each axis's direction",
    d.pitch.rate_stabilized_pitch == 500 and d.roll.rate_stabilized_roll == u16(-500),
    tostring(d.pitch.rate_stabilized_pitch) .. "/" .. tostring(d.roll.rate_stabilized_roll))
  check("and the cyclic limits are kept", d.pitch.max_stabilized_pitch == 1001 and d.roll.max_stabilized_roll == 1003)

  open(source)
  numberFields[FIELD.cyclic_pitch_limit].set(110)
  config.onLoaded()   -- a reload discards the edit
  config.beforeSave(runtime)
  ok, why = same(rawData(), runtime.data)
  check("a reload forgets the edits", ok, why)

  return results
end

print("Mixer > Geometry")
runChecks(nil)

local selfTest = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then selfTest = true end end
if selfTest then
  print()
  print("--self-test: an unconditional cyclic limit write must turn the untouched checks red")
  local spliced, n = readFile(PAGE_PATH):gsub("if edited%.cyclic_pitch_limit then", "if true then")
  check("self-test: the splice applies to both axes", n == 2, "applied " .. n)
  local before = failures
  local results = runChecks(spliced)
  failures = before
  check("self-test: an unchanged save goes red", results.unchanged == false)
  check("self-test: editing another field goes red", results.other == false)
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

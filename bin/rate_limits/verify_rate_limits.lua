-- Behaviour check for the per-rate-table limits of the rates page (issue #2350).
--
-- Run it:
--     lua5.4 bin/rate_limits/verify_rate_limits.lua
--     lua5.4 bin/rate_limits/verify_rate_limits.lua --self-test
--
-- What it drives: the real lib/rate_curve_scale.lua. The expected limits are the
-- firmware's ratesSettingLimits[] (src/main/fc/rc_rates.c:39-46) with its field
-- order {rc_rate_limit, srate_limit, expo_limit}, mapped to the roles rcRate,
-- srate and expo (see the comment above RAW_LIMITS in the module).
--
-- --self-test replaces the table with a flat 255 ceiling (the behaviour before
-- this fix) and requires the value checks to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SELF_TEST = arg and arg[1] == "--self-test"

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

-- rates_type values, the same numbering as the firmware enum (rates.h) and the module.
local TYPE = {NONE = 0, BETAFLIGHT = 1, RACEFLIGHT = 2, KISS = 3, ACTUAL = 4, QUICK = 5, ROTORFLIGHT = 6}

-- Expected firmware limits: {rc_rate_limit, srate_limit, expo_limit} per table.
-- NONE (index 0) has no entry in the firmware table, so its limits are zero.
local FIRMWARE = {
  [TYPE.NONE] = {0, 0, 0},
  [TYPE.BETAFLIGHT] = {255, 90, 100},
  [TYPE.RACEFLIGHT] = {200, 255, 100},
  [TYPE.KISS] = {255, 90, 100},
  [TYPE.ACTUAL] = {200, 200, 100},
  [TYPE.QUICK] = {255, 200, 100},
  [TYPE.ROTORFLIGHT] = {200, 100, 100},
}
local ROLE_INDEX = {rcRate = 1, srate = 2, expo = 3}
local AXIS = "main"

local function loadModule(text)
  local chunk, err
  if text then
    chunk, err = load(text, "=rate_curve_scale", "t")
  else
    chunk, err = loadfile(ROOT .. "/src/rfsuite/lib/rate_curve_scale.lua")
  end
  assert(chunk, err)
  package.loaded["rfsuite.lib.rate_curve_scale"] = nil
  return chunk()
end

-- Expected display maximum for a role: the raw limit converted the way the page does.
local function expectedMax(m, rateType, role)
  return m.toDisplayInt(FIRMWARE[rateType][ROLE_INDEX[role]], rateType, role, AXIS)
end

-- Module under test: the real file, or a copy with the flat ceiling for --self-test.
local function moduleUnderTest()
  if not SELF_TEST then return loadModule(nil) end
  local f = assert(io.open(ROOT .. "/src/rfsuite/lib/rate_curve_scale.lua", "r"))
  local text = f:read("a")
  f:close()
  local mutated, n = text:gsub("local limits = RAW_LIMITS%[rateType%] or RAW_LIMITS%[RATE_TYPE_ACTUAL%]",
    "local limits = {rcRate = 255, srate = 255, expo = 255}")
  assert(n == 1, "self-test could not find the limits lookup")
  return loadModule(mutated)
end

local m = moduleUnderTest()

if SELF_TEST then
  -- The flat ceiling must fail the firmware-limit check on a table that has a lower limit.
  local rf = expectedMax(m, TYPE.ROTORFLIGHT, "expo")
  local _, shownMax = m.displayBounds(TYPE.ROTORFLIGHT, "expo", AXIS)
  local caught = shownMax ~= rf
  print(string.format("\nself-test: flat 255 ceiling %s the Rotorflight expo check",
    caught and "is caught by" or "is NOT caught by"))
  print(string.format("%d checks, %d failed", checks, failures))
  os.exit(caught and 0 or 1)
end

print("Rate table limits: lib/rate_curve_scale.lua")

do
  local allMatch = true
  local first
  for rateType, limits in pairs(FIRMWARE) do
    for role, idx in pairs(ROLE_INDEX) do
      local want = limits[idx]
      local got = m.rawMaxFor(rateType, role)
      if got ~= want then
        allMatch = false
        first = first or string.format("type %d %s: want %d got %d", rateType, role, want, got)
      end
    end
  end
  check("the raw limits match the firmware table for every rates_type and role", allMatch, first)
end

do
  local allMatch = true
  local first
  for rateType in pairs(FIRMWARE) do
    for role in pairs(ROLE_INDEX) do
      local _, shownMax = m.displayBounds(rateType, role, AXIS)
      local want = expectedMax(m, rateType, role)
      if shownMax ~= want then
        allMatch = false
        first = first or string.format("type %d %s: want %d got %s", rateType, role, want, tostring(shownMax))
      end
    end
  end
  check("the display maximum is the converted firmware limit for every table and role", allMatch, first)
end

do
  -- The page cannot take a value above the limit: typing a huge number stops at it.
  local rf = FIRMWARE[TYPE.ROTORFLIGHT][ROLE_INDEX.expo]
  local raw = m.fromDisplayInt(99999, TYPE.ROTORFLIGHT, "expo", AXIS)
  check("a value above the limit is stored as the limit, not 255",
    raw == rf, "stored " .. tostring(raw) .. ", limit " .. rf)
end

do
  -- Round trip: the limit itself survives display and back.
  local allRound = true
  local first
  for rateType in pairs(FIRMWARE) do
    for role in pairs(ROLE_INDEX) do
      local want = FIRMWARE[rateType][ROLE_INDEX[role]]
      local back = m.fromDisplayInt(m.toDisplayInt(want, rateType, role, AXIS), rateType, role, AXIS)
      if back ~= want then
        allRound = false
        first = first or string.format("type %d %s: %d -> %d", rateType, role, want, back)
      end
    end
  end
  check("the firmware limit round-trips through the display for every table and role", allRound, first)
end

do
  -- nil (before the first read) uses the ACTUAL limits, like the scale does.
  local _, shownNil = m.displayBounds(nil, "rcRate", AXIS)
  local _, shownActual = m.displayBounds(TYPE.ACTUAL, "rcRate", AXIS)
  check("an unknown rates_type uses the ACTUAL limits", shownNil == shownActual,
    "nil " .. tostring(shownNil) .. ", actual " .. tostring(shownActual))
end

do
  -- NONE is limited to 0, as the firmware clamps a NONE profile to 0 at boot.
  local raw = m.fromDisplayInt(99999, TYPE.NONE, "rcRate", AXIS)
  check("rates_type NONE is limited to 0 like the firmware", raw == 0, "stored " .. tostring(raw))
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

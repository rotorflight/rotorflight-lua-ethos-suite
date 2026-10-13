-- Behaviour check for the Bluejay page's layout-revision bounds (#2454).
--
-- Run it:
--     lua5.3 bin/bluejay_layout_revs/verify_bluejay_layout_revs.lua
--     lua5.3 bin/bluejay_layout_revs/verify_bluejay_layout_revs.lua --self-test
--
-- What was reported:
--   Issue #2454: six rows are invisible on every released Bluejay, and the
--   layout-revision bounds in app/pages/esc_forward_bluejay.lua look like they
--   sit ahead of the firmware's release history. The finding is real; the
--   implication (that it is a defect) is not. The bounds are a port of the
--   forward model one client keeps, and the two rows the bounds hide on 203/204
--   are exactly the two the firmware stopped applying there.
--
-- Where the bounds come from:
--   stylesuxx/esc-configurator src/sources/Bluejay/settings.js, the COMMON map.
--   Its revisions are the released Bluejay layouts -- 200 (v0.9), 201 (v0.10),
--   203 (v0.12), 204 (v0.15, bluejay master = v0.16) -- plus four that never
--   shipped:
--     202   a damping-mode braking strength only
--     205   the three-way startup beep and a PWM frequency
--     206   the power rating
--     207   force-edt-arm
--     208   dithering dropped
--     209   the dynamic PWM frequency and the two thresholds
--   mathiasvr/bluejay has never released an EEPROM_LAYOUT_REVISION other than
--   33, 200, 201, 203 and 204 (Bluejay.asm:319 is 204 on master), so on 203/204
--   the two rows the bounds hide are the two the firmware does not apply:
--     * Pwm_Freq is written from its default and never read on any released tag;
--     * the startup-beep application ("Read programmed startup beep setting") is
--       gone from v0.12 onward.
--   The rows therefore come back on their own when a layout that carries them
--   ships, and the bounds must not be "fixed" to make them appear early.
--
-- What this gates:
--   * the shipped page's own FIELDS, evaluated per revision, produce exactly the
--     visibility table the configurator model implies. A bound changed for a
--     released revision turns this red, so the change has to be deliberate.
--   * the shipped simulatorResponse reports a revision that has actually been
--     released -- 204 -- and not an invented one. This is what stops the Ethos
--     simulator from showing a Bluejay that does not exist.
--
-- --self-test mutates a copy of the page's bounds and of the fixture and
-- requires both gates to go red, so neither can pass by being unable to fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"
local CODEC_SRC = PREFIX .. "lib/msp_esc_parameters_bluejay.lua"
local PAGE_SRC = PREFIX .. "app/pages/esc_forward_bluejay.lua"
local CODEC_KEY = "rfsuite.lib.msp_esc_parameters_bluejay"

local SELF_TEST = arg[1] == "--self-test"

local checks, failures = 0, 0
local failedLabels = {}
local MUST_GO_RED = {}
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
  else
    failures = failures + 1
    failedLabels[label] = true
    out(string.format("  FAIL  %s", label))
    if detail then out("        " .. tostring(detail)) end
  end
end

local function gateCheck(label, ok, detail)
  MUST_GO_RED[#MUST_GO_RED + 1] = label
  check(label, ok, detail)
end

-- ---------------------------------------------------------------------------
-- Loading the shipped files
-- ---------------------------------------------------------------------------

local realLoadfile = loadfile

_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    return realLoadfile(PREFIX .. path, ...)
  end
  return realLoadfile(path, ...)
end

-- The shared editor and the 4-way page decide nothing about the fields; their
-- open() only hands the config on, and that config carries FIELDS. Captured the
-- same way bin/bluejay_led_control/verify_bluejay_led_control.lua captures it.
package.loaded["rfsuite.app.pages.esc_forward_vendor"] = {
  open = function(_, config) captured.vendor = config end,
}
package.loaded["rfsuite.app.pages.esc_forward_4way"] = {
  open = function(_, config) captured.fourway = config end,
}

captured = {}

local function loadCodec()
  package.loaded[CODEC_KEY] = nil
  return assert(realLoadfile(CODEC_SRC))()
end

local function loadFields()
  captured = {}
  local page = assert(realLoadfile(PAGE_SRC))()
  page.open({})
  assert(type(captured.fourway) == "table", "the page did not hand off to the 4-way page")
  captured.fourway.openEditor({}, {label = "check"})
  assert(type(captured.vendor) == "table", "the page did not hand off to the shared editor")
  return captured.vendor.fields
end

-- ---------------------------------------------------------------------------
-- The model
-- ---------------------------------------------------------------------------

-- The gated keys, and the revision each is first or last visible at, read off
-- esc-configurator's COMMON map. This is the table under test, written out
-- rather than derived from the page -- a check that recomputed the bounds from
-- the bounds would agree with any bound at all.
local RELEASED = { 33, 200, 201, 203, 204 }
local CURRENT = 204

-- revision -> the gated keys visible there. Everything else in FIELDS has no
-- criterion and is visible at every revision.
local EXPECTED = {
  [33]  = {"startup_beep", "low_rpm_power_protection", "dithering"},
  [200] = {"startup_beep", "low_rpm_power_protection", "dithering"},
  [201] = {"startup_power_max", "startup_beep", "dithering"},
  [202] = {"startup_power_max", "braking_strength", "startup_beep", "dithering"},
  [203] = {"startup_power_max", "braking_strength", "dithering"},
  [204] = {"startup_power_max", "braking_strength", "dithering"},
  [205] = {"startup_power_max", "pwm_frequency", "braking_strength", "startup_beep", "dithering"},
  [206] = {"startup_power_max", "braking_strength", "power_rating", "dithering"},
  [207] = {"startup_power_max", "braking_strength", "power_rating", "force_edt_arm", "dithering"},
  [208] = {"startup_power_max", "braking_strength", "power_rating", "force_edt_arm"},
  [209] = {"startup_power_max", "pwm_frequency", "braking_strength", "power_rating", "force_edt_arm",
           "threshold_96to48", "threshold_48to24"},
}

local GATED = {
  "startup_power_max", "pwm_frequency", "braking_strength", "startup_beep",
  "low_rpm_power_protection", "power_rating", "force_edt_arm", "dithering",
  "threshold_96to48", "threshold_48to24",
}

-- The rows the page declares for each gated key, as FIELDS entries.
local function gatedFields(fields)
  local byKey = {}
  for i = 1, #fields do
    local key = fields[i].key
    if key then byKey[key] = fields[i] end
  end
  return byKey
end

-- Which gated keys are visible when the ESC reports `rev`.
local function visibleAt(byKey, rev)
  local visible = {}
  for _, key in ipairs(GATED) do
    local field = byKey[key]
    if not field then
      visible[#visible + 1] = key .. " (no row!)"
    else
      local criterion = field.enabledWhen
      local enabled = criterion == nil or criterion({layout_revision = rev}) == true
      if enabled then visible[#visible + 1] = key end
    end
  end
  table.sort(visible)
  return table.concat(visible, ",")
end

local function expectedText(keys)
  local copy = {}
  for i = 1, #keys do copy[i] = keys[i] end
  table.sort(copy)
  return table.concat(copy, ",")
end

-- ---------------------------------------------------------------------------
-- The checks
-- ---------------------------------------------------------------------------

local function runChecks(fields, fixtureLayout, labelSuffix)
  local sfx = labelSuffix or ""
  local byKey = gatedFields(fields)

  -- Gate 1: the fixture reports a revision that has actually been released.
  local released = false
  for _, rev in ipairs(RELEASED) do
    if rev == fixtureLayout then released = true end
  end
  gateCheck("the simulator fixture reports a released layout revision" .. sfx,
    released and fixtureLayout == CURRENT,
    string.format("fixture layout_revision = %s (%s a released revision, %s the current one)",
      tostring(fixtureLayout), released and "is" or "is not",
      fixtureLayout == CURRENT and "is" or "is not"))

  -- Gate 2: the page's own criteria produce the model's table, per revision.
  local drifts = {}
  local revisions = {}
  for _, rev in ipairs(RELEASED) do revisions[#revisions + 1] = rev end
  for rev = 200, 209 do revisions[#revisions + 1] = rev end
  local seen = {}
  for _, rev in ipairs(revisions) do
    if not seen[rev] then
      seen[rev] = true
      local got = visibleAt(byKey, rev)
      local want = expectedText(EXPECTED[rev] or {})
      if got ~= want then
        drifts[#drifts + 1] = string.format("rev %d: [%s] != [%s]", rev, got, want)
      end
    end
  end
  gateCheck("the page's bounds match the layout model at every revision" .. sfx,
    #drifts == 0, table.concat(drifts, "; "))

  -- Gate 3: the statement the issue is about -- 209 shows rows 204 cannot.
  local at204, at209 = visibleAt(byKey, 204), visibleAt(byKey, 209)
  gateCheck("the current release hides exactly the rows a later layout adds" .. sfx,
    at204 ~= at209 and at204 == expectedText(EXPECTED[204]) and at209 == expectedText(EXPECTED[209]),
    string.format("204 -> [%s], 209 -> [%s]", at204, at209))
end

local codec = loadCodec()
local fields = loadFields()

out("Bluejay layout-revision bounds (#2454)")
out(string.rep("=", 72))
runChecks(fields, tonumber(codec._simulatorResponse[5]))
local pass1Checks, pass1Failures = checks, failures

-- ---------------------------------------------------------------------------
-- self-test: the two mutations the gates have to catch
-- ---------------------------------------------------------------------------
if SELF_TEST then
  out("")
  out(string.rep("=", 72))
  out("self-test: the gates must go red on a changed bound and an invented fixture")
  out(string.rep("=", 72))

  -- Mutation 1: the fixture claims the never-released 209 again.
  checks, failures, failedLabels, MUST_GO_RED = 0, 0, {}, {}
  runChecks(fields, 209, " [self-test: fixture 209]")
  local fixtureWentRed = failedLabels["the simulator fixture reports a released layout revision [self-test: fixture 209]"] == true

  -- Mutation 2: a released revision's bound is loosened, so rev 200 gains a row
  -- the model says it never had. Done on a copy of the shipped FIELDS, so the
  -- shipped table is what the real pass reads.
  local loosened = loadFields()
  for i = 1, #loosened do
    local f = loosened[i]
    if f.key == "startup_power_max" and type(f.enabledWhen) == "function" then
      -- startup_power_max is atLeast(201); make it atLeast(200).
      local real = f.enabledWhen
      f.enabledWhen = function(data)
        local rev = tonumber(data and data.layout_revision) or 0
        if rev == 200 then return true end
        return real(data)
      end
    end
  end
  checks, failures, failedLabels, MUST_GO_RED = 0, 0, {}, {}
  runChecks(loosened, tonumber(codec._simulatorResponse[5]), " [self-test: bound loosened]")
  local boundWentRed = failedLabels["the page's bounds match the layout model at every revision [self-test: bound loosened]"] == true

  out("")
  out(string.rep("-", 72))
  out(string.format("  %s  fixture on 209 turns gate 1 red", fixtureWentRed and "ok  " or "FAIL"))
  out(string.format("  %s  a loosened bound turns gate 2 red", boundWentRed and "ok  " or "FAIL"))
  if not (fixtureWentRed and boundWentRed) then
    out("")
    out("SELF-TEST FAILED -- a gate cannot see the mutation it is meant to catch")
    os.exit(1)
  end
  out("")
  out("SELF-TEST PASSED -- both mutations turn their gate red")
end

checks, failures = pass1Checks, pass1Failures
out("")
out(string.rep("-", 72))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end

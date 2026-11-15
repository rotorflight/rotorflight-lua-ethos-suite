-- The Setup Wizard's collective at full stick (#2687) is written and read on the Rotorflight rates
-- type only. On Actual the same rcRates_4 byte does not mean degrees, so a write there doubles the pitch.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_rates/verify_setup_wizard_rates.lua
--
-- It checks the gate in src/rfsuite/lib/setup_wizard_rates.lua, then drives the real
-- src/rfsuite/app/pages/setup_wizard_pitch.lua to its full-stick page. The UI, bus and MSP modules are
-- stubs; a simulated flight controller has two rate profiles: the first on Rotorflight, the second on
-- Actual (with a different rcRates_4, so a write to it shows). It pins:
--   1. the Rotorflight rates type is 6, so a nil constant cannot pass the gate;
--   2. the gate allows the Rotorflight type only;
--   3. the full-stick page lists one row, for the Rotorflight profile, and shows the Actual note;
--   4. every row writes only its own profile: the Actual profile's rcRates_4 is left alone.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."

local failures, checks = 0, 0
local function check(label, got, want)
  checks = checks + 1
  if got ~= want then
    failures = failures + 1
    print(string.format("FAIL %s: got %s, want %s", label, tostring(got), tostring(want)))
  end
end

local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

-- The gate ------------------------------------------------------------------

package.loaded["rfsuite.lib.setup_wizard_rates"] = nil
local R = dofile(ROOT .. "/src/rfsuite/lib/setup_wizard_rates.lua")

-- Missing function reads as a failed check, not a Lua error, so the page checks still run.
local function settable(tuning)
  if not R.collectiveSettable then return "no collectiveSettable" end
  return R.collectiveSettable(tuning)
end

check("1. the Rotorflight rates type is 6", R.ROTORFLIGHT, 6)
check("2a. the Rotorflight type is settable", settable({rates_type = 6, rcRates_4 = 96}), true)
check("2b. the Actual type is not settable", settable({rates_type = 4, rcRates_4 = 96}), false)
check("2c. the Kiss type is not settable", settable({rates_type = 3, rcRates_4 = 96}), false)
check("2d. no tuning is not settable", settable(nil), false)

-- The simulated flight controller -------------------------------------------

local RATE_MASK = 128   -- R.RATE_PROFILE_MASK: the profile select value is the profile plus this
local ROTORFLIGHT_TYPE, ACTUAL_TYPE = 6, 4
local fc = {
  active = 0,
  -- index (0-based) -> RC_TUNING. Profile 0 is Rotorflight, profile 1 is Actual.
  profiles = {
    [0] = {rates_type = ROTORFLIGHT_TYPE, rcRates_4 = 96},
    [1] = {rates_type = ACTUAL_TYPE, rcRates_4 = 48},
  },
  -- Adjustment slots: slot 1 is the rate profile function, slot 2 the PID profile function, on one channel.
  ranges = {
    [1] = {adjFunction = 1, adjChannel = 0, adjMin = 1, adjMax = 2},
    [2] = {adjFunction = 2, adjChannel = 0},
  },
}

local function onRequest(msg)
  if msg.kind == "status" then
    msg.onData({current_control_rate_profile_index = fc.active})
  elseif msg.kind == "range" then
    msg.onData(fc.ranges[msg.slot] or {adjFunction = 0})
  elseif msg.kind == "select" then
    fc.active = msg.value - RATE_MASK
    if msg.onOk then msg.onOk() end
  elseif msg.kind == "rc_read" then
    msg.onData(copy(fc.profiles[fc.active]))
  elseif msg.kind == "rc_write" then
    fc.profiles[fc.active] = copy(msg.tuning)
    if msg.onOk then msg.onOk() end
  end
end

-- The page's screen: records what the page last drew. Its begin() clears it on each build.
local view = {}
local scr = {}
function scr.begin() view.title, view.body, view.accent, view.rows, view.forward, view.onStart = nil, nil, nil, nil, nil, nil end
function scr.text(_, title, body, accent) view.title, view.body, view.accent = title, body, accent end
function scr.checks(_, rows) view.rows = rows; return {} end
function scr.row(_, _, _, forward) view.forward = forward; return {} end
function scr.safety(_, _, _, _, onStart) view.onStart = onStart; return {} end
setmetatable(scr, {__index = function() return function() end end})

local wiz = {inputs = {}}
setmetatable(wiz, {__index = function() return function() end end})
function wiz.forward() return {text = "Save", press = function() end} end
function wiz.canMove() return true end
function wiz.roleName() return "axis" end
function wiz.rebuild() end

local stubs = {
  ["app/setup_wizard_ui.lua"] = {new = function() return scr end, notLoaded = function(list) return list end},
  ["app/setup_wizard_art.lua"] = {image = function() return {} end},
  ["lib/bus.lua"] = {
    subscribe = function() end,
    unsubscribe = function() end,
    publish = function(topic, msg) if topic == "msp.request" then onRequest(msg) end end,
  },
  ["lib/msp_adjustments.lua"] = {
    RANGE_COUNT = 42,
    buildReadSlotMessage = function(slot, onData, onError)
      return {kind = "range", slot = slot, onData = onData, onError = onError}
    end,
  },
  ["lib/msp_status.lua"] = {
    buildReadMessage = function(onData, onError) return {kind = "status", onData = onData, onError = onError} end,
  },
  ["lib/msp_select_profile.lua"] = {
    buildWriteMessage = function(value, onOk, onErr) return {kind = "select", value = value, onOk = onOk, onErr = onErr} end,
  },
  ["lib/msp_rc_tuning.lua"] = {
    buildReadMessage = function(onData, onError) return {kind = "rc_read", onData = onData, onError = onError} end,
    buildWriteMessage = function(tuning, onOk, onErr)
      return {kind = "rc_write", tuning = tuning, onOk = onOk, onErr = onErr}
    end,
  },
  ["lib/setup_wizard_rates.lua"] = R,
}

package.loaded["rfsuite.lib.require"] = function(path)
  if stubs[path] then return stubs[path] end
  -- The real helper libraries the page uses (lib/setup_wizard_heli.lua, lib/setup_wizard_adjust.lua).
  return dofile(ROOT .. "/src/rfsuite/" .. path)
end

local PAGE = ROOT .. "/src/rfsuite/app/pages/setup_wizard_pitch.lua"
local FULL_TITLE = "@i18n(app.modules.setup_wizard.pit_full_title)@"
local FULL_TEXT = "@i18n(app.modules.setup_wizard.pit_full_text)@"
local ACTUAL_NOTE = "@i18n(app.modules.setup_wizard.rates_actual_note)@"

-- The page, driven to the full-stick screen ----------------------------------

local node = assert(loadfile(PAGE), "cannot open " .. PAGE .. " (run from the repository root)")().new(wiz)
node.build()
check("3. the safety page offers Start", type(view.onStart), "function")
view.onStart()

-- Forward through the base pages until the full-stick page.
for _ = 1, 10 do
  node.build()
  if view.title == FULL_TITLE then break end
  view.forward.press()
end
check("4. the full-stick page is reached", view.title, FULL_TITLE)

-- Each row is one profile the page sets.
local rows = view.rows or {}
check("5a. one row, for the Rotorflight profile", #rows, 1)
check("5b. the Rotorflight row shows its collective (12.0 deg)", rows[1] and rows[1].number[3](), 120)
check("5c. the Actual note is shown", view.accent, ACTUAL_NOTE)
check("5d. the body is the full-stick text", view.body, FULL_TEXT)

-- Typing a value on each row writes that row's profile. 15.0 deg is rcRates_4 120.
for _, row in ipairs(rows) do row.number[4](150) end
check("6a. the Rotorflight profile's rcRates_4 is written", fc.profiles[0].rcRates_4, 120)
check("6b. the Actual profile's rcRates_4 is not written", fc.profiles[1].rcRates_4, 48)

if failures > 0 then
  print(string.format("%d of %d check(s) failed", failures, checks))
  os.exit(1)
end
print(string.format("setup wizard collective gate: all %d checks passed", checks))

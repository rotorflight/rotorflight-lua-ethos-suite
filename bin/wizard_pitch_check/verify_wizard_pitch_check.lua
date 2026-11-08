-- Behaviour check for the Setup Wizard's pitch measure pages (#2706): the page can hold the
-- blades at 0 degrees to check the gauge there, and at 0 degrees it does not measure or calibrate.
--
-- Run it (from the repository root):
--     lua5.4 bin/wizard_pitch_check/verify_wizard_pitch_check.lua
--     lua5.4 bin/wizard_pitch_check/verify_wizard_pitch_check.lua --self-test
--
-- Drives the real src/rfsuite/app/pages/setup_wizard_pitch.lua. The UI, the bus and the wizard
-- context are stubs; the wizard context records what the page asks the flight controller to hold.
-- It pins:
--   1. the measure page holds 9 degrees at the start, with the measure, rate, calibrate and check rows;
--   2. the check row holds 0 degrees, and the page then shows only the check row back to 9 degrees;
--   3. the check row again holds 9 degrees, with the calibrate row back;
--   4. the fine page still holds 9 degrees.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."

local failures, checks = 0, 0
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

-- The strings the page shows, by key, as the i18n tags they are written with.
local CALIBRATE = "@i18n(app.modules.setup_wizard.pit_calibrate)@"
local CHECK_ZERO = "@i18n(app.modules.setup_wizard.pit_check_zero)@"
local BACK_NINE = "@i18n(app.modules.setup_wizard.pit_back_nine)@"

-- The page's screen: records the rows the page last drew.
local view = {}
local scr = {}
function scr.begin() view.rows, view.forward = nil, nil end
function scr.text() end
function scr.checks(_, rows) view.rows = rows; return {} end
function scr.row(_, _, _, forward) view.forward = forward; return {} end
function scr.safety(_, _, _, _, onStart) view.onStart = onStart; return {} end
setmetatable(scr, {__index = function() return function() end end})

-- The holds the page asks for, in order. `holdAxes` returns true, as a live hold does.
local holds = {}
local wiz = {inputs = {}}
setmetatable(wiz, {__index = function() return function() end end})
function wiz.forward() return {text = "Next", press = function() end} end
function wiz.canMove() return true end
function wiz.roleName() return "axis" end
function wiz.rebuild() end
-- The page calls these with a dot, so the hold is the first argument.
function wiz.holdAxes(want) holds[#holds + 1] = want; return true end
function wiz.releaseAxes() holds[#holds + 1] = "release" end

local stubs = {
  ["app/setup_wizard_ui.lua"] = {new = function() return scr end, notLoaded = function(list) return list end},
  ["app/setup_wizard_art.lua"] = {image = function() return {} end},
  ["lib/bus.lua"] = {subscribe = function() end, unsubscribe = function() end, publish = function() end},
}
package.loaded["rfsuite.lib.require"] = function(path)
  if stubs[path] then return stubs[path] end
  return dofile(ROOT .. "/src/rfsuite/" .. path)
end

local heli = dofile(ROOT .. "/src/rfsuite/lib/setup_wizard_heli.lua")
local RAW_9 = heli.swashRaw(9)
local RAW_0 = heli.swashRaw(0)

local function rowWithAnswer(answer)
  for _, row in ipairs(view.rows or {}) do
    if row.answer == answer then return row end
  end
  return nil
end

local function hasMeasure()
  for _, row in ipairs(view.rows or {}) do
    if row.number and row.number[3] and row.label then return true end
  end
  return false
end

local function lastHold()
  for i = #holds, 1, -1 do
    if type(holds[i]) == "table" then return holds[i] end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- The page, driven to the collective measure page.
-- ---------------------------------------------------------------------------
local PAGE = ROOT .. "/src/rfsuite/app/pages/setup_wizard_pitch.lua"
local source = readFile(PAGE)
local node = assert(load(source, "@" .. PAGE))().new(wiz)
node.build()
view.onStart()

-- Forward until the first measure page.
for _ = 1, 10 do
  node.build()
  if hasMeasure() then break end
  view.forward.press()
end

print("the measure page at 9 degrees")
do
  node.build()
  check("1a. the page measures", hasMeasure())
  check("1b. it holds 9 degrees at the start", lastHold() ~= nil and lastHold().collective == RAW_9,
    "collective=" .. tostring(lastHold() and lastHold().collective))
  check("1c. it offers Calibrate", rowWithAnswer(CALIBRATE) ~= nil)
  check("1d. it offers the check at 0 degrees", rowWithAnswer(CHECK_ZERO) ~= nil)
end

print("the check at 0 degrees")
do
  rowWithAnswer(CHECK_ZERO).press()
  node.build()
  local hold = lastHold()
  check("2a. the page now holds 0 degrees", hold ~= nil and hold.collective == RAW_0,
    "collective=" .. tostring(hold and hold.collective))
  check("2b. it does not measure or calibrate at 0 degrees", not hasMeasure() and rowWithAnswer(CALIBRATE) == nil)
  check("2c. it offers the way back to 9 degrees", rowWithAnswer(BACK_NINE) ~= nil)
end

print("back to 9 degrees")
do
  rowWithAnswer(BACK_NINE).press()
  node.build()
  local hold = lastHold()
  check("3a. the page holds 9 degrees again", hold ~= nil and hold.collective == RAW_9,
    "collective=" .. tostring(hold and hold.collective))
  check("3b. Calibrate is back", rowWithAnswer(CALIBRATE) ~= nil)
end

print("the fine page")
do
  view.forward.press()
  node.build()
  local hold = lastHold()
  check("4. the fine page still holds 9 degrees", hold ~= nil and hold.collective == RAW_9,
    "collective=" .. tostring(hold and hold.collective))
end

-- ---------------------------------------------------------------------------
-- self-test: without the check row there is no way to 0 degrees.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the check row must go red without the toggle")
  local mutated, replacements = source:gsub(
    "rows%[#rows %+ 1%] = {answer = checkAnswer, press = toggleCheck, needsMotion = true}", "", 1)
  check("self-test: the check row was found in the page exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    holds = {}
    view.rows = nil
    local sabotaged = assert(load(mutated, "@" .. PAGE))().new(wiz)
    sabotaged.build()
    view.onStart()
    for _ = 1, 10 do
      sabotaged.build()
      if hasMeasure() then break end
      view.forward.press()
    end
    check("self-test: without the toggle there is no check at 0 degrees (the checks above go red)",
      rowWithAnswer(CHECK_ZERO) == nil, "the check row is still there")
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

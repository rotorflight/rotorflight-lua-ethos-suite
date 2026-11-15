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
--   4. the fine page still holds 9 degrees;
--   5. the cyclic measure page holds roll at 9 degrees (#2709);
--   6. the hold angle stepper (#2708) holds the angle it is set to, at most the stored limit, and
--      either side of zero (the negative side checks the collective geometry), and away from 9
--      degrees the page does not measure or calibrate.

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
local MEASURED = "@i18n(app.modules.setup_wizard.pit_measured)@"
local HOLD_ANGLE = "@i18n(app.modules.setup_wizard.pit_hold_angle)@"

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

local function rowWithLabel(label)
  for _, row in ipairs(view.rows or {}) do
    if row.label == label then return row end
  end
  return nil
end

-- The measured blade pitch row (the stepper and the rate rows are not measures).
local function hasMeasure()
  return rowWithLabel(MEASURED) ~= nil
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

print("the cyclic measure page")
do
  -- The fine page's Next goes on to the cyclic measure page (#2709): roll is held at 9 degrees,
  -- so the blades stay along the boom and pitch is not held.
  view.forward.press()
  node.build()
  local hold = lastHold()
  check("5a. the cyclic page holds roll at 9 degrees", hold ~= nil and hold.roll == RAW_9,
    "roll=" .. tostring(hold and hold.roll))
  check("5b. the cyclic page does not hold pitch", hold ~= nil and hold.pitch == 0,
    "pitch=" .. tostring(hold and hold.pitch))
  check("5c. the cyclic page offers Calibrate", rowWithAnswer(CALIBRATE) ~= nil)
end

print("the hold angle stepper on the cyclic page")
do
  -- The stored roll limit is 10 degrees here (tenths: 100). The stepper cannot hold past it.
  wiz.inputs.roll = {max = heli.limitRaw(10)}
  node.build()
  local stepper = rowWithLabel(HOLD_ANGLE)
  check("6a. the cyclic page offers the hold angle stepper", stepper ~= nil and stepper.number ~= nil)
  check("6b. the stepper starts at 9 degrees", stepper ~= nil and stepper.number[3]() == 90,
    "value=" .. tostring(stepper and stepper.number[3]()))
  stepper.number[4](1200)   -- 120 degrees asked for
  node.build()
  stepper = rowWithLabel(HOLD_ANGLE)
  local hold = lastHold()
  check("6c. the stepper holds at most the stored limit", hold ~= nil and hold.roll == heli.swashRaw(10)
    and stepper ~= nil and stepper.number[3]() == 100,
    "roll=" .. tostring(hold and hold.roll) .. " value=" .. tostring(stepper and stepper.number[3]()))
  stepper.number[4](50)   -- 5 degrees, to look at the gauge
  node.build()
  hold = lastHold()
  check("6d. at 5 degrees the page holds roll at 5 degrees", hold ~= nil and hold.roll == heli.swashRaw(5),
    "roll=" .. tostring(hold and hold.roll))
  check("6e. at 5 degrees it does not measure or calibrate", not hasMeasure() and rowWithAnswer(CALIBRATE) == nil)
  check("6f. at 5 degrees it offers the way back to 9 degrees", rowWithAnswer(BACK_NINE) ~= nil)
  rowWithAnswer(BACK_NINE).press()
  node.build()
  hold = lastHold()
  check("6g. back to 9 degrees it holds 9 degrees and Calibrate is back",
    hold ~= nil and hold.roll == RAW_9 and rowWithAnswer(CALIBRATE) ~= nil,
    "roll=" .. tostring(hold and hold.roll))
  -- The stepper goes both ways: the negative side checks the collective geometry (-10 after +10).
  stepper = rowWithLabel(HOLD_ANGLE)
  check("6h. the stepper range is symmetric about zero, at the stored limit",
    stepper ~= nil and stepper.number[1] == -100 and stepper.number[2] == 100,
    "range=" .. tostring(stepper and stepper.number[1]) .. ".." .. tostring(stepper and stepper.number[2]))
  stepper.number[4](-1200)   -- minus 120 degrees asked for
  node.build()
  stepper = rowWithLabel(HOLD_ANGLE)
  hold = lastHold()
  check("6i. the stepper holds the negative side, at most minus the stored limit",
    hold ~= nil and hold.roll == heli.swashRaw(-10) and stepper ~= nil and stepper.number[3]() == -100,
    "roll=" .. tostring(hold and hold.roll) .. " value=" .. tostring(stepper and stepper.number[3]()))
  stepper.number[4](-50)     -- minus 5 degrees
  node.build()
  hold = lastHold()
  check("6j. at minus 5 degrees the page holds roll at minus 5 degrees", hold ~= nil and hold.roll == heli.swashRaw(-5),
    "roll=" .. tostring(hold and hold.roll))
  rowWithLabel(HOLD_ANGLE).number[4](90)   -- back to 9 degrees
  node.build()
  wiz.inputs.roll = nil
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

  print()
  print("--self-test: the stepper must go red without its bound")
  local bounded, bReplacements = source:gsub(
    "heli%.clamp%(math%.floor%(tenths %+ 0%.5%), %-limit, limit%) / 10", "tenths / 10", 1)
  check("self-test: the stepper bound was found in the page exactly once", bReplacements == 1,
    "replacements=" .. bReplacements)
  if bReplacements == 1 then
    holds = {}
    view.rows = nil
    wiz.inputs.collective = {max = heli.limitRaw(10)}
    local unbounded = assert(load(bounded, "@" .. PAGE))().new(wiz)
    unbounded.build()
    view.onStart()
    for _ = 1, 10 do
      unbounded.build()
      if hasMeasure() then break end
      view.forward.press()
    end
    local stepper = rowWithLabel(HOLD_ANGLE)
    stepper.number[4](1200)
    unbounded.build()
    local hold = lastHold()
    check("self-test: without the bound the stepper holds past the limit (the checks above go red)",
      hold ~= nil and hold.collective ~= heli.swashRaw(10), "collective=" .. tostring(hold and hold.collective))
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

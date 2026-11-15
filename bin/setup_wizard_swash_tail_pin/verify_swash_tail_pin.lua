-- Behaviour check for #2700: the swash step must stage a tail-pin move and
-- request an FC restart whenever the tail-pin row shows that the pin moves on save.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_swash_tail_pin/verify_swash_tail_pin.lua
--     lua5.4 bin/setup_wizard_swash_tail_pin/verify_swash_tail_pin.lua --self-test
--
-- What it pins:
--   1. on a stored mismatch (motorised mode, pin on SERVO 4), entering the tail screen
--      shows "Moves on save", stages the tail-pin commit, and requests an FC reboot;
--   2. the tail screen and the done screen display the restart note;
--   3. on a matching configuration (motorised mode, pin on MOTOR 2), the tail screen
--      shows the pin name, stages no commit, and requests no reboot;
--   4. changing the tail mode via the drop-down requests a reboot and stages the commit;
--   5. an unmovable pin (NONE) shows "Set in Mixer", stages no commit, and requests no reboot.
--
-- --self-test runs the same checks on mutants:
--   - Mutant 1: stageTailCommit does not request reboot on movable pin
--   - Mutant 2: pinText does not stage tail commit on stored mismatch
-- Both mutants must be caught and fail the checks.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local MODULE = ROOT .. "/src/rfsuite/app/pages/setup_wizard_swash.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

-- ── recording stubs ───────────────────────────────────────────────────

local scr
local function newScreen()
  local s = { rows = nil, backPress = nil, forwardPress = nil, startPress = nil, textTitle = nil, textNote = nil }
  function s.begin()
    s.rows, s.backPress, s.forwardPress, s.startPress = nil, nil, nil, nil
    s.textTitle, s.textNote = nil, nil
  end
  function s.text(_, title, _, note) s.textTitle = title; s.textNote = note end
  function s.picture() end
  function s.step() end
  function s.paint() end
  function s.refresh() end
  function s.checks(_, rows) s.rows = rows; return {} end
  function s.row(_, back, _, forward)
    s.backPress = back
    s.forwardPress = forward and forward.press
    return {}
  end
  function s.safety(_, _, _, _, onStart)
    s.startPress = onStart
    return {}
  end
  return s
end

local realHeli = assert(loadfile(ROOT .. "/src/rfsuite/lib/setup_wizard_heli.lua"))()
local mspcodec = assert(loadfile(ROOT .. "/src/rfsuite/lib/mspcodec.lua"))()

local stubs = {}
package.loaded["rfsuite.lib.require"] = function(p)
  local s = stubs[p]
  if not s then error("unexpected require: " .. tostring(p)) end
  return s
end

stubs["lib/mspcodec.lua"] = mspcodec
stubs["lib/setup_wizard_heli.lua"] = realHeli
stubs["lib/bus.lua"] = {
  publish = function() end,
  subscribe = function() end,
  unsubscribe = function() end,
}
stubs["lib/msp_status.lua"] = {
  buildReadMessage = function(cb) return { processReply = function() if cb then cb({}) end end } end,
}
stubs["lib/msp_select_profile.lua"] = {
  buildWriteMessage = function(profile, onDone) return { processReply = function() if onDone then onDone() end end } end,
}
stubs["lib/msp_governor_profile.lua"] = {
  buildReadMessage = function(cb) return { processReply = function() if cb then cb({}) end end } end,
  buildWriteMessage = function(g, onDone) return { processReply = function() if onDone then onDone() end end } end,
}
stubs["app/setup_wizard_ui.lua"] = {
  notLoaded = function(keys) return keys end,
  new = function()
    scr = newScreen()
    return scr
  end,
}
stubs["app/setup_wizard_art.lua"] = {
  image = function(name, w, h) return { name = name, w = w, h = h } end,
  photo = function(name, s, f) return { name = name, s = s, f = f } end,
}

local tailOutput = assert(loadfile(ROOT .. "/src/rfsuite/lib/msp_tail_motor_output.lua"))()
stubs["lib/msp_tail_motor_output.lua"] = tailOutput

local T_PIN_MOVE = "@i18n(app.modules.setup_wizard.swa_pin_move)@"
local T_PIN_STUCK = "@i18n(app.modules.setup_wizard.swa_pin_stuck)@"
local T_RESTART = "@i18n(app.modules.setup_wizard.swa_restart)@"
local T_PIN_SERVO = "@i18n(app.modules.setup_wizard.swa_pin_servo)@"
local T_PIN_MOTOR = "@i18n(app.modules.setup_wizard.swa_pin_motor)@"
local T_ROW_PIN = "@i18n(app.modules.setup_wizard.swa_row_pin)@"
local T_TAIL_TITLE = "@i18n(app.modules.setup_wizard.swa_tail_title)@"

local function findRow(rows, label)
  for _, r in ipairs(rows or {}) do
    if r.label == label then return r end
  end
  return nil
end

local function hasNote(rows, note)
  for _, r in ipairs(rows or {}) do
    if r.note == note then return true end
  end
  return false
end

-- ── test runner ───────────────────────────────────────────────────────

local failures, checks = 0, 0
local silent = false
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    if not silent then
      print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
    end
  end
end

local function runSession(source, config)
  package.loaded["rfsuite.setup_wizard.swash"] = nil

  local mix = {
    swash_type = config.swashType or 2,
    main_rotor_dir = config.mainDir or 0,
    tail_rotor_mode = config.tailMode,
  }
  local inputs = { yaw = { rate = 1000 } }
  local pinData = config.pin
  local rebootPending = false
  local commits = {}
  local step

  local wiz = {
    mixConfig = function() return mix end,
    editMix = function(fn) fn(mix) end,
    editInput = function(name, fn) if inputs[name] then fn(inputs[name]) end end,
    motorised = function() return realHeli.motorised(mix.tail_rotor_mode) end,
    rebootPending = function() return rebootPending == true end,
    requestReboot = function() rebootPending = true end,
    commitOnSave = function(key, run) commits[key] = run end,
    send = function() end,
    fetch = function(queries, cb)
      local res = {}
      if queries.pin then res.pin = pinData end
      cb(res)
    end,
    rebuild = function() if step and step.build then step.build() end end,
  }

  local chunk = assert(load(source, "@setup_wizard_swash.lua", "t"))
  local factory = chunk()
  step = factory.new(wiz)

  -- Initial build opens on prepare screen
  step.build()
  assert(scr.startPress, "expected prepare screen to have startPress")

  -- Navigate: prepare -> type -> dir -> tail
  scr.startPress()   -- to type
  step.build()
  assert(scr.forwardPress, "expected type screen to have forwardPress")
  scr.forwardPress() -- to dir
  step.build()
  assert(scr.forwardPress, "expected dir screen to have forwardPress")
  scr.forwardPress() -- to tail
  step.build()

  return {
    step = step,
    wiz = wiz,
    mix = mix,
    commits = commits,
    getReboot = function() return rebootPending end,
    getScreen = function() return scr end,
    forwardToDone = function()
      assert(scr.forwardPress, "expected tail screen to have forwardPress")
      scr.forwardPress()
      step.build()
    end,
  }
end

local function runTests(source)
  local before = failures

  -- 1. Stored mismatch: motorised tail mode, pin still on SERVO 4
  local s1 = runSession(source, {
    tailMode = realHeli.TAIL_MOTORIZED,
    pin = { supported = true, output = tailOutput.OUTPUT.SERVO, result = tailOutput.RESULT.OK },
  })
  local pinRow1 = findRow(s1.getScreen().rows, T_ROW_PIN)
  check("stored mismatch: pin row says Moves on save", pinRow1 and pinRow1.value == T_PIN_MOVE)
  check("stored mismatch: stages tail_pin commit on save", s1.commits["tail_pin"] ~= nil)
  check("stored mismatch: requests FC reboot", s1.getReboot() == true)
  check("stored mismatch: tail screen displays restart note", hasNote(s1.getScreen().rows, T_RESTART))

  s1.forwardToDone()
  check("stored mismatch: done screen displays restart note", s1.getScreen().textNote == T_RESTART)

  -- 2. Matching config: motorised tail mode, pin already on MOTOR 2
  local s2 = runSession(source, {
    tailMode = realHeli.TAIL_MOTORIZED,
    pin = { supported = true, output = tailOutput.OUTPUT.MOTOR, result = tailOutput.RESULT.OK },
  })
  local pinRow2 = findRow(s2.getScreen().rows, T_ROW_PIN)
  check("matching motor: pin row shows MOTOR 2", pinRow2 and pinRow2.value == T_PIN_MOTOR)
  check("matching motor: stages no tail_pin commit", s2.commits["tail_pin"] == nil)
  check("matching motor: no reboot requested", s2.getReboot() == false)
  check("matching motor: tail screen has no restart note", not hasNote(s2.getScreen().rows, T_RESTART))

  -- 3. Matching config: variable pitch mode, pin on SERVO 4
  local s3 = runSession(source, {
    tailMode = realHeli.TAIL_VARIABLE,
    pin = { supported = true, output = tailOutput.OUTPUT.SERVO, result = tailOutput.RESULT.OK },
  })
  local pinRow3 = findRow(s3.getScreen().rows, T_ROW_PIN)
  check("matching servo: pin row shows SERVO 4", pinRow3 and pinRow3.value == T_PIN_SERVO)
  check("matching servo: stages no tail_pin commit", s3.commits["tail_pin"] == nil)
  check("matching servo: no reboot requested", s3.getReboot() == false)

  -- 4. Mode change via drop-down: variable pitch -> motorised
  local tailRow3 = findRow(s3.getScreen().rows, T_TAIL_TITLE)
  assert(tailRow3 and tailRow3.choice and tailRow3.choice.set, "tail choice dropdown expected")
  tailRow3.choice.set(realHeli.TAIL_MOTORIZED)
  check("dropdown change: requests FC reboot", s3.getReboot() == true)
  check("dropdown change: stages tail_pin commit", s3.commits["tail_pin"] ~= nil)
  local pinRow3After = findRow(s3.getScreen().rows, T_ROW_PIN)
  check("dropdown change: pin row updates to Moves on save", pinRow3After and pinRow3After.value == T_PIN_MOVE)

  -- 5. Stuck/unmovable pin: pin on NONE
  local s5 = runSession(source, {
    tailMode = realHeli.TAIL_MOTORIZED,
    pin = { supported = true, output = tailOutput.OUTPUT.NONE, result = tailOutput.RESULT.OK },
  })
  local pinRow5 = findRow(s5.getScreen().rows, T_ROW_PIN)
  check("unmovable pin: shows Set in Mixer", pinRow5 and pinRow5.value == T_PIN_STUCK)
  check("unmovable pin: stages no tail_pin commit", s5.commits["tail_pin"] == nil)
  check("unmovable pin: no reboot requested", s5.getReboot() == false)

  return failures - before
end

-- ── run ───────────────────────────────────────────────────────────────

local realSource = readFile(MODULE)

if not SELF_TEST then
  local f = runTests(realSource)
  if f == 0 then
    print(string.format("OK  all %d checks passed", checks))
    os.exit(0)
  else
    print(string.format("FAILED  %d of %d checks failed", f, checks))
    os.exit(1)
  end
end

-- ── self-test with mutants ────────────────────────────────────────────

print("Running self-test against injected mutants...")

local selfTestFailures = 0
local function checkMutant(name, mutantSource)
  silent = true
  local f = runTests(mutantSource)
  silent = false
  if f > 0 then
    print(string.format("  ok    mutant caught: %s (%d checks went red)", name, f))
  else
    print(string.format("  FAIL  mutant NOT caught: %s", name))
    selfTestFailures = selfTestFailures + 1
  end
end

-- Mutant 1: stageTailCommit does not call wiz.requestReboot() on movable pin
local m1 = realSource:gsub(
  "if tailOutput%.movable%(values, motorised%) then%s+wiz%.requestReboot%(%)%s+end",
  ""
)
assert(m1 ~= realSource, "mutant 1 substitution failed")
checkMutant("stageTailCommit omits wiz.requestReboot()", m1)

-- Mutant 2: pinText does not stage tail commit on stored mismatch
local m2 = realSource:gsub(
  "stageTailCommit%(motorised%)%s+return T%.pinMove",
  "return T.pinMove"
)
assert(m2 ~= realSource, "mutant 2 substitution failed")
checkMutant("pinText omits stageTailCommit(motorised)", m2)

if selfTestFailures == 0 then
  print("ALL SELF-TEST CHECKS PASSED")
  os.exit(0)
else
  print(string.format("SELF-TEST FAILED (%d failures)", selfTestFailures))
  os.exit(1)
end

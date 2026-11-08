-- Behaviour check for #2701: a gear stage change in the Setup Wizard's Motor & ESC step
-- keeps the tail ratio, and never writes a tail product past the firmware's limit.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_motor_tail_stage/verify_setup_wizard_motor_tail_stage.lua
--     lua5.4 bin/setup_wizard_motor_tail_stage/verify_setup_wizard_motor_tail_stage.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/setup_wizard_motor.lua, with the UI, art
-- and MSP modules replaced by recording stubs. The page is opened on its Main screen and the
-- stage drop-down is set. Each scenario pins what the motor config write holds afterwards:
--   1. tail driven from the intermediate shaft, one stage to two with whole teeth: the tail
--      ratio main x a / (mesh x b) is the same before and after, and the write holds the
--      drive tooth a the change needs;
--   2. the same, but the ratio cannot be kept with whole teeth: the stage is not changed, no
--      write is made, and the page shows the refusal note;
--   3. the same, but the restored drive tooth would take a product past TRAIN_MAX: refused;
--   4. tail driven from the main shaft: a stage change leaves the tail as it is.
--
-- --self-test runs the same checks on copies with parts of the fix taken out: the drive
-- tooth correction and the product limit check. Each must go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local MODULE = ROOT .. "/src/rfsuite/app/pages/setup_wizard_motor.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return s
end

-- ── stubs ─────────────────────────────────────────────────────────────

local T_TITLE_MAIN = "@i18n(app.modules.setup_wizard.mot_main_title)@"
local T_STAGE = "@i18n(app.modules.setup_wizard.mot_stage)@"
local T_REFUSED = "@i18n(app.modules.setup_wizard.mot_stage_refused)@"

local scr
local function newScreen()
  local s = { title = nil, rows = nil, forward = nil, start = nil }
  function s.begin() s.rows, s.back, s.forward, s.start = nil, nil, nil, nil end
  function s.text(_, title) s.title = title end
  function s.step() end
  function s.picture() end
  function s.paint() end
  function s.refresh() end
  function s.grid() return {} end
  function s.checks(_, rows)
    s.rows = rows
    return {}
  end
  function s.row(_, back, _, forward)
    s.back, s.forward = back, forward
    return {}
  end
  function s.safety(_, _, _, _, startPress)
    s.start = startPress
    return {}
  end
  -- Any other drawing call is a no-op: the pictures and the paint are not under test.
  return setmetatable(s, { __index = function() return function() end end })
end

local function copy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = copy(v) end
  return out
end

local writes, rebuilds
local function newWiz()
  rebuilds = 0
  writes = {}
  return {
    fetch = function(_, done) done({ motor = S_CFG }, false) end,
    change = function() end,
    copy = copy,
    send = function(msg) writes[#writes + 1] = msg end,
    rebuild = function() rebuilds = rebuilds + 1 end,
    invalidate = function() end,
    requestReboot = function() end,
    rebootPending = function() return false end,
    apiAtLeast = function() return false end,
    motorised = function() return true end,
    governorMode = function() return 0 end,
    rpmFeatureOn = function() return false end,
    setFeature = function() end,
    commitOnSave = function() end,
    forward = function(fn) return { text = "Next", press = fn } end,
  }
end

local stubs = {}
stubs["app/setup_wizard_ui.lua"] = {
  new = function() scr = newScreen(); return scr end,
  notLoaded = function() return {} end,
}
local function anyObject()
  return setmetatable({}, { __index = function() return function() end end })
end
stubs["app/setup_wizard_art.lua"] = setmetatable({}, {
  __index = function() return function() return anyObject() end end,
})
-- The MSP modules: the constants the page reads, and a write message that is the config itself.
stubs["lib/msp_motor_config.lua"] = {
  BASE_PROTOCOL_CHOICES = {}, DISABLED_PROTOCOL = -1, SRXL2_MIN_API_MINOR = 99, SRXL2_PROTOCOL = 99,
  CASTLE_PROTOCOL = 14,
  buildReadMessage = function() end,
  buildWriteMessage = function(cfg) return copy(cfg) end,
}
stubs["lib/msp_esc_sensor_config.lua"] = {
  buildReadMessage = function() end, buildWriteMessage = function() end,
}
stubs["lib/msp_feature_config.lua"] = {
  buildReadMessage = function() end, buildWriteMessage = function() end,
}
package.loaded["rfsuite.lib.require"] = function(path)
  local s = stubs[path]
  if not s then error("unexpected require: " .. tostring(path)) end
  return s
end

-- ── scenarios ─────────────────────────────────────────────────────────

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

-- The motor config as the FC holds it, and the page's session state, per scenario.
-- Main gear one stage: 10 teeth on the pinion, 20 on the main gear (ratio 2).
-- Tail from the intermediate shaft: drive 30, tail 20, mesh (main-side intermediate) 5.
local function scenario(opts)
  local wiz = newWiz()
  local main0, main1 = opts.main0 or 10, opts.main1 or 20
  local from, a, b, mesh = opts.from or 2, opts.a or 30, opts.b or 20, opts.mesh or 5
  local tail0, tail1
  if from == 2 then
    if opts.stages == 2 and opts.train then
      main0, main1 = opts.train.pinion * opts.train.mainSide, opts.train.pinionSide * opts.train.main
      tail0, tail1 = opts.train.mainSide * b, opts.train.main * a
    else
      tail0, tail1 = mesh * b, main1 * a
    end
  else
    tail0, tail1 = b, a
  end
  S_CFG = {
    motor_pwm_protocol = 0,
    main_rotor_gear_ratio_0 = main0, main_rotor_gear_ratio_1 = main1,
    tail_rotor_gear_ratio_0 = tail0, tail_rotor_gear_ratio_1 = tail1,
  }
  package.loaded["rfsuite.setup_wizard.motor"] = {
    [wiz] = { stages = opts.stages or 1, train = opts.train,
      tail = { from = from, a = a, b = b, mesh = mesh } },
  }
  local chunk = assert(loadfile(opts.module or MODULE))
  local page = chunk().new(wiz)
  page.build()
  if not scr.start then return nil, "the intro page offers no Start" end
  scr.start()
  for _ = 1, 12 do
    page.build()
    if scr.title == T_TITLE_MAIN then break end
    if not (scr.forward and scr.forward.press) then return nil, "no Next on the way to Main" end
    scr.forward.press()
  end
  if scr.title ~= T_TITLE_MAIN then return nil, "the Main screen was not reached" end
  local stage
  for _, row in ipairs(scr.rows or {}) do
    if row.label == T_STAGE and row.choice then stage = row.choice end
  end
  if not stage then return nil, "no stage drop-down on Main" end
  local before = #writes
  if opts.target then stage.set(opts.target) end
  local refusedNote = false
  page.build()
  for _, row in ipairs(scr.rows or {}) do
    if row.note == T_REFUSED then refusedNote = true end
  end
  return { writes = writes, before = before, cfg = S_CFG, refusedNote = refusedNote,
    stage = stage, page = page, scr = scr }
end

local function lastWrite(res)
  return res.writes[#res.writes]
end

local function run()
  local before = failures

  -- 1. Tail from the intermediate shaft, one stage to two; whole teeth keep the ratio.
  -- Before: tail products 100 (= mesh 5 x b 20) and 600 (= main 20 x a 30), ratio 6.
  -- After: main 20 x 20 on the train; the drive tooth becomes 120 so 20 x 120 / (20 x 20) = 6.
  do
    local res, err = scenario({ target = 2 })
    check("scenario 1 runs", res ~= nil, err)
    if res then
      local w = lastWrite(res)
      check("1: the stage changed (a write was made)", #res.writes > res.before)
      check("1: main products 200 / 400 (ratio 2 kept)", w and w.main_rotor_gear_ratio_0 == 200 and w.main_rotor_gear_ratio_1 == 400,
        w and (tostring(w.main_rotor_gear_ratio_0) .. "/" .. tostring(w.main_rotor_gear_ratio_1)))
      local r = w and (w.tail_rotor_gear_ratio_1 / w.tail_rotor_gear_ratio_0)
      check("1: tail ratio stays 6 (2400 / 400)", r == 6, w and (tostring(w.tail_rotor_gear_ratio_1) .. "/" .. tostring(w.tail_rotor_gear_ratio_0)))
      check("1: no refusal note", not res.refusedNote)
    end
  end

  -- 2. The same tail, but the restored drive tooth is not whole: 20 x a x 20 / (7 x 20 x 20)
  -- with a = 30 gives 600/7. Refused: no write, the page says why.
  do
    local res, err = scenario({ target = 2, mesh = 7 })
    check("scenario 2 runs", res ~= nil, err)
    if res then
      check("2: refused, no write", #res.writes == res.before)
      check("2: the refusal note is shown", res.refusedNote)
    end
  end

  -- 3. The restored drive tooth would take the main side product past TRAIN_MAX (50000):
  -- main 100 x a 600 = 60000. Refused: no write.
  do
    local res, err = scenario({ target = 2, main0 = 10, main1 = 100, a = 30, b = 20, mesh = 5 })
    check("scenario 3 runs", res ~= nil, err)
    if res then
      check("3: refused past the limit, no write", #res.writes == res.before)
      check("3: the refusal note is shown", res.refusedNote)
    end
  end

  -- 4. Tail from the main shaft: the tail products do not depend on the stage, so the stage
  -- change writes only the main gears and leaves the tail's two products as they were (20 / 30).
  do
    local res, err = scenario({ target = 2, from = 1 })
    check("scenario 4 runs", res ~= nil, err)
    if res then
      local w = lastWrite(res)
      check("4: the stage changed", #res.writes > res.before)
      check("4: tail products unchanged (20 / 30)", w and w.tail_rotor_gear_ratio_0 == 20 and w.tail_rotor_gear_ratio_1 == 30,
        w and (tostring(w.tail_rotor_gear_ratio_0) .. "/" .. tostring(w.tail_rotor_gear_ratio_1)))
    end
  end

  -- 5. Tail from the intermediate shaft, two stages to direct (3); whole teeth keep the ratio,
  -- and the mesh gear on the intermediate shaft is inherited into the tail state.
  do
    local tr = { pinion = 10, pinionSide = 20, mainSide = 15, main = 60 }
    local res, err = scenario({ stages = 2, train = tr, target = 3, from = 2, a = 30, b = 20, mesh = 1 })
    check("scenario 5 runs", res ~= nil, err)
    if res then
      local w = lastWrite(res)
      check("5: the stage changed (a write was made)", #res.writes > res.before)
      check("5: tail ratio stays 6 (1800 / 300)", w and (w.tail_rotor_gear_ratio_1 / w.tail_rotor_gear_ratio_0) == 6,
        w and (tostring(w.tail_rotor_gear_ratio_1) .. "/" .. tostring(w.tail_rotor_gear_ratio_0)))
      check("5: mesh tooth inherited from train.mainSide (300 / 20 = 15)", w and w.tail_rotor_gear_ratio_0 == 15 * 20,
        w and tostring(w.tail_rotor_gear_ratio_0))
      check("5: no refusal note", not res.refusedNote)
    end
  end

  -- 6. Refusal note is cleared when the current stage choice is reselected.
  do
    local res, err = scenario({ target = 2, mesh = 7 })
    check("scenario 6 runs", res ~= nil, err)
    if res then
      check("6: initial refusal note shown", res.refusedNote)
      res.stage.set(1)
      res.page.build()
      local refused = false
      for _, row in ipairs(res.scr.rows or {}) do
        if row.note == T_REFUSED then refused = true end
      end
      check("6: refusal note cleared after reselecting current stage", not refused)
    end
  end

  -- 7. Refusal note is cleared when navigating away via Next.
  do
    local res, err = scenario({ target = 2, mesh = 7 })
    check("scenario 7 runs", res ~= nil, err)
    if res then
      check("7: initial refusal note shown", res.refusedNote)
      if res.scr.forward and res.scr.forward.press then
        res.scr.forward.press()
        res.page.build()
        local refused = false
        for _, row in ipairs(res.scr.rows or {}) do
          if row.note == T_REFUSED then refused = true end
        end
        check("7: refusal note cleared on next screen", not refused)
      else
        check("7: forward button present", false)
      end
    end
  end

  return failures - before
end

-- ── self-test: the same checks on copies with the fix taken out ───────

-- A copy of the page with one snippet replaced, written to a temporary file.
local function mutant(label, from, to)
  local src = readFile(MODULE)
  local s, e = src:find(from, 1, true)
  assert(s, "self-test: snippet not found for " .. label)
  local out = src:sub(1, s - 1) .. to .. src:sub(e + 1)
  local path = os.tmpname() .. ".lua"
  local f = assert(io.open(path, "wb"))
  f:write(out)
  f:close()
  return { path = path, label = label }
end

if SELF_TEST then
  local mutants = {
    mutant("no drive tooth correction", "plan.tailDrive = a", "plan.tailDrive = nil"),
    mutant("no product limit on the tail", "plan.mainT * a <= TRAIN_MAX", "true"),
    mutant("no mesh inheritance on direct stage", "mesh = tr and tr.mainSide or nil", "mesh = nil"),
  }
  local red = 0
  local realModule = MODULE
  for _, m in ipairs(mutants) do
    -- The same checks, run against the copy.
    MODULE = m.path
    failures, checks = 0, 0
    local n = run()
    MODULE = realModule
    os.remove(m.path)
    if n > 0 then
      red = red + 1
      print("self-test ok: '" .. m.label .. "' goes red (" .. n .. " failure(s))")
    else
      print("self-test FAIL: '" .. m.label .. "' still passes")
    end
  end
  if red == #mutants then
    print("self-test: all " .. red .. " mutants red")
    os.exit(0)
  end
  os.exit(1)
end

local n = run()
if n == 0 then
  print("OK  " .. checks .. " checks, setup_wizard_motor stage change")
  os.exit(0)
end
print(n .. " failure(s)")
os.exit(1)

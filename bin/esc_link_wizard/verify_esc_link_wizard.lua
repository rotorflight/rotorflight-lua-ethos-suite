-- Behaviour check for #2704 in the Setup Wizard: the ESC step sets the throttle range over the ESC
-- link, as the EdgeTX suite does, and the spin test is unlocked by that set only when both the FC and
-- the ESC read it back.
--
-- Run it (from the repository root):
--     lua5.4 bin/esc_link_wizard/verify_esc_link_wizard.lua
--     lua5.4 bin/esc_link_wizard/verify_esc_link_wizard.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/setup_wizard_esc.lua and the real lib/esc_params.lua,
-- with a simulated FC (motor config, RC config, ESC telemetry protocol) and a simulated ESC block behind
-- the wizard's send. The UI and art modules are recording stubs.
--
-- It pins:
--   1. the link row is offered for a PWM ESC of the YGE family;
--   2. a set writes the FC endpoints, saves, reads them back, then writes the ESC and reads it back, and
--      the ESC ends with the range the FC got;
--   3. the spin test is unlocked after a confirmed set;
--   4. a set that the FC or the ESC does not confirm leaves the spin test locked;
--   5. an ESC of another family gets no link row.
--
-- --self-test drops the calibration flags set after a confirmed range and requires the spin unlock
-- of check 3 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local ESC_STEP = ROOT .. "/src/rfsuite/app/pages/setup_wizard_esc.lua"
local LIB = ROOT .. "/src/rfsuite/lib/"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local T_LINK = "@i18n(app.modules.setup_wizard.esc_link_btn)@"

-- ── simulated FC and ESC ──────────────────────────────────────────────

local function newWorld(protocol)
  return {
    fc = {
      motor = {motor_pwm_protocol = 0, mincommand = 1000, minthrottle = 1070, maxthrottle = 2000},
      rc = {rc_min_throttle = 1020, rc_max_throttle = 1980},
      escProtocol = protocol or 9,
      motorWriteRefused = false,
    },
    esc = {block = {esc_signature = 165, stick_zero_us = 1100, stick_range_us = 800},
      writeRefused = false, readFails = false},
    sent = {},
  }
end

-- The wizard's surface the ESC step uses. Reads run at once, as the step expects.
local function newWiz(world)
  local wiz = {saves = 0, rebuilds = 0}
  function wiz.rebuild() wiz.rebuilds = wiz.rebuilds + 1 end
  function wiz.invalidate() end
  function wiz.armed() return false end
  function wiz.canMove() return true end
  function wiz.holdMotor() return true end
  function wiz.releaseMotor() end
  function wiz.forward(fn) return {text = "Next", press = fn} end
  function wiz.saveThen(cb) wiz.saves = wiz.saves + 1; cb() end
  function wiz.send(msg)
    world.sent[#world.sent + 1] = msg.kind
    if msg.kind == "rc_read" or msg.kind == "esc_sensor_read" then
      msg.onData()
    elseif msg.kind == "motor_read" then
      local m = world.fc.motor
      msg.onData({motor_pwm_protocol = m.motor_pwm_protocol, mincommand = m.mincommand,
        minthrottle = m.minthrottle, maxthrottle = m.maxthrottle})
    elseif msg.kind == "motor_write" then
      if world.fc.motorWriteRefused then msg.onError(); return end
      for k, v in pairs(msg.data) do world.fc.motor[k] = v end
      msg.onWritten()
    elseif msg.kind == "esc_read" then
      if world.esc.readFails then msg.onError(); return end
      local copy = {}
      for k, v in pairs(world.esc.block) do copy[k] = v end
      msg.onData(copy)
    elseif msg.kind == "esc_write" then
      if world.esc.writeRefused then msg.onError(); return end
      for k, v in pairs(msg.data) do world.esc.block[k] = v end
      msg.onWritten()
    end
  end
  function wiz.fetch(specs, onDone)
    local results, failed = {}, false
    for key, build in pairs(specs) do
      wiz.send(build(function(d) results[key] = d end, function() failed = true end))
    end
    onDone(results, failed)
  end
  return wiz
end

-- A recording screen: the rows and the press of the row that has no answer.
local function newScreen(holder)
  local s = {rows = nil, start = nil, forward = nil}
  holder.screen = s
  function s.begin() s.rows, s.start, s.forward = nil, nil, nil end
  function s.text() end
  function s.step() end
  function s.picture() end
  function s.paint() end
  function s.checks(_, rows) s.rows = rows; return {} end
  function s.row(_, _, _, forward) s.forward = forward; return {} end
  function s.safety(_, _, _, _, startPress) s.start = startPress; return {} end
  return setmetatable(s, { __index = function() return function() end end })
end

local function anyObject()
  return setmetatable({}, { __index = function() return function() end end })
end

local function findAnswer(rows, answer)
  for _, r in ipairs(rows or {}) do if r.answer == answer then return r end end
  return nil
end

-- Runs the step on a fresh world. Returns the context for the checks.
local function open(escSource, protocol)
  local world = newWorld(protocol)
  local wiz = newWiz(world)
  local holder = {}
  local codecs = {
    buildReadMessage = function(onData, onError)
      return {kind = "esc_read", onData = onData, onError = onError}
    end,
    buildWriteMessage = function(data, onWritten, onError)
      return {kind = "esc_write", data = data, onWritten = onWritten, onError = onError}
    end,
  }
  local stubs = {
    ["app/setup_wizard_ui.lua"] = {new = function() return newScreen(holder) end},
    ["app/setup_wizard_art.lua"] = setmetatable({}, {__index = function() return function() return anyObject() end end}),
    ["lib/msp_motor_config.lua"] = {
      buildReadMessage = function(onData, onError) return {kind = "motor_read", onData = onData, onError = onError} end,
      buildWriteMessage = function(data, onWritten, onError)
        return {kind = "motor_write", data = data, onWritten = onWritten, onError = onError}
      end,
    },
    ["lib/msp_rc_config.lua"] = {
      buildReadMessage = function(onData, onError)
        return {kind = "rc_read", onData = function() onData({rc_min_throttle = world.fc.rc.rc_min_throttle,
          rc_max_throttle = world.fc.rc.rc_max_throttle}) end, onError = onError}
      end,
    },
    ["lib/msp_esc_sensor_config.lua"] = {
      buildReadMessage = function(onData, onError)
        return {kind = "esc_sensor_read", onData = function() onData({protocol = world.fc.escProtocol}) end,
          onError = onError}
      end,
    },
    ["lib/esc_params.lua"] = assert(loadfile(LIB .. "esc_params.lua"))(),
    ["lib/msp_esc_parameters_yge.lua"] = codecs,
  }
  package.loaded["rfsuite.lib.require"] = function(path)
    local m = stubs[path]
    if not m then error("unexpected require: " .. tostring(path)) end
    return m
  end
  local step = assert(load(escSource, "@setup_wizard_esc.lua", "t"))()
  local node = step.new(wiz)
  node.build()
  return {world = world, wiz = wiz, node = node, scr = holder.screen}
end

-- Moves from the prepare card to the calibrate page.
local function toCalibrate(ctx)
  ctx.scr.start()
  ctx.node.build()
end

-- The spin test's own button: the row with an answer and a disabled state.
local function spinButton(ctx)
  ctx.scr.forward.press()
  ctx.node.build()
  for _, r in ipairs(ctx.scr.rows or {}) do
    if r.answer ~= nil and r.disabled ~= nil then return r end
  end
  return nil
end

local source = readFile(ESC_STEP)

if SELF_TEST then
  -- Drop the flags a confirmed set sets: the spin test then stays locked after a confirmed range.
  local mutated, n = source:gsub("              calib%.full, calib%.low = true, true\n", "")
  if n ~= 1 then
    print("FAIL  self-test: the flag line was not found once; update this harness")
    os.exit(1)
  end
  source = mutated
end

local before = failures

-- 1 and 2 and 3: a confirmed set.
do
  local ctx = open(source, 9)
  toCalibrate(ctx)
  local row = findAnswer(ctx.scr.rows, T_LINK)
  check("1. the link row is offered for a PWM YGE ESC", row ~= nil)
  if row then
    local mark = #ctx.world.sent
    row.press()
    ctx.node.build()
    local seen = {}
    for i = mark + 1, #ctx.world.sent do seen[#seen + 1] = ctx.world.sent[i] end
    local order = table.concat(seen, ",")
    check("2a. the FC endpoints are written, read back, then the ESC is written and read back",
      order == "motor_write,motor_read,esc_write,esc_read" or order == "motor_write,motor_read,esc_write,esc_read,esc_read",
      "order=" .. order)
    check("2b. the FC ends with the measured range",
      ctx.world.fc.motor.minthrottle == 1020 and ctx.world.fc.motor.maxthrottle == 1980 and ctx.world.fc.motor.mincommand == 1000,
      "min=" .. tostring(ctx.world.fc.motor.minthrottle) .. " max=" .. tostring(ctx.world.fc.motor.maxthrottle))
    check("2c. the ESC ends with the same range as stick zero and span",
      ctx.world.esc.block.stick_zero_us == 1020 and ctx.world.esc.block.stick_range_us == 960,
      "zero=" .. tostring(ctx.world.esc.block.stick_zero_us) .. " span=" .. tostring(ctx.world.esc.block.stick_range_us))
  end
  local spin = spinButton(ctx)
  check("3. the spin test is unlocked after a confirmed set", spin ~= nil and not spin.disabled)
end

-- 4: the ESC does not confirm the write.
do
  local ctx = open(source, 9)
  toCalibrate(ctx)
  ctx.world.esc.writeRefused = true
  findAnswer(ctx.scr.rows, T_LINK).press()
  ctx.node.build()
  local spin = spinButton(ctx)
  check("4a. an ESC that refuses the write leaves the spin test locked", spin ~= nil and spin.disabled == true)
end

-- 4: the FC refuses its endpoints; the ESC is not written at all.
do
  local ctx = open(source, 9)
  toCalibrate(ctx)
  ctx.world.fc.motorWriteRefused = true
  findAnswer(ctx.scr.rows, T_LINK).press()
  ctx.node.build()
  local wroteEsc = false
  for _, k in ipairs(ctx.world.sent) do if k == "esc_write" then wroteEsc = true end end
  check("4b. when the FC refuses, the ESC is not written and the spin stays locked",
    not wroteEsc and spinButton(ctx).disabled == true)
end

-- 5: another family gets no link row.
do
  local ctx = open(source, 3)
  toCalibrate(ctx)
  check("5. an ESC of another family gets no link row", findAnswer(ctx.scr.rows, T_LINK) == nil)
end

if SELF_TEST then
  if failures > before then
    print("ok    mutant red: the spin test is not unlocked by a confirmed set (" .. (failures - before) .. " failed checks)")
    print("OK  self-test: a confirmed set without its flags goes red")
    os.exit(0)
  end
  print("FAIL  mutant passed the checks: the flags are not needed for the spin unlock")
  os.exit(1)
end

if failures == before then
  print("OK  ESC link wizard: offered for YGE, read back on both, spin unlocked only after a confirmed set (" .. checks .. " checks)")
  os.exit(0)
end
os.exit(1)

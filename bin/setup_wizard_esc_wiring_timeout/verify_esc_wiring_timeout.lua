-- Behaviour check for #2699: the Setup Wizard's ESC wiring detection timeout must allow
-- seven protocols (HW5, Scorpion, OpenYGE, Flyrotor, XDFly, ZTW, OMP) up to 10 s to scan
-- all four wiring combinations without timing out early.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_esc_wiring_timeout/verify_esc_wiring_timeout.lua
--     lua5.4 bin/setup_wizard_esc_wiring_timeout/verify_esc_wiring_timeout.lua --self-test
--
-- What it pins:
--   1. on entry the wiring screen shows the Detect action and Idle status;
--   2. pressing Detect sends MSP2_ESC_SENSOR_TRIAL action 1 (start) and shows Stop;
--   3. at t = 6 s and t = 10 s the trial remains active, without premature timeout;
--   4. at t = 12.1 s (> 12 s) wakeup stops the trial, sends action 2 (cancel), and
--      sets the status to timeout;
--   5. manual Stop cancels an active trial and sends action 2;
--   6. leaving the step (released) stops an active trial and sends action 2.
--
-- --self-test restores the old 6 s timeout and requires check 3 (active at 10 s) to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local MODULE = ROOT .. "/src/rfsuite/app/pages/setup_wizard_esctelemetry.lua"

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
  local s = { rows = nil, back = nil, forward = nil }
  function s.begin() s.rows, s.back, s.forward = nil, nil, nil end
  function s.text() end
  function s.picture() end
  function s.step() end
  function s.paint() end
  function s.refresh() end
  function s.checks(_, rows) s.rows = rows; return {} end
  function s.row(_, back, _, forward) s.back, s.forward = back, forward; return {} end
  function s.safety() return {} end
  function s.setCheckValue() return true end
  return s
end

local mspcodec = assert(loadfile(ROOT .. "/src/rfsuite/lib/mspcodec.lua"))()

local stubs = {}
package.loaded["rfsuite.lib.require"] = function(p)
  local s = stubs[p]
  if not s then error("unexpected require: " .. tostring(p)) end
  return s
end
stubs["lib/mspcodec.lua"] = mspcodec

local trialConfig = assert(loadfile(ROOT .. "/src/rfsuite/lib/msp_esc_sensor_trial.lua"))()
stubs["lib/msp_esc_sensor_trial.lua"] = trialConfig
stubs["app/setup_wizard_ui.lua"] = {
  new = function()
    scr = newScreen()
    return scr
  end,
}
stubs["app/setup_wizard_art.lua"] = setmetatable({
  image = function() return {} end,
  power = function() return {} end,
}, { __index = function() return function() return {} end end })
stubs["app/setup_wizard_power.lua"] = {
  SOURCE_NONE = 0,
  SOURCE_ESC = 2,
  new = function()
    return {
      load = function(cb) if cb then cb() end end,
      loaded = true,
      battery = true,
      source = function() return 2 end,
    }
  end,
}
stubs["lib/bus.lua"] = {
  subscribe = function() end,
  unsubscribe = function() end,
  publish = function() end,
}
stubs["lib/live_sensors.lua"] = { value = function() return nil end }
stubs["lib/msp_analog.lua"] = { buildReadMessage = function() return {} end }
stubs["lib/msp_esc_sensor_config.lua"] = {
  choicesFor = function() return {{"Auto", 1}} end,
  buildReadMessage = function(cb)
    return { processReply = function(_, _) cb({ protocol = 1, half_duplex = 0, pin_swap = 0 }) end }
  end,
  buildWriteMessage = function(d) return { isWrite = true, data = d } end,
}
stubs["lib/msp_feature_config.lua"] = {
  buildReadMessage = function(cb)
    return { processReply = function(_, _) cb({ enabledFeatures = 1 << 27 }) end }
  end,
  buildWriteMessage = function(d) return { isWrite = true, data = d } end,
}
stubs["lib/msp_serial_config.lua"] = {
  buildReadMessage = function(cb)
    return { processReply = function(_, _) cb({ ports = {{ identifier = 0, function_mask = 1024 }} }) end }
  end,
  buildWriteMessage = function(d) return { isWrite = true, data = d } end,
}
stubs["lib/msp_motor_config.lua"] = {
  CASTLE_PROTOCOL = 99,
  buildReadMessage = function(cb)
    return { processReply = function(_, _) cb({ motor_pwm_protocol = 1 }) end }
  end,
}
stubs["lib/msp_board_info.lua"] = {
  buildReadMessage = function(cb)
    return { processReply = function(_, _) cb({}) end }
  end,
}
stubs["lib/port_labels.lua"] = {
  label = function(id) return "UART" .. (id + 1) end,
}

-- ── drive the step ────────────────────────────────────────────────────

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

local function runTests(source)
  local before = failures
  local origClock = os.clock
  local simClock = 100.0
  os.clock = function() return simClock end

  local ok, err = pcall(function()
    local chunk = assert(load(source, "@setup_wizard_esctelemetry.lua", "t"))
    local moduleFactory = chunk()

    local sent = {}
    local wiz = {
      takeResume = function() return 3 end, -- screen 3 = WIRING
      apiAtLeast = function() return true end,
      rebuild = function() end,
      send = function(msg) sent[#sent + 1] = msg end,
      fetch = function(_, cb)
        cb({
          feature = { enabledFeatures = 1 << 27 },
          esc = { protocol = 1, half_duplex = 0, pin_swap = 0 },
          serial = { ports = {{ identifier = 0, function_mask = 1024 }} },
          motor = { motor_pwm_protocol = 1 },
          board = {},
        })
      end,
      rebootPending = function() return false end,
      requestReboot = function() end,
      invalidate = function() end,
      hasPending = function() return false end,
      forward = function(fn) return { text = "Next", press = fn } end,
      finishStep = function() end,
    }

    local step = moduleFactory.new(wiz)
    step.build()

    local T_IDLE = "@i18n(app.modules.setup_wizard.wir_idle)@"
    local T_DETECT = "@i18n(app.modules.setup_wizard.wir_detect)@"
    local T_STOP = "@i18n(app.modules.setup_wizard.wir_stop)@"
    local T_TIMEOUT = "@i18n(app.modules.setup_wizard.wir_timeout)@"
    local T_STOPPED = "@i18n(app.modules.setup_wizard.wir_stopped)@"

    -- 1. Initial screen state
    check("initial status is idle", scr.rows[1].value == T_IDLE, "status=" .. tostring(scr.rows[1].value))
    check("initial action button is Detect", scr.rows[2].answer == T_DETECT, "button=" .. tostring(scr.rows[2].answer))
    check("initial action button is enabled", not scr.rows[2].disabled)

    -- 2. Press Detect to start trial
    scr.rows[2].press()
    step.build()
    check("trial start sends MSP start message (action 1)",
      #sent >= 1 and sent[1].payload and sent[1].payload[1] == trialConfig.ACTION_START)
    check("button switches to Stop while trial is active", scr.rows[2].answer == T_STOP)

    -- 3. Progression at t = 6 s and t = 10 s (must NOT time out)
    simClock = 106.0
    step.wakeup()
    step.build()
    check("trial remains active at 6 s", scr.rows[2].answer == T_STOP, "button=" .. tostring(scr.rows[2].answer))

    simClock = 110.0
    step.wakeup()
    step.build()
    check("trial remains active at 10 s (multi-protocol scan window)",
      scr.rows[2].answer == T_STOP and scr.rows[1].value ~= T_TIMEOUT,
      "button=" .. tostring(scr.rows[2].answer) .. " status=" .. tostring(scr.rows[1].value))

    -- 4. Timeout at t = 12.1 s (> 12 s)
    simClock = 112.1
    step.wakeup()
    step.build()
    check("trial stops at 12.1 s with timeout status",
      scr.rows[1].value == T_TIMEOUT, "status=" .. tostring(scr.rows[1].value))
    check("button switches back to Detect after timeout",
      scr.rows[2].answer == T_DETECT, "button=" .. tostring(scr.rows[2].answer))
    local lastMsg = sent[#sent]
    check("timeout sends MSP cancel message (action 2) to restore FC wiring",
      lastMsg and lastMsg.payload and lastMsg.payload[1] == trialConfig.ACTION_CANCEL)

    -- 5. Manual cancel via Stop button
    sent = {}
    scr.rows[2].press() -- start again
    step.build()
    check("restart trial from Detect button", scr.rows[2].answer == T_STOP)
    scr.rows[2].press() -- press Stop
    step.build()
    check("manual stop sets status to stopped", scr.rows[1].value == T_STOPPED)
    check("manual stop restores Detect button", scr.rows[2].answer == T_DETECT)
    lastMsg = sent[#sent]
    check("manual stop sends MSP cancel message (action 2)",
      lastMsg and lastMsg.payload and lastMsg.payload[1] == trialConfig.ACTION_CANCEL)

    -- 6. Cancel when leaving step (released)
    sent = {}
    scr.rows[2].press() -- start again
    step.build()
    step.released()
    lastMsg = sent[#sent]
    check("releasing step cancels active trial with MSP cancel message",
      lastMsg and lastMsg.payload and lastMsg.payload[1] == trialConfig.ACTION_CANCEL)
  end)

  os.clock = origClock
  if not ok then error(err) end
  return failures - before
end

local source = readFile(MODULE)

if SELF_TEST then
  -- Self-test: mutate TRIAL_TIMEOUT = 12 back to 6 s.
  -- The check 'trial remains active at 10 s' must go red.
  local mutant, count = source:gsub("local TRIAL_TIMEOUT = 12", "local TRIAL_TIMEOUT = 6")
  assert(count == 1, "could not apply self-test mutation to TRIAL_TIMEOUT")

  silent = true
  local mutantFailures = runTests(mutant)
  silent = false

  if mutantFailures == 0 then
    print("SELF-TEST FAILED: 6 s timeout mutant did not produce any failure")
    os.exit(1)
  else
    print(string.format("self-test ok: 6 s timeout mutant caught %d failure(s)", mutantFailures))
    os.exit(0)
  end
end

runTests(source)

if failures > 0 then
  print(string.format("\nFAILED: %d of %d checks failed", failures, checks))
  os.exit(1)
else
  print(string.format("ALL %d CHECKS PASSED", checks))
end

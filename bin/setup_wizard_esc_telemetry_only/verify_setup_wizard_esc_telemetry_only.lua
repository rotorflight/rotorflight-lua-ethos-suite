-- Behaviour check for #2739: the Setup Wizard's ESC wiring detection, for an ESC whose
-- parameters the wizard can read (the YGE family, lib/esc_params.lua).
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_esc_telemetry_only/verify_setup_wizard_esc_telemetry_only.lua
--     lua5.4 bin/setup_wizard_esc_telemetry_only/verify_setup_wizard_esc_telemetry_only.lua --self-test
--
-- What it pins, on the real page and the real trial message builder:
--   1. Detect on such an ESC writes half duplex (pin swap on, except F4) before the walk
--      starts, and the walk starts only once that write is answered;
--   2. telemetry only, found from that start, is said as such and is what gets written;
--   3. half duplex found is said as Found;
--   4. a run that fails, and a Stop, put the page's own wiring back after the flight
--      controller's cancel;
--   5. an ESC without a parameter family, or with half duplex on already, starts as configured;
--   6. a refused preset write still starts the walk;
--   7. a Stop before the write is answered starts no walk.
--
-- --self-test turns the preset off and requires check 1 to go red.

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

local stubs = {}
package.loaded["rfsuite.lib.require"] = function(p)
  local s = stubs[p]
  if not s then error("unexpected require: " .. tostring(p)) end
  return s
end

-- The real codecs. The lib files find their requires through package.loaded, so it is set first.
stubs["lib/mspcodec.lua"] = assert(loadfile(ROOT .. "/src/rfsuite/lib/mspcodec.lua"))()
local mspcodec = stubs["lib/mspcodec.lua"]
local trialConfig = assert(loadfile(ROOT .. "/src/rfsuite/lib/msp_esc_sensor_trial.lua"))()
local escParams = assert(loadfile(ROOT .. "/src/rfsuite/lib/esc_params.lua"))()
stubs["lib/msp_esc_sensor_trial.lua"] = trialConfig
stubs["lib/esc_params.lua"] = escParams
stubs["app/setup_wizard_ui.lua"] = { new = function() scr = newScreen(); return scr end }
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
stubs["lib/bus.lua"] = { subscribe = function() end, unsubscribe = function() end, publish = function() end }
stubs["lib/live_sensors.lua"] = { value = function() return nil end }
stubs["lib/msp_analog.lua"] = { buildReadMessage = function() return {} end }
-- The ESC sensor config: the write message keeps its data, and answers through onWritten/onError
-- the way the real builder does.
stubs["lib/msp_esc_sensor_config.lua"] = {
  choicesFor = function() return {{"Auto", 1}} end,
  buildReadMessage = function() return {} end,
  buildWriteMessage = function(d, onWritten, onError)
    local data = {}
    for k, v in pairs(d) do data[k] = v end
    return {
      kind = "esc_write",
      isWrite = true,
      data = data,
      processReply = function() if onWritten then onWritten() end end,
      errorHandler = onError,
    }
  end,
}
stubs["lib/msp_feature_config.lua"] = {
  buildReadMessage = function() return {} end,
  buildWriteMessage = function(d) return { isWrite = true, data = d } end,
}
stubs["lib/msp_serial_config.lua"] = {
  buildReadMessage = function() return {} end,
  buildWriteMessage = function(d) return { isWrite = true, data = d } end,
}
stubs["lib/msp_motor_config.lua"] = {
  CASTLE_PROTOCOL = 99,
  buildReadMessage = function() return {} end,
}
stubs["lib/msp_board_info.lua"] = { buildReadMessage = function() return {} end }
stubs["lib/port_labels.lua"] = { label = function(id) return "UART" .. (id + 1) end }

-- ── helpers ───────────────────────────────────────────────────────────

local failures, checks = 0, 0
local silent = false
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    if not silent then print("FAIL  " .. label .. (detail and ("  -- " .. detail) or "")) end
  end
end

local S = trialConfig.STATE
local T_TELEMETRY_ONLY = "@i18n(app.modules.setup_wizard.wir_telemetry_only)@"
local T_FOUND = "@i18n(app.modules.setup_wizard.wir_found)@"
local T_NOT_FOUND = "@i18n(app.modules.setup_wizard.wir_not_found)@"
local T_STOPPED = "@i18n(app.modules.setup_wizard.wir_stopped)@"

local function isStart(m) return m.command == trialConfig.COMMAND and m.payload and m.payload[1] == trialConfig.ACTION_START end
local function isCancel(m) return m.command == trialConfig.COMMAND and m.payload and m.payload[1] == trialConfig.ACTION_CANCEL end
local function isWrite(m) return m.kind == "esc_write" end
local function trialReply(state, half, swap)
  return { state, 0, half, swap, 0, 0 }
end

local function indexOf(sent, pred, from)
  for i = from or 1, #sent do if pred(sent[i]) then return i end end
  return nil
end

-- A wizard session on the wiring screen, with the ESC and board the case needs.
local function session(esc, board, moduleSource)
  local factory = assert(load(moduleSource, "@setup_wizard_esctelemetry.lua", "t"))()
  local sent = {}
  local rebooted = false
  local wiz = {
    takeResume = function() return 3 end, -- screen 3 = WIRING
    apiAtLeast = function() return true end,
    rebuild = function() end,
    send = function(msg) sent[#sent + 1] = msg end,
    fetch = function(_, cb)
      cb({
        feature = { enabledFeatures = 1 << 27 },
        esc = esc,
        serial = { ports = {{ identifier = 0, function_mask = 1024 }} },
        motor = { motor_pwm_protocol = 1 },
        board = board,
      })
    end,
    rebootPending = function() return false end,
    requestReboot = function() rebooted = true end,
    invalidate = function() end,
    hasPending = function() return false end,
    change = function() end,
    forward = function(fn) return { text = "Next", press = fn } end,
    finishStep = function() end,
  }
  local step = factory.new(wiz)
  step.build()
  return { step = step, sent = sent, rebooted = function() return rebooted end }
end

local function detect(s)
  s.step.build()
  scr.rows[2].press()
  s.step.build()
end

local YGE = 9
local OTHER = 1
local function yge(half) return { protocol = YGE, half_duplex = half, pin_swap = 0 } end
-- MATEKF405 is an F4 board (its name contains "F4"), so the non-F4 case uses an H7 target.
local NON_F4 = { targetName = "MATEKH743" }
local F4 = { targetName = "OMNIBUSF4" }

-- ── cases ─────────────────────────────────────────────────────────────

local function runTests(moduleSource)
  local before = failures
  local origClock = os.clock
  os.clock = function() return 100.0 end

  -- A case that raises (a reply it does not expect) is a failed check, and the rest still run.
  local function case(fn)
    local okCase, caseErr = pcall(fn)
    if not okCase then check("case ran to the end", false, tostring(caseErr)) end
  end

  local ok, err = pcall(function()
    -- 1. The walk starts from half duplex, and only once the write is answered.
    case(function()
      local s = session(yge(0), NON_F4, moduleSource)
      detect(s)
      local w = s.sent[1]
      check("1. Detect on a YGE first writes half duplex, with pin swap on off F4",
        w and isWrite(w) and w.data.half_duplex == 1 and w.data.pin_swap == 1,
        w and string.format("kind=%s half=%s swap=%s", tostring(w.kind), tostring(w.data and w.data.half_duplex), tostring(w.data and w.data.pin_swap)) or "no message")
      check("1. the walk does not start before the write is answered",
        #s.sent == 1 and indexOf(s.sent, isStart) == nil, "sent=" .. #s.sent)
      if w and w.processReply then w.processReply(w) end
      s.step.build()
      check("1. the walk starts once the write is answered",
        indexOf(s.sent, isStart) == 2, "start at " .. tostring(indexOf(s.sent, isStart)))
    end)

    -- 2. Telemetry only is said as such, and written.
    case(function()
      local s = session(yge(0), NON_F4, moduleSource)
      detect(s)
      s.sent[1].processReply(s.sent[1]); s.step.build()
      local start = s.sent[2]
      start.processReply(start, trialReply(S.SUCCESS, 0, 1))
      s.step.build()
      local last = s.sent[#s.sent]
      check("2. telemetry only found is said as telemetry only", scr.rows[1].value == T_TELEMETRY_ONLY,
        "status=" .. tostring(scr.rows[1].value))
      check("2. telemetry only found is written as found (half duplex off)",
        last and isWrite(last) and last.data.half_duplex == 0 and last.data.pin_swap == 1)
      check("2. and the restart is requested", s.rebooted())
    end)

    -- 3. Half duplex found is said as Found.
    case(function()
      local s = session(yge(0), NON_F4, moduleSource)
      detect(s)
      s.sent[1].processReply(s.sent[1]); s.step.build()
      s.sent[2].processReply(s.sent[2], trialReply(S.SUCCESS, 1, 1))
      s.step.build()
      check("3. half duplex found is said as Found", scr.rows[1].value == T_FOUND,
        "status=" .. tostring(scr.rows[1].value))
      local last = s.sent[#s.sent]
      check("3. and half duplex is what gets written", last and isWrite(last) and last.data.half_duplex == 1)
    end)

    -- 4a. A failed run puts the page's own wiring back, after the cancel.
    case(function()
      local s = session(yge(0), NON_F4, moduleSource)
      detect(s)
      s.sent[1].processReply(s.sent[1]); s.step.build()
      s.sent[2].processReply(s.sent[2], trialReply(S.FAILED, 0, 0))
      s.step.build()
      local cancel = indexOf(s.sent, isCancel)
      local back = nil
      for i = #s.sent, 1, -1 do if isWrite(s.sent[i]) then back = i break end end
      check("4a. a failed run sends the cancel", cancel ~= nil)
      check("4a. and then writes the page's own wiring back (half duplex off)",
        cancel and back and back > cancel and s.sent[back].data.half_duplex == 0 and s.sent[back].data.pin_swap == 0,
        string.format("cancel=%s back=%s", tostring(cancel), tostring(back)))
      check("4a. the outcome is Not found", scr.rows[1].value == T_NOT_FOUND, "status=" .. tostring(scr.rows[1].value))
    end)

    -- 4b. A Stop does the same.
    case(function()
      local s = session(yge(0), NON_F4, moduleSource)
      detect(s)
      s.sent[1].processReply(s.sent[1]); s.step.build()
      s.sent[2].processReply(s.sent[2], trialReply(S.RUNNING, 0, 0))
      s.step.build()
      scr.rows[2].press() -- Stop
      s.step.build()
      local cancel = indexOf(s.sent, isCancel)
      local last = s.sent[#s.sent]
      check("4b. a Stop sends the cancel and then the page's own wiring back",
        cancel and last and isWrite(last) and last.data.half_duplex == 0 and #s.sent > cancel)
      check("4b. the outcome is Stopped", scr.rows[1].value == T_STOPPED, "status=" .. tostring(scr.rows[1].value))
    end)

    -- 5. No parameter family, or half duplex already on: the walk starts as configured.
    case(function()
      local s = session({protocol = OTHER, half_duplex = 0, pin_swap = 0}, NON_F4, moduleSource)
      detect(s)
      check("5. an ESC without a parameter family starts the walk at once",
        isStart(s.sent[1]) and not indexOf(s.sent, isWrite), "first=" .. tostring(s.sent[1] and s.sent[1].command))
    end)
    case(function()
      local s = session(yge(1), NON_F4, moduleSource)
      detect(s)
      check("5. half duplex already on starts the walk at once", isStart(s.sent[1]) and not indexOf(s.sent, isWrite))
    end)

    -- 6. A refused write still starts the walk, from the wiring the ESC already had.
    case(function()
      local s = session(yge(0), NON_F4, moduleSource)
      detect(s)
      s.sent[1].errorHandler("write")
      s.step.build()
      check("6. a refused preset write still starts the walk", indexOf(s.sent, isStart) == 2,
        "start at " .. tostring(indexOf(s.sent, isStart)))
    end)

    -- 7. A Stop before the write is answered: no walk starts afterwards.
    case(function()
      local s = session(yge(0), NON_F4, moduleSource)
      detect(s)
      scr.rows[2].press() -- Stop, while the write is still pending
      s.step.build()
      s.sent[1].processReply(s.sent[1])
      s.step.build()
      check("7. a Stop before the write is answered starts no walk", indexOf(s.sent, isStart) == nil)
      local last = s.sent[#s.sent]
      check("7. and the page's own wiring is written back", last and isWrite(last) and last.data.half_duplex == 0)
    end)

    -- 8. The preset pin swap is off on an F4 board (as in the EdgeTX suite).
    case(function()
      local s = session(yge(0), F4, moduleSource)
      detect(s)
      local w = s.sent[1]
      check("8. on an F4 board the preset has no pin swap", w and w.data.half_duplex == 1 and w.data.pin_swap == 0,
        w and string.format("half=%s swap=%s", tostring(w.data.half_duplex), tostring(w.data.pin_swap)) or "no message")
    end)
  end)

  os.clock = origClock
  if not ok then error(err) end
  return failures - before
end

local source = readFile(MODULE)

if SELF_TEST then
  -- Self-test: no preset. Check 1 (the write comes first) must go red.
  local mutant, count = source:gsub(
    "if not esc or not escParams%.familyFor%(esc%.protocol%) or esc%.half_duplex == 1 then return nil end",
    "do return nil end")
  assert(count == 1, "could not apply self-test mutation to presetFor")

  silent = true
  local mutantFailures = runTests(mutant)
  silent = false
  if mutantFailures == 0 then
    print("SELF-TEST FAILED: the no-preset mutant did not produce any failure")
    os.exit(1)
  else
    print(string.format("self-test ok: no-preset mutant caught %d failure(s)", mutantFailures))
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

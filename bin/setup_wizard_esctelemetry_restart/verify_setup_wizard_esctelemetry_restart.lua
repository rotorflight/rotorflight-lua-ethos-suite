-- Behaviour check for #2697: changing the ESC telemetry protocol in the Setup Wizard requests an FC restart.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_esctelemetry_restart/verify_setup_wizard_esctelemetry_restart.lua
--     lua5.4 bin/setup_wizard_esctelemetry_restart/verify_setup_wizard_esctelemetry_restart.lua --self-test
--
-- The flight controller opens the ESC telemetry UART port at boot with the baud rate and receive
-- callback of the configured protocol (escSensorInit in sensors/esc_sensor.c). When the telemetry
-- protocol changes in the Setup Wizard, the new protocol is written to the FC, but the port
-- remains opened with the old baud and callback until reboot.
--
-- What it drives:
--   1. Real src/rfsuite/app/pages/setup_wizard_esctelemetry.lua with UI/art/MSP stubs;
--   2. Pins that entering the step or leaving the protocol untouched requests no reboot;
--   3. Pins that changing the protocol calls wiz.requestReboot();
--   4. Pins that selecting the newly set protocol again requests no reboot;
--   5. Pins that forwardFrom(SETUP) with rebootPending sets resume to WIRING and finishes the step;
--   6. Pins that re-opening the step with resume set opens directly on the wiring screen;
--   7. Checks that setup_wizard.md and setup_wizard/esctelemetry.md document the restart requirement.
--
-- --self-test runs the check against a mutant where wiz.requestReboot() is removed from setProtocol().

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

-- ── stubs ─────────────────────────────────────────────────────────────

local scr
local function newScreen()
  local s = { title = nil, rows = nil, back = nil, forward = nil, start = nil }
  function s:begin() s.rows, s.back, s.forward, s.start = nil, nil, nil, nil end
  function s:text(title) s.title = title end
  function s:step() end
  function s:picture() end
  function s:paint() end
  function s:refresh() end
  function s:checks(rows)
    s.rows = rows
    return {}
  end
  function s:row(back, _, forward)
    s.back, s.forward = back, forward
    return {}
  end
  function s:safety(_, _, _, startPress)
    s.start = startPress
    return {}
  end
  return s
end

local function newWiz(initialProtocol)
  local protocol = initialProtocol or 1
  local rebootRequested = false
  local resumeStep = nil
  local finished = false
  local escData = { protocol = protocol, half_duplex = 0, pin_swap = 0 }
  local ports = {
    { identifier = 0, function_mask = 1024 }, -- UART1 has ESC sensor function
    { identifier = 1, function_mask = 0 },    -- UART2 free
  }

  local w = {
    apiAtLeast = function() return true end,
    takeResume = function()
      local r = resumeStep
      resumeStep = nil
      return r
    end,
    setResume = function(s) resumeStep = s end,
    getResume = function() return resumeStep end,
    requestReboot = function() rebootRequested = true end,
    rebootRequested = function() return rebootRequested end,
    rebootPending = function() return rebootRequested end,
    clearReboot = function() rebootRequested = false end,
    finishStep = function() finished = true end,
    isFinished = function() return finished end,
    hasPending = function() return false end,
    saveThen = function(cb) cb() end,
    change = function() end,
    send = function() end,
    rebuild = function() end,
    forward = function(fn) return { text = rebootRequested and "Save and restart" or "Next", press = fn } end,
    fetch = function(requests, cb)
      local results = {}
      if requests.feature then results.feature = { enabledFeatures = 1 << 27 } end
      if requests.esc then results.esc = escData end
      if requests.serial then results.serial = { ports = ports } end
      if requests.motor then results.motor = { motor_pwm_protocol = 1 } end
      if requests.board then results.board = { boardDesign = "TEST", boardName = "TestBoard" } end
      cb(results, false)
    end,
  }
  return w
end

local stubs = {
  ["app/setup_wizard_ui.lua"] = { new = function() scr = newScreen(); return scr end },
  ["app/setup_wizard_art.lua"] = { image = function() return {} end },
  ["app/setup_wizard_power.lua"] = {
    new = function() return { load = function(cb) cb() end, source = function() return 0 end, loaded = true } end,
    SOURCE_NONE = 0,
    SOURCE_ESC = 1,
  },
  ["lib/bus.lua"] = { subscribe = function() end, unsubscribe = function() end },
  ["lib/live_sensors.lua"] = { value = function() return nil end },
  ["lib/msp_analog.lua"] = { buildReadMessage = function() return {} end },
  ["lib/msp_esc_sensor_trial.lua"] = { COMBINATIONS = 4, buildCancelMessage = function() return {} end },
  ["lib/msp_esc_sensor_config.lua"] = {
    choicesFor = function() return { {"None", 0}, {"Protocol 1", 1}, {"Protocol 2", 2} } end,
    buildReadMessage = function() return {} end,
    buildWriteMessage = function() return {} end,
  },
  ["lib/msp_feature_config.lua"] = { buildReadMessage = function() return {} end, buildWriteMessage = function() return {} end },
  ["lib/msp_serial_config.lua"] = { buildReadMessage = function() return {} end, buildWriteMessage = function() return {} end },
  ["lib/msp_motor_config.lua"] = { CASTLE_PROTOCOL = 99, buildReadMessage = function() return {} end },
  ["lib/msp_board_info.lua"] = { buildReadMessage = function() return {} end },
  ["lib/port_labels.lua"] = { lookup = function() return nil end },
}

package.loaded["rfsuite.lib.require"] = function(path)
  local s = stubs[path]
  if not s then error("unexpected require: " .. tostring(path)) end
  return s
end

-- ── drive the step ────────────────────────────────────────────────────

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local function runEscTelemetryStep(source, initialProto)
  local before = failures
  local wiz = newWiz(initialProto)
  local chunk = assert(load(source, "@setup_wizard_esctelemetry.lua", "t"))
  local factory = chunk()
  local step = factory.new(wiz)

  -- 1. Entry into blades safety card
  step.build()
  check("step starts on blades safety card with Start button", scr.start ~= nil)
  check("entry requests no reboot", wiz.rebootRequested() == false)
  if not scr.start then return failures - before end

  -- 2. Move to setup screen
  scr.start()
  step.build()
  check("setup screen creates rows", scr.rows ~= nil and #scr.rows >= 3)
  check("moving to setup screen requests no reboot", wiz.rebootRequested() == false)

  local protoChoice = scr.rows and scr.rows[2] and scr.rows[2].choice
  check("second row has a protocol choice", protoChoice ~= nil and protoChoice.set ~= nil)
  if not (protoChoice and protoChoice.set) then return failures - before end

  -- 3. Setting the same protocol requests no reboot
  protoChoice.set(initialProto)
  check("selecting the same protocol requests no reboot", wiz.rebootRequested() == false)

  -- 4. Switching to a different protocol
  local targetProto = (initialProto == 1) and 2 or 1
  protoChoice.set(targetProto)
  check("changing protocol requests an FC reboot", wiz.rebootRequested() == true,
    "protocol " .. tostring(initialProto) .. " -> " .. tostring(targetProto) .. " did not call wiz.requestReboot()")
  check("reboot is pending", wiz.rebootPending() == true)

  -- 5. Rebuilding updates forward button and forward press routes to WIRING
  step.build()
  check("forward button is available", scr.forward ~= nil and scr.forward.press ~= nil)
  if scr.forward and scr.forward.press then
    scr.forward.press()
    check("forwarding with reboot pending finishes the step", wiz.isFinished() == true)
    check("forwarding with reboot pending sets resume to WIRING", wiz.getResume() == 3)
  end

  -- 6. Setting the newly set protocol again requests no additional reboot
  wiz.clearReboot()
  protoChoice.set(targetProto)
  check("selecting the newly set protocol again requests no reboot", wiz.rebootRequested() == false)

  -- 7. Switching back to initial protocol requests reboot again
  protoChoice.set(initialProto)
  check("switching back to initial protocol requests an FC reboot", wiz.rebootRequested() == true)

  -- 8. Re-opening step with resume set opens directly on wiring screen
  local resumeWiz = newWiz(targetProto)
  resumeWiz.setResume(3) -- WIRING
  local resumeStep = factory.new(resumeWiz)
  resumeStep.build()
  check("resuming step starts directly on wiring screen", scr.title == "@i18n(app.modules.setup_wizard.wir_title)@")
  check("resuming step has no safety start button", scr.start == nil)

  return failures - before
end

local function runDocs()
  local before = failures
  local overview = readFile(ROOT .. "/docs/pages/wizards/setup_wizard.md")
  check("setup_wizard.md mentions telemetry port and protocol in restart notes",
    overview:find("telemetry port and protocol", 1, true) ~= nil,
    "expected 'telemetry port and protocol' in setup_wizard.md restart points")

  local telDoc = readFile(ROOT .. "/docs/pages/wizards/setup_wizard/esctelemetry.md")
  check("esctelemetry.md documents the restart on protocol change in table",
    telDoc:find("Changing the protocol needs a restart", 1, true) ~= nil,
    "expected 'Changing the protocol needs a restart' in esctelemetry.md table")
  check("esctelemetry.md documents the restart on protocol change in notes",
    telDoc:find("Changing the protocol also needs a restart", 1, true) ~= nil,
    "expected 'Changing the protocol also needs a restart' in esctelemetry.md notes")

  return failures - before
end

local source = readFile(MODULE)

if not SELF_TEST then
  local n = runEscTelemetryStep(source, 1) + runEscTelemetryStep(source, 2) + runDocs()
  if n == 0 then
    print("OK  Setup Wizard ESC telemetry protocol change requests an FC restart (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- ── self-test ─────────────────────────────────────────────────────────

local mutant, count = source:gsub(
  "(local function setProtocol.-)wiz%.requestReboot%(%)(.-wiz%.rebuild)",
  "%1-- mutant: omitted wiz.requestReboot()%2"
)
if count ~= 1 then
  print("FAIL  self-test: could not splice wiz.requestReboot() in setProtocol()")
  os.exit(1)
end

failures, checks = 0, 0
local caught = runEscTelemetryStep(mutant, 1)
if caught > 0 then
  print("ok    mutant red: no reboot requested on protocol change (" .. caught .. " failed checks)")
  print("OK  self-test: removing wiz.requestReboot() from setProtocol() goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: removing wiz.requestReboot() did not go red")
os.exit(1)

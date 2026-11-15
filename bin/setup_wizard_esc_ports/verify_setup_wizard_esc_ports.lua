-- Behaviour check for #2691: the Setup Wizard's ESC telemetry step offers only free serial ports (and the
-- port the ESC telemetry already uses), so a port that carries another function is never replaced.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_esc_ports/verify_setup_wizard_esc_ports.lua
--     lua5.4 bin/setup_wizard_esc_ports/verify_setup_wizard_esc_ports.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/setup_wizard_esctelemetry.lua, with the UI, art,
-- power and MSP modules replaced by stubs and a simulated flight controller with these serial ports:
--   VCP (MSP), UART1 (serial receiver), UART2 (the ESC telemetry), UART3 (free), UART4 (S.Port
--   telemetry), UART5 (GPS).
-- It goes to the setup screen and reads the port row. It pins:
--   1. the free port and the ESC telemetry's own port are offered;
--   2. the receiver, S.Port and GPS ports are not offered, and neither is the USB VCP.
--
-- --self-test runs the same checks on a copy with the old rule (every port that does not receive) and
-- requires check 2 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local STEP = ROOT .. "/src/rfsuite/app/pages/setup_wizard_esctelemetry.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local ESC_SENSOR_BIT = 27
local PORT_LABEL = "@i18n(app.modules.setup_wizard.tel_port)@"
local VCP, UART1, UART2, UART3, UART4, UART5 = 20, 0, 1, 2, 3, 4

local function copy(t)
  local out = {}
  for k, v in pairs(t or {}) do out[k] = type(v) == "table" and copy(v) or v end
  return out
end

local function anyObject()
  return setmetatable({}, { __index = function() return function() end end })
end

local function newFc()
  return {
    features = 1 << ESC_SENSOR_BIT,
    esc = {protocol = 1},
    ports = {
      {identifier = VCP, function_mask = 1},        -- MSP over USB
      {identifier = UART1, function_mask = 64},     -- serial receiver
      {identifier = UART2, function_mask = 1024},   -- the ESC telemetry
      {identifier = UART3, function_mask = 0},      -- free
      {identifier = UART4, function_mask = 32},     -- S.Port telemetry
      {identifier = UART5, function_mask = 2},      -- GPS
    },
    motor = {motor_pwm_protocol = 6},
  }
end

local function newWiz(fc)
  local wiz = {}
  function wiz.fetch(specs, onDone)
    local results, failed = {}, false
    for key, build in pairs(specs) do
      wiz.send(build(function(d) results[key] = d end, function() failed = true end))
    end
    onDone(results, failed)
  end
  function wiz.send(msg)
    if not msg then return end
    if msg.kind == "feature_read" then msg.onData({enabledFeatures = fc.features})
    elseif msg.kind == "esc_read" then msg.onData(copy(fc.esc))
    elseif msg.kind == "serial_read" then msg.onData({ports = copy(fc.ports)})
    elseif msg.kind == "motor_read" then msg.onData(copy(fc.motor))
    elseif msg.kind == "board_read" then msg.onData({})
    end
  end
  function wiz.takeResume() return nil end
  function wiz.apiAtLeast() return true end
  function wiz.rebootPending() return false end
  function wiz.rebuild() end
  return setmetatable(wiz, { __index = function() return function() end end })
end

-- A recording screen. rawget is used on it below: its metatable answers every missing field with a function.
local holder = {}
local function newScreen()
  local s = {}
  holder.screen = s
  function s.begin() rawset(s, "rows", nil); rawset(s, "start", nil) end
  function s.checks(_, rows) rawset(s, "rows", rows); return {} end
  function s.safety(_, _, _, _, startPress) rawset(s, "start", startPress); return {} end
  return setmetatable(s, { __index = function() return function() return {} end end })
end

local function stubs()
  local function reader(kind)
    return function(onData, onError) return {kind = kind, onData = onData, onError = onError} end
  end
  return {
    ["app/setup_wizard_ui.lua"] = {new = function() return newScreen() end},
    ["app/setup_wizard_art.lua"] = setmetatable({}, {__index = function() return function() return anyObject() end end}),
    ["app/setup_wizard_power.lua"] = {new = function()
      return setmetatable({load = function() end}, {__index = function() return function() end end})
    end},
    ["lib/bus.lua"] = {subscribe = function() end, unsubscribe = function() end, publish = function() end},
    ["lib/live_sensors.lua"] = {value = function() return nil end},
    ["lib/msp_analog.lua"] = anyObject(),
    ["lib/msp_esc_sensor_trial.lua"] = anyObject(),
    ["lib/esc_params.lua"] = {familyFor = function() return nil end},
    ["lib/msp_esc_sensor_config.lua"] = {
      choicesFor = function() return {{"None", 0}, {"BLHeli32", 1}} end,
      buildReadMessage = reader("esc_read"),
      buildWriteMessage = function(data) return {kind = "esc_write", data = data} end,
    },
    ["lib/msp_feature_config.lua"] = {
      buildReadMessage = reader("feature_read"),
      buildWriteMessage = function(data) return {kind = "feature_write", data = data} end,
    },
    ["lib/msp_serial_config.lua"] = {
      buildReadMessage = reader("serial_read"),
      buildWriteMessage = function(data) return {kind = "serial_write", data = data} end,
    },
    ["lib/msp_motor_config.lua"] = {buildReadMessage = reader("motor_read")},
    ["lib/msp_board_info.lua"] = {buildReadMessage = reader("board_read")},
    ["lib/port_labels.lua"] = setmetatable({}, {__index = function() return function() return "UART" end end}),
  }
end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local function run(source)
  local before = failures
  local s = stubs()
  package.loaded["rfsuite.lib.require"] = function(path)
    local m = s[path]
    if not m then error("unexpected require: " .. tostring(path)) end
    return m
  end
  local step = assert(load(source, "@setup_wizard_esctelemetry.lua", "t"))()
  local node = step.new(newWiz(newFc()))
  node.build()
  local scr = holder.screen
  local start = rawget(scr, "start")
  check("the blades card offers Start", start ~= nil)
  if not start then return failures - before end
  start()
  node.build()

  local offered = {}
  for _, r in ipairs(rawget(scr, "rows") or {}) do
    if r.label == PORT_LABEL and r.choice then
      for _, v in ipairs(r.choice.values or {}) do offered[v.value] = true end
    end
  end
  local list = {}
  for id in pairs(offered) do list[#list + 1] = tostring(id) end
  table.sort(list)
  local shown = table.concat(list, ",")

  -- 1. Offered.
  check("1a. the free port is offered", offered[UART3] == true, "offered=" .. shown)
  check("1b. the ESC telemetry's own port is offered", offered[UART2] == true, "offered=" .. shown)

  -- 2. Not offered.
  check("2a. the serial receiver port is not offered", not offered[UART1], "offered=" .. shown)
  check("2b. the S.Port telemetry port is not offered", not offered[UART4], "offered=" .. shown)
  check("2c. the GPS port is not offered", not offered[UART5], "offered=" .. shown)
  check("2d. the USB VCP is not offered", not offered[VCP], "offered=" .. shown)
  return failures - before
end

local source = readFile(STEP)

if not SELF_TEST then
  local n = run(source)
  if n == 0 then
    print("OK  ESC telemetry ports: only free ports and the current one are offered (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- The old rule: every port that does not receive.
local mutated, n = source:gsub("      local free = %(p%.function_mask or 0%) == 0\n",
  "      local free = (p.function_mask or 0) & FUNCTION_MASK_RX_SERIAL == 0\n")
if n ~= 1 then
  print("FAIL  self-test: the free-port line was not found once; update this harness")
  os.exit(1)
end
failures, checks = 0, 0
local caught = run(mutated)
if caught > 0 then
  print("ok    mutant red: occupied ports offered (" .. caught .. " failed checks)")
  print("OK  self-test: the old rule goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: the old rule")
os.exit(1)

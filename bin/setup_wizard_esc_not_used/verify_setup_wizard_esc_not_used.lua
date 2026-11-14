-- Behaviour check for #2698: "Not used" on the Setup Wizard's ESC telemetry step clears the stored
-- protocol, so the flight controller's config check (validateAndFixConfig, F.BUS with a master port)
-- cannot turn the ESC sensor feature back on.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_esc_not_used/verify_setup_wizard_esc_not_used.lua
--     lua5.4 bin/setup_wizard_esc_not_used/verify_setup_wizard_esc_not_used.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/setup_wizard_esctelemetry.lua, with the UI, art,
-- power and MSP modules replaced by stubs and a simulated flight controller behind the wizard's send.
-- It goes from the blades card to the setup screen and picks "Not used". It pins:
--   1. the ESC sensor feature bit is cleared and the ESC sensor port is freed;
--   2. the stored ESC telemetry protocol is written as 0;
--   3. Discard writes the protocol back as it was.
--
-- --self-test runs the same checks on a copy without the protocol reset and requires check 2 to go red.

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
local ESC_SENSOR_FUNCTION = 1024
local FBUS_PROTOCOL = 7          -- any stored protocol other than 0 shows the effect
local NOT_USED = "@i18n(app.modules.setup_wizard.tel_not_used)@"

local function copy(t)
  local out = {}
  for k, v in pairs(t or {}) do out[k] = type(v) == "table" and copy(v) or v end
  return out
end

local function anyObject()
  return setmetatable({}, { __index = function() return function() end end })
end

-- ── the simulated flight controller ───────────────────────────────────

local function newFc()
  return {
    features = 1 << ESC_SENSOR_BIT,
    esc = {protocol = FBUS_PROTOCOL, half_duplex = 0, update_hz = 200},
    ports = {
      {identifier = 0, function_mask = 64},                    -- a receiver port (not the ESC's)
      {identifier = 1, function_mask = ESC_SENSOR_FUNCTION},   -- the ESC telemetry port
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
    elseif msg.kind == "feature_write" then fc.features = msg.data.enabledFeatures
    elseif msg.kind == "esc_read" then msg.onData(copy(fc.esc))
    elseif msg.kind == "esc_write" then fc.esc = copy(msg.data)
    elseif msg.kind == "serial_read" then msg.onData({ports = copy(fc.ports)})
    elseif msg.kind == "serial_write" then
      for _, p in ipairs(fc.ports) do
        if p.identifier == msg.data.identifier then p.function_mask = msg.data.function_mask end
      end
    elseif msg.kind == "motor_read" then msg.onData(copy(fc.motor))
    elseif msg.kind == "board_read" then msg.onData({})
    end
  end
  -- The first snapshot is the state before any change; rawset/rawget avoid the no-op metatable below.
  function wiz.change(_, snapshot, restore)
    if rawget(wiz, "snapshot") == nil then rawset(wiz, "snapshot", snapshot) end
    rawset(wiz, "restore", restore)
  end
  function wiz.takeResume() return nil end
  function wiz.apiAtLeast() return true end
  function wiz.rebootPending() return false end
  function wiz.requestReboot() end
  function wiz.rebuild() end
  function wiz.invalidate() end
  function wiz.canMove() return true end
  return setmetatable(wiz, { __index = function() return function() end end })
end

-- A recording screen: the rows of the last checks() and the safety card's Start.
local holder = {}
local function newScreen()
  local s = {rows = nil, start = nil}
  holder.screen = s
  function s.begin() s.rows, s.start = nil, nil end
  function s.checks(_, rows) s.rows = rows; return {} end
  function s.safety(_, _, _, _, startPress) s.start = startPress; return {} end
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
      choicesFor = function() return {{"None", 0}, {"F.BUS", FBUS_PROTOCOL}} end,
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
  local fc = newFc()
  local wiz = newWiz(fc)
  local s = stubs()
  package.loaded["rfsuite.lib.require"] = function(path)
    local m = s[path]
    if not m then error("unexpected require: " .. tostring(path)) end
    return m
  end
  local step = assert(load(source, "@setup_wizard_esctelemetry.lua", "t"))()
  local node = step.new(wiz)

  -- Blades card, then the setup screen.
  node.build()
  local scr = holder.screen
  check("the blades card offers Start", scr.start ~= nil)
  if not scr.start then return failures - before end
  scr.start()
  node.build()

  local usedRow
  for _, r in ipairs(scr.rows or {}) do
    if r.choice and r.choice.values then
      for _, v in ipairs(r.choice.values) do
        if v.text == NOT_USED then usedRow = r end
      end
    end
  end
  check("the setup screen has the Used / Not used row", usedRow ~= nil)
  if not usedRow then return failures - before end

  usedRow.choice.set(0)

  -- 1. Feature off, port freed.
  check("1a. the ESC sensor feature bit is cleared", fc.features & (1 << ESC_SENSOR_BIT) == 0)
  local escPortMask
  for _, p in ipairs(fc.ports) do if p.identifier == 1 then escPortMask = p.function_mask end end
  check("1b. the ESC sensor port is freed", escPortMask == 0, "mask=" .. tostring(escPortMask))

  -- 2. The protocol is written as 0.
  check("2. the stored ESC telemetry protocol is written as 0", fc.esc.protocol == 0,
    "protocol=" .. tostring(fc.esc.protocol))

  -- 3. Discard puts the protocol back.
  local restore, snapshot = rawget(wiz, "restore"), rawget(wiz, "snapshot")
  check("3a. the step registered a Discard", type(restore) == "function" and snapshot ~= nil)
  if type(restore) == "function" and snapshot ~= nil then
    restore(snapshot)
    check("3b. Discard writes the protocol back", fc.esc.protocol == FBUS_PROTOCOL,
      "protocol=" .. tostring(fc.esc.protocol))
  end
  return failures - before
end

local source = readFile(STEP)

if not SELF_TEST then
  local n = run(source)
  if n == 0 then
    print("OK  ESC telemetry Not used: feature off, port freed, protocol 0, Discard restores it (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- Without the reset: the protocol stays what it was.
local mutated, n = source:gsub("      if esc then\n        esc%.protocol = 0\n        writeEsc%(copy%(esc%)%)\n      end\n", "")
if n ~= 1 then
  print("FAIL  self-test: the protocol reset was not found once; update this harness")
  os.exit(1)
end
failures, checks = 0, 0
local caught = run(mutated)
if caught > 0 then
  print("ok    mutant red: Not used keeps the protocol (" .. caught .. " failed checks)")
  print("OK  self-test: without the reset the protocol check goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: without the reset")
os.exit(1)

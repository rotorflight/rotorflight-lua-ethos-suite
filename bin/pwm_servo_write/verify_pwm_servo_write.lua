-- Behaviour check for Issue #2445: the PWM servo page must list only the PWM outputs,
-- and must write each one raw (MSP_SET_SERVO_CONFIG, cmd 124).
--
-- Run it:
--     lua5.4 bin/pwm_servo_write/verify_pwm_servo_write.lua
--
-- What it drives, and why:
--   * The real app/pages/servos_pwm.lua, the real app/page_runtime.lua, the real
--     app/servo_bus_guard.lua and the real MSP servo-config module. Status, mixer
--     and serial-config reads are stubs that the scenario answers; the servo-config
--     write builders are the real ones, so the command number and the index in the
--     payload are the ones the firmware would receive.
--   * Three bench layouts. No bus port: PWM servos only. A FBUS port or an SBUS port
--     with bus channels in servo_count: the list must show the PWM outputs only.
--   * Against unpatched master the list shows the packed count (16 tiles in the bus
--     layout), and every save is written with cmd 212 and the packed index, which the
--     firmware translates to a bus servo.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  local last = 0
  for i = 1, #path do
    local ch = path:sub(i, i)
    if ch == "/" or ch == string.char(92) then last = i end
  end
  if last == 0 then return "." end
  return path:sub(1, last - 1)
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then f:close() return name end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then path = resolvePath(path) end
  if env ~= nil then return realLoadfile(path, mode, env)
  elseif mode ~= nil then return realLoadfile(path, mode)
  else return realLoadfile(path) end
end

local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(resolvePath(name))
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local function anything()
  local t = {}
  return setmetatable(t, {
    __index = function() return function() return anything() end end,
    __call = function() return anything() end,
  })
end

-- ---------------------------------------------------------------------------
-- Stubs
-- ---------------------------------------------------------------------------

lcd = anything()
lcd.getWindowSize = function() return 800, 480 end
system = anything()

local dialogs = {}
local tiles = {}
form = anything()
form.clear = function() end
form.invalidate = function() end
form.height = function() return 0 end
form.openDialog = function(opts) dialogs[#dialogs + 1] = opts end
form.addButton = function(_, _, opts)
  tiles[#tiles + 1] = opts
  return anything()
end

local lastHeaderOpts = nil
package.loaded["rfsuite.app.header"] = {
  build = function(_, opts) lastHeaderOpts = opts; return anything() end,
}
package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return true end}
package.loaded["rfsuite.app.progress_dialog"] = {
  SPEED = {DEFAULT = 1},
  open = function() return {value = function() end, close = function() end} end,
}
package.loaded["rfsuite.app.tile_grid"] = {
  metrics = function() return 3, 120, 90, 4, 0 end,
  fitLabel = function(text) return text end,
}
package.loaded["rfsuite.lib.memstats"] = {print = function() end}
package.loaded["rfsuite.lib.debug_log"] = anything()
package.loaded["rfsuite.lib.settings_store"] = {
  load = function() return {} end,
  saveConfirmEnabled = function() return false end,
  clone = function(t) return t end,
  save = function() return true end,
}

-- Status and mixer: stubs with recorded reads, answered by the scenario.
package.loaded["rfsuite.lib.msp_status"] = {
  buildReadMessage = function(onData, onError)
    return {kind = "statusRead", onData = onData, onError = onError}
  end,
}
package.loaded["rfsuite.lib.msp_mixer_config"] = {
  buildReadMessage = function(onData, onError)
    return {kind = "mixerRead", onData = onData, onError = onError}
  end,
  buildWriteMessage = function() return {kind = "mixerWrite"} end,
}

-- Serial config: the real module, with its read builder replaced so the scenario
-- answers the ports read. The guard reads the same module.
do
  local serialConfig = requireModule("lib/msp_serial_config.lua")
  serialConfig.buildReadMessage = function(onData, onError)
    return {kind = "serialRead", onData = onData, onError = onError}
  end
end

-- Servo config: the real module. The reads are recorded for the scenario; the write
-- builders stay real, so the command and the payload are the firmware's.
do
  local servoConfig = requireModule("lib/msp_servo_config.lua")
  local realForIndex = servoConfig.forIndex
  servoConfig.forIndex = function(index)
    local servo = realForIndex(index)
    servo.buildReadMessage = function(onData, onError)
      return {kind = "servoRead", onData = onData, onError = onError}
    end
    return servo
  end
end

-- Keep the runtime of the open editor, so the scenario can mark its page dirty.
local runtimeRef = nil
do
  local fieldLayout = requireModule("app/field_layout.lua")
  local realBuildSingle = fieldLayout.buildSingle
  fieldLayout.buildSingle = function(runtime, ...)
    runtimeRef = runtime
    return realBuildSingle(runtime, ...)
  end
end

local sent = {}
local bus = requireModule("lib/bus.lua")
bus.subscribe("msp.request", function(m) sent[#sent + 1] = m end)

local page = requireModule("app/pages/servos_pwm.lua")

-- ---------------------------------------------------------------------------
-- Scenario driver
-- ---------------------------------------------------------------------------

local SERVO_FIXTURE = {
  mid = 1500, min = 1000, max = 2000, rneg = 100, rpos = 100,
  rate = 0, speed = 0, reverse = 0, geometry = 0,
}

local function answerReads(kinds, fixtureFor)
  local answered = 0
  for _, m in ipairs(sent) do
    if kinds[m.kind] and not m.answered then
      m.answered = true
      answered = answered + 1
      m.onData(fixtureFor(m.kind))
    end
  end
  return answered
end

local currentWake = nil
local function runWakeups(n)
  for _ = 1, n do if currentWake then currentWake() end end
end

local function countWrites(command)
  local n = 0
  for _, m in ipairs(sent) do
    if m.command == command and m.isWrite then n = n + 1 end
  end
  return n
end

local function lastWrite(command)
  for i = #sent, 1, -1 do
    local m = sent[i]
    if m.command == command and m.isWrite then return m end
  end
  return nil
end

-- Opens the page on a bench with the given servo_count and ports, then the list.
local function openList(servoCount, ports)
  sent, tiles, dialogs, lastHeaderOpts, runtimeRef, currentWake = {}, {}, {}, nil, nil, nil
  page.open({
    onBack = function() end,
    setWakeupHandler = function(fn) currentWake = fn end,
  })
  answerReads({statusRead = true, mixerRead = true, serialRead = true}, function(kind)
    if kind == "statusRead" then return {servo_count = servoCount} end
    if kind == "mixerRead" then return {swash_type = 0, tail_rotor_mode = 0} end
    return {ports = ports}
  end)
  runWakeups(1)
  return #tiles
end

-- Presses tile k, lets its read complete, marks the page dirty and saves it, as the
-- Save button does. Returns the write that the page sent, if any.
local function saveTile(k)
  tiles[k].press()
  for _ = 1, 10 do
    if answerReads({servoRead = true}, function() return SERVO_FIXTURE end) == 0 then break end
  end
  runWakeups(5)
  if not runtimeRef or not lastHeaderOpts or not lastHeaderOpts.onSave then
    return nil, "the editor did not open"
  end
  runtimeRef:setDirty(true)
  local before = #sent
  local ok, err = pcall(function() lastHeaderOpts.onSave() end)
  if not ok then return nil, "Save raised: " .. tostring(err) end
  for i = before + 1, #sent do
    local m = sent[i]
    if m.isWrite and (m.command == 124 or m.command == 212) then return m, nil end
  end
  return nil, "Save sent no servo write"
end

-- ---------------------------------------------------------------------------
-- Checks
-- ---------------------------------------------------------------------------

local SCENARIOS = {
  {
    label = "no bus port: PWM servos only",
    servoCount = 2, ports = {{function_mask = 0}},
    expectTiles = 2, tile = 2, expectIndex = 1,
  },
  {
    label = "FBUS port, two PWM servos: packed total 20",
    servoCount = 20, ports = {{function_mask = 524288}},
    expectTiles = 2, tile = 1, expectIndex = 0,
  },
  {
    label = "SBUS port, three PWM servos: packed total 21",
    servoCount = 21, ports = {{function_mask = 262144}},
    expectTiles = 3, tile = 3, expectIndex = 2,
  },
}

for _, s in ipairs(SCENARIOS) do
  print(s.label)
  local tileCount = openList(s.servoCount, s.ports)
  check("the list shows the PWM outputs only",
    tileCount == s.expectTiles,
    "tiles shown: " .. tileCount .. ", expected " .. s.expectTiles)
  if tileCount >= s.tile then
    local write, why = saveTile(s.tile)
    check("the save completes", write ~= nil, why)
    check("the PWM servo is written raw (cmd 124), not packed (cmd 212)",
      countWrites(212) == 0 and countWrites(124) == 1,
      "cmd 124 writes: " .. countWrites(124) .. ", cmd 212 writes: " .. countWrites(212))
    local payload = write and write.payload
    check("the raw index in the payload is the PWM servo's own index",
      payload ~= nil and payload[1] == s.expectIndex,
      "payload[1] = " .. tostring(payload and payload[1]) .. ", expected " .. s.expectIndex)
  else
    check("the save completes", false, "tile " .. s.tile .. " does not exist")
  end
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

-- Behaviour check for Issue #2496: an override must not be switched on before the
-- page has read its values.
--
-- Run it:
--     lua5.4 bin/override_read_gate/verify_override_read_gate.lua
--
-- What it drives, and why:
--   * The real app/pages/mixer_trims.lua, mixer_geometry.lua, servos_pwm.lua and
--     servos_bus.lua, with the real app/page_runtime.lua. The header, the progress
--     dialog and the tile grid are stubs; the MSP modules are the real ones with their
--     message builders replaced, so every message the page publishes is recorded by the
--     bus and the scenario answers each read the way the FC would.
--   * Two scenarios per page. In "read fails" the page's read errors out, so the
--     runtime is not loaded. In "read succeeds" the page is loaded. Pressing Tool and
--     confirming the override dialog must write the override only in the second.
--   * Against unpatched master the "read fails" scenario writes the override anyway:
--     the live write is held back, the override is not. That is the defect.

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
local focusCalls = 0
-- The real header handle. page_runtime hands the page runtime.onTool() exactly
-- one focus function -- headerHandle.focusTool (app/page_runtime.lua:1314) --
-- and the dialog owes that one a call on every path: the form loses its focus
-- when a dialog closes (page_runtime.lua's own note on closeDialog). Counting
-- the calls here is therefore the only way to see the hand-off; the function
-- the harness passes to onTool is never forwarded.
local function headerHandleStub()
  local h = setmetatable({}, {__index = function() return function() end end})
  h.focusTool = function() focusCalls = focusCalls + 1 end
  return h
end
package.loaded["rfsuite.app.header"] = {
  build = function(_, opts) lastHeaderOpts = opts; return headerHandleStub() end,
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

-- Mixer config: replaced builders, so the page's reads are recorded and answered here.
package.loaded["rfsuite.lib.msp_mixer_config"] = {
  buildReadMessage = function(onData, onError)
    return {kind = "mixerRead", onData = onData, onError = onError}
  end,
  buildWriteMessage = function(_, onWritten, onError)
    return {kind = "mixerWrite", processReply = function() if onWritten then onWritten() end end, errorHandler = onError}
  end,
}

-- Mixer override: real constants, replaced builders.
do
  local mixerOverride = requireModule("lib/msp_mixer_override.lua")
  mixerOverride.buildWriteMessage = function(index, value)
    return {kind = "override", index = index, value = value}
  end
end

-- Status (servo count) and servo config: real modules, read builders replaced.
package.loaded["rfsuite.lib.msp_status"] = {
  buildReadMessage = function(onData, onError)
    return {kind = "statusRead", onData = onData, onError = onError}
  end,
}
do
  local servoConfig = requireModule("lib/msp_servo_config.lua")
  -- servos_bus reads through the module-level builder with its own index
  servoConfig.buildReadMessage = function(_, onData, onError)
    return {kind = "servoRead", onData = onData, onError = onError}
  end
  servoConfig.forIndex = function()
    return {
      FIELD_META = servoConfig.FIELD_META,
      buildReadMessage = function(onData, onError)
        return {kind = "servoRead", onData = onData, onError = onError}
      end,
      buildWriteMessage = function() return {kind = "servoWrite"} end,
      buildRawWriteMessage = function() return {kind = "servoWrite"} end,
    }
  end
end
do
  local servoOverride = requireModule("lib/msp_servo_override.lua")
  servoOverride.buildWriteMessage = function(index, value)
    return {kind = "override", index = index, value = value}
  end
  servoOverride.buildWriteAllMessage = function(value)
    return {kind = "overrideAll", value = value}
  end
end

-- The three stick-input sources mixer_geometry reads alongside the mixer config.
local function inputSource()
  return {
    buildReadMessage = function(onData, onError)
      return {kind = "mixerRead", onData = onData, onError = onError}
    end,
    buildWriteMessage = function()
      return {kind = "mixerWrite"}
    end,
  }
end
package.loaded["rfsuite.lib.msp_mixer_input"] = {
  pitch = inputSource, roll = inputSource, collective = inputSource,
}

local sent = {}
local bus = requireModule("lib/bus.lua")
bus.subscribe("msp.request", function(m) sent[#sent + 1] = m end)

-- ---------------------------------------------------------------------------
-- Scenario driver
-- ---------------------------------------------------------------------------

local MIXER_FIXTURE = {
  tail_rotor_mode = 0,
  swash_trim_0 = 0, swash_trim_1 = 0, swash_trim_2 = 0,
  tail_center_trim = 0, tail_motor_idle = 0,
}
local SERVO_FIXTURE = {
  mid = 1500, min = 1000, max = 2000, rneg = 100, rpos = 100,
  rate = 0, speed = 0, reverse = 0, geometry = 0,
}

local function countKind(kind)
  local n = 0
  for _, m in ipairs(sent) do if m.kind == kind then n = n + 1 end end
  return n
end

-- Answers every not-yet-answered read of the given kinds with the outcome.
-- Returns how many reads were answered.
local function answerReads(kinds, outcome, fixtureFor)
  local answered = 0
  for _, m in ipairs(sent) do
    if kinds[m.kind] and not m.answered then
      m.answered = true
      answered = answered + 1
      if outcome == "ok" then m.onData(fixtureFor(m.kind))
      else m.onError("read timed out") end
    end
  end
  return answered
end

-- The wakeup handler the page or its runtime registered last. A page's list sets it
-- to nil, and the editor it opens registers its own.
local currentWake = nil
local function runWakeups(n)
  for _ = 1, n do if currentWake then currentWake() end end
end

local function resetScenario()
  sent = {}
  dialogs = {}
  tiles = {}
  lastHeaderOpts = nil
  currentWake = nil
  focusCalls = 0
end

local function pageOpts()
  return {
    onBack = function() end,
    setWakeupHandler = function(fn) currentWake = fn end,
  }
end

-- mixer_trims and mixer_geometry: the page opens its editor directly.
local function openMixerPage(page, outcome)
  resetScenario()
  page.open(pageOpts())
  -- the open read: tail rotor mode, always answered with success
  for _, m in ipairs(sent) do
    if m.kind == "mixerRead" and not m.answered then
      m.answered = true
      m.onData({tail_rotor_mode = 0})
      break
    end
  end
  runWakeups(1)
  for _ = 1, 10 do
    if answerReads({mixerRead = true}, outcome, function() return MIXER_FIXTURE end) == 0 then break end
  end
  runWakeups(5)
end

-- servos_pwm and servos_bus: status and mixer reads, then a list, then a tap on a
-- tile opens the editor for that servo.
local function openServoPage(page, outcome)
  resetScenario()
  page.open(pageOpts())
  answerReads({statusRead = true, mixerRead = true}, "ok", function(kind)
    if kind == "statusRead" then return {servo_count = 2} end
    return {swash_type = 0, tail_rotor_mode = 0}
  end)
  runWakeups(1)
  if #tiles == 0 then return false, "the list shows no servo tile" end
  tiles[1].press()
  for _ = 1, 10 do
    if answerReads({servoRead = true}, outcome, function() return SERVO_FIXTURE end) == 0 then break end
  end
  runWakeups(5)
  return true, nil
end

-- Presses Tool, then OK on the dialog it opens. Returns the dialog's OK result.
local function pressToolAndConfirm()
  local before = #dialogs
  if not lastHeaderOpts or not lastHeaderOpts.onTool then return nil, "no Tool handler registered" end
  -- The focus hand-off the dialog owes the page: page_runtime hands the page
  -- runtime.headerHandle.focusTool as focusFn (page_runtime.lua:1314), so the
  -- counter lives on the header handle, not on this function's argument.
  focusCalls = 0
  local ok, err = pcall(function() lastHeaderOpts.onTool() end)
  if not ok then return nil, "Tool press raised: " .. tostring(err) end
  if #dialogs == before then return nil, "Tool press opened no dialog" end
  local d = dialogs[#dialogs]
  local okResult
  ok, err = pcall(function() okResult = d.buttons[1].action() end)
  if not ok then return nil, "OK press raised: " .. tostring(err) end
  return okResult, nil
end

local function runScenarios(label, expectedWrites, openFn)
  print(label .. ": read fails, the override is not written")
  local opened, why = openFn("fail")
  check("the page opens its editor", opened ~= false, why)
  check("Tool opens the override dialog", lastHeaderOpts ~= nil and lastHeaderOpts.onTool ~= nil)
  local result, err = pressToolAndConfirm()
  check("pressing Tool and OK raises no error", err == nil, err)
  check("no override is written while the read has not completed",
    countKind("override") == 0,
    "override messages sent: " .. countKind("override"))
  check("the dialog closes on OK", result == true, "action returned " .. tostring(result))
  check("a refused confirmation still hands the focus back", focusCalls == 1,
    "focusFn calls: " .. focusCalls)

  print(label .. ": read succeeds, the override is written as before")
  opened, why = openFn("ok")
  check("the page opens its editor", opened ~= false, why)
  result, err = pressToolAndConfirm()
  check("pressing Tool and OK raises no error", err == nil, err)
  check("the override is written once the read has completed",
    countKind("override") == expectedWrites,
    "override messages sent: " .. countKind("override"))
  check("the dialog closes on OK", result == true, "action returned " .. tostring(result))
  check("an accepted confirmation hands the focus back", focusCalls == 1,
    "focusFn calls: " .. focusCalls)
end

-- ---------------------------------------------------------------------------
-- Checks
-- ---------------------------------------------------------------------------

local function mixerOpener(page)
  return function(outcome) openMixerPage(page, outcome); return true end
end
local function servoOpener(page)
  return function(outcome) return openServoPage(page, outcome) end
end

runScenarios("mixer_trims", 4, mixerOpener(requireModule("app/pages/mixer_trims.lua")))
runScenarios("mixer_geometry", 4, mixerOpener(requireModule("app/pages/mixer_geometry.lua")))
runScenarios("servos_pwm", 1, servoOpener(requireModule("app/pages/servos_pwm.lua")))
runScenarios("servos_bus", 1, servoOpener(requireModule("app/pages/servos_bus.lua")))

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

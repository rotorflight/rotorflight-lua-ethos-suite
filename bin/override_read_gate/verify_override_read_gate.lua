-- Behaviour check for Issue #2496: an override must not be switched on before the
-- page has read its values.
--
-- Run it:
--     lua5.4 bin/override_read_gate/verify_override_read_gate.lua
--
-- What it drives, and why:
--   * The real app/pages/mixer_trims.lua and app/pages/mixer_geometry.lua, with the
--     real app/page_runtime.lua. The MSP modules, the header and the progress dialog
--     are stubs; every message the page publishes is recorded by the bus, and the
--     scenario answers each read the way the FC would.
--   * Two scenarios per page. In "read fails" the page's read errors out, so the
--     runtime is not loaded. In "read succeeds" the page is loaded. Pressing Tool and
--     confirming the override dialog must write the override only in the second.
--   * Against unpatched master the "read fails" scenario writes the override anyway:
--     four override messages, while the live write is held back. That is the defect.

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
form = anything()
form.clear = function() end
form.invalidate = function() end
form.openDialog = function(opts) dialogs[#dialogs + 1] = opts end

local lastHeaderOpts = nil
package.loaded["rfsuite.app.header"] = {
  build = function(_, opts) lastHeaderOpts = opts; return anything() end,
}
package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return true end}
package.loaded["rfsuite.app.progress_dialog"] = {
  SPEED = {DEFAULT = 1},
  open = function() return {value = function() end, close = function() end} end,
}
package.loaded["rfsuite.lib.memstats"] = {print = function() end}
package.loaded["rfsuite.lib.debug_log"] = anything()
package.loaded["rfsuite.lib.settings_store"] = {
  load = function() return {} end,
  saveConfirmEnabled = function() return false end,
  clone = function(t) return t end,
  save = function() return true end,
}

-- The mixer config read: the page's open read and the runtime's source read both go
-- through here. Messages are recorded once, by the bus subscriber below.
package.loaded["rfsuite.lib.msp_mixer_config"] = {
  buildReadMessage = function(onData, onError)
    return {kind = "mixerRead", onData = onData, onError = onError}
  end,
  buildWriteMessage = function(_, onWritten, onError)
    return {kind = "mixerWrite", processReply = function() if onWritten then onWritten() end end, errorHandler = onError}
  end,
}

package.loaded["rfsuite.lib.msp_mixer_override"] = {
  OVERRIDE_OFF = 2501,
  OVERRIDE_PASSTHROUGH = 2502,
  buildWriteMessage = function(index, value)
    return {kind = "override", index = index, value = value}
  end,
}

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

local FIXTURE = {
  tail_rotor_mode = 0,
  swash_trim_0 = 0, swash_trim_1 = 0, swash_trim_2 = 0,
  tail_center_trim = 0, tail_motor_idle = 0,
}

local function countKind(kind)
  local n = 0
  for _, m in ipairs(sent) do if m.kind == kind then n = n + 1 end end
  return n
end

-- Answers the open read first, then the runtime's source reads with the outcome,
-- then runs the UI ticks so the outcome takes effect, as on the radio.
local function openPage(page, outcome)
  sent = {}
  dialogs = {}
  lastHeaderOpts = nil
  local wakeup = nil
  page.open({
    onBack = function() end,
    setWakeupHandler = function(fn) wakeup = fn end,
  })
  -- Only the open read (the first read the page sends) gets the mode answer here.
  -- Some pages create their runtime at once, so the value reads must wait for the
  -- scenario below and must not be answered by this loop.
  for _, m in ipairs(sent) do
    if m.kind == "mixerRead" and not m.answered then
      m.answered = true
      m.onData({tail_rotor_mode = 0})
      break
    end
  end
  if wakeup then wakeup() end
  for _ = 1, 10 do
    local progressed = false
    for _, m in ipairs(sent) do
      if m.kind == "mixerRead" and not m.answered then
        m.answered = true
        progressed = true
        if outcome == "ok" then m.onData(FIXTURE)
        else m.onError("read timed out") end
      end
    end
    if not progressed then break end
  end
  for _ = 1, 5 do if wakeup then wakeup() end end
end

-- Presses Tool, then OK on the dialog it opens. Returns the dialog's OK result.
local function pressToolAndConfirm()
  local before = #dialogs
  local ok, err = pcall(function() lastHeaderOpts.onTool(function() end) end)
  if not ok then return nil, "Tool press raised: " .. tostring(err) end
  if #dialogs == before then return nil, "Tool press opened no dialog" end
  local d = dialogs[#dialogs]
  local okResult
  ok, err = pcall(function() okResult = d.buttons[1].action() end)
  if not ok then return nil, "OK press raised: " .. tostring(err) end
  return okResult, nil
end

-- ---------------------------------------------------------------------------
-- Checks
-- ---------------------------------------------------------------------------

for _, pageName in ipairs({"mixer_trims", "mixer_geometry"}) do
  local page = requireModule("app/pages/" .. pageName .. ".lua")

  print(pageName .. ": read fails, the override is not written")
  openPage(page, "fail")
  check("Tool opens the override dialog", lastHeaderOpts ~= nil and lastHeaderOpts.onTool ~= nil)
  do
    local result, why = pressToolAndConfirm()
    check("pressing Tool and OK raises no error", why == nil, why)
    check("no override is written while the read has not completed",
      countKind("override") == 0,
      "override messages sent: " .. countKind("override"))
    check("the dialog closes on OK", result == true, "action returned " .. tostring(result))
  end

  print(pageName .. ": read succeeds, the override is written as before")
  openPage(page, "ok")
  do
    local result, why = pressToolAndConfirm()
    check("pressing Tool and OK raises no error", why == nil, why)
    check("the override is written to all four axes once the read has completed",
      countKind("override") == 4,
      "override messages sent: " .. countKind("override"))
    check("the dialog closes on OK", result == true, "action returned " .. tostring(result))
  end
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

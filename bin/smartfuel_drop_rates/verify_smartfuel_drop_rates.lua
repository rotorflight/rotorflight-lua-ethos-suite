-- Behaviour check for issue #2659: on the SmartFuel page the voltage and charge drop rates
-- are editable with Source OFF, where the radio's own estimate uses them, and each mode
-- enables its own set of fields when the pilot switches between modes.
--
-- Run it:
--     lua5.4 bin/smartfuel_drop_rates/verify_smartfuel_drop_rates.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/pages/power_smartfuel.lua, the real app/page_runtime.lua, the
--     real app/field_layout.lua and the real lib/msp_smartfuel_config.lua. The read is
--     answered with the codec's own simulator reply. Header, dialogs, settings store and model
--     preferences are stubs. Each number field records what the page last passed to enable().
--   * The mode is changed through the page's own choice field and the page's wakeup handler is
--     run after each change, as Ethos does.
--   * Expected per mode (OFF 0, VOLTAGE 1, CURRENT 2, COMBINED 3):
--       drop rates   enabled in 0, 1, 3
--       sag gain     enabled in 1, 3
--   * Against unpatched master the drop rates are disabled with Source OFF. With the first
--     version of the fix, a switch between OFF and VOLTAGE or COMBINED left sag gain as it
--     was, because the page only refreshed when "drop rates enabled" changed.

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

-- A field that remembers the last enable() it was given; everything else is accepted.
local function recordingField()
  local f = {}
  return setmetatable(f, {
    __index = function(_, k)
      if k == "enable" then return function(self, v) rawset(self, "enabled", v) end end
      return function() return anything() end
    end,
  })
end

local fields = {}
local lastLabel = ""
form = anything()
form.clear = function() end
form.invalidate = function() end
form.addLine = function(label) lastLabel = tostring(label or ""); return anything() end
form.addChoiceField = function(_, _, choices, getter, setter)
  local f = recordingField()
  fields[#fields + 1] = {label = lastLabel, kind = "choice", get = getter, set = setter, field = f}
  return f
end
form.addNumberField = function(_, _, min, max, getter, setter)
  local f = recordingField()
  fields[#fields + 1] = {label = lastLabel, kind = "number", get = getter, set = setter, field = f}
  return f
end
form.openDialog = function() end
form.addStaticText = function() return anything() end

package.loaded["rfsuite.app.header"] = {build = function() return anything() end}
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
package.loaded["rfsuite.lib.model_preferences"] = {
  load = function() return {}, "prefs.ini" end,
  smartfuelModelType = function() return 0 end,
  setSmartfuelModelType = function(prefs) return prefs end,
  save = function() return true end,
}
package.loaded["rfsuite.app.settings_save"] = {reportFailure = function() end}

-- Every read the page publishes is answered with the codec's own simulator reply.
local sent = {}
local bus = requireModule("lib/bus.lua")
bus.subscribe("msp.request", function(m) sent[#sent + 1] = m end)

local page = requireModule("app/pages/power_smartfuel.lua")

local function findField(part, kind)
  for _, f in ipairs(fields) do
    if f.label:find(part, 1, true) and (kind == nil or f.kind == kind) then return f end
  end
  return nil
end

local wakeupHandler = nil
local function openAndLoad()
  page.open({
    onBack = function() end,
    setWakeupHandler = function(fn) wakeupHandler = fn end,
  })
  for _ = 1, 10 do
    local answered = false
    for _, m in ipairs(sent) do
      if not m.done and not m.isWrite and m.simulatorResponse and m.processReply then
        m.done = true; answered = true
        local reply = {}
        for i, b in ipairs(m.simulatorResponse) do reply[i] = b end
        m.processReply(nil, reply)
      end
    end
    if not answered then break end
  end
  if wakeupHandler then wakeupHandler() end
end

-- ---------------------------------------------------------------------------
-- Scenario
-- ---------------------------------------------------------------------------

openAndLoad()
local modeField = findField("@i18n(sensors.smartfuel)@", "choice")
local voltageDrop = findField("smartfuel_voltage_drop_rate", "number")
local chargeDrop = findField("smartfuel_charge_drop_rate", "number")
local sagGain = findField("smartfuel_sag_gain", "number")
check("the page offers the mode and the three tuning fields",
  modeField ~= nil and voltageDrop ~= nil and chargeDrop ~= nil and sagGain ~= nil)
if not (modeField and voltageDrop and chargeDrop and sagGain) then os.exit(1) end

local NAMES = {[0] = "OFF", [1] = "VOLTAGE", [2] = "CURRENT", [3] = "COMBINED"}
local function expectFor(mode, how)
  local drop = mode == 0 or mode == 1 or mode == 3
  local sag = mode == 1 or mode == 3
  local name = NAMES[mode] .. " (" .. how .. ")"
  check(name .. ": voltage drop rate " .. (drop and "enabled" or "disabled"),
    voltageDrop.field.enabled == drop, "enable(" .. tostring(voltageDrop.field.enabled) .. ")")
  check(name .. ": charge drop rate " .. (drop and "enabled" or "disabled"),
    chargeDrop.field.enabled == drop, "enable(" .. tostring(chargeDrop.field.enabled) .. ")")
  check(name .. ": sag gain " .. (sag and "enabled" or "disabled"),
    sagGain.field.enabled == sag, "enable(" .. tostring(sagGain.field.enabled) .. ")")
end

local function selectMode(mode)
  modeField.set(mode)
  if wakeupHandler then wakeupHandler() end
end

-- The mode as loaded, then every switch a pilot can make, each pair in both directions.
expectFor(modeField.get(), "as loaded")
for _, step in ipairs({0, 1, 0, 3, 0, 2, 0, 1, 3, 2, 1, 0, 2, 3, 0, 2, 1, 2, 3}) do
  selectMode(step)
  expectFor(step, "after a switch")
end

if failures > 0 then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
end
print(string.format("\n%d checks passed", checks))

-- Behaviour check for issue #2666: the consumption warning percentage can be set from 0, the
-- firmware's own minimum (cbat_alert_percent 0..100, rotorflight-firmware settings.c).
--
-- Run it:
--     lua5.4 bin/battery_consumption_warning_min/verify_battery_consumption_warning_min.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/pages/power_battery.lua, the real app/page_runtime.lua and the
--     real app/field_layout.lua, with the MSP modules, header and dialogs stubbed (the same
--     stubs as bin/battery_edit_profile). form.addNumberField records the range each field is
--     given, so the check reads the range the pilot can enter on the page.
--   * The field must offer 0 to 60, and entering 0 must store 0 in the page's data, which is
--     what the save writes.
--   * Against unpatched master the field starts at 15, so 0 cannot be entered.

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

local function deepcopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = deepcopy(x) end
  return out
end

-- ---------------------------------------------------------------------------
-- Stubs
-- ---------------------------------------------------------------------------

lcd = anything()
lcd.getWindowSize = function() return 800, 480 end
system = anything()

local fields = {}          -- every field the page adds, with the label of its line
local lastLabel = ""
local dialogs = {}
form = anything()
form.clear = function() end
form.invalidate = function() end
form.addLine = function(label) lastLabel = tostring(label or ""); return anything() end
form.addChoiceField = function(_, _, choices, getter, setter)
  fields[#fields + 1] = {label = lastLabel, kind = "choice", get = getter, set = setter}
  return anything()
end
form.addNumberField = function(_, _, min, max, getter, setter)
  local f = anything()
  fields[#fields + 1] = {label = lastLabel, kind = "number", min = min, max = max, get = getter, set = setter, field = f}
  return f
end
form.openDialog = function(opts) dialogs[#dialogs + 1] = opts end
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
  saveConfirmEnabled = function() return false end,   -- Save writes at once, no confirmation
  clone = function(t) return t end,
  save = function() return true end,
}

-- Every MSP message the page publishes, in order.
local sent = {}
local function message(kind, extra)
  local m = extra or {}
  m.kind = kind
  return m
end

-- The battery config: two profiles of cells, profile 0 active.
local fixtureBattery = {
  hasProfileCells = true,
  batteryCapacity_0 = 2200, batteryCapacity_1 = 3300, batteryCapacity_2 = 4000,
  batteryCapacity_3 = 5000, batteryCapacity_4 = 6000, batteryCapacity_5 = 0,
  batteryCellCount_0 = 6, batteryCellCount_1 = 4, batteryCellCount_2 = 6,
  batteryCellCount_3 = 6, batteryCellCount_4 = 6, batteryCellCount_5 = 6,
  vbatmincellvoltage_0 = 3.3, vbatmincellvoltage_1 = 3.3, vbatmincellvoltage_2 = 3.3,
  vbatmincellvoltage_3 = 3.3, vbatmincellvoltage_4 = 3.3, vbatmincellvoltage_5 = 3.3,
  vbatmaxcellvoltage_0 = 4.2, vbatmaxcellvoltage_1 = 4.2, vbatmaxcellvoltage_2 = 4.2,
  vbatmaxcellvoltage_3 = 4.2, vbatmaxcellvoltage_4 = 4.2, vbatmaxcellvoltage_5 = 4.2,
  vbatfullcellvoltage_0 = 4.1, vbatfullcellvoltage_1 = 4.1, vbatfullcellvoltage_2 = 4.1,
  vbatfullcellvoltage_3 = 4.1, vbatfullcellvoltage_4 = 4.1, vbatfullcellvoltage_5 = 4.1,
  vbatwarningcellvoltage_0 = 3.5, vbatwarningcellvoltage_1 = 3.5, vbatwarningcellvoltage_2 = 3.5,
  vbatwarningcellvoltage_3 = 3.5, vbatwarningcellvoltage_4 = 3.5, vbatwarningcellvoltage_5 = 3.5,
  consumptionWarningPercentage = 30,
}
local FIELD_META = {}
for _, base in ipairs({"batteryCellCount", "vbatmincellvoltage", "vbatmaxcellvoltage",
                       "vbatfullcellvoltage", "vbatwarningcellvoltage", "consumptionWarningPercentage"}) do
  FIELD_META[base] = {min = 0, max = 100, default = 0, decimals = 2, suffix = "V"}
end
package.loaded["rfsuite.lib.msp_battery_config"] = {
  FIELD_META = FIELD_META,
  buildReadMessage = function(onValues, onErr)
    return message("batteryRead", {processReply = function(v) if onValues then onValues(v) end end})
  end,
  buildWriteMessage = function(values, onOk, onErr)
    local m = message("batteryWrite", {values = deepcopy(values), processReply = function() if onOk then onOk() end end})
    sent[#sent + 1] = m
    return m, nil
  end,
}

local PROFILE_CHOICES = {{"1", 0}, {"2", 1}, {"3", 2}, {"4", 3}, {"5", 4}, {"6", 5}}
package.loaded["rfsuite.lib.msp_battery_profile"] = {
  PROFILE_CHOICES = PROFILE_CHOICES,
  buildReadMessage = function(onValues, onErr)
    return message("profileRead", {processReply = function(v) if onValues then onValues(v) end end})
  end,
  buildWriteMessage = function(values, onOk, onErr)
    local m = message("profileWrite", {values = deepcopy(values), processReply = function() if onOk then onOk() end end})
    sent[#sent + 1] = m
    return m, nil
  end,
}

package.loaded["rfsuite.lib.msp_eeprom"] = {
  buildWriteMessage = function(onOk, onErr)
    local m = message("eeprom", {processReply = function() if onOk then onOk() end end})
    sent[#sent + 1] = m
    return m
  end,
}
package.loaded["rfsuite.lib.msp_reboot"] = {
  buildWriteMessage = function(onOk)
    local m = message("reboot", {processReply = function() if onOk then onOk() end end})
    sent[#sent + 1] = m
    return m
  end,
}

local bus = requireModule("lib/bus.lua")
bus.subscribe("msp.request", function(m) sent[#sent + 1] = m end)

-- field_layout.buildSingle receives the runtime the page is built on: keep it.
local fieldLayout = requireModule("app/field_layout.lua")
local runtimeRef = nil
local realBuildSingle = fieldLayout.buildSingle
fieldLayout.buildSingle = function(runtime, ...)
  if not runtimeRef then runtimeRef = runtime end
  return realBuildSingle(runtime, ...)
end

local page = requireModule("app/pages/power_battery.lua")

-- ---------------------------------------------------------------------------
-- Scenario helpers
-- ---------------------------------------------------------------------------

local function findField(part, kind)
  for _, f in ipairs(fields) do
    if f.label:find(part, 1, true) and (kind == nil or f.kind == kind) then return f end
  end
  return nil
end

local function kindCount(kind)
  local n = 0
  for _, m in ipairs(sent) do if m.kind == kind then n = n + 1 end end
  return n
end

-- Answers every read the page publishes with the fixture, then runs the wakeup ticks.
local wakeupHandler = nil
local function openAndLoad()
  fields, sent, dialogs, runtimeRef, wakeupHandler = {}, {}, {}, nil, nil
  lastLabel = ""
  page.open({
    onBack = function() end,
    setWakeupHandler = function(fn) wakeupHandler = fn end,
  })
  for _ = 1, 10 do
    local answered = false
    for _, m in ipairs(sent) do
      if m.kind == "batteryRead" and not m.done then
        m.done = true; answered = true
        m.processReply(deepcopy(fixtureBattery))
      elseif m.kind == "profileRead" and not m.done then
        m.done = true; answered = true
        m.processReply({batteryProfile = 0})
      end
    end
    if not answered then break end
  end
  if wakeupHandler then wakeupHandler() end
end

-- The save through the page's own confirm path, with every write accepted.

-- ---------------------------------------------------------------------------
-- Scenario
-- ---------------------------------------------------------------------------

openAndLoad()
local f = findField("consumption_warning_percentage", "number")
check("the page offers a consumption warning field", f ~= nil)
if f then
  check("its minimum is 0", f.min == 0, "offered " .. tostring(f.min))
  check("its maximum is 60", f.max == 60, "offered " .. tostring(f.max))
  f.set(0)
  check("entering 0 reads back 0", f.get() == 0, "read " .. tostring(f.get()))
  local data = runtimeRef and runtimeRef.data
  local stored = data and (data.consumptionWarningPercentage
    or (data.battery and data.battery.consumptionWarningPercentage))
  check("entering 0 stores 0 for the save", stored == 0, "stored " .. tostring(stored))
end

if failures > 0 then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
end
print(string.format("\n%d checks passed", checks))

-- Behaviour check for #2502: editing the cells of a non-active battery profile does
-- not make that profile active when the page is saved.
--
-- Run it:
--     lua5.4 bin/battery_edit_profile/verify_battery_edit_profile.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/pages/power_battery.lua, the real app/page_runtime.lua
--     and the real app/field_layout.lua. The battery and profile MSP modules, the
--     header, the progress dialog and the EEPROM and reboot writes are stubs. Each
--     message the page publishes is recorded, and the scenario answers it as the FC
--     would.
--   * The Edit Battery choice must exist, change only the cell rows, and leave the
--     saved profile (MSP_BATTERY_PROFILE) on the active profile. The cell values must
--     be written under the edited profile's keys.
--   * Against unpatched master there is no Edit Battery choice, and editing a cell
--     of profile 3 writes profile 3 as the active one.

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
form.addNumberField = function(_, _, _, _, getter, setter)
  local f = anything()
  fields[#fields + 1] = {label = lastLabel, kind = "number", get = getter, set = setter, field = f}
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
local function save()
  if not runtimeRef or not runtimeRef.headerHandle then
    runtimeRef.confirmSave = runtimeRef.confirmSave
  end
  local start = #sent
  runtimeRef:confirmSave(function() end)
  for _ = 1, 20 do
    local progressed = false
    for i = start + 1, #sent do
      local m = sent[i]
      if not m.answered and m.processReply and (m.kind == "batteryWrite" or m.kind == "profileWrite"
          or m.kind == "eeprom" or m.kind == "reboot") then
        m.answered = true; progressed = true
        m.processReply()
      end
    end
    if not progressed then break end
  end
end

local function lastWrite(kind)
  for i = #sent, 1, -1 do
    if sent[i].kind == kind then return sent[i] end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- 1. The Edit Battery choice exists and starts on the active profile
-- ---------------------------------------------------------------------------

print("open")
openAndLoad()
local editField = findField("edit_battery", "choice")
check("the Edit Battery choice exists", editField ~= nil)
check("the Edit Battery choice starts on the active profile",
      editField and editField.get() == 0, "shown=" .. tostring(editField and editField.get()))

-- ---------------------------------------------------------------------------
-- 2. Editing profile 3's cells does not make profile 3 active on save
-- ---------------------------------------------------------------------------

print("edit another profile, then save")
openAndLoad()
editField = findField("edit_battery", "choice")
local maxField = findField("max_cell_voltage", "number")
check("the cell rows exist", maxField ~= nil)
-- The choice a pilot uses to pick the profile whose cells are edited: Edit Battery
-- where it exists. Unpatched, the only choice is the active profile, so the same
-- steps run through it and the bug shows.
local selector = editField or findField("power.selected", "choice")
if selector and maxField then
  selector.set(2)                           -- profile 3
  check("the cell row now shows profile 3's value", maxField.get() == 4.2,
        "shown=" .. tostring(maxField.get()))
  maxField.set(4.3)                         -- change profile 3's max cell voltage
  save()

  local profileWrite = lastWrite("profileWrite")
  check("the save writes the profile", profileWrite ~= nil)
  check("the saved profile stays on the active profile (0), not profile 3",
        profileWrite and profileWrite.values and profileWrite.values.batteryProfile == 0,
        "written=" .. tostring(profileWrite and profileWrite.values and profileWrite.values.batteryProfile))

  local batteryWrite = lastWrite("batteryWrite")
  check("the cell value lands under profile 3's key",
        batteryWrite and batteryWrite.values and batteryWrite.values.vbatmaxcellvoltage_2 == 4.3,
        "vbatmaxcellvoltage_2=" .. tostring(batteryWrite and batteryWrite.values and batteryWrite.values.vbatmaxcellvoltage_2))
  check("the active profile's cell value is untouched",
        batteryWrite and batteryWrite.values and batteryWrite.values.vbatmaxcellvoltage_0 == 4.2)
end

-- ---------------------------------------------------------------------------
-- 3. Without an edit, the cell rows follow the active profile as before
-- ---------------------------------------------------------------------------

print("no edit: cells follow the active profile")
openAndLoad()
maxField = findField("max_cell_voltage", "number")
if maxField then
  maxField.set(4.25)
  save()
  local profileWrite = lastWrite("profileWrite")
  check("without an edit the active profile is written unchanged",
        profileWrite and profileWrite.values and profileWrite.values.batteryProfile == 0)
  local batteryWrite = lastWrite("batteryWrite")
  check("without an edit the active profile's cell value is written",
        batteryWrite and batteryWrite.values and batteryWrite.values.vbatmaxcellvoltage_0 == 4.25)
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

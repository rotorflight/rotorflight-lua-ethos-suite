-- Behaviour check for #2545: a model-preference save that the store refuses is
-- reported, and the page keeps its dirty state (issue #2545).
--
-- Run it:
--     lua5.4 bin/model_prefs_save/verify_model_prefs_save.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/pages/power_alerts.lua, stats.lua and
--     power_smartfuel.lua, and the real app/page_runtime.lua, with the real bus
--     and the real app/settings_save.lua helper. The UI (form, header), the
--     model-preferences codec and the MSP-side modules are stubs.
--   * Each page is driven the way the pilot drives it: a session update selects
--     the model, a field setter makes the page dirty, the header's Save is pressed
--     and the confirm dialog is answered.
--   * Refused save: no model-preferences update is published, the page stays dirty
--     (the Save button stays lit) and the save-failed dialog opens. Accepted save:
--     the update is published once and no failure dialog opens.
--   * page_runtime: a beforeSave that returns false aborts performSave before any
--     write and before the busy state; a beforeSave that returns nothing does not.
--   * Against unpatched master the refused-save checks fail: the pages ignored
--     save()'s return value and published anyway.

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

local function noop() end

-- A stand-in for a runtime or header handle: any method is a no-op unless the
-- test sets it.
local function permissive(raw)
  return setmetatable(raw or {}, {__index = function() return noop end})
end

-- ---------------------------------------------------------------------------
-- Stubs: UI, header, model preferences and the MSP-side modules
-- ---------------------------------------------------------------------------

lcd = permissive()
system = permissive()
model = permissive()

local dialogs = {}
local fieldSetters = {}
local function lastFunction(...)
  local args = {...}
  for i = #args, 1, -1 do
    if type(args[i]) == "function" then return args[i] end
  end
  return nil
end

form = {
  clear = noop,
  invalidate = noop,
  openDialog = function(opts) dialogs[#dialogs + 1] = opts end,
  addLine = function(label) return {label = label} end,
  addNumberField = function(line, _, ...)
    fieldSetters[line.label] = lastFunction(...)
    return permissive()
  end,
  addChoiceField = function(line, _, ...)
    fieldSetters[line.label] = lastFunction(...)
    return permissive()
  end,
}

local headerOpts, headerHandle
local saveEnabledCalls = {}
local function newHeaderHandle()
  return permissive({
    setSaveEnabled = function(v) saveEnabledCalls[#saveEnabledCalls + 1] = v end,
    setReloadEnabled = noop,
  })
end
package.loaded["rfsuite.app.header"] = {
  build = function(_, opts)
    headerOpts = opts
    headerHandle = newHeaderHandle()
    return headerHandle
  end,
}
package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return false end}

-- The save switch: each scenario sets saveResult before pressing Save.
local prefsStore = {saveCalls = 0, saveResult = true}
local mp = {}
function mp.pathFor() return "model.ini" end
function mp.load() return {}, "model.ini" end
function mp.powerAlerts() return {flighttime = 300, alert_type = 0, becalertvalue = 6.5, rxalertvalue = 7.5} end
function mp.setPowerAlerts(prefs) return prefs end
function mp.stats() return {flightcount = 1, lastflighttime = 60, totalflighttime = 600} end
function mp.setStats(prefs) return prefs end
function mp.smartfuelModelType() return 0 end
function mp.setSmartfuelModelType(prefs) return prefs end
function mp.save()
  prefsStore.saveCalls = prefsStore.saveCalls + 1
  return prefsStore.saveResult
end
package.loaded["rfsuite.lib.model_preferences"] = mp

package.loaded["rfsuite.lib.settings_store"] = {
  load = function() return {} end,
  saveConfirmEnabled = function() return false end,
}
package.loaded["rfsuite.lib.memstats"] = {print = noop}
package.loaded["rfsuite.lib.debug_log"] = {print = noop, msp = noop, mspEnabled = function() return false end}
package.loaded["rfsuite.lib.msp_eeprom"] = permissive()
package.loaded["rfsuite.lib.msp_reboot"] = permissive()
package.loaded["rfsuite.app.progress_dialog"] = permissive()
package.loaded["rfsuite.app.field_layout"] = permissive()
package.loaded["rfsuite.lib.msp_smartfuel_config"] = {MODE_CHOICES = {}}

local bus = requireModule("lib/bus.lua")

-- Counts what each page publishes; the topics are the ones the pages use.
local published = {}
local function countTopic(topic)
  published[topic] = 0
  bus.subscribe(topic, function() published[topic] = published[topic] + 1 end)
end
countTopic("model.power_alerts.update")
countTopic("model.timer.update")
countTopic("model.stats.update")
countTopic("model.smartfuel_type.update")
countTopic("msp.request")

local function resetScenario(saveResult)
  dialogs, saveEnabledCalls, fieldSetters = {}, {}, {}
  headerOpts, headerHandle = nil, nil
  prefsStore.saveCalls, prefsStore.saveResult = 0, saveResult
  for k in pairs(published) do published[k] = 0 end
end

local function failureDialogOpened()
  for _, d in ipairs(dialogs) do
    if d.title == "@i18n(app.msg_save_failed_title)@"
      and d.message == "@i18n(app.msg_save_failed_local_body)@" then
      return true
    end
  end
  return false
end

-- The pilot presses Save and confirms the dialog.
local function pressSaveAndConfirm()
  headerOpts.onSave()
  local confirm = dialogs[#dialogs]
  if confirm and confirm.buttons and confirm.buttons[1] then
    confirm.buttons[1].action()
  end
end

-- ---------------------------------------------------------------------------
-- 1. power_alerts
-- ---------------------------------------------------------------------------

local ALERT_LABEL = "@i18n(app.modules.power.alert_type)@"

local function runAlerts(saveResult)
  resetScenario(saveResult)
  local page = requireModule("app/pages/power_alerts.lua")
  page.open({onBack = noop})
  bus.publish("session.update", {mcuId = "A1"})      -- select a model
  fieldSetters[ALERT_LABEL](1)                        -- a real edit: now dirty
  pressSaveAndConfirm()
end

print("power_alerts: refused save")
runAlerts(false)
check("the store was asked to save", prefsStore.saveCalls == 1, "saveCalls=" .. prefsStore.saveCalls)
check("a refused save publishes no power-alerts update",
  published["model.power_alerts.update"] == 0 and published["model.timer.update"] == 0,
  "power_alerts=" .. published["model.power_alerts.update"] .. " timer=" .. published["model.timer.update"])
check("a refused save keeps the Save button lit",
  saveEnabledCalls[#saveEnabledCalls] == true, tostring(saveEnabledCalls[#saveEnabledCalls]))
check("a refused save shows the save-failed dialog", failureDialogOpened())
headerOpts.onBack()

print("power_alerts: accepted save")
runAlerts(true)
check("an accepted save publishes the power-alerts update once",
  published["model.power_alerts.update"] == 1, "published=" .. published["model.power_alerts.update"])
check("an accepted save darkens the Save button",
  saveEnabledCalls[#saveEnabledCalls] == false, tostring(saveEnabledCalls[#saveEnabledCalls]))
check("an accepted save shows no failure dialog", not failureDialogOpened())
headerOpts.onBack()

-- ---------------------------------------------------------------------------
-- 2. stats
-- ---------------------------------------------------------------------------

local FLIGHTCOUNT_LABEL = "@i18n(app.modules.stats.flightcount)@"

local function runStats(saveResult)
  resetScenario(saveResult)
  local page = requireModule("app/pages/stats.lua")
  page.open({onBack = noop})
  bus.publish("session.update", {mcuId = "A1"})
  fieldSetters[FLIGHTCOUNT_LABEL](5)
  pressSaveAndConfirm()
end

print("stats: refused save")
runStats(false)
check("the store was asked to save", prefsStore.saveCalls == 1, "saveCalls=" .. prefsStore.saveCalls)
check("a refused save publishes no stats update", published["model.stats.update"] == 0,
  "published=" .. published["model.stats.update"])
check("a refused save keeps the Save button lit",
  saveEnabledCalls[#saveEnabledCalls] == true, tostring(saveEnabledCalls[#saveEnabledCalls]))
check("a refused save shows the save-failed dialog", failureDialogOpened())
headerOpts.onBack()

print("stats: accepted save")
runStats(true)
check("an accepted save publishes the stats update once",
  published["model.stats.update"] == 1, "published=" .. published["model.stats.update"])
check("an accepted save shows no failure dialog", not failureDialogOpened())
headerOpts.onBack()

-- ---------------------------------------------------------------------------
-- 3. power_smartfuel: the model-type save is part of the page's beforeSave
-- ---------------------------------------------------------------------------

-- The page hands its config to page_runtime; the test keeps it to call
-- beforeSave the way performSave does.
local capturedConfig = nil
package.loaded["rfsuite.app.page_runtime"] = {
  new = function(config)
    capturedConfig = config
    return permissive({data = {}, cleanData = {}, loaded = true, activeDialog = false, disposed = false})
  end,
}

local MODEL_TYPE_LABEL = "@i18n(app.modules.power.model_type)@"

print("power_smartfuel: refused model-type save")
resetScenario(false)
local smartfuel = requireModule("app/pages/power_smartfuel.lua")
smartfuel.open({})
bus.publish("session.update", {mcuId = "A1"})   -- select a model: model type loads
fieldSetters[MODEL_TYPE_LABEL](2)               -- pilot changes the model type
local returned = capturedConfig.beforeSave(permissive())
check("a refused model-type save aborts the save", returned == false, "returned=" .. tostring(returned))
check("a refused model-type save publishes no model-type update",
  published["model.smartfuel_type.update"] == 0, "published=" .. published["model.smartfuel_type.update"])
check("a refused model-type save shows the save-failed dialog", failureDialogOpened())
local retried = capturedConfig.beforeSave(permissive())
check("the next save tries the model type again, because it was not stored",
  prefsStore.saveCalls == 2, "saveCalls=" .. prefsStore.saveCalls)

print("power_smartfuel: accepted model-type save")
resetScenario(true)
smartfuel.open({})
bus.publish("session.update", {mcuId = "A1"})
fieldSetters[MODEL_TYPE_LABEL](2)
local accepted = capturedConfig.beforeSave(permissive())
check("an accepted model-type save does not abort", accepted ~= false, "returned=" .. tostring(accepted))
check("an accepted model-type save publishes the model-type update once",
  published["model.smartfuel_type.update"] == 1, "published=" .. published["model.smartfuel_type.update"])

-- ---------------------------------------------------------------------------
-- 4. page_runtime: performSave honours a beforeSave that returns false
-- ---------------------------------------------------------------------------

-- The real page_runtime, unstubbed. Only the header is a stand-in above.
package.loaded["rfsuite.app.page_runtime"] = nil
local pageRuntime = requireModule("app/page_runtime.lua")

print("page_runtime: performSave")
do
  resetScenario(true)
  local calls = 0
  local rt = pageRuntime.new({
    pageTitle = "Test",
    logTag = "test",
    opts = {},
    mspModule = permissive(),
    beforeSave = function() calls = calls + 1; return false end,
  })
  rt.loaded = true
  rt:markDirty()
  -- Against unpatched master the save goes on past beforeSave and into the
  -- placeholder dialog code, which errors; pcall reports that as a failed check.
  local ok, err = pcall(rt.performSave, rt, nil)
  check("a beforeSave that returns false is called once", calls == 1, "calls=" .. calls)
  check("a beforeSave that returns false does not reach the save dialog", ok,
    tostring(err))
  check("a beforeSave that returns false writes nothing", published["msp.request"] == 0,
    "msp.request=" .. published["msp.request"])
  check("a beforeSave that returns false leaves the page busy-free and dirty",
    not rt.busy and rt.dirty == true, "busy=" .. tostring(rt.busy) .. " dirty=" .. tostring(rt.dirty))
end

do
  resetScenario(true)
  local calls = 0
  local rt = pageRuntime.new({
    pageTitle = "Test",
    logTag = "test",
    opts = {},
    mspModule = permissive(),
    beforeSave = function() calls = calls + 1 end,
  })
  rt.loaded = true
  rt:markDirty()
  -- Past beforeSave the save goes on to its writes, which the placeholder module
  -- cannot answer; only the state reached before that is under test.
  pcall(rt.performSave, rt, nil)
  check("a beforeSave that returns nothing is called and lets the save proceed",
    calls == 1 and rt.busy == true, "calls=" .. calls .. " busy=" .. tostring(rt.busy))
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

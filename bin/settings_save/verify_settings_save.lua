-- Behaviour check for #2500: a local settings page reports a refused save and
-- keeps its dirty state (issue #2500).
--
-- Run it:
--     lua5.4 bin/settings_save/verify_settings_save.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/pages/settings_general.lua, with the real bus and the
--     real app/settings_save.lua helper. The store and the header are stubs: the
--     store's save() returns the value the scenario asks for, and the header's
--     onSave is pressed the way the pilot presses Save.
--   * Refused save: no settings.update is published, the Save button stays lit, and
--     a dialog with the save-failed text opens. Accepted save: the page publishes
--     once, the button goes dark, and no failure dialog opens.
--   * Before the fix the page ignored save()'s return value, so the refused case
--     published, cleared the button and showed nothing. Against unpatched master
--     the refused-save checks fail.

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

-- A permissive stub: any field or call yields another permissive stub.
local function anything()
  local t = {}
  return setmetatable(t, {
    __index = function() return function() return anything() end end,
    __call = function() return anything() end,
  })
end

-- ---------------------------------------------------------------------------
-- Stubs for the parts of the UI and the store the page touches
-- ---------------------------------------------------------------------------

lcd = anything()
system = anything()
model = anything()

local dialogs = {}
local developerSetter = nil
form = anything()
form.clear = function() end
form.openDialog = function(opts) dialogs[#dialogs + 1] = opts end
form.addBooleanField = function(_, _, getter, setter)
  if developerSetter == nil then developerSetter = setter end
  return anything()
end

local headerOpts = nil
local saveEnabledCalls = {}
local headerHandle = anything()
headerHandle.setSaveEnabled = function(v) saveEnabledCalls[#saveEnabledCalls + 1] = v end
package.loaded["rfsuite.app.header"] = {build = function(_, opts) headerOpts = opts; return headerHandle end}
package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return true end}

local function deepcopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = deepcopy(x) end
  return out
end

local store = {saveCalls = 0, saveResult = true}
store.load = function() return {developer = {developer_mode = false}} end
store.clone = deepcopy
local function deepsame(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do if not deepsame(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
store.same = deepsame
store.save = function() store.saveCalls = store.saveCalls + 1; return store.saveResult end
package.loaded["rfsuite.lib.settings_store"] = store

local bus = requireModule("lib/bus.lua")
local published = 0
bus.subscribe("settings.update", function() published = published + 1 end)

local page = requireModule("app/pages/settings_general.lua")

-- ---------------------------------------------------------------------------
-- Scenario: dirty the page, press Save, confirm
-- ---------------------------------------------------------------------------

local function runSave(saveResult)
  dialogs, saveEnabledCalls, published, store.saveCalls = {}, {}, 0, 0
  store.saveResult = saveResult
  headerOpts, developerSetter = nil, nil
  page.open({onBack = function() end})
  developerSetter(true)                 -- a real edit: the page is now dirty
  headerOpts.onSave()                   -- the pilot presses Save
  local confirm = dialogs[#dialogs]
  if confirm and confirm.buttons and confirm.buttons[1] then
    confirm.buttons[1].action()         -- and confirms
  end
end

local function failureDialogOpened()
  for _, d in ipairs(dialogs) do
    if d.title == "@i18n(app.msg_save_failed_title)@" and d.message == "@i18n(app.msg_save_failed_local_body)@" then
      return true
    end
  end
  return false
end

print("refused save")
runSave(false)
check("the store was asked to save", store.saveCalls == 1, "saveCalls=" .. store.saveCalls)
check("a refused save publishes nothing", published == 0, "published=" .. published)
check("a refused save keeps the Save button lit",
      saveEnabledCalls[#saveEnabledCalls] == true, tostring(saveEnabledCalls[#saveEnabledCalls]))
check("a refused save shows the save-failed dialog", failureDialogOpened())

print("accepted save")
runSave(true)
check("an accepted save publishes once", published == 1, "published=" .. published)
check("an accepted save darkens the Save button",
      saveEnabledCalls[#saveEnabledCalls] == false, tostring(saveEnabledCalls[#saveEnabledCalls]))
check("an accepted save shows no failure dialog", not failureDialogOpened())

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

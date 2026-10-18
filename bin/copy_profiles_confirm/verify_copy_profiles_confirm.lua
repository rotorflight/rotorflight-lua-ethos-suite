-- Behaviour check for the Copy Profiles confirmation (issue #2349): the dialog names the profile
-- type, the source profile and the destination that will be overwritten.
--
-- Run it:
--     lua5.4 bin/copy_profiles_confirm/verify_copy_profiles_confirm.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/pages/copy_profiles.lua, with the real bus. The header, the form, the
--     progress dialog and the MSP modules are stand-ins.
--   * The three choices are set the way the pilot sets them (profile type, source, destination), then
--     Save is pressed. The dialog that opens is checked for its title and its text.
--   * The i18n markers are resolved here from bin/i18n/json/en.json, the way the build does for a
--     string the page formats with string.format(), so the text is the one the pilot reads.
--
-- Against unpatched master the dialog says "Save settings?" and names no profile, so the text checks fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
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
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local function noop() end
local function anyStub()
  return setmetatable({}, {__index = function() return function() return anyStub() end end,
    __call = function() return anyStub() end})
end

-- The English strings, read from the locale source the build uses.
local function readEnglish()
  local f = assert(io.open(ROOT .. "/bin/i18n/json/en.json", "rb"))
  local text = f:read("a")
  f:close()
  local json = {}
  -- Walk the document for "english" values under the copyprofiles block. A flat lookup by the
  -- key's own name is enough for the strings this check needs.
  for key, value in text:gmatch('"([%w_]+)": {\r?\n%s*"english": "([^"]*)"') do
    json[key] = value
  end
  return json
end
local EN = readEnglish()

local function resolve(text)
  return (text:gsub("@i18n%(([%w%._]+)%)@", function(key)
    local name = key:match("([%w_]+)$")
    return EN[name] or ("@i18n(" .. key .. ")@")
  end))
end

-- The build resolves a marker in the source. A string the page formats has the marker as its
-- template, so the format is applied to the resolved text.
local realFormat = string.format
string.format = function(fmt, ...)
  local args = {...}
  for i = 1, select("#", ...) do
    if type(args[i]) == "string" then args[i] = resolve(args[i]) end
  end
  return realFormat(resolve(fmt), table.unpack(args, 1, select("#", ...)))
end

lcd = anyStub()
system = anyStub()
model = anyStub()
TEXT_LEFT = nil

local dialogs, choiceSetters = {}, {}
form = {
  clear = noop,
  invalidate = noop,
  openDialog = function(opts) dialogs[#dialogs + 1] = opts end,
  addLine = function(label) return {label = label} end,
  addChoiceField = function(_, _, _, getter, setter)
    choiceSetters[#choiceSetters + 1] = setter
    return {enable = noop}
  end,
  addNumberField = function() return {enable = noop} end,
}

local headerOpts
package.loaded["rfsuite.app.header"] = {build = function(_, opts)
  headerOpts = opts
  return {setSaveEnabled = noop, setReloadEnabled = noop, focusSave = noop, focusReload = noop}
end}
package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return false end}
package.loaded["rfsuite.app.progress_dialog"] = {open = function() return {close = noop, value = noop} end, SPEED = {}}
package.loaded["rfsuite.lib.msp_copy_profile"] = {buildWriteMessage = function() return {} end}
package.loaded["rfsuite.lib.msp_eeprom"] = {buildWriteMessage = function() return {} end}

local bus = requireModule("lib/bus.lua")
local page = requireModule("app/pages/copy_profiles.lua")

local function confirmAfter(profileType, source, dest)
  dialogs, choiceSetters = {}, {}
  headerOpts = nil
  page.open({onBack = noop})
  local typeSet, sourceSet, destSet = choiceSetters[1], choiceSetters[2], choiceSetters[3]
  -- Values are the choice values: type 0 = PID, 1 = Rate; profiles 0-based.
  typeSet(profileType)
  sourceSet(source)
  destSet(dest)
  headerOpts.onSave()
  return dialogs[#dialogs]
end

-- ---------------------------------------------------------------------------
-- 1. A rate copy from profile 3 onto profile 1
-- ---------------------------------------------------------------------------

print("confirmation text")
local dialog = confirmAfter(1, 2, 0)
check("a dialog opens for the copy", dialog ~= nil)
if dialog then
  check("the title says a profile is copied", resolve(dialog.title) == "Copy profile?",
    "title=" .. tostring(resolve(dialog.title)))
  local expected = "Copy Rate Profile 3 to Profile 1? This permanently overwrites Profile 1 in the flight controller."
  check("the text names the type, the source and the destination it overwrites",
    dialog.message == expected, "message=" .. tostring(dialog.message))
end

print("PID copy")
local pidDialog = confirmAfter(0, 0, 4)
check("a PID copy names the PID profile, source 1 and destination 5",
  pidDialog and pidDialog.message == "Copy PID Profile 1 to Profile 5? This permanently overwrites Profile 5 in the flight controller.",
  pidDialog and pidDialog.message or "no dialog")

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

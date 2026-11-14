-- lua5.4 bin/startup_glasses/verify_glasses_settings_page.lua
-- Drives the real ActiveLook settings page (app/pages/settings_activelook_settings.lua)
-- with form and system replaced by recorders. The page's real helpers run: the
-- version gate (lib/ethos_version.lua), the preference schema (lib/activelook_config.lua),
-- the restart reminder, the one-time setup hint, the display-field gating and the
-- dialog cleanup. Only the page common wrapper (load, save, header) is replaced.
local source = debug.getinfo(1, "S").source:sub(2)
local root = (source:match("^(.*)[/\\][^/\\]+$") or ".") .. "/../../src/rfsuite/"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print("  ok    " .. label)
  else
    failures = failures + 1
    print("  FAIL  " .. label)
    if detail then print("        " .. tostring(detail)) end
  end
end

local MENU_LABEL = "@i18n(app.modules.settings.activelook_glasses_menu)@"
local DISPLAY_LABEL = "@i18n(app.modules.settings.feature_activelook)@"
local RESTART_TEXT = "@i18n(app.modules.settings.activelook_restart_radio)@"
local SETUP_TEXT = "@i18n(app.modules.settings.activelook_setup_hint)@"

-- ---------------------------------------------------------------------------
-- Recorders for the Ethos form and system APIs
-- ---------------------------------------------------------------------------

local fields, dialogs, version, registerAvailable
local currentLine

local function resetRecorders()
  fields, dialogs = {}, {}
end

form = {
  addLine = function(label)
    currentLine = {label = label}
    return currentLine
  end,
  addBooleanField = function(line, _, get, set)
    local field = {kind = "bool", label = line.label, get = get, set = set, enabled = true, enableCalls = 0}
    function field:enable(v) self.enabled = v == true; self.enableCalls = self.enableCalls + 1 end
    fields[#fields + 1] = field
    return field
  end,
  addSwitchField = function(line, _, get, set)
    local field = {kind = "switch", label = line.label, get = get, set = set}
    fields[#fields + 1] = field
    return field
  end,
  addNumberField = function(line, _, _, _, get, set)
    local field = {kind = "number", label = line.label, get = get, set = set}
    function field:suffix() end
    fields[#fields + 1] = field
    return field
  end,
  openDialog = function(args)
    local dialog = {args = args, closed = false}
    function dialog:close() self.closed = true end
    dialogs[#dialogs + 1] = dialog
    return dialog
  end,
}

system = {
  getVersion = function()
    return {major = version[1], minor = version[2], revision = version[3]}
  end,
  getSource = function() return nil end,
}

local function setVersion(v, registration)
  version = v
  if registration then
    system.registerGlasses = function() end
  else
    system.registerGlasses = nil
  end
end

-- ---------------------------------------------------------------------------
-- The page is loaded with the real helpers. The common wrapper is replaced by
-- one that builds the page the way the suite does and keeps its cleanup.
-- ---------------------------------------------------------------------------

local settings, cleanup
local function fakeCommon()
  return {
    openPage = function(_title, _opts, build)
      settings = {activelook = settings and settings.activelook or {}}
      cleanup = build(settings, function() end)
    end,
  }
end

local cache = {}
local function requireModule(path)
  if path == "app/pages/settings_activelook_common.lua" then return fakeCommon() end
  if cache[path] == nil then
    cache[path] = assert(loadfile(root .. path))()
  end
  return cache[path]
end
package.loaded["rfsuite.lib.require"] = requireModule

local page = assert(loadfile(root .. "app/pages/settings_activelook_settings.lua"))()

local function openPage(values)
  settings = {activelook = values or {}}
  resetRecorders()
  cleanup = nil
  page.open({})
end

local function field(label)
  for _, f in ipairs(fields) do
    if f.label == label then return f end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Version gate: the menu switch shows only on 26.2.0 or newer with the API
-- ---------------------------------------------------------------------------

print("version gate")
local GATE = {
  {{1, 6, 5}, true, false},
  {{26, 1, 99}, true, false},
  {{26, 2, 0}, true, true},
  {{26, 2, 1}, true, true},
  {{27, 0, 0}, true, true},
  {{26, 2, 0}, false, false},
  {{27, 0, 0}, false, false},
}
for _, case in ipairs(GATE) do
  local v, api, expected = case[1], case[2], case[3]
  setVersion(v, api)
  openPage({})
  local shown = field(MENU_LABEL) ~= nil
  check(string.format("%d.%d.%d, API %s: menu switch %s",
    v[1], v[2], v[3], api and "present" or "absent", expected and "shown" or "hidden"),
    shown == expected, "shown=" .. tostring(shown))
end

-- Without the menu the display field keeps its saved behaviour: no enable call.
setVersion({26, 1, 99}, true)
openPage({enabled = false})
local display = field(DISPLAY_LABEL)
check("older firmware: display field is not gated (never enabled/disabled)",
  display ~= nil and display.enableCalls == 0)

-- ---------------------------------------------------------------------------
-- Menu switch: restart reminder, and the display field follows it
-- ---------------------------------------------------------------------------

print("menu switch")
setVersion({26, 2, 0}, true)
openPage({register_glasses = false, enabled = false})
display = field(DISPLAY_LABEL)
check("menu off: display field is disabled", display ~= nil and display.enabled == false)

local menu = field(MENU_LABEL)
menu.set(true)
check("menu on: the preference is set", settings.activelook.register_glasses == true)
check("menu on: the display field is enabled", display.enabled == true)
check("menu on: a restart reminder is shown", #dialogs == 1 and dialogs[1].args.message == RESTART_TEXT,
  #dialogs > 0 and tostring(dialogs[#dialogs].args.message) or "no dialog")

menu.set(true)
check("setting the same value again opens no new reminder", #dialogs == 1)

-- Turning the menu off keeps the saved display value and disables the field again
settings.activelook.enabled = true
display.set(true)
menu.set(false)
check("menu off again: the display value is kept", settings.activelook.enabled == true)
check("menu off again: the display field is disabled", display.enabled == false)

-- ---------------------------------------------------------------------------
-- Display field: gated by the menu switch, one-time setup hint on off -> on
-- ---------------------------------------------------------------------------

print("display field")
setVersion({26, 2, 0}, true)
openPage({register_glasses = false, enabled = false})
display = field(DISPLAY_LABEL)
display.set(true)
check("menu off: turning the display on is refused", settings.activelook.enabled == false)
check("menu off: no setup hint for a refused change", #dialogs == 0)

openPage({register_glasses = true, enabled = false})
display = field(DISPLAY_LABEL)
display.set(true)
check("menu on: the display field turns on", settings.activelook.enabled == true)
check("off -> on: the one-time setup hint is shown",
  #dialogs == 1 and dialogs[1].args.message == SETUP_TEXT,
  #dialogs > 0 and tostring(dialogs[#dialogs].args.message) or "no dialog")

display.set(true)
check("already on: no new setup hint", #dialogs == 1)

openPage({register_glasses = true, enabled = true})
display = field(DISPLAY_LABEL)
display.set(false)
display.set(true)
check("off -> on again after a switch off: the hint shows again", #dialogs == 1 and dialogs[1].args.message == SETUP_TEXT)

-- Older firmware: no gate, the setup hint still follows the off -> on change
setVersion({26, 1, 99}, true)
openPage({enabled = false})
display = field(DISPLAY_LABEL)
display.set(true)
check("older firmware: the display turns on without the menu switch", settings.activelook.enabled == true)

-- ---------------------------------------------------------------------------
-- Dialog cleanup: leaving the page closes a pending hint
-- ---------------------------------------------------------------------------

print("cleanup")
setVersion({26, 2, 0}, true)
openPage({register_glasses = true, enabled = false})
display = field(DISPLAY_LABEL)
display.set(true)
local hint = dialogs[#dialogs]
check("a hint is open before leaving the page", hint ~= nil and hint.closed == false)
check("the page returns a cleanup callback", type(cleanup) == "function")
if cleanup then cleanup() end
check("leaving the page closes the pending hint", hint.closed == true)

-- A new hint replaces the one still open
openPage({register_glasses = true, enabled = false})
display = field(DISPLAY_LABEL)
display.set(true)
local first = dialogs[#dialogs]
field(MENU_LABEL)  -- present
menu = field(MENU_LABEL)
menu.set(false)
check("a restart reminder replaces an open setup hint", first.closed == true)

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

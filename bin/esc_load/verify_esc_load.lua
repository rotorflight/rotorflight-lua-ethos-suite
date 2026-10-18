-- Behaviour check for the ESC current limit and the dashboard's ESC load (issue #2355).
--
-- Run it:
--     lua5.4 bin/esc_load/verify_esc_load.lua
--
-- What it drives, and why:
--   * lib/esc_current_limit.lua and lib/model_preferences.lua, real. A limit is whole amps,
--     zero means "not set", and a figure is stored per model.
--   * The three manufacturer pages, real. Each hands its family's limit to its onLoaded in the
--     family's own unit (AM32 in amps; Scorpion and YGE in hundredths of an amp), so the figure
--     reaching the bus is in amps. The vendor page and the four-way page are stand-ins that only
--     capture the config the page builds.
--   * The Power > Preferences page, real. Offline its field is disabled; online it shows the stored
--     figure, and Save publishes it (0 clears it). A snapshot does not overwrite a pending edit.
--   * tasks/session.lua, real, through a copy that exports its session table (the only change is
--     that export; the code under test is the file as it is). A changed figure is written once, an
--     unchanged one writes nothing, another model's figure is ignored, and the snapshot carries
--     the figure.
--   * widgets/dashboard/context.lua, real. esc_load is the current as a percentage of the limit,
--     and nil (drawn as `--`) where no limit is on file, the link is down, or there is no reading.
--
-- Against unpatched master there is no esc_current_limit module, no esc_load source and no
-- Preferences page, so the checks fail at their first step.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"
local TASKS = SUITE .. "/tasks"

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

-- Anything that is not under test: every field is a function returning another stand-in.
local function anyStub()
  return setmetatable({}, {__index = function() return function() return anyStub() end end,
    __call = function() return anyStub() end})
end

-- Modules the pages and the session use that are replaced by stand-ins. Everything else is
-- loaded for real, once, through requireModule's cache.
local STUBS = {}

local function requireModule(name)
  if STUBS[name] ~= nil then return STUBS[name] end
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

-- The radio's globals the modules touch at load time.
lcd = anyStub()
system = anyStub()
model = anyStub()

local bus = requireModule("lib/bus.lua")
local escCurrentLimit = requireModule("lib/esc_current_limit.lua")
local modelPreferences = requireModule("lib/model_preferences.lua")

-- Every write the model preferences would make goes to this list instead of the card.
local writes = {}
do
  -- What the card holds: the last table written to each path, handed back on the next load,
  -- the way the real file would be read again after a reconnect.
  local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepcopy(x) end
    return out
  end
  local card = {}
  local ini = requireModule("lib/ini.lua")
  ini.load_ini_file = function(path)
    if card[path] == nil then return nil end
    return deepcopy(card[path])
  end
  ini.save_ini_file = function(path, tbl)
    card[path] = deepcopy(tbl)
    writes[#writes + 1] = {path = path, battery = tbl.battery}
    return true
  end
end

local function lastEvent(list)
  return list[#list]
end

-- Records every model.esc_current_limit.update the bus carries.
local limitEvents = {}
bus.subscribe("model.esc_current_limit.update", function(payload)
  limitEvents[#limitEvents + 1] = payload
end)

-- ---------------------------------------------------------------------------
-- 1. Whole amps, and "not set" as zero
-- ---------------------------------------------------------------------------

print("esc_current_limit: normalisation")
check("nil is not a limit", escCurrentLimit.normalize(nil) == nil)
check("zero is not a limit (it is how every family spells not set)", escCurrentLimit.normalize(0) == nil)
check("a negative figure is not a limit", escCurrentLimit.normalize(-3) == nil)
check("text that is not a number is not a limit", escCurrentLimit.normalize("abc") == nil)
check("12.4 A rounds to 12", escCurrentLimit.normalize(12.4) == 12)
check("12.6 A rounds to 13", escCurrentLimit.normalize(12.6) == 13)
check("a figure given as text is read", escCurrentLimit.normalize("47") == 47)

print("esc_current_limit: remember")
bus.publish("session.update", {})
limitEvents = {}
check("no flight controller connected: nothing is remembered",
  escCurrentLimit.remember(40) == false and #limitEvents == 0)

bus.publish("session.update", {mcuId = "M1"})
check("a new limit is handed to the session for this flight controller",
  escCurrentLimit.remember(40) == true
    and #limitEvents == 1 and limitEvents[1].mcuId == "M1" and limitEvents[1].amps == 40,
  "events=" .. #limitEvents)

bus.publish("session.update", {mcuId = "M1", escCurrentLimit = 40})
limitEvents = {}
check("the limit already on file is not sent again",
  escCurrentLimit.remember(40) == true and #limitEvents == 0)
check("a changed limit is sent", escCurrentLimit.remember(41) == true
  and #limitEvents == 1 and limitEvents[1].amps == 41)

limitEvents = {}
check("zero is never sent as a limit", escCurrentLimit.remember(0) == false and #limitEvents == 0)

-- ---------------------------------------------------------------------------
-- 2. Model preferences keep the figure per model, zero as not set
-- ---------------------------------------------------------------------------

print("model_preferences: the stored figure")
check("no figure stored: none is reported", modelPreferences.escCurrentLimit({}) == nil)
check("a stored figure reads back in whole amps",
  modelPreferences.escCurrentLimit(modelPreferences.setEscCurrentLimit({}, 90)) == 90)
check("storing zero clears the figure back to not set",
  modelPreferences.escCurrentLimit(modelPreferences.setEscCurrentLimit({}, 0)) == nil)
check("storing nil clears the figure back to not set",
  modelPreferences.escCurrentLimit(modelPreferences.setEscCurrentLimit({}, nil)) == nil)
check("a figure above the range is held to 1000 A",
  modelPreferences.escCurrentLimit(modelPreferences.setEscCurrentLimit({}, 5000)) == 1000)

-- ---------------------------------------------------------------------------
-- 3. The manufacturer pages hand their own unit over, in amps
-- ---------------------------------------------------------------------------

local vendorConfig = nil
local fourWayConfig = nil
STUBS["app/pages/esc_forward_vendor.lua"] = {open = function(_, config) vendorConfig = config end}
STUBS["app/pages/esc_forward_4way.lua"] = {open = function(_, config) fourWayConfig = config end}
STUBS["lib/msp_esc_parameters_scorpion.lua"] = anyStub()
STUBS["lib/msp_esc_parameters_yge.lua"] = anyStub()
STUBS["lib/msp_esc_parameters_am32.lua"] = anyStub()

print("manufacturer pages: the limit in amps")

bus.publish("session.update", {mcuId = "M1"})
limitEvents = {}
requireModule("app/pages/esc_forward_scorpion.lua").open({})
vendorConfig.onLoaded({data = {max_current = 12000}})
check("Scorpion: max_current 12000 (hundredths of an amp) is 120 A",
  #limitEvents == 1 and limitEvents[1].amps == 120,
  "events=" .. #limitEvents .. " amps=" .. tostring(limitEvents[1] and limitEvents[1].amps))
limitEvents = {}
vendorConfig.onLoaded({data = {max_current = 0}})
check("Scorpion: a zero max_current is not a limit", #limitEvents == 0)

bus.publish("session.update", {mcuId = "M1"})
limitEvents = {}
requireModule("app/pages/esc_forward_yge.lua").open({})
vendorConfig.onLoaded({data = {current_limit = 4500}})
check("YGE: current_limit 4500 (hundredths of an amp) is 45 A",
  #limitEvents == 1 and limitEvents[1].amps == 45,
  "events=" .. #limitEvents .. " amps=" .. tostring(limitEvents[1] and limitEvents[1].amps))

bus.publish("session.update", {mcuId = "M1"})
limitEvents = {}
requireModule("app/pages/esc_forward_am32.lua").open({})
fourWayConfig.openEditor({}, {label = "Set 1"})
vendorConfig.onLoaded({loaded = true, data = {current_limit = 60}})
check("AM32: current_limit 60 is already amps",
  #limitEvents == 1 and limitEvents[1].amps == 60,
  "events=" .. #limitEvents .. " amps=" .. tostring(limitEvents[1] and limitEvents[1].amps))

bus.publish("session.update", {mcuId = "M1", escCurrentLimit = 60})
limitEvents = {}
vendorConfig.onLoaded({loaded = true, data = {current_limit = 60}})
check("a page visit that finds the limit already on file sends nothing", #limitEvents == 0)

-- ---------------------------------------------------------------------------
-- 4. Power > Preferences
-- ---------------------------------------------------------------------------

local headerOpts, headerHandle, saveLit, dialogs
local fieldGetter, fieldSetter, fieldEnabled

STUBS["app/close_key.lua"] = {shouldHandleClose = function() return false end}
STUBS["app/header.lua"] = {build = function(_, opts)
  headerOpts = opts
  headerHandle = {
    setSaveEnabled = function(v) saveLit = v end,
    setReloadEnabled = noop,
    focusSave = noop,
  }
  return headerHandle
end}

local function openPreferences()
  dialogs, saveLit = {}, nil
  fieldGetter, fieldSetter, fieldEnabled = nil, nil, nil
  local form = {
    clear = noop,
    invalidate = noop,
    openDialog = function(opts) dialogs[#dialogs + 1] = opts end,
    addLine = function(label) return {label = label} end,
    addNumberField = function(_, _, _, _, getter, setter)
      fieldGetter, fieldSetter = getter, setter
      return {enable = function(_, v) fieldEnabled = v end, suffix = noop}
    end,
  }
  _G.form = form
  local page = requireModule("app/pages/power_preferences.lua")
  page.open({onBack = noop})
end

local function pressSaveAndConfirm()
  headerOpts.onSave()
  local confirm = dialogs[#dialogs]
  if confirm and confirm.buttons and confirm.buttons[1] then confirm.buttons[1].action() end
end

print("power_preferences: the page")
bus.publish("session.update", {mcuId = nil})
openPreferences()
check("offline (no model) the field is disabled", fieldEnabled == false, tostring(fieldEnabled))
bus.publish("session.update", {mcuId = "M1", escCurrentLimit = 40})
check("online it shows the stored figure", fieldGetter() == 40, "shown=" .. tostring(fieldGetter()))
check("online the field is enabled", fieldEnabled == true)

limitEvents = {}
check("an untouched page: Save is dark", saveLit == false)
fieldSetter(55)
check("an edit lights Save", saveLit == true)
pressSaveAndConfirm()
check("Save publishes the new figure for this model",
  #limitEvents == 1 and limitEvents[1].mcuId == "M1" and limitEvents[1].amps == 55,
  "events=" .. #limitEvents)
check("after Save the page is clean again", saveLit == false)

limitEvents = {}
fieldSetter(0)
pressSaveAndConfirm()
check("Save with 0 clears the figure (amps = nil)",
  #limitEvents == 1 and limitEvents[1].amps == nil, "events=" .. #limitEvents)

fieldSetter(70)
bus.publish("session.update", {mcuId = "M1", escCurrentLimit = 20})
check("a snapshot does not overwrite a pending edit", fieldGetter() == 70, "shown=" .. tostring(fieldGetter()))
headerOpts.onBack()

-- ---------------------------------------------------------------------------
-- 5. tasks/session.lua stores the figure once, per model
-- ---------------------------------------------------------------------------

print("tasks/session.lua: the stored figure")
local sessionSource = assert(io.open(TASKS .. "/session.lua", "rb")):read("a"):gsub("\r\n", "\n")
local exporting, n = sessionSource:gsub("\nreturn {\n", "\nreturn {\n  _session = session,\n", 1)
assert(n == 1, "could not add the test export to session.lua")
local session = assert(load(exporting, "=session_under_test"))()
local S = session._session

local snapshot = nil
bus.subscribe("session.update", function(payload) snapshot = payload end)
local queue = {add = function() return true end, clear = function() end}
local function tick()
  session.wakeup(queue, "sport", nil, {telemetryState = function() return false end})
end

-- A wakeup with no link clears the session's identity (tasks/session.lua), so the connected model
-- is set again before each message. The writes are counted by the figure they carry: the first load of a model
-- also writes its defaults once, which is existing behaviour and not what is under test.
local function writesWith(amps)
  local count = 0
  for _, w in ipairs(writes) do
    if w.battery.esc_current_limit == amps then count = count + 1 end
  end
  return count
end

-- M1 is the model connected for the whole section; `mcuId` names the model a message is about.
local function send(mcuId, amps)
  S.mcuId = "M1"
  bus.publish("model.esc_current_limit.update", {mcuId = mcuId, amps = amps})
end

writes = {}
send("M1", 60)
check("a new figure is written once", writesWith(60) == 1, "writes with 60=" .. writesWith(60))
check("the session holds the figure", S.escCurrentLimit == 60)
tick()
check("the snapshot carries the figure", snapshot and snapshot.escCurrentLimit == 60,
  "snapshot=" .. tostring(snapshot and snapshot.escCurrentLimit))

writes = {}
send("M1", 60)
check("the same figure again writes nothing", #writes == 0, "writes=" .. #writes)

writes = {}
send("M2", 70)
check("another model's figure is ignored", #writes == 0 and S.escCurrentLimit == 60,
  "writes=" .. #writes .. " held=" .. tostring(S.escCurrentLimit))

writes = {}
send("M1", nil)
check("a cleared figure is written as not set",
  writesWith(0) == 1 and S.escCurrentLimit == nil, "writes=" .. #writes .. " held=" .. tostring(S.escCurrentLimit))

-- ---------------------------------------------------------------------------
-- 6. The dashboard's ESC load
-- ---------------------------------------------------------------------------

print("dashboard: esc_load")
local context = requireModule("widgets/dashboard/context.lua")
local function escLoad(widget)
  context.setWidget(widget)
  return context.tasks.telemetry.getSensor("esc_load")
end

local load1 = escLoad({connected = true, escCurrentLimit = 50, current = 20})
check("20 A on a 50 A limit is 40 %", load1 == 40, "got " .. tostring(load1))
local load2 = escLoad({connected = true, escCurrentLimit = 50, current = 60})
check("above the limit it reads above 100 %", load2 == 120, "got " .. tostring(load2))
check("no limit on file reads nothing (drawn as --)",
  escLoad({connected = true, current = 20}) == nil)
check("a limit of zero reads nothing", escLoad({connected = true, escCurrentLimit = 0, current = 20}) == nil)
check("no current reading reads nothing", escLoad({connected = true, escCurrentLimit = 50}) == nil)
check("a link that is down reads nothing",
  escLoad({connected = false, escCurrentLimit = 50, current = 20}) == nil)

local statsWidget = {
  connected = true,
  escCurrentLimit = 80,
  current = 40,
  flightmodeState = "inflight",
  dashboardStats = {},
}
context.setWidget(statsWidget)
context.tasks.telemetry.collectPresentationStats()
check("inflight presentation stats record esc_load",
  statsWidget.dashboardStats.esc_load and statsWidget.dashboardStats.esc_load.max == 50,
  "got " .. tostring(statsWidget.dashboardStats.esc_load and statsWidget.dashboardStats.esc_load.max))

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

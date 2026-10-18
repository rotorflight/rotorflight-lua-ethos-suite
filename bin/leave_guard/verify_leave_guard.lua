-- Behaviour check for Back with unsaved changes (issue #2504).
--
-- Run it:
--     lua5.4 bin/leave_guard/verify_leave_guard.lua
--
-- What it drives, and why:
--   * The real app/page_runtime.lua: Back on a dirty page asks first. Discard leaves, Stay keeps
--     the page, Save saves and keeps it. A clean page, a live-write page and a page that has not
--     loaded leave at once. While armed the question offers Discard and Stay only.
--   * The real src/rfsuite/app/pages/power_alerts.lua, a page that keeps its own state: the same
--     question through its own Back. The header, the form and the model preferences are stand-ins.
--
-- Against unpatched master Back leaves at once, so the dirty-page checks fail.

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

lcd = anyStub()
lcd.getWindowSize = function() return 480, 320 end
system = anyStub()
model = anyStub()
TEXT_LEFT = nil

-- The button texts as the build leaves them in a test (markers), mapped to their names.
local LABELS = {
  ["@i18n(app.btn_save)@"] = "SAVE",
  ["@i18n(app.btn_discard)@"] = "DISCARD",
  ["@i18n(app.btn_stay)@"] = "STAY",
  ["@i18n(app.msg_unsaved_title)@"] = "TITLE",
}

-- Every dialog the pages open lands here, so a test can find and press its buttons.
local dialogs = {}
local function lastDialog() return dialogs[#dialogs] end
local function pressButton(dialog, label)
  for _, b in ipairs(dialog.buttons or {}) do
    if (LABELS[b.label] or b.label) == label then return b.action() end
  end
  return nil
end
local function buttonLabels(dialog)
  local out = {}
  for _, b in ipairs(dialog.buttons or {}) do out[#out + 1] = LABELS[b.label] or b.label end
  return out
end

form = {
  clear = noop,
  invalidate = noop,
  openDialog = function(opts) dialogs[#dialogs + 1] = opts; return {close = noop} end,
  addLine = function(label) return {label = label} end,
  getFieldSlots = function() return {{x = 0, y = 0, w = 10, h = 10}} end,
  addStaticText = function() return {enable = noop} end,
  addNumberField = function(_, _, _, _, getter, setter)
    _G.fieldSetter = setter
    return {enable = noop, suffix = noop}
  end,
  addChoiceField = function(_, _, _, getter, setter)
    _G.choiceSetter = setter
    return {enable = noop}
  end,
}

local bus = requireModule("lib/bus.lua")
local pageRuntime = requireModule("app/page_runtime.lua")

-- ---------------------------------------------------------------------------
-- 1. The page runtime
-- ---------------------------------------------------------------------------

local function newRuntime(extra)
  local config = {pageTitle = "Test", logTag = "test", opts = {}, mspModule = anyStub()}
  for k, v in pairs(extra or {}) do config[k] = v end
  local rt = pageRuntime.new(config)
  rt.loaded = true
  rt:markDirty()
  return rt
end

print("page runtime: Back with unsaved changes")
do
  dialogs = {}
  local left = 0
  local rt = newRuntime({opts = {onBack = function() left = left + 1 end}})
  rt:goBack()
  check("Back on a dirty page opens the question and does not leave",
    left == 0 and #dialogs == 1, "left=" .. left .. " dialogs=" .. #dialogs)
  check("the question offers Save, Discard and Stay",
    #dialogs == 1 and table.concat(buttonLabels(lastDialog()), ",") == "SAVE,DISCARD,STAY",
    "buttons=" .. (#dialogs == 1 and table.concat(buttonLabels(lastDialog()), ",") or "?"))

  pressButton(lastDialog(), "STAY")
  check("Stay keeps the page open", left == 0 and not rt.disposed)

  dialogs = {}
  rt:goBack()
  pressButton(lastDialog(), "DISCARD")
  check("Discard leaves the page", left == 1 and rt.disposed)
end

do
  dialogs = {}
  local saved = 0
  local left = 0
  local rt = newRuntime({opts = {onBack = function() left = left + 1 end}})
  rt.performSave = function() saved = saved + 1 end
  rt:goBack()
  pressButton(lastDialog(), "SAVE")
  check("Save saves and keeps the page open", saved == 1 and left == 0 and not rt.disposed,
    "saved=" .. saved .. " left=" .. left)
end

do
  dialogs = {}
  local left = 0
  local rt = newRuntime({opts = {onBack = function() left = left + 1 end}})
  rt.dirty = false
  rt:goBack()
  check("a clean page leaves at once, without a question", left == 1 and #dialogs == 0)
end

do
  dialogs = {}
  local left = 0
  local rt = newRuntime({liveWrite = true, opts = {onBack = function() left = left + 1 end}})
  rt:goBack()
  check("a live-write page leaves at once (it has nothing to save)", left == 1 and #dialogs == 0)
end

do
  dialogs = {}
  local left = 0
  local rt = newRuntime({opts = {onBack = function() left = left + 1 end}})
  rt.loaded = false
  rt:goBack()
  check("a page that has not loaded leaves at once", left == 1 and #dialogs == 0)
end

do
  dialogs = {}
  local left = 0
  local rt = newRuntime({opts = {onBack = function() left = left + 1 end}})
  rt.busy = true
  rt:goBack()
  check("busy: Back does not open a dialog and does not leave", left == 0 and #dialogs == 0)
end

do
  dialogs = {}
  local left = 0
  local rt = newRuntime({opts = {onBack = function() left = left + 1 end}})
  rt.activeDialog = {}
  rt:goBack()
  check("active dialog: Back does not open a dialog and does not leave", left == 0 and #dialogs == 0)
end

do
  dialogs = {}
  local focused = 0
  local rt = newRuntime()
  rt.headerHandle = {focusSave = function() focused = focused + 1 end}
  rt:goBack()
  pressButton(lastDialog(), "STAY")
  check("Stay returns focus to the Save button", focused == 1)
end

do
  dialogs = {}
  local left = 0
  local rt = newRuntime({isMspPage = true, opts = {onBack = function() left = left + 1 end}})
  rt.isArmed = true
  rt:goBack()
  local labels = #dialogs == 1 and table.concat(buttonLabels(lastDialog()), ",") or "none"
  check("armed: the question offers Discard and Stay, not Save",
    labels == "DISCARD,STAY", "buttons=" .. labels)
  check("armed: the question does not leave", left == 0)
end

-- ---------------------------------------------------------------------------
-- 2. A page that keeps its own state: power_alerts
-- ---------------------------------------------------------------------------

local headerOpts
package.loaded["rfsuite.app.header"] = {build = function(_, opts)
  headerOpts = opts
  return {setSaveEnabled = noop, setReloadEnabled = noop, focusSave = noop, focusReload = noop, focusMenu = noop}
end}
package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return false end}
package.loaded["rfsuite.lib.model_preferences"] = {
  load = function() return {}, "model.ini" end,
  powerAlerts = function() return {flighttime = 300, alert_type = 0, becalertvalue = 6.5, rxalertvalue = 7.5} end,
  setPowerAlerts = function(prefs) return prefs end,
  save = function() return true end,
}

print("power_alerts: Back with unsaved changes")
do
  dialogs = {}
  local left = 0
  local page = requireModule("app/pages/power_alerts.lua")
  page.open({onBack = function() left = left + 1 end})
  bus.publish("session.update", {mcuId = "A1"})
  _G.choiceSetter(1)                 -- a real edit: the page is dirty
  headerOpts.onBack()
  check("Back on a dirty alerts page asks first and does not leave",
    left == 0 and #dialogs == 1, "left=" .. left .. " dialogs=" .. #dialogs)
  pressButton(lastDialog(), "DISCARD")
  check("Discard on the alerts page leaves", left == 1)
end

do
  dialogs = {}
  local left = 0
  local page = requireModule("app/pages/power_alerts.lua")
  page.open({onBack = function() left = left + 1 end})
  bus.publish("session.update", {mcuId = "A1"})
  headerOpts.onBack()
  check("Back on a clean alerts page leaves at once", left == 1 and #dialogs == 0,
    "left=" .. left .. " dialogs=" .. #dialogs)
end

print("ports: Back with unsaved changes")
do
  local sent = {}
  local sub = bus.subscribe("msp.request", function(m) sent[#sent + 1] = m end)
  local wakeupHandler = nil
  package.loaded["rfsuite.lib.msp_board_info"] = {
    buildReadMessage = function(onOk)
      return {processReply = function(self, data) onOk(data or self) end}
    end,
  }
  package.loaded["rfsuite.lib.msp_serial_config"] = {
    buildReadMessage = function(onOk)
      return {processReply = function(self, data) onOk(data or self) end}
    end,
    buildWriteMessage = function(_, onOk)
      return {processReply = function(self, data) onOk(data or self) end}
    end,
  }
  package.loaded["rfsuite.lib.msp_eeprom"] = {
    buildWriteMessage = function(onOk)
      return {processReply = function(_) onOk() end}
    end,
  }
  package.loaded["rfsuite.lib.msp_reboot"] = {
    buildWriteMessage = function() return {} end,
  }

  local page = requireModule("app/pages/ports.lua")
  local left = 0
  page.open({
    onBack = function() left = left + 1 end,
    setWakeupHandler = function(fn) wakeupHandler = fn end,
  })
  sent[1].processReply({board_design = "", board_name = "", identifier = 0})
  sent[2].processReply({ports = {{identifier = 0, function_mask = 0, msp_baud_index = 5, gps_baud_index = 5, blackbox_baud_index = 5, telem_baud_index = 5}}})
  if wakeupHandler then wakeupHandler() end

  dialogs = {}
  headerOpts.onBack()
  check("Back on a clean ports page leaves at once", left == 1 and #dialogs == 0)

  left = 0
  sent = {}
  page.open({
    onBack = function() left = left + 1 end,
    setWakeupHandler = function(fn) wakeupHandler = fn end,
  })
  sent[1].processReply({board_design = "", board_name = "", identifier = 0})
  sent[2].processReply({ports = {{identifier = 0, function_mask = 0, msp_baud_index = 5, gps_baud_index = 5, blackbox_baud_index = 5, telem_baud_index = 5}}})
  if wakeupHandler then wakeupHandler() end

  _G.choiceSetter(1)
  dialogs = {}
  headerOpts.onBack()
  check("Back on a dirty ports page asks first and does not leave", left == 0 and #dialogs == 1)
  check("the ports question offers Save, Discard and Stay",
    #dialogs == 1 and table.concat(buttonLabels(lastDialog()), ",") == "SAVE,DISCARD,STAY")

  pressButton(lastDialog(), "STAY")
  dialogs = {}
  bus.publish("session.update", {isArmed = true})
  headerOpts.onBack()
  check("armed ports page offers Discard and Stay, not Save",
    #dialogs == 1 and table.concat(buttonLabels(lastDialog()), ",") == "DISCARD,STAY")

  pressButton(lastDialog(), "DISCARD")
  check("Discard on ports page leaves", left == 1)
  bus.unsubscribe("msp.request", sub)
end

-- ---------------------------------------------------------------------------
-- The question's text and its tracked handle (review of #239)
-- ---------------------------------------------------------------------------
print("leave_confirm: the question's text and handle")
do
  local leaveConfirm = requireModule("app/leave_confirm.lua")
  local function noop() end
  local function args(canSave, armed)
    return leaveConfirm.args({canSave = canSave, armed = armed, save = noop, discard = noop, focus = noop})
  end
  local plainBody = args(true, false).message
  check("a page that cannot save for another reason does not say the model is armed",
    args(false, false).message == plainBody and args(false, false).message ~= args(false, true).message)
  check("a page that cannot save because the model is armed says so",
    args(false, true).message ~= plainBody)

  local opened = nil
  local savedForm = form
  form = {openDialog = function(spec) opened = spec; return {close = function() end} end}
  local discarded, cleared = 0, 0
  local handle = leaveConfirm.open(
    leaveConfirm.args({canSave = true, save = noop, discard = function() discarded = discarded + 1 end, focus = noop}),
    function() cleared = cleared + 1 end)
  local discardButton = opened.buttons[#opened.buttons - 1]
  discardButton.action()
  form = savedForm
  check("the tracked dialog returns its handle", handle ~= nil and handle.close ~= nil)
  check("a button clears the page's handle before it runs", cleared == 1 and discarded == 1)
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)

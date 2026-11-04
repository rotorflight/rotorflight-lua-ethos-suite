-- Behaviour check for #2679: a save whose writes went out but did not all commit must say the flight
-- controller may already run the new values, and offer the restart.
--
-- Run it (from the repository root):
--     lua5.4 bin/save_failure_restart/verify_save_failure_restart.lua
--     lua5.4 bin/save_failure_restart/verify_save_failure_restart.lua --self-test
--
-- What it drives: the real src/rfsuite/app/page_runtime.lua under stubs. The bus acknowledges or refuses
-- each message the save publishes (source writes, EEPROM write, restart); the wakeup handler the runtime
-- registers opens the dialogs.
--
-- It pins:
--   1. a save whose source writes were acknowledged and whose EEPROM write failed shows the "may already
--      be using the new values" text, with a Restart FC button, and pressing it publishes MSP_REBOOT;
--   2. a save whose first source write itself failed shows the plain "not saved" text, without the restart;
--   3. a save with no source written (every source skipped) shows the plain text, without the restart;
--   4. a save whose first source was written and whose second source write failed shows the running
--      text with the restart: the first source's values may already run;
--   5. the restart is not offered while armed.
--
-- --self-test drops the flag that marks a written save and requires the restart checks to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local RUNNING = "@i18n(app.msg_save_failed_running_body)@"
local PLAIN = "@i18n(app.msg_save_failed_body)@"
local RESTART = "@i18n(app.btn_restart_fc)@"

_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = { getVersion = function() return { simulation = false, radio = { name = "stub" } } end }
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }

local function widgetStub()
  return { focus = function() end, enable = function() end, value = function() end,
    setValue = function() end, setText = function() end, getValue = function() return 0 end,
    show = function() end, hide = function() end }
end
local dialogs = {}
_G.form = {
  addButton = widgetStub, addTextButton = widgetStub, addStaticText = widgetStub,
  addLine = function() return 1 end, clear = function() end, height = function() return 320 end,
  getFieldSlots = function(_, hints)
    local n = type(hints) == "table" and #hints or 6
    local slots = {}
    for i = 1, n do slots[i] = { x = (i - 1) * 80, y = 0, w = 80, h = 30 } end
    return slots
  end,
  openDialog = function(args) dialogs[#dialogs + 1] = args; return { close = function() end } end,
  openProgressDialog = function() return { close = function() end, value = function() end } end,
}
_G.TIME_LEFT, _G.TEXT_LEFT, _G.LEFT, _G.CENTERED, _G.RIGHT, _G.TOP_LEFT = 1, 2, 3, 4, 5, 6
_G.FONT_XS, _G.FONT_S, _G.FONT_M, _G.FONT_L, _G.FONT_XL = 10, 20, 30, 40, 50
_G.EVT_CLOSE, _G.EVT_KEY, _G.EVT_EXIT_BREAK, _G.EVT_KEY_DOWN_BREAK = 1, 2, 3, 4
_G.KEY_ENTER_LONG, _G.KEY_RTN_BREAK, _G.KEY_EXIT_BREAK, _G.KEY_ENTER_BREAK = 5, 6, 7, 8

-- The bus: each message is acknowledged or refused according to the scenario.
local scenario = {}
local published = {}
package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end, unsubscribe = function() end,
  publish = function(topic, msg)
    if topic ~= "msp.request" or type(msg) ~= "table" then return end
    published[#published + 1] = msg.kind
    if msg.kind == "source" then
      if scenario.refuseKey == msg.key then msg.onError("refused") else msg.onWritten() end
    elseif msg.kind == "eeprom" then
      if scenario.eepromRefused then msg.onError("refused") else msg.onWritten() end
    elseif msg.kind == "reboot" then
      msg.onWritten()
    end
  end,
}
package.loaded["rfsuite.lib.memstats"] = { print = function() end }
package.loaded["rfsuite.lib.debug_log"] = {
  print = function() end, format = function() end, msp = function() end,
  enabled = function() return false end, mspEnabled = function() return false end,
}
package.loaded["rfsuite.lib.settings_store"] = {
  saveConfirmEnabled = function() return false end, reloadConfirmEnabled = function() return false end,
  load = function() return {} end, save = function() end, DEFAULTS = {},
}
package.loaded["rfsuite.lib.msp_eeprom"] = {
  buildWriteMessage = function(onWritten, onError) return {kind = "eeprom", onWritten = onWritten, onError = onError} end,
}
package.loaded["rfsuite.lib.msp_reboot"] = {
  buildWriteMessage = function(onWritten, onError) return {kind = "reboot", onWritten = onWritten, onError = onError} end,
}
package.loaded["rfsuite.app.header"] = {
  build = function()
    return { setTitle = function() end, setSaveEnabled = function() end, setReloadEnabled = function() end,
      setToolEnabled = function() end, focusMenu = function() end, focusSave = function() end,
      focusReload = function() end, focusTool = function() end }
  end,
}

-- The runtime loads its helpers by suite-relative paths (lib/require.lua, ...): resolve them here.
local realLoadfile = loadfile
loadfile = function(path, ...)
  if type(path) == "string" and (path:match("^lib/") or path:match("^app/")) then
    path = SUITE .. "/" .. path
  end
  return realLoadfile(path, ...)
end

local PageRuntime = dofile(SUITE .. "/app/page_runtime.lua")

-- A source for the page: `written` says whether its codec builds a write.
local function sourceFor(key, written)
  return {
    key = key,
    mspModule = written and {
      buildReadMessage = function() return {} end,
      buildWriteMessage = function(_, onWritten, onError)
        return {kind = "source", key = key, onWritten = onWritten, onError = onError}
      end,
    } or {
      buildReadMessage = function() return {} end,
    },
  }
end

-- A fresh runtime with the given sources (in order).
local function newRuntime(sources)
  local wakeup
  local opts = {
    setEventHandler = function() end,
    setWakeupHandler = function(fn) wakeup = fn end,
    setPaintHandler = function() end,
    setCleanupHandler = function() end,
    onBack = function() end,
  }
  local rt = PageRuntime.new({
    pageTitle = "Harness", logTag = "harness", profileField = "none",
    mspModule = {buildReadMessage = function() return {} end},
    sources = sources,
    opts = opts,
  })
  rt:buildChrome()    -- registers the wakeup handler the runtime drives the dialogs from
  rt.busy = false     -- buildChrome() starts a load; the save starts from a loaded, idle page
  rt.dirty = true     -- a save needs unsaved changes (canSave)
  rt.loaded = true
  rt.data = {mixer = {value = 1}, yaw = {value = 2}}
  return rt, function() return wakeup end
end

local function lastDialog()
  return dialogs[#dialogs]
end

local function buttonLabels(dialog)
  local out = {}
  for _, b in ipairs((dialog and dialog.buttons) or {}) do out[#out + 1] = b.label end
  return out
end

local function hasLabel(labels, label)
  for _, l in ipairs(labels) do if l == label then return true end end
  return false
end

-- Runs one save and lets the wakeup open the dialog.
local function saveAndShow(sources)
  dialogs = {}
  published = {}
  local rt, getWakeup = newRuntime(sources)
  rt:performSave(function() end)
  -- The save's own dialog closes through a queued UI action, so a few wakeups run the rest.
  local wake = getWakeup()
  for _ = 1, 5 do
    if wake then wake() end
  end
  return rt, lastDialog()
end

local src = assert(io.open(SUITE .. "/app/page_runtime.lua", "rb")):read("a")
src = src:gsub("\r\n", "\n")

if SELF_TEST then
  -- Drop the flag that marks a save whose writes went out, for the EEPROM failure.
  local mutated, n = src:gsub("          self_%.pendingSaveRunning = wroteAny or nil\n", "")
  if n ~= 1 then
    print("FAIL  self-test: the flag line was not found once; update this harness")
    os.exit(1)
  end
  package.loaded["rfsuite.app.page_runtime"] = nil
  PageRuntime = assert(load(mutated, "@page_runtime.lua", "t"))()
end

-- 1. Writes went out, the EEPROM commit failed.
scenario = {eepromRefused = true}
local _, d1 = saveAndShow({sourceFor("mixer", true)})
check("1a. the dialog says the FC may already run the new values", d1 ~= nil and d1.message == RUNNING,
  "message=" .. tostring(d1 and d1.message))
local labels1 = buttonLabels(d1)
check("1b. the dialog offers Restart FC", hasLabel(labels1, RESTART), table.concat(labels1, ","))
if d1 and hasLabel(labels1, RESTART) then
  for _, b in ipairs(d1.buttons) do if b.label == RESTART then b.action() end end
  local rebooted = false
  for _, k in ipairs(published) do if k == "reboot" then rebooted = true end end
  check("1c. pressing Restart FC publishes MSP_REBOOT", rebooted)
end

-- 2. The first source's write itself failed: nothing is known to be running.
scenario = {refuseKey = "mixer"}
local _, d2 = saveAndShow({sourceFor("mixer", true)})
check("2. a first source refused shows the plain text, without the restart",
  d2 ~= nil and d2.message == PLAIN and not hasLabel(buttonLabels(d2), RESTART),
  "message=" .. tostring(d2 and d2.message))

-- 3. No source was written (all skipped), then the EEPROM commit failed.
scenario = {eepromRefused = true}
local _, d3 = saveAndShow({sourceFor("mixer", false)})
check("3. a save with nothing written shows the plain text, without the restart",
  d3 ~= nil and d3.message == PLAIN and not hasLabel(buttonLabels(d3), RESTART),
  "message=" .. tostring(d3 and d3.message))

-- 4. The first source was written, the second source's write failed.
scenario = {refuseKey = "yaw"}
local _, d4 = saveAndShow({sourceFor("mixer", true), sourceFor("yaw", true)})
check("4a. a later source refused after an earlier write shows the running text",
  d4 ~= nil and d4.message == RUNNING, "message=" .. tostring(d4 and d4.message))
check("4b. ... and offers the restart", hasLabel(buttonLabels(d4), RESTART))

-- 5. Armed: the restart is not offered.
scenario = {}
local rt5 = newRuntime({sourceFor("mixer", true)})
rt5.isArmed = true
dialogs = {}
rt5:showSaveError(function() end, true)
check("5. the restart is not offered while armed", not hasLabel(buttonLabels(lastDialog()), RESTART))

if SELF_TEST then
  if failures > 0 then
    print("ok    mutant red: a written save is not marked as running (" .. failures .. " failed checks)")
    print("OK  self-test: without the running flag the restart checks go red")
    os.exit(0)
  end
  print("FAIL  mutant passed the checks: the running flag")
  os.exit(1)
end

if failures == 0 then
  print("OK  save failure: a save whose writes went out says so and offers the restart (" .. checks .. " checks)")
  os.exit(0)
end
os.exit(1)

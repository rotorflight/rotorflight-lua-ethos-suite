-- Behaviour check for the header Tool button's enable state (issue #2553).
--
-- Run it:
--     lua5.4 bin/tool_button_loaded/verify_tool_button_loaded.lua
--
-- Save is gated by the page runtime; Tool was not. A page with an onTool
-- therefore showed an enabled Tool button before its values had loaded, and
-- on the mixer and servo override pages the dialog it opened could be
-- confirmed against unread values. The runtime now drives the Tool button
-- from the same loaded flag as Save, and the header passes it to the button.
--
-- What it drives:
--   part 1  the real src/rfsuite/app/page_runtime.lua with a bus stub that
--           holds, answers or fails each read, so every loaded transition is
--           visible: build, first read in flight, read answered, reload,
--           read failed.
--   part 2  the real src/rfsuite/app/header.lua with a form stub, so the
--           runtime's setToolEnabled() call is checked on the button itself.
-- Both go red on the pre-fix sources: there is no setToolEnabled, and the Tool
-- button stays enabled while the page is unloaded.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0
local out = print

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    out(string.format("  ok    %s", label))
  else
    failures = failures + 1
    out(string.format("  FAIL  %s", label))
    if detail then out("        " .. tostring(detail)) end
  end
end

-- ── Ethos environment ──────────────────────────────────────────────────────

local SUITE_PREFIX = SUITE .. "/"
package.path = SUITE_PREFIX .. "?.lua;" .. package.path
_G.PREFIX = SUITE_PREFIX

local realLoadfile = loadfile
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local isAbsolute = path:sub(1, 1) == "/" or path:match("^%a:[/\\]") ~= nil
    local absolute = isAbsolute and path or (SUITE_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

_G.print = function() end
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = { getVersion = function() return { simulation = false, radio = { name = "stub" } } end }
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }

local function widgetStub()
  return {
    focus = function() end,
    enable = function() end,
    value = function() end,
    setValue = function() end,
    setText = function() end,
    getValue = function() return 0 end,
    show = function() end,
    hide = function() end,
  }
end

local function dialogStub()
  return {
    value = function() end,
    message = function() end,
    closeAllowed = function() end,
    close = function() end,
  }
end

-- A button that remembers the enable state the header gives it.
local function buttonStub()
  local b = { enabled = true }
  function b:enable(v) self.enabled = v and true or false end
  function b:focus() end
  return b
end

_G.form = {
  addButton = function() return buttonStub() end,
  addTextButton = function() return buttonStub() end,
  addStaticText = widgetStub,
  addLine = function() return 1 end,
  clear = function() end,
  height = function() return 320 end,
  getFieldSlots = function(_, hints)
    local n = type(hints) == "table" and #hints or 6
    local slots = {}
    for i = 1, n do slots[i] = { x = (i - 1) * 80, y = 0, w = 80, h = 30 } end
    return slots
  end,
  openDialog = dialogStub,
  openProgressDialog = dialogStub,
}

_G.lcd = {
  loadMask = function() return {} end,
  getTextSize = function() return 10, 10 end,
  getWindowSize = function() return 800, 480 end,
  font = function() end,
  drawText = function() end,
  drawFilledRectangle = function() end,
  drawRectangle = function() end,
  drawBitmap = function() end,
  RGB = function() return 0 end,
}

_G.TIME_LEFT, _G.TEXT_LEFT, _G.LEFT, _G.CENTERED, _G.RIGHT, _G.TOP_LEFT = 1, 2, 3, 4, 5, 6
_G.FONT_XS, _G.FONT_S, _G.FONT_M, _G.FONT_L, _G.FONT_XL = 10, 20, 30, 40, 50
_G.EVT_CLOSE, _G.EVT_KEY, _G.EVT_EXIT_BREAK, _G.EVT_KEY_DOWN_BREAK = 0x01, 0x02, 0x03, 0x04
_G.KEY_ENTER_LONG, _G.KEY_RTN_BREAK, _G.KEY_EXIT_BREAK, _G.KEY_ENTER_BREAK = 0x05, 0x06, 0x07, 0x08

-- ── module stubs ───────────────────────────────────────────────────────────

-- Reads are held, answered or failed by the scenario.
local mode = "answer"          -- "answer" | "hold" | "fail"
local held = {}

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end,
  unsubscribe = function() end,
  publish = function(topic, message)
    if topic ~= "msp.request" or type(message) ~= "table" then return end
    if mode == "hold" then
      held[#held + 1] = message
    elseif mode == "fail" then
      if message.onError then message.onError("stub failure") end
    else
      if message.onData then message.onData({ profile = 1 }) end
    end
  end,
}
package.loaded["rfsuite.lib.memstats"] = { print = function() end }
package.loaded["rfsuite.lib.debug_log"] = {
  print = function() end,
  format = function() end,
  msp = function() end,
  enabled = function() return false end,
  mspEnabled = function() return false end,
}
package.loaded["rfsuite.lib.settings_store"] = {
  saveConfirmEnabled = function() return true end,
  reloadConfirmEnabled = function() return true end,
  load = function() return {} end,
  save = function() end,
  DEFAULTS = {},
}
package.loaded["rfsuite.lib.msp_eeprom"] = {
  buildWriteMessage = function() return { onData = function() end, onError = function() end } end,
}
package.loaded["rfsuite.lib.msp_reboot"] = { reboot = function() end }

-- The runtime's view of the header: records what it was told.
local toolCalls = {}
local headerOpts = nil
package.loaded["rfsuite.app.header"] = {
  build = function(_, opts)
    headerOpts = opts
    return {
      setTitle = function() end,
      setSaveEnabled = function() end,
      setReloadEnabled = function() end,
      setToolEnabled = function(enabled) toolCalls[#toolCalls + 1] = enabled and true or false end,
      focusMenu = function() end,
      focusSave = function() end,
      focusReload = function() end,
      focusTool = function() end,
    }
  end,
}

-- ── part 1: the runtime ────────────────────────────────────────────────────

local PageRuntime = dofile(SUITE .. "/app/page_runtime.lua")

local function sessionOpts()
  local opts = {}
  local function setter(name)
    return function(handler) opts[name] = handler end
  end
  opts.setEventHandler = setter("setEventHandler")
  opts.setWakeupHandler = setter("setWakeupHandler")
  opts.setPaintHandler = setter("setPaintHandler")
  opts.setCleanupHandler = setter("setCleanupHandler")
  opts.onBack = function() end
  return opts
end

-- A read's answer is applied on the page's wakeup tick, not inside onData, so
-- every answer is followed by a tick (as in verify_profile_anchor.lua).
local pageOpts = nil

local function newPage(withTool)
  toolCalls = {}
  pageOpts = sessionOpts()
  local config = {
    pageTitle = "Harness",
    logTag = "harness",
    profileField = "none",
    mspModule = {
      buildReadMessage = function(onData, onError) return { onData = onData, onError = onError } end,
      buildWriteMessage = function(_, onData, onError) return { onData = onData, onError = onError } end,
    },
    opts = pageOpts,
  }
  if withTool then
    config.onTool = function() end
  end
  local runtime = PageRuntime.new(config)
  runtime:buildChrome()
  runtime:registerField("default", widgetStub())
  return runtime
end

local function tick()
  if pageOpts and pageOpts.setWakeupHandler then pageOpts.setWakeupHandler() end
end

local function lastTool()
  return toolCalls[#toolCalls]
end

out("part 1: the runtime drives the Tool button from loaded")

-- A page without an onTool has no Tool button to drive.
mode = "answer"
do
  newPage(false)
  check("a page without onTool never calls setToolEnabled", #toolCalls == 0,
    "calls: " .. #toolCalls)
end

-- Build, then the first read in flight: Tool off. Answered: Tool on.
mode = "hold"
held = {}
local runtime = newPage(true)
check("Tool is off right after the chrome is built", lastTool() == false,
  "last call: " .. tostring(lastTool()))

runtime:loadInitial()
check("Tool stays off while the first read is in flight", lastTool() == false,
  "last call: " .. tostring(lastTool()))

mode = "answer"
for _, msg in ipairs(held) do msg.onData({ profile = 1 }) end
tick()
check("Tool is on once the first read has answered", lastTool() == true,
  "last call: " .. tostring(lastTool()))

-- A reload drops the page to unloaded again: Tool off during the read.
mode = "hold"
held = {}
runtime:loadData()
check("Tool goes off when a reload starts", lastTool() == false,
  "last call: " .. tostring(lastTool()))
mode = "answer"
for _, msg in ipairs(held) do msg.onData({ profile = 1 }) end
tick()
check("Tool is on again after the reload answers", lastTool() == true,
  "last call: " .. tostring(lastTool()))

-- A busy operation (e.g. performSave) disables Tool even while loaded.
runtime:setBusy(true)
check("Tool is off while the page is busy", lastTool() == false,
  "last call: " .. tostring(lastTool()))
runtime:setBusy(false)
check("Tool is on again once no longer busy", lastTool() == true,
  "last call: " .. tostring(lastTool()))

-- A failed read leaves the page unloaded: Tool stays off.
mode = "fail"
runtime:loadData()
tick()
check("Tool stays off after a failed read", lastTool() == false,
  "last call: " .. tostring(lastTool()))

-- ── part 2: the header button ──────────────────────────────────────────────

out("")
out("part 2: the real header sets the Tool button's enable state")

package.loaded["rfsuite.app.header"] = nil
package.loaded["rfsuite.lib.require"] = function(path)
  if path == "app/tile_grid.lua" then return {} end
  error("unexpected require in header harness: " .. tostring(path))
end
local header = dofile(SUITE .. "/app/header.lua")

-- The button object is not exposed, so read its state through the form stub,
-- which records the buttons in creation order: Menu, Save, Reload, Tool.
local created = {}
form.addButton = function()
  local b = buttonStub()
  created[#created + 1] = b
  return b
end

created = {}
local h1 = header.build("Harness", {
  onBack = function() end, onSave = function() end,
  onReload = function() end, onTool = function() end,
})
local toolBtn = created[4]    -- Menu, Save, Reload, Tool
check("header: Tool is enabled when onTool is given and nothing has said otherwise",
  toolBtn and toolBtn.enabled == true, toolBtn and tostring(toolBtn.enabled) or "no button")

h1.setToolEnabled(false)
check("header: setToolEnabled(false) disables Tool", toolBtn.enabled == false,
  "enabled: " .. tostring(toolBtn.enabled))
h1.setToolEnabled(true)
check("header: setToolEnabled(true) enables Tool", toolBtn.enabled == true,
  "enabled: " .. tostring(toolBtn.enabled))

created = {}
local h2 = header.build("Harness", {
  onBack = function() end, onSave = function() end, onReload = function() end,
})
local noToolBtn = created[4]
h2.setToolEnabled(true)
check("header: a page without onTool keeps Tool disabled", noToolBtn.enabled == false,
  "enabled: " .. tostring(noToolBtn.enabled))

out("")
out(string.format("%d checks, %d failed", checks, failures))
if failures > 0 then
  out("SOME CHECKS FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

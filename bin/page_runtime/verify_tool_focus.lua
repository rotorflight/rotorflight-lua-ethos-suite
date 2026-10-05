-- Behaviour check for the header Tool button's hand-off to a page's onTool.
--
-- Run it:
--     lua5.4 bin/page_runtime/verify_tool_focus.lua
--
-- Every page that gives PageRuntime an onTool writes it as
-- function(focusFn), and calls focusFn() when its dialog closes or is
-- cancelled (accelerometer, alignment, mixer_geometry, mixer_trims,
-- servos_bus, servos_pwm).
-- buildChrome() used to call it as runtime:onTool(focus), which made the
-- runtime table the first argument, so on the radio calibrating the
-- accelerometer ended in "focusFn is not callable (a table value)" from
-- closeDialog().
--
-- What it drives: the real src/rfsuite/app/page_runtime.lua under stubs, with
-- a header stub that keeps the opts buildChrome() hands it, so pressing Tool
-- runs exactly the closure the radio would. The checks go red on the pre-fix
-- page_runtime.lua: the page receives the runtime table, and closeDialog()
-- throws when given it.

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
    -- A Windows drive-letter path ("C:/...") is already absolute too.
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

_G.form = {
  addButton = widgetStub,
  addTextButton = widgetStub,
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

_G.TIME_LEFT, _G.TEXT_LEFT, _G.LEFT, _G.CENTERED, _G.RIGHT, _G.TOP_LEFT = 1, 2, 3, 4, 5, 6
_G.FONT_XS, _G.FONT_S, _G.FONT_M, _G.FONT_L, _G.FONT_XL = 10, 20, 30, 40, 50
_G.EVT_CLOSE, _G.EVT_KEY, _G.EVT_EXIT_BREAK, _G.EVT_KEY_DOWN_BREAK = 0x01, 0x02, 0x03, 0x04
_G.KEY_ENTER_LONG, _G.KEY_RTN_BREAK, _G.KEY_EXIT_BREAK, _G.KEY_ENTER_BREAK = 0x05, 0x06, 0x07, 0x08

-- ── module stubs ───────────────────────────────────────────────────────────

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end,
  unsubscribe = function() end,
  publish = function() end,
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
  buildWriteMessage = function() return {} end,
}
package.loaded["rfsuite.lib.msp_reboot"] = { reboot = function() end }

local headerOpts = nil
local toolFocused = 0
package.loaded["rfsuite.app.header"] = {
  build = function(_, opts)
    headerOpts = opts
    return {
      setTitle = function() end,
      setSaveEnabled = function() end,
      setReloadEnabled = function() end,
      focusMenu = function() end,
      focusSave = function() end,
      focusReload = function() end,
      focusTool = function() toolFocused = toolFocused + 1 end,
    }
  end,
}

-- ── the subject ────────────────────────────────────────────────────────────

local PageRuntime = dofile(SUITE .. "/app/page_runtime.lua")

local received = {}
local opts = {
  setEventHandler = function() end,
  setWakeupHandler = function() end,
  setPaintHandler = function() end,
  setCleanupHandler = function() end,
  onBack = function() end,
}

local runtime
runtime = PageRuntime.new({
  pageTitle = "Harness",
  logTag = "harness",
  profileField = "none",
  mspModule = {
    buildReadMessage = function() return {} end,
    buildWriteMessage = function() return {} end,
  },
  opts = opts,
  -- The shape every real page uses (see app/pages/accelerometer.lua).
  onTool = function(focusFn, ...)
    received.focusFn = focusFn
    received.extra = select("#", ...)
    runtime:showDialog("t", "m")
    received.closeOk, received.closeErr = pcall(function() runtime:closeDialog(focusFn) end)
  end,
})
runtime:buildChrome()

out("Tool button -> page onTool(focusFn)")
check("header was given an onTool", type(headerOpts and headerOpts.onTool) == "function")
if headerOpts and headerOpts.onTool then headerOpts.onTool() end
check("page received a function as focusFn", type(received.focusFn) == "function",
  "got " .. type(received.focusFn))
check("page received no extra arguments", received.extra == 0, "got " .. tostring(received.extra))
check("closeDialog(focusFn) does not throw", received.closeOk == true, received.closeErr)
check("closing the dialog refocused the Tool button", toolFocused == 1,
  "focusTool calls: " .. toolFocused)

out("")
out(string.format("%d checks, %d failed", checks, failures))
if failures > 0 then
  out("SOME CHECKS FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

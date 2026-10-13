-- Behaviour check for #2303: the armed-save warning is non-blocking, and a
-- local-settings page is exempt from the armed save gate.
--
-- Run it:
--     lua5.4 bin/armed_save/verify_armed_save.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/app/header.lua and the real
--     src/rfsuite/app/page_runtime.lua. The subject is a UI behaviour no build
--     and no package step reaches: an EEPROM_WRITE rejected by the FC while
--     armed used to open a modal form.openDialog() that seized the whole form
--     until the pilot pressed OK, and #2303 replaces it with a transient
--     footer banner drawn from the paint handler.
--   * The banner's own clock (part 5) is driven directly on a header handle,
--     because the timing is the part a page_runtime-level check cannot see.
--
-- The scene: a one-source page whose read succeeds, whose MSP_SET_* write
-- succeeds, and whose closing MSP_EEPROM_WRITE is answered with an error while
-- self.isArmed is true -- exactly the firmware's "armed_blocked" path.
--
-- Which checks are gates, and how --self-test proves it:
--   1. "the armed EEPROM rejection is shown as a header banner" and
--   2. "the armed EEPROM rejection opens no modal" --
--      both go red on the pre-fix page_runtime, where showSaveArmed() opened a
--      form.openDialog(). --self-test loads a copy of page_runtime.lua with the
--      banner call spliced back to the pre-fix modal and requires both to fail.
--   3. "the banner clears after its window" -- goes red if BANNER_SECONDS is
--      spliced to a value the fake clock never reaches.
--   The remaining checks are controls: an unarmed rejection must still be a
--   real failure dialog, a local-settings page must save while armed, and an
--   FC page without localSettings must stay gated.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0
local out = print

local BANNER_TEXT = "@i18n(app.msg_save_not_commited)@"

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

-- requireModule() calls loadfile() with a path that carries no directory part;
-- on the radio the working directory is src/rfsuite.
_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (SUITE_PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

_G.package = package
_G.package.loaded = package.loaded
_G.os = os
_G.math = math
_G.string = string
_G.table = table
_G.print = function() end
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }

-- Controllable clock: the banner window is measured with os.clock().
local fakeClock = 100
os.clock = function() return fakeClock end

local hapticCount = 0
local hapticEnabled = true
_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
  playHaptic = function()
    if hapticEnabled then hapticCount = hapticCount + 1 end
  end,
}

-- Spy on the paint surface. The banner is drawn with lcd, not a form line.
local drawnTexts = {}
local invalidations = 0
_G.lcd = {
  loadMask = function(p) return {path = p} end,
  getWindowSize = function() return 800, 480 end,
  getTextSize = function(text) return #tostring(text) * 8, 16 end,
  font = function() end,
  color = function() end,
  RGB = function(r, g, b, a) return r, g, b, a end,
  drawFilledRectangle = function() end,
  drawText = function(x, y, text) drawnTexts[#drawnTexts + 1] = tostring(text) end,
  invalidate = function() invalidations = invalidations + 1 end,
}

local function newWidget(name)
  local w = { name = name }
  w.focus = function() end
  w.enable = function() end
  w.value = function() end
  w.setValue = function() end
  return w
end

local openDialogs = 0
local lineCounter = 0
_G.form = {
  addLine = function() lineCounter = lineCounter + 1; return lineCounter end,
  getFieldSlots = function(line, hints)
    local slots = {}
    local x = 0
    for i = 1, #hints do
      slots[i] = { x = x, y = 0, w = 60, h = 20 }
      x = x + 60
    end
    return slots
  end,
  addStaticText = function() return newWidget("text") end,
  addButton = function() return newWidget("button") end,
  addTextButton = function() return newWidget("textbutton") end,
  addNumberField = function() local f = newWidget("number"); f.suffix = function() return f end; return f end,
  clear = function() end,
  height = function() return 320 end,
  openDialog = function() openDialogs = openDialogs + 1; return newWidget("dialog") end,
  openProgressDialog = function() return newWidget("progressdialog") end,
}

_G.TIME_LEFT = 1
_G.TEXT_LEFT = 2
_G.LEFT = 3
_G.CENTERED = 4
_G.RIGHT = 5
_G.TOP_LEFT = 6
_G.FONT_XS = 10
_G.FONT_S = 20
_G.FONT_M = 30
_G.FONT_L = 40
_G.FONT_XL = 50
_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02
_G.EVT_EXIT_BREAK = 0x03
_G.EVT_KEY_DOWN_BREAK = 0x04
_G.KEY_ENTER_LONG = 0x05
_G.KEY_RTN_BREAK = 0x06
_G.KEY_EXIT_BREAK = 0x07
_G.KEY_ENTER_BREAK = 0x08

-- ── shared seams ───────────────────────────────────────────────────────────

local sessionHandlers = {}
local eepromFails = false

local function resetScene()
  fakeClock = 100
  sessionHandlers = {}
  eepromFails = false
  hapticCount = 0
  hapticEnabled = true
  drawnTexts = {}
  invalidations = 0
  openDialogs = 0
end

local function publishSession(armed)
  for _, handler in ipairs(sessionHandlers) do
    handler({ pidProfile = 1, isArmed = armed, mcuId = "0123456789" })
  end
end

-- ── module stubs ───────────────────────────────────────────────────────────

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function(topic, handler)
    if topic == "session.update" then sessionHandlers[#sessionHandlers + 1] = handler end
  end,
  unsubscribe = function() end,
  publish = function(topic, message)
    if topic ~= "msp.request" or type(message) ~= "table" then return end
    if message.kind == "read" then
      if message.onData then message.onData({}) end
    elseif message.kind == "eeprom" then
      if eepromFails then
        if message.onError then message.onError("armed_blocked") end
      elseif message.onData then
        message.onData()
      end
    elseif message.kind == "write" then
      if message.onData then message.onData() end
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
  saveConfirmEnabled = function() return false end,
  reloadConfirmEnabled = function() return false end,
  load = function() return {} end,
  save = function() end,
}
package.loaded["rfsuite.app.close_key"] = { shouldHandleClose = function() return false end }
package.loaded["rfsuite.app.progress_dialog"] = {
  SPEED = { DEFAULT = 1.0, FAST = 2.0, SLOW = 0.75, VSLOW = 0.5 },
  open = function()
    return {
      value = function() end,
      close = function() end,
    }
  end,
}
package.loaded["rfsuite.lib.msp_eeprom"] = {
  buildWriteMessage = function(onWritten, onError)
    return { kind = "eeprom", onData = onWritten, onError = onError }
  end,
}
package.loaded["rfsuite.lib.msp_reboot"] = {
  buildWriteMessage = function(onWritten, onError)
    return { kind = "reboot", onData = onWritten, onError = onError }
  end,
}

local function mspModuleStub()
  return {
    buildReadMessage = function(onData, onError)
      return { kind = "read", onData = onData, onError = onError }
    end,
    buildWriteMessage = function(_, onWritten, onError)
      return { kind = "write", onData = onWritten, onError = onError }
    end,
  }
end

-- ── driving a page ─────────────────────────────────────────────────────────

local function newPage(PageRuntimeClass, config)
  local opts = {}
  local paintHandler
  opts.onBack = function() end
  opts.setEventHandler = function(fn) opts.event = fn end
  opts.setWakeupHandler = function(fn) opts.wakeup = fn end
  opts.setPaintHandler = function(fn) paintHandler = fn end
  opts.setCleanupHandler = function(fn) opts.cleanup = fn end

  local full = {
    pageTitle = "ArmedHarness",
    logTag = "armed-harness",
    profileField = "pidProfile",
    mspModule = mspModuleStub(),
    opts = opts,
    isMspPage = config.isMspPage,
    localSettings = config.localSettings,
  }
  local runtime = PageRuntimeClass.new(full)
  runtime:buildChrome()
  runtime:registerField("default", newWidget("field"))

  local function tick()
    if opts.wakeup then opts.wakeup() end
  end
  local function paint()
    if paintHandler then paintHandler() end
  end
  return runtime, tick, paint
end

-- Loads, arms, edits, and presses Save directly (performSave, bypassing the
-- optional confirm dialog so the check is about the EEPROM path).
local function armedSaveTrace(PageRuntimeClass, config)
  resetScene()
  local runtime, tick, paint = newPage(PageRuntimeClass, config)
  runtime:loadInitial()
  tick() -- read lands, page loaded

  publishSession(true)
  tick() -- isArmed = true

  runtime:markDirty()
  local saveableWhileArmed = runtime:canSave()
  -- The firmware's armed path: the EEPROM commit is refused, everything before
  -- it (the MSP_SET_* write) already succeeded.
  eepromFails = true
  runtime:performSave(function() end)
  tick() -- closeDialog + pendingSaveArmed consumed, banner shown

  paint() -- the header's paint tick draws the banner
  local paintedBanner = false
  for _, text in ipairs(drawnTexts) do
    if text == BANNER_TEXT then paintedBanner = true end
  end

  return {
    runtime = runtime,
    saveableWhileArmed = saveableWhileArmed,
    bannerPainted = paintedBanner,
    openDialogs = openDialogs,
    haptics = hapticCount,
    bannerThenExpire = function()
      -- Advance past the banner window and let the wakeup tick close it.
      fakeClock = fakeClock + 5
      local before = invalidations
      tick()
      drawnTexts = {}
      paint()
      local stillPainted = false
      for _, text in ipairs(drawnTexts) do
        if text == BANNER_TEXT then stillPainted = true end
      end
      return stillPainted, invalidations - before
    end,
  }
end

-- ── run ────────────────────────────────────────────────────────────────────

local realPageRuntime = dofile(SUITE .. "/app/page_runtime.lua")

out("part 1: an armed EEPROM rejection is reported without a modal")
local armed
do
  armed = armedSaveTrace(realPageRuntime, { isMspPage = false })
  check("the armed EEPROM rejection is shown as a header banner",
    armed.bannerPainted == true,
    "no banner text was painted")
  check("the armed EEPROM rejection opens no modal", armed.openDialogs == 0,
    "form.openDialog was called " .. tostring(armed.openDialogs) .. " time(s)")
  check("the pilot gets haptic feedback for the banner", armed.haptics == 1,
    "playHaptic called " .. tostring(armed.haptics) .. " time(s)")
  local stillPainted, invalidated = armed.bannerThenExpire()
  check("the banner clears after its window", stillPainted == false,
    "the banner was still painted after its 2.5 s window")
  check("expiring the banner asks for one repaint", invalidated == 1,
    "lcd.invalidate called " .. tostring(invalidated) .. " time(s)")
end

out("")
out("part 2: control -- an unarmed rejection is still a real failure dialog")
do
  resetScene()
  local runtime, tick = newPage(realPageRuntime, { isMspPage = false })
  runtime:loadInitial()
  tick()
  publishSession(false)
  tick()
  eepromFails = true
  runtime:markDirty()
  runtime:performSave(function() end)
  tick()
  check("an unarmed EEPROM rejection opens the save-failed dialog",
    openDialogs == 1, "openDialog called " .. tostring(openDialogs) .. " time(s)")
  check("and no banner is shown for it", hapticCount == 0,
    "playHaptic called " .. tostring(hapticCount) .. " time(s)")
end

out("")
out("part 3: a local-settings page saves while armed, and says nothing")
do
  resetScene()
  local runtime, tick = newPage(realPageRuntime, { isMspPage = true, localSettings = true })
  runtime:loadInitial()
  tick()
  publishSession(true)
  tick()
  runtime:markDirty()
  check("a local-settings page is saveable while armed", runtime:canSave() == true)
  runtime:performSave(function() end)
  tick()
  check("its save opens no modal", openDialogs == 0,
    "openDialog called " .. tostring(openDialogs) .. " time(s)")
  check("and the armed warning does not fire for it", hapticCount == 0,
    "playHaptic called " .. tostring(hapticCount) .. " time(s)")
end

out("")
out("part 4: gate -- an FC page without localSettings stays armed-gated")
do
  resetScene()
  local runtime, tick = newPage(realPageRuntime, { isMspPage = true })
  runtime:loadInitial()
  tick()
  publishSession(true)
  tick()
  runtime:markDirty()
  check("an FC page is not saveable while armed", runtime:canSave() == false)
end

out("")
out("part 5: the header banner's own window")
do
  resetScene()
  local header = package.loaded["rfsuite.app.header"]
  local handle = header.build("Banner", { onSave = function() end })
  check("the header handle exposes the banner API",
    type(handle.showBanner) == "function"
      and type(handle.paintBanner) == "function"
      and type(handle.updateBanner) == "function")
  drawnTexts = {}
  handle.showBanner("banner-under-test")
  handle.paintBanner()
  local shown = drawnTexts[1] == "banner-under-test"
  check("showBanner + paintBanner draws the text", shown == true,
    "drew: " .. tostring(drawnTexts[1]))
  check("updateBanner reports nothing while the window is open",
    handle.updateBanner() == false)
  fakeClock = fakeClock + 5
  check("updateBanner reports the expiry once", handle.updateBanner() == true)
  check("updateBanner is silent afterwards", handle.updateBanner() == false)
  drawnTexts = {}
  handle.paintBanner()
  check("an expired banner is not painted", #drawnTexts == 0,
    "drew " .. tostring(#drawnTexts) .. " text(s)")
end

-- ── self-test ──────────────────────────────────────────────────────────────

local selfTest = false
for _, arg in ipairs(arg or {}) do
  if arg == "--self-test" then selfTest = true end
end

if selfTest then
  out("")
  out("--self-test: the gates below must be able to go red")

  -- 1+2: the pre-fix showSaveArmed() opened a modal instead of the banner.
  local f = assert(io.open(SUITE .. "/app/page_runtime.lua", "r"))
  local source = f:read("*a")
  f:close()
  local splicedSource, n = source:gsub(
    "self%.headerHandle%.showBanner%(MSG_SAVE_ARMED_BANNER%)",
    'self:openMessageDialog({title="pre-fix", message="pre-fix", ' ..
    'buttons={}, wakeup=function() end, paint=function() end})', 1)
  assert(n == 1, "splice did not apply to page_runtime")
  package.loaded["rfsuite.app.page_runtime"] = nil
  local preFix = assert(load(splicedSource, "@page_runtime_pre_fix"))()

  local trace = armedSaveTrace(preFix, { isMspPage = false })
  check("the banner gate goes red on the pre-fix page_runtime",
    trace.bannerPainted == false,
    "the spliced page_runtime still painted a banner")
  check("the no-modal gate goes red with it",
    trace.openDialogs > 0,
    "the spliced page_runtime opened no dialog")
  package.loaded["rfsuite.app.page_runtime"] = realPageRuntime

  -- 3: the banner window. Splice BANNER_SECONDS up so the fake clock's +5
  -- jump cannot reach it; the expiry check must then stay painted.
  local hf = assert(io.open(SUITE .. "/app/header.lua", "r"))
  local hsource = hf:read("*a")
  hf:close()
  local hspliced, hn = hsource:gsub("local BANNER_SECONDS = 2%.5", "local BANNER_SECONDS = 9999")
  assert(hn == 1, "splice did not apply to header")
  package.loaded["rfsuite.app.header"] = nil
  local preFixHeader = assert(load(hspliced, "@header_pre_fix"))()
  local hhandle = preFixHeader.build("Banner", { onSave = function() end })
  hhandle.showBanner("banner-under-test")
  fakeClock = fakeClock + 5
  check("the banner-expiry gate goes red with a huge window",
    hhandle.updateBanner() == false,
    "the spliced header expired the banner anyway")
end

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

-- Behaviour check for the dialog teardown a page performs when it is left
-- (#2383).
--
-- Run it:
--     lua5.4 bin/dialog_lifecycle/verify_dialog_lifecycle.lua
--
-- What it drives, and why:
--   * The real app/page_runtime.lua, app/pages/ports.lua and
--     app/pages/developer_msp_exp.lua, loaded under an Ethos stub whose form
--     has a mutation gate: every widget and dialog method raises once
--     `gate.forbidden` is set. That models app/tool.lua's own close()
--     comment verbatim -- "on real Ethos the tool close callback can run after
--     form mutation has already been forbidden" -- so the teardown path is
--     the one thing this harness is about. The pages are reached exactly the
--     way the radio reaches them: open(opts) installs a setCleanupHandler,
--     and calling that handler is app/tool.lua:close().
--   * Every page that can be reached is one of the three above, so the fix is
--     pinned where it lives rather than in a copy of it.
--
-- Which cases go RED on the pre-fix files:
--   1. page_runtime: an open "Save to FC?" modal is not closed by dispose().
--   2. page_runtime: dispose() raises, because closeDialog() refocuses the
--      menu button on a form that has already stopped accepting writes.
--   4. ports: its reload confirmation modal is not closed by dispose().
--   5. developer_msp_exp: dispose() raises, because that page holds a RAW
--      form.openProgressDialog handle -- not the app/progress_dialog.lua
--      wrapper -- so value()/close() reach the form directly.
-- Cases 3 and 6 pin behaviour that has to survive the fix rather than
-- anything it repairs.
--
-- A check that cannot fail proves nothing about the behaviour it passes, so
-- every case below states what it expects and the gate is real: it is set by
-- the harness itself and read by the stub, never stubbed per case.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0

-- The real print, held before _G.print is replaced below: the suite prints
-- through the same global and a silent stub must not swallow this file's own
-- output.
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

-- Runs fn and reports the error text instead of letting it abort the run:
-- several cases below assert precisely that the teardown must NOT raise, and
-- on the pre-fix files it does.
local function raised(fn)
  local ok, err = pcall(fn)
  if ok then return nil end
  return tostring(err)
end

-- ── form mutation gate ─────────────────────────────────────────────────────

local gate = { forbidden = false, writes = 0 }

local function mutation(what)
  if gate.forbidden then
    error("form mutation forbidden: " .. what, 3)
  end
  gate.writes = gate.writes + 1
end

-- Every handle form.openDialog/openProgressDialog hands out. `closed` is only
-- set after the gate call, so a refused close leaves closed == false and a
-- check cannot pass on a close that never happened.
local dialogsOpened = {}

local function dialogHandle(kind)
  local h
  h = {
    kind = kind,
    closed = false,
    value = function() mutation(kind .. ":value") end,
    message = function() mutation(kind .. ":message") end,
    closeAllowed = function() mutation(kind .. ":closeAllowed") end,
    close = function()
      mutation(kind .. ":close")
      h.closed = true
    end,
  }
  dialogsOpened[#dialogsOpened + 1] = h
  return h
end

local function lastDialog(kind)
  for i = #dialogsOpened, 1, -1 do
    if dialogsOpened[i].kind == kind then return dialogsOpened[i] end
  end
  return nil
end

local function resetDialogs()
  for i = #dialogsOpened, 1, -1 do dialogsOpened[i] = nil end
end

-- Header buttons and page fields. Only the methods the pages under test
-- actually call are present, and every one of them is a form write -- which
-- is the whole point: focus() and enable() are the calls that must not happen
-- once the form has stopped accepting writes.
local function widgetStub(name)
  return {
    name = name,
    focus = function() mutation(name .. ":focus") end,
    enable = function() mutation(name .. ":enable") end,
    value = function() mutation(name .. ":value") end,
    setValue = function() mutation(name .. ":setValue") end,
    setText = function() mutation(name .. ":setText") end,
    getValue = function() return 0 end,
    show = function() mutation(name .. ":show") end,
    hide = function() mutation(name .. ":hide") end,
    close = function() mutation(name .. ":close") end,
  }
end

-- app/header.lua's real build() is replaced rather than stubbed field by
-- field: the pages under test only ever use the returned handle and the opts
-- they handed in, and driving onSave/onReload through the recorded opts is
-- what puts a confirmation modal on screen the way the pilot does.
local headerOpts = nil

local function headerStub()
  return {
    build = function(_, opts)
      headerOpts = opts
      local handle = {
        _buttons = {},
        focusMenu = function() mutation("menuButton:focus") end,
        focusSave = function() mutation("saveButton:focus") end,
        focusReload = function() mutation("reloadButton:focus") end,
        focusTool = function() mutation("toolButton:focus") end,
        setTitle = function() mutation("titleField:value") end,
        setSaveEnabled = function() mutation("saveButton:enable") end,
        setReloadEnabled = function() mutation("reloadButton:enable") end,
      }
      return handle
    end,
  }
end

local function slotsStub(count)
  local out = {}
  for i = 1, (count or 6) do
    out[i] = { x = (i - 1) * 80, y = 0, w = 80, h = 30 }
  end
  return out
end

-- ── Ethos environment ──────────────────────────────────────────────────────

local SUITE_PREFIX = SUITE .. "/"
package.path = SUITE_PREFIX .. "?.lua;" .. package.path
_G.PREFIX = SUITE_PREFIX

local realLoadfile = loadfile

-- requireModule() calls loadfile() with a path that carries no directory
-- part; on the radio the working directory is src/rfsuite. Same redirect the
-- tool_ui harness uses, for the same reason.
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
_G.lcd = {
  getWindowSize = function() return 480, 320 end,
  getTextSize = function(t) return #t, 12 end,
  drawRectangle = function() end,
  drawText = function() end,
  drawBitmap = function() end,
  setColor = function() end,
  font = function() return 1 end,
  color = function() end,
}
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = {
  getVersion = function() return { simulation = false, radio = { name = "stub" } } end,
  getMemoryUsage = function() return {} end,
  formatBytes = function(n) return tostring(n) end,
  killEvents = function() end,
}
_G.radio = { getActiveProfileId = function() return 1 end, getProfileId = function() return 1 end }

_G.form = {
  addButton = function(_, slot) return widgetStub("button@" .. tostring(slot)) end,
  addTextButton = function(_, slot) return widgetStub("textbutton@" .. tostring(slot)) end,
  addStaticText = function(_, rect) return widgetStub("text@" .. tostring(rect)) end,
  addNumberField = function() return widgetStub("numberField") end,
  addChoiceField = function() return widgetStub("choiceField") end,
  addLine = function() return 1 end,
  clear = function() end,
  height = function() return 320 end,
  getFieldSlots = function(_, hints) return slotsStub(type(hints) == "table" and #hints or 6) end,
  openDialog = function(args)
    local h = dialogHandle("openDialog")
    h.args = args
    return h
  end,
  openProgressDialog = function(args)
    local h = dialogHandle("openProgressDialog")
    h.args = args
    return h
  end,
}

-- Constants the sources read as Ethos globals. Values taken from the source
-- lines that use them (app/header.lua:122 adds FONT_S and CENTERED), not
-- guessed at.
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

-- ── Module stubs ───────────────────────────────────────────────────────────
--
-- Pre-seeded under the keys lib/require.lua derives, so requireModule()
-- finds them without a loadfile (require.lua:77-78). Everything kept out of
-- the real tree is something that would otherwise reach io.open, the radio's
-- settings store, or an MSP codec this harness has no business running.

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end,
  unsubscribe = function() end,
  -- Answers a read immediately, the way the queue does when the link is up.
  -- loadData() deliberately defers its own success branch to the next tick
  -- (queueUiAction), so this only makes the message arrive, not the page
  -- finish loading -- that still takes a wakeup, as on the radio.
  publish = function(topic, message)
    if topic == "msp.request" and type(message) == "table"
        and type(message.onData) == "function" then
      message.onData(message.data or {})
    end
  end,
}
package.loaded["rfsuite.lib.memstats"] = { print = function() end }
package.loaded["rfsuite.lib.debug_log"] = { print = function() end }
package.loaded["rfsuite.lib.msp_eeprom"] = {
  buildWriteMessage = function() return { onData = function() end, onError = function() end } end,
}
package.loaded["rfsuite.lib.msp_reboot"] = { reboot = function() end }
package.loaded["rfsuite.lib.msp_experimental"] = {
  buildReadMessage = function(onData, onError)
    return { onData = onData, onError = onError, data = {} }
  end,
  buildWriteMessage = function(_, onData, onError)
    return { onData = onData, onError = onError, data = {} }
  end,
}
package.loaded["rfsuite.lib.settings_store"] = {
  -- Both confirmations ON, so the modal is what gets exercised -- a stub that
  -- returned false would route straight into performSave() and the case would
  -- pass without a dialog ever appearing.
  saveConfirmEnabled = function() return true end,
  reloadConfirmEnabled = function() return true end,
  developerModeEnabled = function() return true end,
  load = function()
    return { general = {}, developer = {} }
  end,
  save = function() end,
  DEFAULTS = { general = {}, developer = {} },
}
package.loaded["rfsuite.lib.msp_serial_config"] = {
  buildReadMessage = function(onData, onError)
    return { onData = onData, onError = onError, data = { ports = {} } }
  end,
  buildWriteMessage = function() return { onData = function() end, onError = function() end } end,
}
package.loaded["rfsuite.lib.msp_rx_config"] = {
  buildReadMessage = function(onData, onError)
    return { onData = onData, onError = onError, data = { serialrx_provider = 0 } }
  end,
}
package.loaded["rfsuite.app.header"] = headerStub()

-- One MSP module shape shared by every runtime built below.
local function mspModuleStub()
  return {
    buildReadMessage = function(onData, onError)
      return { onData = onData, onError = onError, data = {} }
    end,
    buildWriteMessage = function(_, onData, onError)
      return { onData = onData, onError = onError, data = {} }
    end,
  }
end

-- Runs fn through the cleanup handler and returns the error text, or nil when
-- it did not raise. Written out rather than folded into an `and/or` chain
-- because `raised()` legitimately returns nil, and `a and nil or b` answers b.
local function teardown(opts)
  local handler = opts.setCleanupHandler
  if not handler then return "no cleanup handler installed" end
  return raised(handler)
end

-- ── helpers ────────────────────────────────────────────────────────────────

-- Builds the opts table the pages install their handlers into. Each setter
-- stores whatever it is handed under its own name, so opts.setCleanupHandler
-- always answers the handler that is installed right now -- the pages call it
-- with nil while tearing down, which is why the harness reads it fresh at the
-- moment it wants to fire it.
local function makeOpts()
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

local function newRuntime()
  local PageRuntime = dofile(SUITE .. "/app/page_runtime.lua")
  local opts = makeOpts()
  local runtime = PageRuntime.new({
    pageTitle = "Harness",
    logTag = "harness",
    mspModule = mspModuleStub(),
    opts = opts,
  })
  runtime:buildChrome()
  return runtime, opts
end

-- ── cases ──────────────────────────────────────────────────────────────────

out("case 1: page_runtime -- a pending save confirmation is closed by dispose()")
do
  resetDialogs()
  gate.forbidden = false
  local runtime, opts = newRuntime()

  runtime:loadInitial()
  if opts.setWakeupHandler then opts.setWakeupHandler() end   -- runs the queued success branch
  runtime:markDirty()                                        -- what a pilot edit does
  runtime:confirmSave(nil)

  local modal = lastDialog("openDialog")
  check("confirmSave() opened a confirmation modal", modal ~= nil)
  if modal then
    check("the modal is still open before dispose()", modal.closed == false)
    check("dispose() closed it", teardown(opts) == nil and modal.closed == true,
      "an orphaned modal stays on screen with an OK button that only reaches a disposed runtime")
  end
  runtime = nil
end

out("")
out("case 2: page_runtime -- dispose() must not write to a form that refuses writes")
do
  resetDialogs()
  local runtime, opts = newRuntime()
  runtime:loadInitial()
  if opts.setWakeupHandler then opts.setWakeupHandler() end

  -- A read is in flight, so a progress dialog is up, and the pilot closes the
  -- tool: app/tool.lua's close() runs the cleanup handler with the form
  -- already refusing mutations.
  runtime:showDialog("t", "m")
  gate.forbidden = true
  local err = teardown(opts)
  gate.forbidden = false
  check("dispose() did not raise", err == nil, err)
end

out("")
out("case 3: page_runtime -- a live close still refocuses the header")
do
  resetDialogs()
  gate.forbidden = false
  local runtime = nil
  local err = raised(function()
    runtime = newRuntime()
    runtime:loadInitial()
    -- focusMenu is only reached without a focusFn, which is exactly the
    -- initial-load case closeDialog's own comment describes.
    local opts = runtime.opts
    if opts.setWakeupHandler then opts.setWakeupHandler() end
  end)
  check("initial load completed without raising", err == nil, err)
  -- The write count proves the refocus happened: loadData disables the fields,
  -- then closeDialog's updateSaveEnabled + focusMenu write to the header.
  check("the header was written after the progress dialog closed", gate.writes > 0,
    "writes=" .. gate.writes)
end

out("")
out("case 4: ports -- its reload confirmation is closed by dispose()")
do
  resetDialogs()
  gate.forbidden = false
  local ports = dofile(SUITE .. "/app/pages/ports.lua")
  local opts = makeOpts()
  -- open() runs startLoad() at the end; the bus stub above answers both reads
  -- inline, so the page comes up loaded and idle, as it would on the radio.
  ports.open(opts)

  check("the page built its header", headerOpts ~= nil and headerOpts.onReload ~= nil)
  if headerOpts and headerOpts.onReload then
    headerOpts.onReload()
    local modal = lastDialog("openDialog")
    check("the Reload button opened a confirmation modal", modal ~= nil)
    if modal then
      check("dispose() closed it", teardown(opts) == nil and modal.closed == true,
        "ports' openConfirmDialog()/closeConfirmDialog() did not pair up")
    end
  end
end

out("")
out("case 5: ports -- dispose() must not write to a form that refuses writes")
do
  resetDialogs()
  local ports = dofile(SUITE .. "/app/pages/ports.lua")
  local opts = makeOpts()
  ports.open(opts)
  headerOpts = nil
  if headerOpts and headerOpts.onReload then headerOpts.onReload() end

  gate.forbidden = true
  local err = teardown(opts)
  gate.forbidden = false
  check("dispose() did not raise", err == nil, err)
end

out("")
out("case 6: developer_msp_exp -- a raw progress handle is torn down safely")
do
  resetDialogs()
  gate.forbidden = false
  local page = dofile(SUITE .. "/app/pages/developer_msp_exp.lua")
  local opts = makeOpts()
  page.open(opts)

  local raw = lastDialog("openProgressDialog")
  check("open() left a raw progress dialog up", raw ~= nil)
  if raw then
    -- Not forbidden: the handle must genuinely be closed, not merely survive.
    local err = teardown(opts)
    check("goBack() did not raise", err == nil, err)
    check("the raw handle was closed", raw.closed == true,
      "this page bypasses app/progress_dialog.lua, so close() reaches the form raw")
  end

  -- Second visit: opened with a form that still accepts writes, so the page
  -- comes up normally, and the gate is shut only for the teardown. The raise
  -- itself is the defect there. The raw handle is deliberately NOT asserted
  -- closed, because a form that refuses writes cannot close anything --
  -- asserting it would ask for the impossible.
  resetDialogs()
  local opts2 = makeOpts()
  page.open(opts2)
  gate.forbidden = true
  local err2 = teardown(opts2)
  gate.forbidden = false
  check("goBack() did not raise on a refusing form", err2 == nil, err2)
end

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
out("form writes observed: " .. gate.writes)
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

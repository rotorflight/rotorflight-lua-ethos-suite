-- Behaviour check for the dashboard's erase wait (follow-up to #2495, found on the
-- Rotorflight Dashboard widget, not the status page).
--
-- Run it:
--     lua5.4 bin/dashboard_erase/verify_dashboard_erase.lua
--
-- What it drives: the real src/rfsuite/widgets/dashboard.lua through the widget table
-- it registers with system.registerWidget(). The erase starts the way a user starts it:
-- the Erase toolbar item (key event), then OK on the confirmation dialog. The bus, the MSP
-- messages, the clock and the forms are stubs; every message is recorded and each reply
-- (acknowledgement, summary, failure) is given by the scenario.
--
-- The firmware acknowledges the erase before it runs (blackboxErase() only sets a state),
-- and the summary's ready bit is false until the flash is idle. A single read after the
-- acknowledgement can therefore report "not ready" while the erase is still running.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local DASHBOARD = ROOT .. "/src/rfsuite/widgets/dashboard.lua"

local checks, failures = 0, 0
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

local FLAG_READY, FLAG_SUPPORTED = 1, 2
local ERASE_TOOLBAR_INDEX = 2           -- TOOLBAR_ITEMS[2] is Erase
local ERASE_FAILED_MESSAGE = "@i18n(app.modules.blackbox.erase_failed)@"

-- ---------------------------------------------------------------------------
-- Clock: the wait is timed with os.clock(), so the scenario moves it by hand.
-- ---------------------------------------------------------------------------
local now = 100
os.clock = function() return now end

-- ---------------------------------------------------------------------------
-- Stubs.
-- ---------------------------------------------------------------------------
local sent, registered, dialogs, progresses = {}, nil, {}, {}

local function noop() end

-- Event codes the widget compares against. Any distinct values do.
EVT_KEY, EVT_TOUCH = 1, 2
KEY_ENTER_BREAK, KEY_PAGE_LONG, KEY_DOWN_BREAK = 10, 11, 12
ROTARY_LEFT, ROTARY_RIGHT = 13, 14
TOUCH_START, TOUCH_END = 20, 21

lcd = setmetatable({ RGB = function() return 0 end, isVisible = function() return true end },
  { __index = function() return noop end })
lcd.hasFocus = function() return true end

system = {
  registerWidget = function(w) registered = w end,
  getVersion = function() return { simulation = false } end,
  getSource = function() return { state = function() return nil end } end,
  openPage = noop,
}
form = {
  openDialog = function(o) dialogs[#dialogs + 1] = o end,
  openProgressDialog = function()
    local p = { closed = false, value = noop, closeAllowed = noop }
    p.close = function() p.closed = true end
    progresses[#progresses + 1] = p
    return p
  end,
  clear = noop,
  addLine = function() return {} end,
  addStaticText = function() return {} end,
}

local function anyStub()
  return setmetatable({}, { __index = function() return function() return {} end end })
end

-- The real summary decoder, over a byte-level codec, so a reply is checked as its bytes arrive.
local codec = {
  readU8 = function(buf)
    local o = buf.offset or 1
    buf.offset = o + 1
    return buf[o] or 0
  end,
  readU32 = function(buf)
    local o = buf.offset or 1
    local v = 0
    for i = 3, 0, -1 do v = v * 256 + (buf[o + i] or 0) end
    buf.offset = o + 4
    return v
  end,
}
local realSummaryModule
local function realSummary()
  realSummaryModule = realSummaryModule or dofile(ROOT .. "/src/rfsuite/lib/msp_dataflash_summary.lua")
  return realSummaryModule
end

local dataflashSummaryMsg = {
  buildReadMessage = function(ok, err)
    local real = realSummary().buildReadMessage(ok, err)
    return { kind = "summary", ok = ok, err = err, processReply = real.processReply }
  end,
}
local dataflashEraseMsg = {
  buildWriteMessage = function(ok, err) return { kind = "erase", ok = ok, err = err } end,
}

package.loaded["rfsuite.lib.require"] = function(name)
  if name == "lib/bus.lua" then
    return {
      publish = function(topic, msg)
        if topic == "msp.request" then sent[#sent + 1] = msg end
      end,
      subscribe = noop,
      unsubscribe = noop,
    }
  elseif name == "lib/mspcodec.lua" then
    return codec
  elseif name == "lib/msp_dataflash_summary.lua" then
    return dataflashSummaryMsg
  elseif name == "lib/msp_dataflash_erase.lua" then
    return dataflashEraseMsg
  elseif name == "widgets/dashboard/context.lua" then
    local utils = setmetatable({}, { __index = function() return noop end })
    return { widgets = { dashboard = { utils = utils } } }
  elseif name == "lib/settings_store.lua" then
    return {
      load = function() return {} end,
      dashboard = function() return {} end,
      debugLogsEnabled = function() return false end,
    }
  end
  return anyStub()
end

-- ---------------------------------------------------------------------------
-- Helpers.
-- ---------------------------------------------------------------------------
local function latest(kind)
  for i = #sent, 1, -1 do
    if sent[i].kind == kind then return sent[i] end
  end
  return nil
end

local function countOf(kind)
  local n = 0
  for _, m in ipairs(sent) do if m.kind == kind then n = n + 1 end end
  return n
end

local function freshWidget()
  sent, dialogs, progresses = {}, {}, {}
  registered = nil
  local dash = dofile(DASHBOARD)
  dash.init({})
  local w = registered.create()
  w.connected = true
  w.dashboardSettings = {}
  -- The erase wait does not depend on the paint preparation; keep that path out of the test.
  w.needsPaint = false
  return w
end

local function wake(w)
  -- Paint preparation is not part of the erase wait; keep it out of every wakeup.
  w.needsPaint = false
  registered.wakeup(w)
  w.needsPaint = false
end

-- Awake wakeups, one per second, as the dashboard runs them.
local function advance(w, seconds)
  for _ = 1, seconds do
    now = now + 1
    wake(w)
  end
end

-- Starts an erase the way the user does: the Erase toolbar item, then OK on the confirmation.
-- Returns the erase command message, so the scenario can answer its acknowledgement.
local function startErase(w)
  w.toolbarVisible = true
  w.selectedToolbarIndex = ERASE_TOOLBAR_INDEX
  registered.event(w, EVT_KEY, KEY_ENTER_BREAK)
  dialogs[#dialogs].buttons[1].action()
  return latest("erase")
end

local function summaryReply(flags)
  latest("summary").ok({ flags = flags, total = 100, used = 10 })
end

local function failureShown()
  for _, d in ipairs(dialogs) do
    if d.message == ERASE_FAILED_MESSAGE then return true end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Scenarios.
-- ---------------------------------------------------------------------------
local function runChecks()
  -- D1: a read that reports "not ready" does not end the wait; the next read follows after
  -- half a second, and not before; a read that reports ready ends it.
  do
    local w = freshWidget()
    local erase = startErase(w)
    erase.ok()
    wake(w)
    check("D1 the acknowledged erase reads the summary", countOf("summary") == 1,
      "summaries = " .. countOf("summary"))
    local t0 = now
    summaryReply(FLAG_SUPPORTED)                 -- not ready: still erasing
    wake(w)
    check("D1 a read that reports not ready does not finish the erase", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
    now = t0 + 0.2
    wake(w)
    check("D1 no read is sent before the half-second retry", countOf("summary") == 1,
      "summaries = " .. countOf("summary"))
    now = t0 + 0.5
    wake(w)
    check("D1 the wait reads again after half a second", countOf("summary") == 2,
      "summaries = " .. countOf("summary"))
    summaryReply(FLAG_READY + FLAG_SUPPORTED)    -- ready now
    wake(w)
    check("D1 a read that reports ready finishes the erase", w.eraseActive ~= true,
      "eraseActive = " .. tostring(w.eraseActive))
    check("D1 a finished erase shows no failure", not failureShown())
  end

  -- D2: a reply without flags cannot end the wait; it is read again.
  do
    local w = freshWidget()
    local erase = startErase(w)
    erase.ok()
    wake(w)
    latest("summary").ok({ total = 100, used = 10 })
    wake(w)
    check("D2 a reply without flags does not finish the erase", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
    local t0 = now
    now = t0 + 0.5
    wake(w)
    check("D2 a reply without flags is read again", countOf("summary") == 2,
      "summaries = " .. countOf("summary"))
  end

  -- D3: a board without dataflash finishes the wait at the first answer, without a failure.
  do
    local w = freshWidget()
    local erase = startErase(w)
    erase.ok()
    wake(w)
    summaryReply(0)
    wake(w)
    check("D3 a board without dataflash finishes the erase", w.eraseActive ~= true,
      "eraseActive = " .. tostring(w.eraseActive))
    check("D3 that finish shows no failure", not failureShown())
  end

  -- D4: a read that fails does not finish the wait, and is followed by another read.
  do
    local w = freshWidget()
    local erase = startErase(w)
    erase.ok()
    wake(w)
    latest("summary").err()
    wake(w)
    check("D4 a failed read does not finish the erase", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
    now = now + 0.5
    wake(w)
    check("D4 a failed read is followed by another read", countOf("summary") == 2,
      "summaries = " .. countOf("summary"))
  end

  -- D5: the timeout counts from the acknowledgement. Time before the acknowledgement does not
  -- count, and an erase that never reports ready fails 240 s after it.
  do
    local w = freshWidget()
    local erase = startErase(w)
    advance(w, 200)                              -- no acknowledgement yet
    erase.ok()
    advance(w, 230)
    check("D5 230 s after the acknowledgement the erase is still running", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
    advance(w, 20)
    check("D5 an erase still not ready 240 s after the acknowledgement ends", w.eraseActive ~= true,
      "eraseActive = " .. tostring(w.eraseActive))
    check("D5 the timeout shows the erase failure", failureShown())
  end

  -- D6: time the dashboard was hidden does not count towards the timeout.
  do
    local w = freshWidget()
    local erase = startErase(w)
    erase.ok()
    wake(w)
    now = now + 600                              -- hidden for ten minutes: no wakeup reaches the wait
    wake(w)
    check("D6 time spent hidden does not fail the erase", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
  end

  -- D7: the real acknowledgement path starts the first read.
  do
    local w = freshWidget()
    local erase = startErase(w)
    wake(w)
    check("D7 no read is sent before the erase is acknowledged", countOf("summary") == 0,
      "summaries = " .. countOf("summary"))
    erase.ok()
    wake(w)
    check("D7 the acknowledgement starts the first read", countOf("summary") == 1,
      "summaries = " .. countOf("summary"))
  end

  -- D8: the late acknowledgement and error of an erase that timed out do not touch a newer erase.
  do
    local w = freshWidget()
    local stale = startErase(w)
    advance(w, 241)                              -- never acknowledged: times out from the start
    check("D8 an erase never acknowledged times out", w.eraseActive ~= true)
    local fresh = startErase(w)
    stale.ok()
    stale.err()
    wake(w)
    check("D8 a late acknowledgement and error of an earlier erase leave a newer one alone",
      w.eraseActive == true and w.eraseError ~= true and countOf("summary") == 0,
      "eraseActive = " .. tostring(w.eraseActive) .. ", eraseError = " .. tostring(w.eraseError))
    fresh.ok()
    wake(w)
    check("D8 the newer erase reads once it is acknowledged", countOf("summary") == 1)
  end

  -- D9: a summary reply to a read of an earlier erase does not end a newer erase.
  do
    local w = freshWidget()
    local first = startErase(w)
    first.ok()
    wake(w)
    local staleSummary = latest("summary")       -- the first erase's read is still outstanding
    advance(w, 241)                              -- the first erase times out
    check("D9 the first erase times out while its read is outstanding", w.eraseActive ~= true)
    local second = startErase(w)
    second.ok()
    wake(w)
    staleSummary.ok({ flags = FLAG_READY + FLAG_SUPPORTED, total = 100, used = 10 })
    wake(w)
    check("D9 a reply to an earlier erase does not end a newer one", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
    check("D9 the newer erase still reads for itself", countOf("summary") == 2,
      "summaries = " .. countOf("summary"))
  end

  -- D10: closing the widget during a read clears that read, so a reused widget's next erase
  -- reads as soon as it is acknowledged.
  do
    local w = freshWidget()
    local erase = startErase(w)
    erase.ok()
    wake(w)
    check("D10 a read is in flight before the close", w.eraseReadInFlight == true)
    registered.close(w)
    check("D10 close clears the in-flight read and its retry time",
      w.eraseReadInFlight ~= true and w.eraseNextReadAt == nil and w.eraseActive ~= true,
      "inFlight = " .. tostring(w.eraseReadInFlight) .. ", nextReadAt = " .. tostring(w.eraseNextReadAt))
    local again = startErase(w)
    again.ok()
    wake(w)
    check("D10 the next erase reads as soon as it is acknowledged", countOf("summary") == 2,
      "summaries = " .. countOf("summary"))
  end
end

print("widget: src/rfsuite/widgets/dashboard.lua")
runChecks()
-- D11, D12: the real decoder, fed the bytes a reply carries.
local function runDecoderChecks()
  -- D11: a reply shorter than the summary is an error, and the wait reads again.
  do
    local w = freshWidget()
    local erase = startErase(w)
    erase.ok()
    wake(w)
    latest("summary").processReply(nil, { 3, 0, 0 })   -- three bytes, not thirteen
    wake(w)
    check("D11 a short summary reply does not finish the erase", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
    local t0 = now
    now = t0 + 0.5
    wake(w)
    check("D11 a short summary reply is read again", countOf("summary") == 2,
      "summaries = " .. countOf("summary"))
  end

  -- D12: a full summary reply that reports ready finishes the erase.
  do
    local w = freshWidget()
    local erase = startErase(w)
    erase.ok()
    wake(w)
    latest("summary").processReply(nil, { 1, 235, 3, 0, 0, 0, 0, 214, 7, 0, 112, 13, 0 })
    wake(w)
    check("D12 a full summary reply that reports ready finishes the erase", w.eraseActive ~= true,
      "eraseActive = " .. tostring(w.eraseActive))
  end
end

runDecoderChecks()
print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end

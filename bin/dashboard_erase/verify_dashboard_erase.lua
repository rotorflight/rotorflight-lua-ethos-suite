-- Behaviour check for the dashboard's erase wait (follow-up to #2495, found on the
-- Rotorflight Dashboard widget, not the status page).
--
-- Run it:
--     lua5.4 bin/dashboard_erase/verify_dashboard_erase.lua
--
-- What it drives: the real src/rfsuite/widgets/dashboard.lua through the widget table
-- it registers with system.registerWidget(). The bus, the MSP messages, the clock and the
-- forms are stubs; every message is recorded and each reply is given by the scenario.
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

-- ---------------------------------------------------------------------------
-- Clock: the wait is timed with os.clock(), so the scenario moves it by hand.
-- ---------------------------------------------------------------------------
local now = 100
os.clock = function() return now end

-- ---------------------------------------------------------------------------
-- Stubs.
-- ---------------------------------------------------------------------------
local sent, registered, dialogs, progresses = {}, nil, {}, {}

local function anyStub()
  return setmetatable({}, { __index = function() return function() return {} end end })
end

local function noop() end

lcd = setmetatable({ RGB = function() return 0 end, isVisible = function() return true end },
  { __index = function() return noop end })
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

local dataflashSummaryMsg = {
  buildReadMessage = function(ok, err) return { kind = "summary", ok = ok, err = err } end,
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
    }
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

-- Starts an erase the way the toolbar does, bypassing the confirmation dialog.
local function startErase(w)
  w.eraseActive = true
  w.eraseStartedAt = now
  w.eraseWaited = 0
  w.eraseLastTick = now
  w.eraseGeneration = (w.eraseGeneration or 0) + 1
  w.eraseProgressValue = 0
  w.eraseReadPending = false
  w.eraseDone = false
  w.eraseError = false
  -- doEraseBlackbox() is local; its effect is the erase command and the progress dialog.
  progresses[#progresses + 1] = { closed = false, value = noop, closeAllowed = noop,
    close = function() progresses[#progresses].closed = true end }
  return latest("erase")
end

local function summaryReply(flags)
  latest("summary").ok({ flags = flags, total = 100, used = 10 })
end

-- ---------------------------------------------------------------------------
-- Scenarios.
-- ---------------------------------------------------------------------------
local function runChecks()
  -- D1: a read right after the erase acknowledgement that reports "not ready yet" does not
  -- end the wait; a later read that reports ready does.
  do
    local w = freshWidget()
    -- the erase command is acknowledged: the page now reads the summary once
    w.eraseActive = true
    w.eraseStartedAt = now
    w.eraseReadPending = true
    wake(w)
    summaryReply(FLAG_SUPPORTED)                 -- not ready: still erasing
    wake(w)
    check("D1 a read that reports not ready does not finish the erase", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
    now = now + 1                                 -- the retry is due after half a second
    wake(w)
    check("D1 the wait reads again while the erase runs", latest("summary") ~= nil and countOf("summary") >= 2)
    summaryReply(FLAG_READY + FLAG_SUPPORTED)     -- ready now
    wake(w)
    check("D1 a read that reports ready finishes the erase", w.eraseActive ~= true,
      "eraseActive = " .. tostring(w.eraseActive))
  end

  -- D2: a board without dataflash finishes the wait at the first answer.
  do
    local w = freshWidget()
    w.eraseActive = true
    w.eraseStartedAt = now
    w.eraseReadPending = true
    wake(w)
    summaryReply(0)
    wake(w)
    check("D2 a board without dataflash finishes the erase", w.eraseActive ~= true,
      "eraseActive = " .. tostring(w.eraseActive))
  end

  -- D3: a read that fails does not finish the wait.
  do
    local w = freshWidget()
    w.eraseActive = true
    w.eraseStartedAt = now
    w.eraseReadPending = true
    wake(w)
    latest("summary").err()
    wake(w)
    check("D3 a failed read does not finish the erase", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
  end

  -- D4: an erase that never reports ready fails after the timeout, and shows the failure.
  -- The timeout is 240 s of awake time (a full chip erase takes up to 200 s).
  do
    local w = freshWidget()
    w.eraseActive = true
    w.eraseStartedAt = now
    w.eraseLastTick = now
    w.eraseWaited = 0
    w.eraseReadPending = true
    wake(w)
    summaryReply(FLAG_SUPPORTED)
    for _ = 1, 230 do
      now = now + 1
      wake(w)
    end
    check("D4 an erase still running after 230 s is not reported as failed", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
    for _ = 1, 20 do
      now = now + 1
      wake(w)
    end
    check("D4 an erase that never reports ready ends after the timeout", w.eraseActive ~= true,
      "eraseActive = " .. tostring(w.eraseActive))
    check("D4 the timeout shows the erase failure", #dialogs >= 1)
  end

  -- D5: time the dashboard was hidden does not count towards the timeout.
  do
    local w = freshWidget()
    w.eraseActive = true
    w.eraseStartedAt = now
    w.eraseLastTick = now
    w.eraseWaited = 0
    w.eraseReadPending = true
    wake(w)
    summaryReply(FLAG_SUPPORTED)
    now = now + 600                     -- hidden for ten minutes: no wakeup reaches the wait
    wake(w)
    check("D5 time spent hidden does not fail the erase", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
  end

  -- D6: a reply to a read of an earlier erase does not end a newer erase.
  do
    local w = freshWidget()
    startErase(w)                       -- erase A
    w.eraseReadPending = true           -- the acknowledgement asks for the first read
    wake(w)
    local staleSummary = latest("summary")
    startErase(w)                       -- erase B starts while A's read is still outstanding
    staleSummary.ok({ flags = FLAG_READY + FLAG_SUPPORTED, total = 100, used = 10 })
    wake(w)                             -- the dashboard looks at the wait again
    check("D6 a reply to an earlier erase does not end a newer one", w.eraseActive == true,
      "eraseActive = " .. tostring(w.eraseActive))
  end
end

print("widget: src/rfsuite/widgets/dashboard.lua")
runChecks()
print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end

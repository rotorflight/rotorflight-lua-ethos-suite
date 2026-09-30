-- Behaviour check for the flight-log flush (#2385).
--
-- Run it:
--     lua5.3 bin/logging/verify_log_flush_retry.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/tasks/logging.lua under stubs for the five things it
--     reaches out to (bus, settings store, debug log, ini, atomic write). It is
--     driven through its own public surface -- setTelemetrySensors(),
--     setSettings(), wakeup(), and the session.update the bus would deliver --
--     so every case goes through the same path a flight takes, not a local.
--   * io.open is the seam. A card that cannot be opened, and a handle whose
--     write() raises, are the two conditions the fix is about, and both are
--     things a real SD card does; neither is reachable by a build step.
--   * Every sample is identifiable: the stubbed sensor returns a counter in the
--     voltage column, so "was row 1 written?" is a fact about the bytes in the
--     file rather than a row count.
--
-- Which cases go RED on the pre-fix logging.lua:
--   1. an io.open that fails must not empty the queue -- pre-fix it does, and
--      the samples are gone before the card comes back
--   2. a failing write() must not shorten the queue -- pre-fix it trims anyway
--   3. either failure must say so -- pre-fix both paths are silent
--   6. a log that ends with unwritten rows must report them -- pre-fix it drops
--      them without a word
--   7. a paused log keeps its rows, because it resumes -- pre-fix pause()'s
--      flush(true) empties the queue on the same open failure as case 1
-- Cases 4, 5 and 8 pin behaviour that has to survive the fix.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0

-- The real print, held before _G.print is replaced below. The suite prints
-- through the same global, and the whole point of cases 3 to 6 is what it
-- prints -- so output is captured, not swallowed, and a silent stub here would
-- make this file's most important assertion pass for the wrong reason.
local out = print
local printed = {}

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

local function linesMatching(needle)
  local n = 0
  for _, line in ipairs(printed) do
    if line:find(needle, 1, true) then n = n + 1 end
  end
  return n
end

-- ── the seams ──────────────────────────────────────────────────────────────

-- Row N carries ", N, 0, 0, 0, 0" in the voltage column, so row 1 is
-- ", 1, 0, 0, 0, 0". Written rows are searched for that exact text.
local FIRST_ROW = ", 1, 0, 0, 0, 0"

local csv = ""            -- everything the logger has actually written
local openShouldFail = false
local writeShouldFail = false
local openAttempts = 0

local realOpen = io.open

local function csvHandle()
  local h
  h = {
    write = function(_, text)
      if writeShouldFail then error("simulated card write failure") end
      csv = csv .. text
      return h
    end,
    flush = function()
      if writeShouldFail then error("simulated card write failure") end
    end,
    close = function() end,
  }
  return h
end

-- Only the CSV path is intercepted; everything else goes to the real io.open,
-- so nothing else in the process loses the ability to read a file.
io.open = function(path, mode)
  if type(path) == "string" and path:find("%.csv$") then
    openAttempts = openAttempts + 1
    if openShouldFail then return nil end
    return csvHandle()
  end
  return realOpen(path, mode)
end

local realMkdir = os.mkdir
os.mkdir = function() return true end

-- ── Ethos environment ──────────────────────────────────────────────────────

local SUITE_PREFIX = SUITE .. "/"
package.path = SUITE_PREFIX .. "?.lua;" .. package.path
_G.PREFIX = SUITE_PREFIX

local realLoadfile = loadfile

-- requireModule() calls loadfile() with a path that carries no directory part;
-- on the radio the working directory is src/rfsuite. Same redirect the tool_ui
-- harness uses, for the same reason.
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
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = { getVersion = function() return { simulation = false, radio = { name = "stub" } } end }

-- Captured, and prefixed so a stray suite line is never mistaken for the
-- logger's own diagnostics.
_G.print = function(message)
  printed[#printed + 1] = tostring(message)
end

-- ── module stubs ───────────────────────────────────────────────────────────
--
-- Pre-seeded under the keys lib/require.lua derives, so requireModule() finds
-- them without a loadfile (require.lua:77-78).

local sessionHandler = nil

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function(topic, handler)
    if topic == "session.update" then sessionHandler = handler end
  end,
  unsubscribe = function() end,
  publish = function() end,
}
package.loaded["rfsuite.lib.settings_store"] = {
  loggingEnabled = function() return true end,
  -- 0, so every wakeup() takes a sample and the flush gate is reached by
  -- queue depth alone -- os.clock() is CPU time and barely moves in a loop, so
  -- the FLUSH_INTERVAL half of that condition would otherwise never fire here
  -- and every case below would have to count wall-clock seconds.
  loggingSampleInterval = function() return 0 end,
  debugLogsEnabled = function() return true end,
  mspLogsEnabled = function() return false end,
  load = function() return {} end,
}
package.loaded["rfsuite.lib.debug_log"] = {
  print = function(m) printed[#printed + 1] = tostring(m) end,
  format = function(fmt, ...) printed[#printed + 1] = string.format(fmt, ...) end,
  msp = function() end,
  enabled = function() return true end,
  mspEnabled = function() return false end,
}
package.loaded["rfsuite.lib.ini"] = {
  save_ini_file = function() return true end,
  load_ini_file = function() return {} end,
}
package.loaded["rfsuite.lib.atomic_write"] = {
  -- start() only needs this to succeed; the header it would write is not what
  -- any case here inspects.
  write = function() return true end,
  stage = function() return nil end,
  commit = function() return true end,
  abort = function() end,
}

-- ── the subject ────────────────────────────────────────────────────────────

local logging = dofile(SUITE .. "/tasks/logging.lua")

-- ── driving it ─────────────────────────────────────────────────────────────

local PROTOCOL = 1
local rowCounter = 0

logging.setTelemetrySensors({
  getValue = function(_, name)
    if name == "voltage" then
      rowCounter = rowCounter + 1
      return rowCounter
    end
    return 0
  end,
})
logging.setSettings({})

local function publishSession(snapshot)
  if sessionHandler then sessionHandler(snapshot) end
end

-- Arms the logger without arming anything: session.update is the only thing
-- that decides inFlight(), so this is the whole "we are flying" signal.
local function armSession()
  publishSession({
    connected = true,
    isArmed = true,
    mcuId = "0123456789",
    craftName = "Harness",
  })
end

-- 20 is FLUSH_QUEUE_SIZE in logging.lua:11, the point at which wakeup() calls
-- flush(false). Pumping to that depth is what makes a flush happen at all.
local FLUSH_AT = 20

local function pump(times)
  for _ = 1, (times or FLUSH_AT) do logging.wakeup(PROTOCOL) end
end

local function resetLog()
  csv = ""
  printed = {}
  openShouldFail = false
  writeShouldFail = false
  openAttempts = 0
  rowCounter = 0
  publishSession({ connected = false, isArmed = false })
end

-- ── cases ──────────────────────────────────────────────────────────────────

out("case 1: an unopenable file must not empty the queue")
do
  resetLog()
  armSession()
  pump(1)                       -- first wakeup starts the log
  openShouldFail = true
  pump(FLUSH_AT - 1)            -- reach the flush depth and fail the open
  check("the open was actually attempted", openAttempts > 0,
    "openAttempts=" .. openAttempts)

  openShouldFail = false
  pump(1)                       -- next flush finds the card again
  check("the oldest sample survived the failed open", csv:find(FIRST_ROW, 1, true) ~= nil,
    "nothing in the file but: " .. (csv == "" and "<empty>" or csv))
end

out("")
out("case 2: a failing write must not shorten the queue")
do
  resetLog()
  armSession()
  pump(1)
  writeShouldFail = true
  pump(FLUSH_AT - 1)
  writeShouldFail = false
  pump(1)
  check("the oldest sample survived the failed write", csv:find(FIRST_ROW, 1, true) ~= nil,
    "nothing in the file but: " .. (csv == "" and "<empty>" or csv))
end

out("")
out("case 3: either failure must say so")
do
  resetLog()
  armSession()
  pump(1)
  openShouldFail = true
  pump(FLUSH_AT - 1)
  check("the open failure is reported", linesMatching("cannot open") > 0,
    "printed " .. #printed .. " line(s), none about the open")
  check("the report says the samples are kept, not lost",
    linesMatching("keeping") > 0, "no line mentions what happened to the queue")

  resetLog()
  armSession()
  pump(1)
  writeShouldFail = true
  pump(FLUSH_AT - 1)
  check("the write failure is reported", linesMatching("write to") > 0,
    "printed " .. #printed .. " line(s), none about the write")
  -- Tied to the failure wording, not to the bare tag: start() already prints
  -- "[logging] started <file>", so matching "[logging]" alone would be satisfied
  -- by the logger working correctly and would prove nothing here.
  check("the failure line carries the [logging] tag",
    linesMatching("[logging] cannot open") + linesMatching("[logging] write to") > 0,
    "the failure is reported without the module prefix, so it cannot be traced")
end

out("")
out("case 4: a persistent failure reports once, not once per flush")
do
  resetLog()
  armSession()
  pump(1)
  openShouldFail = true
  pump(FLUSH_AT * 3)            -- three more flushes, same failure
  local n = linesMatching("cannot open")
  check("the open failure is reported exactly once", n == 1, "reported " .. n .. " times")
end

out("")
out("case 5: a new streak after a success is reported again")
do
  resetLog()
  armSession()
  pump(1)
  openShouldFail = true
  pump(FLUSH_AT - 1)
  check("first streak reported", linesMatching("cannot open") == 1)

  openShouldFail = false
  pump(1)                       -- recovers, so the latch has to clear
  check("the recovery wrote the file", csv:find(FIRST_ROW, 1, true) ~= nil)

  -- Second streak as a *write* failure, and that is not an arbitrary choice:
  -- once a flush has succeeded the handle is held open, so a card that goes
  -- away does not fail io.open (it is not called again) -- it fails the write,
  -- which is the path that closes the handle. An open failure here would never
  -- be reached and the case would prove nothing.
  writeShouldFail = true
  pump(FLUSH_AT)
  check("the second streak is reported too", linesMatching("write to") == 1,
    "reported " .. linesMatching("write to") .. " time(s), expected 1")
  check("both streaks are in the log", linesMatching("keeping") == 2,
    "reported " .. linesMatching("keeping") .. " line(s), expected 2")
end

out("")
out("case 6: a log that ends with unwritten rows reports them")
do
  resetLog()
  armSession()
  pump(1)
  openShouldFail = true
  pump(FLUSH_AT - 1)
  publishSession({ connected = false, isArmed = false })   -- disarm -> stop()
  check("the lost rows are counted", linesMatching("unwritten samples") > 0,
    "a log that ended with unwritten rows said nothing")

  -- And the next flight must not inherit them: stop() is what makes the queue
  -- empty again, so a fresh start() writes a file that begins with its own
  -- first sample and not one from the previous flight.
  resetLog()
  armSession()
  pump(1)
  pump(FLUSH_AT)
  local rows = select(2, csv:gsub("\n", ""))
  check("the next flight's file holds only its own rows", rows == FLUSH_AT,
    "file has " .. rows .. " rows, expected " .. FLUSH_AT)
end

out("")
out("case 7: a paused log keeps its rows, because it resumes")
do
  resetLog()
  armSession()
  pump(1)
  openShouldFail = true
  pump(FLUSH_AT - 1)
  -- flightResumable with isArmed unset: flight_timer's "same flight" answer,
  -- which is the branch that pauses instead of stopping.
  publishSession({ connected = false, flightResumable = true, mcuId = "0123456789" })

  openShouldFail = false
  armSession()
  pump(1)
  check("the resumed flush wrote the rows taken during the pause",
    csv:find(FIRST_ROW, 1, true) ~= nil,
    "a paused log dropped its samples instead of holding them")
end

out("")
out("case 8: a healthy flight is unchanged")
do
  resetLog()
  armSession()
  pump(FLUSH_AT * 3)
  check("the file was written", csv ~= "", "nothing was written on a working card")
  -- Matched on the failure wording, not on the "[logging]" tag: start() already
  -- prints "[logging] started <file>" on a healthy card, and a check that
  -- counted that as a failure would be reporting the logger working.
  check("no failure was reported",
    linesMatching("cannot open") + linesMatching("write to")
      + linesMatching("unwritten samples") == 0,
    "printed " .. #printed .. " line(s): " .. table.concat(printed, " | "))
  check("the oldest sample is present", csv:find(FIRST_ROW, 1, true) ~= nil)
end

io.open = realOpen
os.mkdir = realMkdir

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
out("io.open attempts on the CSV path: " .. openAttempts)
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

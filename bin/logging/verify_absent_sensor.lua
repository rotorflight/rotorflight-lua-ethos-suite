-- Behaviour check for a sensor the aircraft is not sending (Issue #2440).
--
-- Run it:
--     lua5.4 bin/logging/verify_absent_sensor.lua
--
-- What it drives, and why:
--   * The real src/rfsuite/tasks/logging.lua under the same stubs the flush
--     harness uses for the five modules it reaches out to (bus, settings store,
--     debug log, ini, atomic write). It is driven through its own public
--     surface -- setTelemetrySensors(), setSettings(), wakeup(), and the
--     session.update the bus would deliver -- so every row goes through the
--     path a flight takes.
--   * io.open on the CSV path is the seam. The check reads the bytes that reach
--     the file, not a copy of the row format held in this test.
--   * The sensor is a fake whose getValue() returns nil ("not sending"), a real
--     number, or nothing set at all, per case.
--
-- Which cases go RED on the pre-fix logging.lua (the sensorValue() that turned
-- nil into 0):
--   1. a sensor that is not sending is an empty field, not 0
--   2. with no sensor set at all, every column is an empty field, not 0
--   4. a sensor that starts sending later is written as an empty field until
--      it does, and as its value from then on
-- Cases 3 and 5 pin behaviour that has to survive the fix:
--   3. a real 0 is still written as "0" -- a zero A draw is a measurement
--   5. no "nil" text reaches the file, and every row keeps its column count

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")

local checks, failures = 0, 0

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

-- ── the seams ──────────────────────────────────────────────────────────────

local csv = ""
local realOpen = io.open

local function csvHandle()
  local h
  h = {
    write = function(_, text)
      csv = csv .. text
      return h
    end,
    flush = function() end,
    close = function() end,
  }
  return h
end

-- Only the CSV path is intercepted; everything else goes to the real io.open.
io.open = function(path, mode)
  if type(path) == "string" and path:find("%.csv$") then
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
_G.model = { get = function() return 0 end, name = function() return "stub" end }
_G.system = { getVersion = function() return { simulation = false, radio = { name = "stub" } } end }

_G.print = function(message)
  printed[#printed + 1] = tostring(message)
end

-- ── module stubs ───────────────────────────────────────────────────────────

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
  -- 0, so every wakeup() takes a sample; the flush is then reached by queue
  -- depth alone, the same way the flush harness drives it.
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
  write = function() return true end,
  stage = function() return nil end,
  commit = function() return true end,
  abort = function() end,
}

-- ── the subject ────────────────────────────────────────────────────────────

local logging = dofile(SUITE .. "/tasks/logging.lua")

-- ── driving it ─────────────────────────────────────────────────────────────

local PROTOCOL = 1
local FLUSH_AT = 20   -- FLUSH_QUEUE_SIZE in logging.lua

-- What the fake sensor reports for each column on the next sample. A nil entry
-- is a sensor the aircraft is not sending.
local readings = {}

local function fakeSensors()
  return {
    getValue = function(_, name) return readings[name] end,
  }
end

local function publishSession(snapshot)
  if sessionHandler then sessionHandler(snapshot) end
end

local function armSession()
  publishSession({
    connected = true,
    isArmed = true,
    mcuId = "0123456789",
    craftName = "Harness",
  })
end

local function pump(times)
  for _ = 1, times do logging.wakeup(PROTOCOL) end
end

-- Ends the previous case's log first, and clears the file only afterwards:
-- stop() writes whatever is still queued, and that must not land in this
-- case's file.
local function resetLog()
  publishSession({ connected = false, isArmed = false })
  logging.close()
  csv = ""
  printed = {}
  readings = {}
end

-- ── reading the file back ──────────────────────────────────────────────────

-- Index of a column in the row, counting the time field as 1.
local function fieldIndex(name)
  for i, column in ipairs(logging.getLogTable()) do
    if column.name == name then return i + 1 end
  end
  error("no such log column: " .. name)
end

local FIELD_COUNT = #logging.getLogTable() + 1

local function dataRows()
  local rows = {}
  for line in csv:gmatch("[^\n]+") do
    if line:sub(1, 4) ~= "time" then rows[#rows + 1] = line end
  end
  return rows
end

-- Splits a row on commas and trims each field; an empty field stays "".
local function fieldsOf(row)
  local fields = {}
  for field in (row .. ","):gmatch("([^,]*),") do
    fields[#fields + 1] = field:match("^%s*(.-)%s*$")
  end
  return fields
end

local function describe(row)
  return row and ("row: " .. row) or "no row was written"
end

-- ── cases ──────────────────────────────────────────────────────────────────

out("case 2: no sensor set at all -- every column empty, not 0")
do
  -- Must run before setTelemetrySensors(): the logger has no sensor yet.
  resetLog()
  logging.setSettings({})
  armSession()
  pump(FLUSH_AT)
  local rows = dataRows()
  check("the file has rows", #rows > 0, "no rows written")
  local allEmpty = #rows > 0
  for _, row in ipairs(rows) do
    local f = fieldsOf(row)
    for i = 2, FIELD_COUNT do
      if f[i] ~= "" then allEmpty = false end
    end
  end
  check("every column is an empty field", allEmpty, describe(rows[1]))
end

logging.setTelemetrySensors(fakeSensors())

out("case 1: a sensor the aircraft is not sending is an empty field, not 0")
do
  resetLog()
  readings = { voltage = 12.1, current = nil, rpm = 4000, temp_esc = 50, throttle_percent = 60 }
  armSession()
  pump(FLUSH_AT)
  local rows = dataRows()
  check("the file has rows", #rows > 0, "no rows written")
  local current = fieldIndex("current")
  local absentEmpty, othersKept = #rows > 0, #rows > 0
  for _, row in ipairs(rows) do
    local f = fieldsOf(row)
    if f[current] ~= "" then absentEmpty = false end
    if f[fieldIndex("voltage")] ~= "12.1" or f[fieldIndex("rpm")] ~= "4000" then othersKept = false end
  end
  check("the absent column is an empty field", absentEmpty, describe(rows[1]))
  check("the sensors that are sending keep their values", othersKept, describe(rows[1]))
  check("the row keeps its column count", #fieldsOf(rows[1] or "") == FIELD_COUNT,
    "fields=" .. #fieldsOf(rows[1] or "") .. " expected=" .. FIELD_COUNT)
end

out("case 3: a real 0 is still written as \"0\"")
do
  resetLog()
  readings = { voltage = 12.1, current = 0, rpm = 4000, temp_esc = 50, throttle_percent = 60 }
  armSession()
  pump(FLUSH_AT)
  local rows = dataRows()
  check("the file has rows", #rows > 0, "no rows written")
  local current = fieldIndex("current")
  local allZero = #rows > 0
  for _, row in ipairs(rows) do
    if fieldsOf(row)[current] ~= "0" then allZero = false end
  end
  check("a sensor that reads 0 is written as 0", allZero, describe(rows[1]))
end

out("case 4: a sensor that starts sending later is written from then on")
do
  resetLog()
  readings = { voltage = 12.1, current = nil, rpm = 4000, temp_esc = 50, throttle_percent = 60 }
  armSession()
  pump(FLUSH_AT)
  readings.current = 7.5
  pump(FLUSH_AT)
  local rows = dataRows()
  local current = fieldIndex("current")
  local first = rows[1] and fieldsOf(rows[1])[current]
  local last = rows[#rows] and fieldsOf(rows[#rows])[current]
  check("the rows before it arrived are empty", first == "",
    "first current field=" .. tostring(first) .. " (" .. describe(rows[1]) .. ")")
  check("the rows after it arrived carry the value", last == "7.5",
    "last current field=" .. tostring(last) .. " (" .. describe(rows[#rows]) .. ")")
end

out("case 5: no \"nil\" text reaches the file, and the column count holds")
do
  resetLog()
  readings = {}   -- every sensor absent
  armSession()
  pump(FLUSH_AT)
  local rows = dataRows()
  check("the file has rows", #rows > 0, "no rows written")
  check("the text \"nil\" never appears", not csv:find("nil", 1, true), describe(rows[1]))
  local countsHold = #rows > 0
  for _, row in ipairs(rows) do
    if #fieldsOf(row) ~= FIELD_COUNT then countsHold = false end
  end
  check("every row keeps its column count", countsHold,
    "expected " .. FIELD_COUNT .. " fields per row")
end

resetLog()
io.open = realOpen
os.mkdir = realMkdir

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d", checks, failures))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

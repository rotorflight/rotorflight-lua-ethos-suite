-- Behaviour check for #2506: the Logs page reads a CSV column by the name in its
-- header row, skips a column the file does not carry, and draws nothing for a file
-- without data rows instead of a flat zero line.
--
-- Run it:
--     lua5.4 bin/log_columns/verify_log_columns.lua
--     lua5.4 bin/log_columns/verify_log_columns.lua --self-test
--
-- What it drives: the real src/rfsuite/lib/log_columns.lua, the pure reader that
-- app/pages/logs.lua calls. The page wiring itself is not driven here: the page needs
-- the full UI. The check is that the page passes the header map and the row count
-- through unchanged, which is a code reading, not a run.
--
-- Against the position-based reader of unpatched master, the foreign-order and
-- missing-column checks go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local MODULE = ROOT .. "/src/rfsuite/lib/log_columns.lua"

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

local function sameList(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

local function listText(t)
  local parts = {}
  for i = 1, #t do parts[i] = tostring(t[i]) end
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

local function runChecks(lib)
  -- C1: a file written by this suite. Its header names are the page's own names.
  do
    local csv = "time, voltage, current, rpm, temp_esc, throttle_percent\n1,12.5,3.1,900,45,60\n"
    local map = lib.headerIndex(csv)
    check("C1 suite log: names map to their positions",
      map.voltage == 2 and map.current == 3 and map.rpm == 4 and map.temp_esc == 5
        and map.throttle_percent == 6, "map: voltage=" .. tostring(map.voltage))
  end

  -- C2: a file in another column order. The name decides the column, not the position.
  do
    local csv = "time, rpm, voltage\n1,100,12.5\n2,200,12.1\n"
    local map = lib.headerIndex(csv)
    check("C2 foreign order: voltage is column 3, rpm is column 2",
      map.voltage == 3 and map.rpm == 2, "voltage=" .. tostring(map.voltage) .. " rpm=" .. tostring(map.rpm))
    check("C2 voltage values come from the voltage column",
      sameList(lib.column(csv, map.voltage), {12.5, 12.1}),
      "got " .. listText(lib.column(csv, map.voltage)))
    check("C2 rpm values come from the rpm column",
      sameList(lib.column(csv, map.rpm), {100, 200}), "got " .. listText(lib.column(csv, map.rpm)))
  end

  -- C3: a column the file does not carry has no index, so the page skips it.
  do
    local csv = "time, rpm\n1,100\n"
    check("C3 a column the header does not name is absent (not position 2)",
      lib.headerIndex(csv).voltage == nil)
  end

  -- C4: a header-only file has no data rows, so nothing is drawn.
  do
    local csv = "time, voltage\n"
    check("C4 header-only file has zero data rows", lib.dataRowCount(csv) == 0)
    check("C4 header-only file gives an empty column", #lib.column(csv, 2) == 0)
  end

  -- C5: an empty file names no column and has no rows.
  do
    check("C5 empty file names no column", next(lib.headerIndex("")) == nil)
    check("C5 empty file has zero data rows", lib.dataRowCount("") == 0)
  end

  -- C6: Windows line endings do not add rows or break the names.
  do
    local csv = "time, voltage\r\n1,12.5\r\n2,12.4\r\n"
    check("C6 CRLF: two data rows", lib.dataRowCount(csv) == 2, "rows: " .. lib.dataRowCount(csv))
    check("C6 CRLF: the name is found", lib.headerIndex(csv).voltage == 2)
    check("C6 CRLF: values are read", sameList(lib.column(csv, 2), {12.5, 12.4}),
      "got " .. listText(lib.column(csv, 2)))
  end

  -- C7: a value that is not a number is 0 (as before), and a short row gives 0.
  do
    local csv = "time, voltage, rpm\n1,abc\n2,12.1,300\n"
    check("C7 non-numeric value and short row read as 0",
      sameList(lib.column(csv, 2), {0, 12.1}), "got " .. listText(lib.column(csv, 2)))
    check("C7 the short row gives 0 for a later column",
      sameList(lib.column(csv, 3), {0, 300}), "got " .. listText(lib.column(csv, 3)))
  end

  -- C8: spaces around a name are ignored, and a repeated name keeps its first column.
  do
    check("C8 spaces around a name are ignored", lib.headerIndex("time,  voltage ,x\n").voltage == 2)
    check("C8 a repeated name keeps its first column", lib.headerIndex("time, voltage, voltage\n").voltage == 2)
  end
end

local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

print("module: src/rfsuite/lib/log_columns.lua")
runChecks(dofile(MODULE))

if selfTest then
  print("")
  print("--self-test: the checks must go red for a position-based reader")
  local source = readFile(MODULE)
  local spliced, n = source:gsub("function M%.headerIndex%(csvText%)",
    "function M.headerIndex(csvText)\n  if csvText then return {voltage = 2, current = 3, rpm = 4, temp_esc = 5, throttle_percent = 6} end", 1)
  assert(n == 1, "splice did not apply")
  local lib = assert(load(spliced, "@log_columns_positional"))()
  local before = failures
  runChecks(lib)
  local red = failures > before
  failures = before
  check("the foreign-order and missing-column checks go red for a position-based reader", red)
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end

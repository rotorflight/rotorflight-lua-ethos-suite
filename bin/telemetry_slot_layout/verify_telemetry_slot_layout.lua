-- Behaviour check for the slot placement of a Telemetry save (issue #2671),
-- and for the ELRS sync's fresh read before it writes (issue #2674).
--
-- Run it from the repository root:
--     lua5.4 bin/telemetry_slot_layout/verify_telemetry_slot_layout.lua
--
-- What it drives, and why:
--   * lib/telemetry_slot_layout.lua is the whole placement rule, with no
--     dependency on form, catalog or runtime. A sensor that stays selected keeps
--     its slot; a deselected one frees it; a new one takes the first free slot.
--     Before the fix, every save refilled the managed slots in catalogue order.
--   * The page must hand its save to that module, and the ELRS sync must read
--     the FC's telemetry config again before it writes it back (the source
--     checks below; the sync itself needs a radio).

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."

local failures = 0
local checks = 0

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

local function readFile(relative)
  local f = io.open(ROOT .. "/" .. relative, "rb")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end

local function same(a, b, slotCount)
  for i = 1, slotCount do
    if (a[i] or 0) ~= (b[i] or 0) then return false end
  end
  return true
end

local function show(t, slotCount)
  local parts = {}
  for i = 1, slotCount do parts[#parts + 1] = tostring(t[i] or 0) end
  return "{" .. table.concat(parts, ",") .. "}"
end

local layout = dofile(ROOT .. "/src/rfsuite/lib/telemetry_slot_layout.lua")

-- Ids 10..50 are managed by the page; 200 stands for a native CRSF slot.
local managed = {[10] = true, [20] = true, [30] = true, [40] = true, [50] = true}
local function isManaged(id) return managed[id] == true end

print("placement")

do
  local slots = {10, 0, 20, 200, 30}
  local out = layout.place(slots, {10, 20, 30}, isManaged, 8)
  check("a save with no change keeps every position (including the gap)",
    same(out, {10, 0, 20, 200, 30}, 8), show(out, 8))
end

do
  local out = layout.place({10, 0, 20, 200, 30}, {10, 30}, isManaged, 8)
  check("switching off 20 frees only its slot",
    same(out, {10, 0, 0, 200, 30}, 8), show(out, 8))
end

do
  local out = layout.place({10, 0, 20, 200, 30}, {10, 20, 30, 50}, isManaged, 8)
  check("a new selection takes the first free slot, not the end of the list",
    out[2] == 50 and out[1] == 10 and out[3] == 20, show(out, 8))
  check("the native slot 200 keeps its position",
    out[4] == 200, show(out, 8))
end

do
  local out = layout.place({10, 10, 20}, {10, 20}, isManaged, 6)
  check("a duplicate managed id is freed, the first copy keeps its slot",
    same(out, {10, 0, 20, 0, 0, 0}, 6), show(out, 6))
end

do
  local out = layout.place(nil, {10, 20}, isManaged, 5)
  check("a short or missing slot array is filled from the front, the rest is empty",
    same(out, {10, 20, 0, 0, 0}, 5), show(out, 5))
end

do
  -- 40 slots: 3 native slots kept, 37 managed selected, one of them already placed
  local slots, wanted = {}, {}
  for i = 1, 40 do slots[i] = 0 end
  slots[1], slots[2], slots[3] = 200, 201, 202
  for i = 1, 37 do wanted[i] = 1000 + i end
  for i = 1, 37 do managed[1000 + i] = true end
  local out = layout.place(slots, wanted, isManaged, 40)
  local count = 0
  local seen = {}
  for i = 1, 40 do
    if out[i] ~= 0 then count = count + 1 end
    if seen[out[i]] and out[i] ~= 0 then count = -1000 end
    seen[out[i]] = true
  end
  check("37 new selections plus 3 native slots fill exactly 40 slots without duplicates",
    count == 40 and out[1] == 200 and out[2] == 201 and out[3] == 202, "count=" .. tostring(count))
end

print("wiring")

local page = readFile("src/rfsuite/app/pages/telemetry.lua") or ""
check("the Telemetry page requires lib/telemetry_slot_layout.lua",
  page:find('requireModule("lib/telemetry_slot_layout.lua")', 1, true) ~= nil)
check("the Telemetry page places its slots through the shared rule",
  page:find("slotLayout.place(", 1, true) ~= nil)
check("the Telemetry page no longer refills slots in catalogue order",
  page:find("slots[i] = orderedSelected[index]", 1, true) == nil)

local elrs = readFile("src/rfsuite/lib/elrslink_task.lua") or ""
local startAt = elrs:find("local function syncElrsToRotorflight(", 1, true)
-- The working copy is CRLF (.gitattributes: *.lua eol=crlf), so the end of the
-- function is the first line that starts with "end" at column 0, whatever its ending.
local endAt = startAt and elrs:find("\nend", startAt, true)
local body = (startAt and endAt) and elrs:sub(startAt, endAt) or ""
local readAt = body:find("telemetryConfig.buildReadConfigMessage(", 1, true)
local writeAt = body:find("telemetryConfig.buildWriteMessage(fresh", 1, true)
check("the ELRS sync reads the telemetry config before it writes it",
  readAt ~= nil and writeAt ~= nil and readAt < writeAt,
  string.format("read at %s, write at %s", tostring(readAt), tostring(writeAt)))
check("the ELRS sync writes the frame it has just read, not the cached copy",
  body:find("buildWriteMessage(fcConfigData", 1, true) == nil)

print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then os.exit(1) end

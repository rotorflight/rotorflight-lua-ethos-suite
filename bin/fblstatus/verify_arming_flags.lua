-- Behaviour check for the arming-disable flags on the FBL Status page (#2346).
--
-- Run it:
--     lua5.3 bin/fblstatus/verify_arming_flags.lua
--
-- What it drives, and why:
--   * lib/arming_flags.lua is the whole mask arithmetic and has no dependency
--     at all -- no form, no lcd, no bus -- so every case runs here rather than
--     on a radio. The page keeps the layout; that file keeps the arithmetic,
--     and the split is what makes this check possible.
--   * The i18n tags come out as the literal @i18n(...)@ strings, because that
--     is what the module holds; the widths of the translated strings are a
--     separate question and are checked by verify_arming_flag_widths.py,
--     which is the half of #2346 that needs the locale files.
--
-- The cases that describe the OLD behaviour are the point: the page used to
-- join every active flag into one value-column string, and a check that only
-- describes the new one would pass just as happily against the old code.

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

local arming = dofile(ROOT .. "/src/rfsuite/lib/arming_flags.lua")

local function tagFor(bit)
  return "@i18n(app.modules.fblstatus.arming_disable_flag_" .. bit .. ")@"
end

-- ---------------------------------------------------------------------------
-- The mask
-- ---------------------------------------------------------------------------

print("arming-disable mask")

check("an empty mask has no active flags", #arming.active(0) == 0)
check("a nil mask is an empty mask", #arming.active(nil) == 0)
check("a non-numeric mask is an empty mask", #arming.active("nonsense") == 0)
check("a negative mask is an empty mask", #arming.active(-4) == 0)
check("a NaN mask is an empty mask", #arming.active(0 / 0) == 0)

-- Every one of the 26 named bits on its own: one entry, and the right name.
local allBitsOk, allBitsDetail = true, nil
for bit = 0, arming.FLAG_COUNT - 1 do
  local mask = 2 ^ bit
  local active = arming.active(mask)
  if #active ~= 1 or active[1] ~= tagFor(bit) then
    allBitsOk = false
    allBitsDetail = string.format("bit %d gave %d entries, first %s", bit, #active, tostring(active[1]))
    break
  end
end
check("each of the 26 named bits decodes to exactly its own name", allBitsOk, allBitsDetail)

-- The mask from #2346: Fail Safe, Throttle, Calibrating, MSP, Arm Switch --
-- the five that are typically set together on the bench.
local BENCH = 2 ^ 1 + 2 ^ 7 + 2 ^ 12 + 2 ^ 16 + 2 ^ 25
check("the bench mask has five active flags", arming.count(BENCH) == 5, arming.count(BENCH))

check(
  "the bench mask decodes lowest bit first",
  table.concat(arming.active(BENCH), ",") ==
    table.concat({tagFor(1), tagFor(7), tagFor(12), tagFor(16), tagFor(25)}, ","),
  table.concat(arming.active(BENCH), ","))

-- A bit this build does not name must not be silently dropped: a pilot who
-- cannot arm needs to see that something is holding the model, even if the
-- suite cannot name it.
local unknown = arming.active(2 ^ 30)
check("a bit above 25 is reported, not dropped", #unknown == 1 and unknown[1] == "0x40000000", table.concat(unknown, ","))

-- ---------------------------------------------------------------------------
-- What the page is allowed to put where
-- ---------------------------------------------------------------------------

print("value column vs. full-width rows")

local okText, okCount = arming.summary(0)
check("an empty mask summarises as the OK tag", okText == "@i18n(app.modules.fblstatus.ok)@", okText)
check("an empty mask counts zero", okCount == 0)

local fiveText, fiveCount = arming.summary(BENCH)
check("the bench mask counts five", fiveCount == 5)
check(
  "the summary is a count in the active template, never a flag name",
  fiveText == string.format(arming.ACTIVE_FMT, 5),
  fiveText)
check(
  "the summary carries no flag name",
  fiveText:find("arming_disable_flag", 1, true) == nil,
  fiveText)

-- The summary's rendered width is NOT checked here: this harness sees the
-- unresolved @i18n(...)@ tag, whose length says nothing about the string the
-- pilot reads. That half is verify_arming_flag_widths.py, which has the
-- locale files.
--
-- The old form, kept in the module only so this check can assert that it was
-- over budget. Five flag names in one value-column cell is what was clipped.
local joined = arming.joinedTextForComparison(BENCH)
check(
  "the old joined form really was over budget (>24 characters)",
  #joined > 24,
  string.format("the joined form is %d characters", #joined))
check(
  "the old joined form grows with the flag set",
  #arming.joinedTextForComparison(2 ^ 1) < #arming.joinedTextForComparison(2 ^ 1 + 2 ^ 25),
  "one flag vs two")

-- ---------------------------------------------------------------------------
-- The page's own use of it
-- ---------------------------------------------------------------------------

print("page wiring")

local function readFile(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local text = fh:read("*a")
  fh:close()
  return text
end

local page = readFile(ROOT .. "/src/rfsuite/app/pages/diagnostics_fblstatus.lua")
check("the page file is readable", page ~= nil)

if page then
  check("the page no longer builds a joined flag string", page:find("armingFlagsText", 1, true) == nil)
  check("the page takes its summary from the module", page:find("armingFlags.summary", 1, true) ~= nil)
  -- The detail rows have to be full-width lines; a value line would put the
  -- names back in the narrow column this change exists to get them out of.
  check("the page draws the names through addTextLine", page:find("common.addTextLine", 1, true) ~= nil)
  check("the page never writes a flag name into a value line", page:find("fields.arming, active", 1, true) == nil)
  check("the page still has its ten value lines", select(2, page:gsub("common%.addValueLine", "")) == 10,
    select(2, page:gsub("common%.addValueLine", "")))
end

-- ---------------------------------------------------------------------------

print("")
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.exit(1)

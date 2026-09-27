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

local combined = arming.active(2 ^ 1 + 2 ^ 30)
check(
  "an unknown bit is not swallowed when a known bit is also present",
  #combined == 2 and combined[1] == tagFor(1) and combined[2] == "0x40000000",
  table.concat(combined, ","))

local multiUnknown = arming.active(2 ^ 26 + 2 ^ 27)
check(
  "multiple unknown bits are each reported individually",
  #multiUnknown == 2 and multiUnknown[1] == "0x4000000" and multiUnknown[2] == "0x8000000",
  table.concat(multiUnknown, ","))

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
  check("the detail rows cleanup starts after active rows (#active + 2)",
    page:find("for i = #active + 2, #armingRows do", 1, true) ~= nil)
  check("the detail heading is restored if flags reappear",
    page:find("armingRows[1]:value(ARMING_DETAIL_HEADING)", 1, true) ~= nil)
end

-- ---------------------------------------------------------------------------
-- Detail rows pool behaviour (renderArmingDetails)
-- ---------------------------------------------------------------------------

print("detail rows pool behaviour")

local function createPoolHarness()
  local armingRows = {}
  local armingSignature = nil
  local common = {
    addTextLine = function(text, indent)
      local obj = { text = text, indent = indent }
      function obj:value(t) self.text = t end
      return obj
    end
  }
  local ARMING_DETAIL_HEADING = "Active reasons:"
  local ARMING_DETAIL_INDENT = 12

  local function renderArmingDetails(active)
    local signature = table.concat(active, "\1")
    if signature == armingSignature then return end
    armingSignature = signature

    if #active == 0 then
      for i = 1, #armingRows do armingRows[i]:value("") end
      return
    end

    if armingRows[1] == nil then
      armingRows[1] = common.addTextLine(ARMING_DETAIL_HEADING)
    else
      armingRows[1]:value(ARMING_DETAIL_HEADING)
    end
    for i = 1, #active do
      local row = armingRows[i + 1]
      if row == nil then
        row = common.addTextLine("", ARMING_DETAIL_INDENT)
        armingRows[i + 1] = row
      end
      row:value(active[i])
    end
    for i = #active + 2, #armingRows do
      armingRows[i]:value("")
    end
  end

  return { rows = armingRows, render = renderArmingDetails }
end

local pool = createPoolHarness()

-- 1. Single active reason: heading at row 1, reason at row 2, NOT blanked by cleanup
pool.render({"THROTTLE"})
check("single active flag: heading is present", pool.rows[1] and pool.rows[1].text == "Active reasons:")
check("single active flag: flag is visible and not blanked by cleanup", pool.rows[2] and pool.rows[2].text == "THROTTLE")
check("single active flag: exactly two rows created", #pool.rows == 2)

-- 2. Three active reasons: rows expand
pool.render({"FAILSAFE", "THROTTLE", "MSP"})
check("three active flags: heading is present", pool.rows[1].text == "Active reasons:")
check("three active flags: row 2 is FAILSAFE", pool.rows[2].text == "FAILSAFE")
check("three active flags: row 3 is THROTTLE", pool.rows[3].text == "THROTTLE")
check("three active flags: row 4 is MSP", pool.rows[4].text == "MSP")
check("three active flags: four rows total", #pool.rows == 4)

-- 3. All flags cleared (#active == 0): all rows blanked
pool.render({})
local allBlank = true
for i = 1, #pool.rows do
  if pool.rows[i].text ~= "" then allBlank = false break end
end
check("zero active flags: all rows are blanked", allBlank)

-- 4. Flags reappear (1 active flag): heading restored, row 2 set, rows 3..4 blanked
pool.render({"MSP"})
check("flags reappear: heading is restored", pool.rows[1].text == "Active reasons:")
check("flags reappear: active flag is set", pool.rows[2].text == "MSP")
check("flags reappear: previous row 3 is blanked", pool.rows[3].text == "")
check("flags reappear: previous row 4 is blanked", pool.rows[4].text == "")

-- ---------------------------------------------------------------------------

print("")
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.exit(1)

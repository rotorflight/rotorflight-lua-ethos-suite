-- Behaviour and lifecycle check for field_layout.lua slot pooling.
--
-- Run it:
--     lua5.3 bin/field_layout/verify_field_layout.lua
--
-- What it drives, and why:
--   * app/field_layout.lua pools accessor slots by (page, spec, kind, scale, decimals).
--     Ethos form widgets retain closures across form.clear(), so pooling prevents
--     unbounded closure growth across repeated page visits (see docs/memory-and-module-lifecycle.md §8).
--   * Tests poolStats() (count, live) across initial state, field building,
--     releaseRuntime(), and re-visiting pages.
--   * Verifies that releaseRuntime() detaches dataRef and controlRef safely:
--     subsequent get/set calls from retained widgets become harmless no-ops.
--   * Verifies number, choice, and bit accessors, including multi-source and FIELD_META.

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

-- ---------------------------------------------------------------------------
-- Ethos form mock
-- ---------------------------------------------------------------------------

form = {}

function form.addLine(label)
  return { label = label }
end

function form.getFieldSlots(line, hints)
  local slots = {}
  for i = 1, #hints do
    slots[i] = i
  end
  return slots
end

function form.addStaticText(line, slot, text)
  return { type = "text", line = line, slot = slot, text = text }
end

function form.addChoiceField(line, slot, choices, get, setWithDirty)
  return {
    type = "choice",
    line = line,
    slot = slot,
    choices = choices,
    get = get,
    set = setWithDirty,
  }
end

function form.addNumberField(line, slot, min, max, get, setWithDirty)
  local f = {
    type = "number",
    line = line,
    slot = slot,
    min = min,
    max = max,
    get = get,
    set = setWithDirty,
    step = true,
  }
  function f:decimals(d) self.dec = d end
  function f:suffix(s) self.suf = s end
  function f:step(st) self.stepVal = st end
  function f:default(def) self.defVal = def end
  return f
end

-- ---------------------------------------------------------------------------
-- Mock runtime factory
-- ---------------------------------------------------------------------------

local function newMockRuntime(logTag, initialData, mspModule)
  local rt = {
    logTag = logTag or "test_page",
    dataRef = { data = initialData or {} },
    controlRef = {},
    registeredFields = {},
    dirtyCount = 0,
    sources = {
      {
        key = "default",
        mspModule = mspModule or { FIELD_META = {} },
      },
      {
        key = "profile",
        mspModule = { FIELD_META = {} },
      },
    },
  }
  rt.controlRef.runtime = rt

  function rt:registerField(key, field)
    self.registeredFields[key] = field
  end

  function rt:markDirty()
    self.dirtyCount = self.dirtyCount + 1
  end

  function rt:refreshDirty()
    self.dirtyCount = self.dirtyCount + 1
  end

  return rt
end

-- ---------------------------------------------------------------------------
-- Load module under test
-- ---------------------------------------------------------------------------

package.loaded["rfsuite.app.field_layout"] = nil
local field_layout = dofile(ROOT .. "/src/rfsuite/app/field_layout.lua")

print("Checking field_layout slot pooling and lifecycle:")

-- Case 1: Initial state & poolStats
do
  local count, live = field_layout.poolStats()
  check("initial pool is empty", count == 0 and live == 0,
    string.format("count=%d, live=%d", count, live))
end

-- Case 2: Number field building and accessor behavior
-- Scale = 10, no decimals: raw 150 -> display 15, set display 25 -> raw 250
local numField
local rt1 = newMockRuntime("page_main", { p_gain = 150 })
do
  field_layout.buildField(rt1, nil, nil, {
    key = "p_gain",
    min = 0,
    max = 200,
    scale = 10,
    default = 50,
  })

  numField = rt1.registeredFields["p_gain"]
  check("number field registered", numField ~= nil and numField.type == "number")
  check("number field display min/max scaled (0..200 scaled by 10 -> 0..20)",
    numField.min == 0 and numField.max == 20)
  check("number field default value scaled (50 scaled by 10 -> 5)", numField.defVal == 5)

  local count, live = field_layout.poolStats()
  check("poolStats after 1 number field", count == 1 and live == 1,
    string.format("count=%d, live=%d", count, live))

  -- Getter / setter
  check("number getter scales raw value (150 -> 15)", numField.get() == 15,
    "got: " .. tostring(numField.get()))

  numField.set(25)
  check("number setter unscales value (25 -> 250)", rt1.dataRef.data.p_gain == 250,
    "got: " .. tostring(rt1.dataRef.data.p_gain))
  check("number setter marks runtime dirty", rt1.dirtyCount == 1,
    "dirtyCount=" .. tostring(rt1.dirtyCount))
end

-- Case 3: Re-claiming slot on the same page does not allocate a new pool entry
do
  field_layout.buildField(rt1, nil, nil, {
    key = "p_gain",
    min = 0,
    max = 200,
    scale = 10,
    default = 50,
  })

  local count, live = field_layout.poolStats()
  check("re-claiming identical slot keeps pool count unchanged", count == 1 and live == 1,
    string.format("count=%d, live=%d", count, live))
end

-- Case 4: Choice field building and accessor behavior
local choiceField
do
  rt1.dataRef.data.filter_type = 2
  field_layout.buildField(rt1, nil, nil, {
    key = "filter_type",
    choices = { "OFF", "LOW", "MEDIUM", "HIGH" },
  })

  choiceField = rt1.registeredFields["filter_type"]
  check("choice field registered", choiceField ~= nil and choiceField.type == "choice")

  local count, live = field_layout.poolStats()
  check("poolStats after choice field", count == 2 and live == 2,
    string.format("count=%d, live=%d", count, live))

  check("choice getter returns raw index", choiceField.get() == 2,
    "got: " .. tostring(choiceField.get()))

  choiceField.set(3)
  check("choice setter stores raw index", rt1.dataRef.data.filter_type == 3,
    "got: " .. tostring(rt1.dataRef.data.filter_type))
  check("choice setter marks runtime dirty", rt1.dirtyCount == 2,
    "dirtyCount=" .. tostring(rt1.dirtyCount))
end

-- Case 5: Bit fields (shared word, distinct bit slots)
local bitField2, bitField3
do
  rt1.dataRef.data.gov_flags = 0 -- binary 0000
  field_layout.buildField(rt1, nil, nil, {
    key = "gov_flags",
    bit = 2,
    choices = { "OFF", "ON" },
  })
  field_layout.buildField(rt1, nil, nil, {
    key = "gov_flags",
    bit = 3,
    choices = { "OFF", "ON" },
  })

  bitField2 = rt1.registeredFields["gov_flags:bit2"]
  bitField3 = rt1.registeredFields["gov_flags:bit3"]
  check("bit field 2 registered with bit key", bitField2 ~= nil)
  check("bit field 3 registered with bit key", bitField3 ~= nil)

  local count, live = field_layout.poolStats()
  check("poolStats after two bit fields", count == 4 and live == 4,
    string.format("count=%d, live=%d", count, live))

  -- Bit get/set
  check("bit 2 initial read is 0", bitField2.get() == 0)
  check("bit 3 initial read is 0", bitField3.get() == 0)

  bitField2.set(1) -- sets bit 2 (value 4)
  check("setting bit 2 yields 4 in shared word", rt1.dataRef.data.gov_flags == 4,
    "got: " .. tostring(rt1.dataRef.data.gov_flags))
  check("bit 2 reads back 1", bitField2.get() == 1)
  check("bit 3 still reads 0", bitField3.get() == 0)

  bitField3.set(1) -- sets bit 3 (value 8, total 12)
  check("setting bit 3 yields 12 in shared word", rt1.dataRef.data.gov_flags == 12,
    "got: " .. tostring(rt1.dataRef.data.gov_flags))
  check("bit 2 still reads 1", bitField2.get() == 1)
  check("bit 3 reads 1", bitField3.get() == 1)

  bitField2.set(0) -- clears bit 2 (value back to 8)
  check("clearing bit 2 yields 8 in shared word", rt1.dataRef.data.gov_flags == 8,
    "got: " .. tostring(rt1.dataRef.data.gov_flags))
  check("bit 2 reads 0", bitField2.get() == 0)
  check("bit 3 reads 1", bitField3.get() == 1)
end

-- Case 6: Multi-source field (source = "profile")
local multiField
do
  rt1.dataRef.data.profile = { tail_gain = 40 }
  field_layout.buildField(rt1, nil, nil, {
    key = "tail_gain",
    source = "profile",
    min = 0,
    max = 100,
  })

  multiField = rt1.registeredFields["profile:tail_gain"]
  check("multi-source field registered with source prefix", multiField ~= nil)

  local count, live = field_layout.poolStats()
  check("poolStats after multi-source field", count == 5 and live == 5,
    string.format("count=%d, live=%d", count, live))

  check("multi-source getter reads from nested source table", multiField.get() == 40)
  multiField.set(55)
  check("multi-source setter writes to nested source table", rt1.dataRef.data.profile.tail_gain == 55)
end

-- Case 7: FIELD_META fallback resolution
do
  local metaModule = {
    FIELD_META = {
      yaw_rate = { min = 10, max = 500, default = 200, scale = 10, decimals = 1, suffix = "°/s", step = 5 },
    },
  }
  local rtMeta = newMockRuntime("page_meta", { yaw_rate = 200 }, metaModule)
  field_layout.buildField(rtMeta, nil, nil, { key = "yaw_rate" })

  local metaField = rtMeta.registeredFields["yaw_rate"]
  check("meta fallback used for min/max/suffix/step",
    metaField ~= nil and metaField.min == 10 and metaField.max == 500 and metaField.suf == "°/s" and metaField.dec == 1)

  local count, live = field_layout.poolStats()
  check("poolStats after meta field", count == 6 and live == 6,
    string.format("count=%d, live=%d", count, live))

  field_layout.releaseRuntime(rtMeta)
  local _, liveAfterMeta = field_layout.poolStats()
  check("releasing meta page drops its live slots", liveAfterMeta == 5,
    "liveAfterMeta=" .. tostring(liveAfterMeta))
end

-- Case 8: releaseRuntime() detaches slots without shrinking the pool
do
  local preCount, preLive = field_layout.poolStats()
  field_layout.releaseRuntime(rt1)
  local postCount, postLive = field_layout.poolStats()

  check("releaseRuntime does NOT shrink total pool count", postCount == preCount,
    string.format("pre=%d, post=%d", preCount, postCount))
  check("releaseRuntime drops live slots of released page to 0", postLive == 0,
    "postLive=" .. tostring(postLive))
  check("runtime slot ID tracker cleared", rt1._fieldLayoutSlotIds == nil)
end

-- Case 9: Post-release safety (retained widgets get harmless no-ops)
do
  -- Read operations on detached slots return safe fallbacks
  check("detached number getter returns 0", numField.get() == 0)
  check("detached choice getter returns nil", choiceField.get() == nil)
  check("detached bit getter returns 0", bitField2.get() == 0)

  -- Write operations on detached slots are harmless no-ops
  local dirtyBefore = rt1.dirtyCount
  numField.set(999)
  choiceField.set(1)
  bitField2.set(1)
  multiField.set(888)

  check("detached number setter does not modify old data", rt1.dataRef.data.p_gain == 250)
  check("detached choice setter does not modify old data", rt1.dataRef.data.filter_type == 3)
  check("detached bit setter does not modify old data", rt1.dataRef.data.gov_flags == 8)
  check("detached multi-source setter does not modify old data", rt1.dataRef.data.profile.tail_gain == 55)
  check("detached setters do not trigger dirty notifications", rt1.dirtyCount == dirtyBefore,
    string.format("before=%d, after=%d", dirtyBefore, rt1.dirtyCount))
end

-- Case 10: Re-visiting page re-claims existing pooled slots (no closure churn)
local rt2 = newMockRuntime("page_main", {
  p_gain = 180,
  filter_type = 1,
  gov_flags = 4,
  profile = { tail_gain = 70 },
})
do
  field_layout.buildField(rt2, nil, nil, {
    key = "p_gain",
    min = 0,
    max = 200,
    scale = 10,
    default = 50,
  })
  field_layout.buildField(rt2, nil, nil, {
    key = "filter_type",
    choices = { "OFF", "LOW", "MEDIUM", "HIGH" },
  })
  field_layout.buildField(rt2, nil, nil, {
    key = "gov_flags",
    bit = 2,
    choices = { "OFF", "ON" },
  })
  field_layout.buildField(rt2, nil, nil, {
    key = "gov_flags",
    bit = 3,
    choices = { "OFF", "ON" },
  })
  field_layout.buildField(rt2, nil, nil, {
    key = "tail_gain",
    source = "profile",
    min = 0,
    max = 100,
  })

  local count, live = field_layout.poolStats()
  check("re-visiting page reuses pool without allocating new slots", count == 6 and live == 5,
    string.format("count=%d, live=%d", count, live))

  local newNumField = rt2.registeredFields["p_gain"]
  check("re-claimed slot reads new runtime data (180 -> 18)", newNumField.get() == 18)

  newNumField.set(19)
  check("re-claimed slot writes new runtime data (19 -> 190)", rt2.dataRef.data.p_gain == 190)
  check("re-claimed slot marks new runtime dirty", rt2.dirtyCount == 1)

  -- Cleanup
  field_layout.releaseRuntime(rt2)
  local _, liveAfter = field_layout.poolStats()
  check("releasing second visit drops live count to 0 again", liveAfter == 0,
    "liveAfter=" .. tostring(liveAfter))
end

-- Case 11: Page isolation in slotId prevents cross-page aliasing
do
  local rtOther = newMockRuntime("page_other", { p_gain = 990 })
  field_layout.buildField(rtOther, nil, nil, {
    key = "p_gain",
    min = 0,
    max = 200,
    scale = 10,
    default = 50,
  })

  local count, live = field_layout.poolStats()
  check("different page allocates distinct slot in pool", count == 7 and live == 1,
    string.format("count=%d, live=%d", count, live))

  local otherField = rtOther.registeredFields["p_gain"]
  check("different page reads its own data (990 -> 99)", otherField.get() == 99)

  field_layout.releaseRuntime(rtOther)
end

-- Case 12: Layout helpers buildSingle and buildGroup
do
  local rtLayout = newMockRuntime("page_layout", { roll = 40, pitch = 45, yaw = 50 })

  -- buildSingle
  field_layout.buildSingle(rtLayout, "Roll Gain", { key = "roll", min = 0, max = 100 })
  check("buildSingle registers field", rtLayout.registeredFields["roll"] ~= nil)

  -- buildGroup
  field_layout.buildGroup(rtLayout, "Rate Gains", {
    { title = "P", spec = { key = "pitch", min = 0, max = 100 } },
    { title = "Y", spec = { key = "yaw", min = 0, max = 100 } },
  })
  check("buildGroup registers pitch field", rtLayout.registeredFields["pitch"] ~= nil)
  check("buildGroup registers yaw field", rtLayout.registeredFields["yaw"] ~= nil)

  field_layout.releaseRuntime(rtLayout)
end

print()
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
end
print(string.format("%d of %d checks FAILED", failures, checks))
os.exit(1)

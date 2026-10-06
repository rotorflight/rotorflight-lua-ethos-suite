-- Behaviour check for the lower clamp on the biased ESC words (#2467).
--
-- Run it:
--     lua5.4 bin/esc_xdfly_bias/verify_xdfly_bias.lua
--     lua5.4 bin/esc_xdfly_bias/verify_xdfly_bias.lua --self-test
--
-- What the defect under test is:
--   lib/msp_esc_parameters_xdfly.lua's encode() subtracts FIELD_OFFSETS without
--   clamping the result. The offsets themselves are correct and symmetric --
--   decode() adds the bias at :129, encode() subtracts it -- and that part of
--   #2343 does not reproduce. What is missing is the boundary validation #2343
--   also asks for, and the shape of the failure is silent: the three fields with
--   a positive bias (gov_p, gov_i, motor_poles, all = 1) turn a value of 0 into
--   0 - 1 = -1, and mspcodec.writeU16 MASKS rather than clamps, because
--   toByte() is math_floor(value) % 256 (lib/mspcodec.lua:85-87). Both bytes come
--   out 0xFF.
--
--   0xFFFF is not an arbitrary number here. It is what the ESC answers a write
--   it refused, which is the reason the sibling suite guards it:
--   rotorflight-lua-edgetx-suite .../msp/api/esc_parameters_xdfly.lua:146-153
--   -- "a shifted value is never taken below zero: 0xFFFF is what the ESC
--   answers a write it refused, so a word of that shape must not be built here."
--   EdgeTX clamps with `if v < 0 then v = 0 end`. This suite had the same bias
--   table and no clamp, so the two suites disagreed about the one word that
--   carries a refusal.
--
-- What this drives, and why:
--   * The real lib/msp_esc_parameters_xdfly.lua loaded from its path, and the
--     real lib/mspcodec.lua, because the mask lives in the codec and the
--     subtraction in the module -- asserting on either alone would miss half the
--     mechanism.
--   * The real lib/msp_esc_parameters_omp.lua and lib/msp_esc_parameters_ztw.lua
--     as well. Both requireModule() the XDFLY codec and delegate
--     buildWriteMessage to it (omp:8/:43-46, ztw:8/:43-46), so all three vendors
--     carry the defect, and a clamp that landed in only one file would leave two
--     broken. The signature each one patches in is asserted too, since that is
--     the one line those files contribute and it must not disturb the payload.
--   * Not the page. app/field_layout.lua:442-446 hands FIELD_META's min straight
--     to form.addNumberField, and that min equals the bias for all three fields,
--     so the widget cannot produce a value below the bias -- which is stated in
--     case 1 as a measured fact rather than left implicit, because it is exactly
--     why this bug survived and why "unreachable through the UI" is not the same
--     claim as "not a defect".
--
-- Which checks go RED without the fix:
--   * 8 of them, all of them gates: three "a below-bias value packs 0xFFFF", the
--     exhaustive sweep over -20..0 on all three fields, the absent-key case, and
--     the two vendors that inherit the codec. --self-test proves that rather than
--     asserting it: it cuts the clamp back out of the codec and requires all eight
--     to go red, comparing verdicts BY NAME.
--
--   * Three further checks deliberately stay GREEN on the pre-fix code, and
--     calling that out is part of the file: the FIELD_OFFSETS round-trip over the
--     legal range (#2343's half that does not reproduce), the whole-block sweep,
--     and the two vendors' signature bytes. They are checks, not gates -- a gate
--     that cannot fail is worse than no check at all. The sweep is the subtle one:
--     without the clamp, -1 masks to 0xFFFF inside the SAME two bytes the clamp
--     writes, so it cannot tell the defect from the fix.
--
--   * The cut is verified five ways first, because a slice that takes an unrelated
--     table with it looks exactly like a test failure: the temp file must LOAD, the
--     clamp must actually be GONE, the untouched parts of the function must still
--   be THERE (the 4-byte header, the trailing U32 and the bias table are the
--   anchors), the sabotaged module must be the one in `package.loaded`, and both
--   passes must have registered the same gate names.
--
--   * It cuts rather than serving the pre-fix file from git, because the CI
--   checkout has no history to serve it from.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"

local CODEC_SRC = PREFIX .. "lib/msp_esc_parameters_xdfly.lua"
local OMP_SRC = PREFIX .. "lib/msp_esc_parameters_omp.lua"
local ZTW_SRC = PREFIX .. "lib/msp_esc_parameters_ztw.lua"

local SELF_TEST = arg[1] == "--self-test"

local checks, failures = 0, 0
local gates, gateVerdicts = {}, {}
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

-- A gate is a check that MUST fail on the pre-fix code. Two things are recorded,
-- the name and the verdict, and --self-test needs both: it compares the two
-- passes by name (a case that runs on one tree and not the other would otherwise
-- be compared against nothing) and it reads the verdicts to count how many gates
-- stayed green.
--
-- Which of this file's checks are gates is not a matter of taste. Measured on the
-- pre-fix codec while writing it:
--
--   * "the offsets round-trip over the legal range" stays GREEN. It pins the
--     FIELD_OFFSETS arithmetic, which the pre-fix code got right -- that is why
--     #2343 does not reproduce. Real check, wrong gate.
--   * "clamping changes nothing outside the field's own two bytes" stays GREEN
--     too, and for a non-obvious reason: without the clamp, -1 masks to 0xFFFF
--     inside the SAME two bytes the clamp writes. Both the defect and the fix
--     stay inside the field, so this guards the fix rather than catching the
--     defect. It earns its place as a check; as a gate it would be the 2026-09-28
--     startup_time mistake again.
--   * "OMP/ZTW still write their own signature byte" stays GREEN for the same
--     reason -- the signature line is in the file the cut does not touch.
--
-- So the gates are exactly the eight assertions about "no below-bias value reaches
-- 0xFFFF", across the three fields, the exhaustive sweep, the absent key, and the
-- two vendors that inherit the codec. Everything else here is a plain check that
-- holds before and after.
local function gate(label, ok, detail)
  gates[#gates + 1] = label
  gateVerdicts[#gateVerdicts + 1] = {label = label, ok = ok and true or false}
  check(label, ok, detail)
end

-- Pass 2's counterpart, and deliberately NOT gate(). A gate going red is the
-- self-test's SUCCESS, so counting it in `failures` would make --self-test exit
-- 1 on a perfectly good run -- and the sibling harnesses in this tree all exit 0
-- when their self-test succeeds (bin/governor_profile, bin/gc_pause,
-- bin/esc_signature). So a probe records its verdict and nothing else; the
-- "every gate went red" check at the end is what turns the set into a result.
local function probe(label, ok, detail)
  gates[#gates + 1] = label
  gateVerdicts[#gateVerdicts + 1] = {label = label, ok = ok and true or false}
  out(string.format("  %s  %s", ok and "green" or "RED   ", label))
  if not ok and detail then out("        " .. tostring(detail)) end
end

-- ---------------------------------------------------------------------------
-- Loading
-- ---------------------------------------------------------------------------

-- lib/require.lua loadfiles paths that carry no directory part; on the radio the
-- working directory is src/rfsuite. The redirect is for the codec's OWN
-- `requireModule("lib/mspcodec.lua")` call -- the codec file itself is loaded
-- with realLoadfile below, because the redirect prepends the suite prefix to
-- anything ending in .lua, which is right for "lib/..." and wrong for this path.
local realLoadfile = loadfile

_G.loadfile = function(path, ...)
  if type(path) == "string" and path:match("%.lua$") then
    local absolute = path:sub(1, 1) == "/" and path or (PREFIX .. path)
    return realLoadfile(absolute, ...)
  end
  return realLoadfile(path, ...)
end

-- The four biased fields and their bias, transcribed from the codec's own
-- FIELD_OFFSETS (msp_esc_parameters_xdfly.lua:69-74). Asserted against the
-- module below rather than assumed, so a future edit to that table shows up here
-- as a changed expectation instead of as a silently different subject.
local EXPECTED_OFFSETS = {
  gov_p = 1,
  gov_i = 1,
  capacity_correction = -10,
  motor_poles = 1,
}

-- The U16 fields with a POSITIVE bias are the ones that can underflow. The
-- negative one (capacity_correction, -10) shifts the other way and can never go
-- below zero -- asserted in case 1 so that "the clamp applies where it can fire"
-- is a statement about the table rather than about this list.
local UNDERFLOW_FIELDS = {"gov_p", "gov_i", "motor_poles"}

-- The wire word an ESC answers a refused write with.
local REFUSAL_WORD = 0xFFFF

-- Loads a codec file from a given path, so the self-test can put the pre-fix
-- codec in the same seat.
--
-- Two things this has to get right, and both of them bit this file while it was
-- being written:
--
--   * The key to clear is the one INSIDE the file, not one invented here.
--     msp_esc_parameters_xdfly.lua opens with its own self-cache guard keyed
--     "rfsuite.lib.msp_esc_parameters_xdfly", so loading the sabotaged copy
--     under a different key cleared nothing: the guard found the FIXED codec
--     already in package.loaded and returned it. Pass 2 then ran the fixed codec
--     twice and every gate stayed green. The self-test's own "the sabotaged codec
--     is the one now in the seat" check caught it.
--   * realLoadfile, not the redirect above: the redirect prepends the suite
--     prefix to anything ending in .lua, which is right for requireModule()'s
--     bare "lib/..." paths and wrong for this absolute one. The file's OWN
--     loadfile() calls still go through the redirect, so its codec loads as usual.
local XDFLY_KEY = "rfsuite.lib.msp_esc_parameters_xdfly"

local function loadCodec(file, key)
  package.loaded[XDFLY_KEY] = nil
  if key then package.loaded[key] = nil end
  return assert(realLoadfile(file))()
end

local codec = loadCodec(CODEC_SRC)
local mspcodec = package.loaded["rfsuite.lib.mspcodec"]
assert(mspcodec, "the codec did not load mspcodec -- the redirect is not working")

-- ---------------------------------------------------------------------------
-- Reading a field out of a payload
-- ---------------------------------------------------------------------------

-- Four single-byte header values occupy payload slots 1..4, so the first U16
-- field starts at slot 5. Counting from the codec's own EDIT_FIELDS rather than
-- hard-coding an offset: a field added to the list moves everything after it, and
-- a harness with a stale constant would report on the wrong byte and look
-- perfectly healthy.
local function fieldByteOffset(key)
  for i = 1, #codec.EDIT_FIELDS do
    if codec.EDIT_FIELDS[i] == key then return 5 + (i - 1) * 2 end
  end
  error("no such field in EDIT_FIELDS: " .. tostring(key))
end

local function readU16At(buf, off)
  return (buf[off] or 0) + (buf[off + 1] or 0) * 256
end

-- The payload the codec builds for a table -- buildWriteMessage() is the only
-- caller of encode(), so this is the write path itself, not a private function.
local function payloadFor(data, m)
  m = m or codec
  return m.buildWriteMessage(data, function() end, function() end).payload
end

local function wireWord(data, key, m)
  return readU16At(payloadFor(data, m), fieldByteOffset(key))
end

-- 4 header bytes + 2 per edit field + 4 for the trailing activefields U32.
local EXPECTED_BYTES = 4 + #codec.EDIT_FIELDS * 2 + 4

-- ---------------------------------------------------------------------------
-- cases
-- ---------------------------------------------------------------------------

out("case 1: the subject -- the bias table, and that the widget currently hides this")
do
  check(string.format("the payload is %d bytes", EXPECTED_BYTES),
    #payloadFor({}) == EXPECTED_BYTES, string.format("got %d", #payloadFor({})))

  -- The bias table this file reasons about is the codec's own, measured rather
  -- than read: encode() packs `value - bias`, so a KNOWN in-range value reveals
  -- the bias directly as value - wireWord. (An earlier version read the bias out
  -- of a zero table by subtracting two decodings of the same word, which is 0 by
  -- construction -- a check that cannot fail.)
  --
  -- The probe value has to sit inside the legal range of every field, so the
  -- clamp under test cannot be what is being measured. 5 is inside gov_p/gov_i
  -- (1..10), motor_poles (1..55) and capacity_correction (-10..10).
  local PROBE = 5
  local mismatch = {}
  for key, want in pairs(EXPECTED_OFFSETS) do
    local actualBias = PROBE - wireWord({[key] = PROBE}, key)
    if actualBias ~= want then
      mismatch[#mismatch + 1] = string.format("%s: bias %d, expected %d", key, actualBias, want)
    end
  end
  check("every bias is the one this file assumes, measured off a known in-range value",
    #mismatch == 0, table.concat(mismatch, "; "))

  -- The reason the defect is latent: FIELD_META's min equals the bias, so the
  -- widget cannot produce a value below it. Measured from the codec's own table,
  -- not asserted in prose.
  local floors = {}
  for _, key in ipairs(UNDERFLOW_FIELDS) do
    local meta = codec.FIELD_META and codec.FIELD_META[key]
    floors[#floors + 1] = string.format("%s min=%s bias=%d", key,
      meta and tostring(meta.min) or "nil", EXPECTED_OFFSETS[key])
  end
  check("the three underflowing fields declare min == bias, which is why the page cannot reach it",
    (function()
      for _, key in ipairs(UNDERFLOW_FIELDS) do
        local meta = codec.FIELD_META and codec.FIELD_META[key]
        if not meta or meta.min ~= EXPECTED_OFFSETS[key] then return false end
      end
      return true
    end)(), table.concat(floors, "; "))
end

out("")
out("case 2: a value below the bias packs the refusal word  <- the defect")
do
  for _, key in ipairs(UNDERFLOW_FIELDS) do
    local word = wireWord({[key] = 0}, key)
    gate(string.format("%s = 0 does not pack 0xFFFF", key),
      word ~= REFUSAL_WORD, string.format("packed 0x%04X", word))
  end

  -- Exhaustive rather than spot-checked: every value below the bias, for every
  -- underflowing field. One value proving the clamp exists is a spot check; this
  -- is the claim.
  local leaked, bad = 0, nil
  for _, key in ipairs(UNDERFLOW_FIELDS) do
    for v = -20, 0 do
      local word = wireWord({[key] = v}, key)
      if word > 0x00FF then
        leaked = leaked + 1
        if not bad then
          bad = string.format("%s = %d packed 0x%04X", key, v, word)
        end
      end
    end
  end
  gate("no value below the bias packs a word above 0x00FF, over all three fields",
    leaked == 0, string.format("%d of 63 leaked; first: %s", leaked, tostring(bad)))

  -- The clamp has to land on zero, not merely on "something small": a value of
  -- -1 must not become 1, which is gov_p's own legal wire word.
  local wrong = nil
  for _, key in ipairs(UNDERFLOW_FIELDS) do
    for v = -5, 0 do
      local word = wireWord({[key] = v}, key)
      if word ~= 0 then
        wrong = string.format("%s = %d packed %d, not 0", key, v, word)
        break
      end
    end
  end
  gate("every value below the bias clamps to 0, not to some other small word",
    wrong == nil, wrong)
end

out("")
out("case 3: an absent key does not pack the refusal word either")
do
  -- `data and data[key] or 0` packs 0 for a key the table never carried, which
  -- is the same invented-zero shape #2348 had to fix in msp_governor_profile.lua
  -- -- except that there the zero was in range and here it lands on a word with a
  -- meaning. An unanswered or short read leaves exactly such a table.
  local leaked, bad = 0, nil
  for _, key in ipairs(UNDERFLOW_FIELDS) do
    local word = wireWord({}, key)
    if word == REFUSAL_WORD or word > 0x00FF then
      leaked = leaked + 1
      if not bad then bad = string.format("%s absent packed 0x%04X", key, word) end
    end
  end
  gate("an empty table packs no refusal word for any underflowing field",
    leaked == 0, string.format("%d of 3 leaked; first: %s", leaked, tostring(bad)))

  -- And the signature byte must still come through: the fix is a clamp on the
  -- biased fields, not a change to the header.
  local p = payloadFor({})
  check("the header is untouched: signature 166, command/model/version 0",
    p[1] == 166 and p[2] == 0 and p[3] == 0 and p[4] == 0,
    string.format("%d %d %d %d", p[1], p[2], p[3], p[4]))
end

out("")
out("case 4: the legal UI range is untouched -- so this cannot pass by breaking the offset")
do
  -- The offsets are the part that already works (#2343 does not reproduce). If
  -- the clamp changed anything inside the legal range it would have broken the
  -- very thing the fix is not about.
  local mismatch = {}
  local function identity(key, lo, hi)
    for v = lo, hi do
      local p = payloadFor({[key] = v})
      local buf = {}
      for i = 1, #p do buf[i] = p[i] end
      buf.offset = 1
      mspcodec.readU8(buf); mspcodec.readU8(buf); mspcodec.readU8(buf); mspcodec.readU8(buf)
      local decoded
      for i = 1, #codec.EDIT_FIELDS do
        local k = codec.EDIT_FIELDS[i]
        local raw = (mspcodec.readU16(buf) or 0)
        decoded = raw + (EXPECTED_OFFSETS[k] or 0)
        if k == key then break end
      end
      if decoded ~= v then
        mismatch[#mismatch + 1] = string.format("%s %d -> %d", key, v, decoded)
      end
    end
  end
  identity("gov_p", 1, 10)
  identity("gov_i", 1, 10)
  identity("motor_poles", 1, 55)
  identity("capacity_correction", -10, 10)
  -- Not a gate, and the header explains why: this pins the FIELD_OFFSETS
  -- arithmetic, which the pre-fix codec also got right.
  check("decode(encode(x)) == x over every legal value of all four biased fields",
    #mismatch == 0, string.format("%d mismatches; first: %s", #mismatch,
      mismatch[1] or ""))

  -- A whole-block sweep, so the clamp is not caught moving a byte it has no
  -- business touching. The assertion is about WHICH slots changed, not how many:
  -- clamping a below-bias value on a field whose in-range word is a small number
  -- changes only that field's LOW byte, because the high byte was already 0 --
  -- so a byte count would be measuring the fixture's magnitudes rather than the
  -- clamp's reach. "Only inside this field's own two slots" is the claim.
  local inRange = {
    governor = 2, cell_cutoff = 3, timing = 1, lv_bec_voltage = 1,
    motor_direction = 1, gov_p = 5, gov_i = 4, acceleration = 1,
    auto_restart_time = 1, hv_bec_voltage = 12, startup_power = 1,
    brake_type = 1, brake_force = 50, sr_function = 1,
    capacity_correction = -5, motor_poles = 14, led_color = 4, smart_fan = 1,
  }
  local stray, changed, examples = nil, 0, {}
  for _, key in ipairs(UNDERFLOW_FIELDS) do
    local own = {fieldByteOffset(key), fieldByteOffset(key) + 1}
    for v = -20, 0 do
      local t = {}
      for k, val in pairs(inRange) do t[k] = val end
      t[key] = v
      local before, after = payloadFor(inRange), payloadFor(t)
      for i = 1, #before do
        if before[i] ~= after[i] then
          changed = changed + 1
          if i ~= own[1] and i ~= own[2] and not stray then
            stray = string.format("%s = %d moved slot %d, which is not its own (%d/%d)",
              key, v, i, own[1], own[2])
          end
          if #examples < 3 then examples[#examples + 1] = string.format("%s=%d slot %d: %d -> %d",
            key, v, i, before[i], after[i]) end
        end
      end
    end
  end
  check("the clamp did move the field it is supposed to move", changed > 0,
    "nothing changed at all -- this case cannot fail")
  check("and it changed nothing outside that field's own two bytes",
    stray == nil, stray or "")
end

out("")
out("case 5: OMP and ZTW inherit the clamp")
do
  -- Both requireModule() the XDFLY codec and delegate buildWriteMessage to it.
  -- A clamp that landed in only the XDFLY file would leave these two broken, so
  -- they are driven rather than assumed.
  for _, v in ipairs({{"OMP", OMP_SRC, "rfsuite.lib.msp_esc_parameters_omp", 208},
                      {"ZTW", ZTW_SRC, "rfsuite.lib.msp_esc_parameters_ztw", 221}}) do
    local label, file, key, signature = v[1], v[2], v[3], v[4]
    local m = loadCodec(file, key)
    check(string.format("%s loads and inherits the base module", label),
      type(m) == "table" and type(m.EDIT_FIELDS) == "table"
      and #m.EDIT_FIELDS == #codec.EDIT_FIELDS)

    local leaked = 0
    for _, f in ipairs(UNDERFLOW_FIELDS) do
      if wireWord({[f] = 0}, f, m) > 0x00FF then leaked = leaked + 1 end
    end
    gate(string.format("%s packs no refusal word for a below-bias value", label),
      leaked == 0, string.format("%d of 3 leaked", leaked))

    -- The one line those files do contribute is the signature, and it has to
    -- survive: a payload whose first byte is not the vendor's own signature is
    -- rejected by esc_forward_vendor.lua's isCompatibleEsc() before the pilot
    -- ever sees the page.
    local p = payloadFor({}, m)
    check(string.format("%s still writes its own signature byte %d", label, signature),
      p[1] == signature, string.format("payload starts with %d", p[1]))
    check(string.format("%s still produces a %d-byte payload", label, EXPECTED_BYTES),
      #p == EXPECTED_BYTES, string.format("got %d", #p))
  end
end

-- ---------------------------------------------------------------------------
-- self-test: the pre-fix codec has to fail every gate
-- ---------------------------------------------------------------------------

-- Replaces the encode() field loop with the pre-fix one: the subtraction with no
-- clamp, which is the whole of the old code.
--
-- Matched by plain find() and slicing, not by pattern: the anchors are unique in
-- the file and a %%-escaped pattern over a CRLF terminator is a needless way to
-- hit "invalid pattern capture".
local PRE_FIX_LOOP = [[  for i = 1, #EDIT_FIELDS do
    local key = EDIT_FIELDS[i]
    local value = data and data[key] or 0
    mspcodec.writeU16(payload, value - (FIELD_OFFSETS[key] or 0))
  end]]

local function preFixCodecFile()
  local f = assert(io.open(CODEC_SRC, "rb"))
  local src = f:read("a")
  f:close()

  -- The checked-out tree is CRLF on Windows (core.autocrlf=true, no
  -- .gitattributes), so the terminator written back is the one that was read.
  local nl = src:find("\r\n", 1, true) and "\r\n" or "\n"

  -- Anchored on encode() first, and only then on the loop. "  for i = 1,
  -- #EDIT_FIELDS do" appears TWICE -- once in decode() and once in encode() --
  -- and searching for it from the top of the file cuts the wrong one. That is
  -- not hypothetical: the first version of this cut replaced decode()'s loop,
  -- which left the clamp in encode() untouched and made pass 2 a second run of
  -- the fixed code. The verification checks below caught it; this anchor is the
  -- fix.
  local encodeHead = assert(src:find("local function encode(data)", 1, true),
    "sabotage: encode() not found")
  local head = assert(src:find("  for i = 1, #EDIT_FIELDS do", encodeHead, true),
    "sabotage: the encode() field loop not found")
  local closeEnd = assert(src:find("  end", head + 10, true),
    "sabotage: the encode() field loop is not closed by `  end`")
  local afterClose = assert(src:find(nl, closeEnd, true),
    "sabotage: no line ending after the loop's closing `end`") + #nl

  local body = PRE_FIX_LOOP:gsub("\n", nl)
  local out = src:sub(1, head - 1) .. body .. nl .. src:sub(afterClose)

  local path = os.tmpname() .. "_xdfly_prefix.lua"
  local w = assert(io.open(path, "wb"))
  w:write(out)
  w:close()
  return path, out
end

if SELF_TEST then
  out("")
  out("self-test: the pre-fix codec must fail every gate")

  -- Gate list as registered in pass 1, before anything is loaded twice.
  local expectedGates = {}
  for i, g in ipairs(gates) do expectedGates[i] = g end

  local path, sabotaged = preFixCodecFile()

  -- Verification step 1: the temp file must LOAD. A cut that broke the module is
  -- caught here, not three layers down.
  local pre = loadCodec(path, "rfsuite.lib.msp_esc_parameters_xdfly_prefix")
  check("the sabotaged codec loads", type(pre) == "table" and type(pre.EDIT_FIELDS) == "table")

  -- Verification step 2: the clamp must actually be GONE, and
  -- verification step 3: the parts the cut must NOT have taken must be THERE.
  -- Without the second half of this pair a cut that emptied the whole function
  -- would pass every "clamp is gone" test and fail for the wrong reason.
  check("the clamp really is gone from the sabotaged source",
    sabotaged:find("if wire < 0 then wire = 0 end", 1, true) == nil)
  check("and the header writes are still in it",
    sabotaged:find("data and data.esc_signature or 166", 1, true) ~= nil)
  check("and so is the trailing activefields write",
    sabotaged:find("data and data.activefields or 0", 1, true) ~= nil)
  check("and the bias table is untouched",
    sabotaged:find("capacity_correction = -10", 1, true) ~= nil)

  -- Verification step 4: the file was SERVED, not written and forgotten. This
  -- one is not ceremony: the first version cleared a key the file does not use
  -- (see loadCodec's comment), so the codec's own self-cache guard handed back
  -- the FIXED module and pass 2 re-ran the fixed code.
  check("the sabotaged codec is the one now in the seat", pre ~= codec)
  package.loaded[XDFLY_KEY] = pre

  -- Pass 2: every gate-producing case again, against the pre-fix codec. `codec`
  -- is a local the case bodies read, so swapping it is what re-runs them --
  -- written out again here rather than shared with pass 1, because a self-test
  -- that calls the same function it is auditing is auditing nothing.
  local saved = codec
  codec = pre

  local before = checks
  -- Pass 2 re-runs every gate-producing case verbatim rather than calling pass
  -- 1's case bodies: a self-test that reuses the function it is auditing is
  -- auditing nothing, and the duplication is the point.
  do
    for _, key in ipairs(UNDERFLOW_FIELDS) do
      local word = wireWord({[key] = 0}, key)
      probe(string.format("%s = 0 does not pack 0xFFFF", key),
        word ~= REFUSAL_WORD, string.format("packed 0x%04X", word))
    end

    local leaked, bad = 0, nil
    for _, key in ipairs(UNDERFLOW_FIELDS) do
      for v = -20, 0 do
        local word = wireWord({[key] = v}, key)
        if word > 0x00FF then
          leaked = leaked + 1
          if not bad then bad = string.format("%s = %d packed 0x%04X", key, v, word) end
        end
      end
    end
    probe("no value below the bias packs a word above 0x00FF, over all three fields",
      leaked == 0, string.format("%d of 63 leaked; first: %s", leaked, tostring(bad)))

    local wrong = nil
    for _, key in ipairs(UNDERFLOW_FIELDS) do
      for v = -5, 0 do
        local word = wireWord({[key] = v}, key)
        if word ~= 0 then
          wrong = string.format("%s = %d packed %d, not 0", key, v, word)
          break
        end
      end
    end
    probe("every value below the bias clamps to 0, not to some other small word",
      wrong == nil, wrong)

    -- case 3, the absent key: `data and data[key] or 0` invents a 0, which is
    -- 0 - 1 on all three fields.
    local missingLeaked, missingBad = 0, nil
    for _, key in ipairs(UNDERFLOW_FIELDS) do
      local word = wireWord({}, key)
      if word == REFUSAL_WORD or word > 0x00FF then
        missingLeaked = missingLeaked + 1
        if not missingBad then
          missingBad = string.format("%s absent packed 0x%04X", key, word)
        end
      end
    end
    probe("an empty table packs no refusal word for any underflowing field",
      missingLeaked == 0, string.format("%d of 3 leaked; first: %s",
        missingLeaked, tostring(missingBad)))

    -- case 4's identity half, as a plain check: the pre-fix codec passes it, and
    -- that is the correct outcome (see gate()'s header).
    local mismatch = {}
    local function identity(key, lo, hi)
      for v = lo, hi do
        local p = payloadFor({[key] = v})
        local buf = {}
        for i = 1, #p do buf[i] = p[i] end
        buf.offset = 1
        mspcodec.readU8(buf); mspcodec.readU8(buf); mspcodec.readU8(buf); mspcodec.readU8(buf)
        local decoded
        for i = 1, #codec.EDIT_FIELDS do
          local k = codec.EDIT_FIELDS[i]
          local raw = (mspcodec.readU16(buf) or 0)
          decoded = raw + (EXPECTED_OFFSETS[k] or 0)
          if k == key then break end
        end
        if decoded ~= v then
          mismatch[#mismatch + 1] = string.format("%s %d -> %d", key, v, decoded)
        end
      end
    end
    identity("gov_p", 1, 10)
    identity("gov_i", 1, 10)
    identity("motor_poles", 1, 55)
    identity("capacity_correction", -10, 10)
    check("decode(encode(x)) == x over every legal value of all four biased fields",
      #mismatch == 0, string.format("%d mismatches; first: %s", #mismatch,
        mismatch[1] or ""))

    -- case 4's sweep half, as a plain check: it holds on the pre-fix code too,
    -- because -1 masks to 0xFFFF inside the same two bytes the clamp writes.
    local stray = nil
    for _, key in ipairs(UNDERFLOW_FIELDS) do
      local own = {fieldByteOffset(key), fieldByteOffset(key) + 1}
      for v = -20, 0 do
        local t = {gov_p = 5, gov_i = 4, motor_poles = 14, capacity_correction = -5}
        t[key] = v
        local before, after = payloadFor({gov_p = 5, gov_i = 4, motor_poles = 14,
          capacity_correction = -5}), payloadFor(t)
        for i = 1, #before do
          if before[i] ~= after[i] and i ~= own[1] and i ~= own[2] and not stray then
            stray = string.format("%s = %d moved slot %d", key, v, i)
          end
        end
      end
    end
    check("and it changed nothing outside that field's own two bytes",
      stray == nil, stray or "")

    -- case 5's inheritance half, against the pre-fix base.
    --
    -- Deliberately NOT loadCodec() here. loadCodec clears XDFLY_KEY precisely so
    -- that the file's own self-cache guard cannot hand back a stale module -- and
    -- that is exactly wrong for this case, because OMP and ZTW pull the base in
    -- BY PATH through requireModule(), so clearing the key makes them pick the
    -- FIXED codec back off disk. The first version did that, and both vendor
    -- gates stayed green while the six above went red: the vendors were being
    -- measured against the repaired base. So the key is SEEDED with `pre` and the
    -- vendor file is loaded directly, which is the only order in which
    -- requireModule() can find the sabotaged base.
    for _, v in ipairs({{"OMP", OMP_SRC, "rfsuite.lib.msp_esc_parameters_omp", 208},
                        {"ZTW", ZTW_SRC, "rfsuite.lib.msp_esc_parameters_ztw", 221}}) do
      local label, file, key, signature = v[1], v[2], v[3], v[4]
      package.loaded[key] = nil
      package.loaded[XDFLY_KEY] = pre
      local m = assert(realLoadfile(file))()
      check(string.format("(pre-fix) %s loaded on the sabotaged base", label),
        package.loaded[XDFLY_KEY] == pre,
        "the base was re-read from disk, so this half tested the fixed codec")
      local leaked = 0
      for _, f in ipairs(UNDERFLOW_FIELDS) do
        if wireWord({[f] = 0}, f, m) > 0x00FF then leaked = leaked + 1 end
      end
      probe(string.format("%s packs no refusal word for a below-bias value", label),
        leaked == 0, string.format("%d of 3 leaked", leaked))
      local p = payloadFor({}, m)
      check(string.format("%s still writes its own signature byte %d", label, signature),
        p[1] == signature, string.format("payload starts with %d", p[1]))
    end
    package.loaded[XDFLY_KEY] = pre
  end

  -- Verification step 5: both passes must have registered the same gate NAMES.
  -- A case that runs on one tree and not the other would otherwise be compared
  -- against nothing.
  local pass1 = {}
  for i = 1, #expectedGates do pass1[expectedGates[i]] = true end
  local pass2 = {}
  for i = #expectedGates + 1, #gates do pass2[gates[i]] = true end

  local onlyIn1, onlyIn2 = {}, {}
  for g in pairs(pass1) do if not pass2[g] then onlyIn1[#onlyIn1 + 1] = g end end
  for g in pairs(pass2) do if not pass1[g] then onlyIn2[#onlyIn2 + 1] = g end end
  check("both passes registered the same gate names",
    #onlyIn1 == 0 and #onlyIn2 == 0,
    string.format("only in pass 1: %s | only in pass 2: %s",
      #onlyIn1 > 0 and table.concat(onlyIn1, "; ") or "(none)",
      #onlyIn2 > 0 and table.concat(onlyIn2, "; ") or "(none)"))

  local pass2Gates = #gates - #expectedGates
  check("the pre-fix codec ran every gate pass 2 registered",
    pass2Gates > 0, string.format("only %d gates ran in pass 2", pass2Gates))

  -- The gate verdicts are what the header's "N of M go red" claim rests on, read
  -- from gateVerdicts rather than by subtracting failure counts: the pass-2
  -- checks include plain ones that are SUPPOSED to stay green, so
  -- checks-minus-failures would count those as gates that cannot fail. That was
  -- the first version of this line and it reported 12 of 13 gates green while the
  -- sabotage had not run at all.
  local stayedGreen, greenNames = {}, {}
  for i = #expectedGates + 1, #gateVerdicts do
    if gateVerdicts[i].ok then
      stayedGreen[#stayedGreen + 1] = gateVerdicts[i]
    end
  end
  for i, g in ipairs(stayedGreen) do greenNames[i] = g.label end
  check(string.format("every one of the %d pass-2 gates went red", pass2Gates),
    #stayedGreen == 0,
    string.format("%d stayed green: %s", #stayedGreen, table.concat(greenNames, " | ")))

  codec = saved
  package.loaded["rfsuite.lib.msp_esc_parameters_xdfly"] = saved
  os.remove(path)
else
  out("")
  out("(run with --self-test to prove every gate is able to fail)")
  check("--self-test not requested", true)
end

out("")
out(string.rep("-", 60))
out(string.format("checks: %d   failures: %d   gates: %d", checks, failures, #gates))
if failures > 0 then
  out("")
  out("FAILED")
  os.exit(1)
end
out("ALL CHECKS PASSED")

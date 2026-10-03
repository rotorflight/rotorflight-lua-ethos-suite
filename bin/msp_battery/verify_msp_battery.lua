-- Behaviour check for the MSP payload codec and the battery/smartfuel decoders.
--
-- Run it:
--     lua5.4 bin/msp_battery/verify_msp_battery.lua
--
-- What it drives, and why:
--   * lib/mspcodec.lua and lib/msp_battery.lua are pure byte<->number code with
--     no Ethos dependency at all, so the whole decode path runs on a
--     workstation. The only thing a radio adds is the transport, and that is
--     not what is under test here.
--   * A truncated MSP reply cannot be reproduced against real hardware without
--     a firmware that sends one, and it must not have to be: the failure it
--     causes is that a decoder reads past the end of the buffer and gets nil,
--     and every one of those reads can be staged here by handing the decoder a
--     short table.
--   * The reply lengths are not guesses. They are transcribed from the firmware
--     handler -- MSP_BATTERY_CONFIG writes 15 fixed bytes plus
--     BATTERY_PROFILE_COUNT (6) u16 capacities, unconditionally; the
--     MSP2_GET_SMARTFUEL_CONFIG case writes four u8 fields. Case 1 pins both
--     against the simulatorResponse tables that ship in msp_battery.lua, so if
--     either the firmware or a field list changes, this goes red.
--
-- Cases 4 and 6 are the ones that go red on the pre-fix sources: readU8
-- returned nil, which the smartfuel decoder fed straight into a division
-- (raising, because queue.lua calls processReply without a pcall) and the
-- battery decoder stored into a typed numeric field. Every other case pins
-- behaviour that has to survive a change here. A check that cannot fail proves
-- nothing about the behaviour it passes.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

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

-- The modules resolve their dependencies through rfsuite.lib.require, which on
-- a radio is loadfile() with Ethos' path prefixes. Here it is the real thing
-- with plain paths: msp_battery.lua's only dependency is mspcodec.lua, and
-- mspcodec.lua has none.
package.loaded["rfsuite.lib.require"] = function(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(SUITE .. "/" .. name)
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end

local requireModule = package.loaded["rfsuite.lib.require"]
local mspcodec = requireModule("lib/mspcodec.lua")
local mspBattery = requireModule("lib/msp_battery.lua")

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

-- Exactly the bytes the firmware's MSP_BATTERY_CONFIG handler writes, with the
-- simulatorResponse table's values, so Case 1 and Case 4 check the same shape.
local BATTERY_REPLY = {
  136, 19,      -- u16 batteryCapacity = 5000 mAh
  6,            -- u8  batteryCellCount
  1,            -- u8  voltageMeterSource
  1,            -- u8  currentMeterSource
  74, 1,        -- u16 vbatmincellvoltage = 330 -> 3.30 V
  164, 1,       -- u16 vbatmaxcellvoltage = 420 -> 4.20 V
  154, 1,       -- u16 vbatfullcellvoltage = 410 -> 4.10 V
  94, 1,        -- u16 vbatwarningcellvoltage = 350 -> 3.50 V
  100,          -- u8  lvcPercentage
  30,           -- u8  consumptionWarningPercentage
  232, 3, 20, 5, 64, 6, 108, 7, 152, 8, 196, 9, -- u16 batteryCapacity_0..5
}

local SMARTFUEL_REPLY = { 2, 10, 50, 40 }

local function firstN(source, n)
  local out = {}
  for i = 1, n do out[i] = source[i] end
  return out
end

-- Decode through the real message builder, so the case exercises the same
-- processReply/errorHandler wiring the queue uses rather than a copy of it.
local function decodeBattery(buf)
  local got, reason
  mspBattery.buildBatteryConfigReadMessage(
    function(d) got = d end,
    function(r) reason = r end
  ).processReply(nil, buf)
  return got, reason
end

local function decodeSmartfuel(buf)
  local got, reason
  mspBattery.buildSmartfuelConfigReadMessage(
    function(d) got = d end,
    function(r) reason = r end
  ).processReply(nil, buf)
  return got, reason
end

-- ---------------------------------------------------------------------------
-- Case 1: the two wire sizes
-- ---------------------------------------------------------------------------

print("case 1: the decoders require the payload sizes the firmware writes")

check("BATTERY_CONFIG_SIZE matches the firmware handler (15 + 6 * 2)",
  mspBattery.BATTERY_CONFIG_SIZE == 27, mspBattery.BATTERY_CONFIG_SIZE)

check("SMARTFUEL_CONFIG_SIZE matches the firmware handler (4 * u8)",
  mspBattery.SMARTFUEL_CONFIG_SIZE == 4, mspBattery.SMARTFUEL_CONFIG_SIZE)

-- The size the decoder insists on and the size the Ethos simulator feeds it
-- have to be the same number, or one of the two is wrong. Since the per-profile
-- cell voltages landed there are two wire sizes in play: 27 bytes is what the
-- firmware handler always writes, and 81 adds the 6 cellCount bytes plus
-- 4 * 6 * 2 cell-voltage bytes of a newer firmware. The fixture has to be
-- exactly one of the two -- shorter and the decoder refuses it, longer and
-- the fixture no longer describes any real payload.
local BATTERY_CONFIG_FULL_SIZE = 81
local simBattery = mspBattery.buildBatteryConfigReadMessage(function() end).simulatorResponse
check("the BATTERY_CONFIG simulatorResponse is a whole wire size",
  #simBattery == mspBattery.BATTERY_CONFIG_SIZE
    or #simBattery == BATTERY_CONFIG_FULL_SIZE, #simBattery)

local simSmartfuel = mspBattery.buildSmartfuelConfigReadMessage(function() end).simulatorResponse
check("the SMARTFUEL_CONFIG simulatorResponse is exactly SMARTFUEL_CONFIG_SIZE",
  #simSmartfuel == mspBattery.SMARTFUEL_CONFIG_SIZE, #simSmartfuel)

-- ---------------------------------------------------------------------------
-- Case 2: a full BATTERY_CONFIG reply decodes
-- ---------------------------------------------------------------------------

print("case 2: a complete BATTERY_CONFIG reply decodes to the values it carries")

local config, configReason = decodeBattery(BATTERY_REPLY)

check("a complete payload is accepted", config ~= nil, configReason)

if config then
  check("batteryCapacity", config.batteryCapacity == 5000, config.batteryCapacity)
  check("cellCount", config.cellCount == 6, config.cellCount)
  check("vbatMinCell", math.abs(config.vbatMinCell - 3.30) < 1e-9, config.vbatMinCell)
  check("vbatMaxCell", math.abs(config.vbatMaxCell - 4.20) < 1e-9, config.vbatMaxCell)
  check("vbatFullCell", math.abs(config.vbatFullCell - 4.10) < 1e-9, config.vbatFullCell)
  check("vbatWarningCell", math.abs(config.vbatWarningCell - 3.50) < 1e-9, config.vbatWarningCell)
  check("consumptionWarningPercentage", config.consumptionWarningPercentage == 30,
    config.consumptionWarningPercentage)

  -- Every profile the dashboard's selector offers, not just the first. The
  -- pre-profile fix left these readable but never checked index 5, which is
  -- the one a six-pack pilot actually picks.
  local expectedProfiles = { 1000, 1300, 1600, 1900, 2200, 2500 }
  for i = 0, 5 do
    check(string.format("profiles[%d]", i), config.profiles[i] == expectedProfiles[i + 1],
      tostring(config.profiles[i]))
  end

  -- The failure this whole change is about: a value that is a number but
  -- missing. copyBatteryConfig() copies these straight into
  -- session.batteryConfig, where the dashboard and announceVoltage() do
  -- arithmetic on them.
  local allNumeric = true
  for _, key in ipairs({ "batteryCapacity", "cellCount", "vbatMinCell", "vbatMaxCell",
                         "vbatFullCell", "vbatWarningCell", "consumptionWarningPercentage" }) do
    if type(config[key]) ~= "number" then allNumeric = false end
  end
  for i = 0, 5 do
    if type(config.profiles[i]) ~= "number" then allNumeric = false end
  end
  check("no field is nil", allNumeric)
end

-- ---------------------------------------------------------------------------
-- Case 3: the same, for SMARTFUEL_CONFIG
-- ---------------------------------------------------------------------------

print("case 3: a complete SMARTFUEL_CONFIG reply decodes to the values it carries")

local smartfuel, smartfuelReason = decodeSmartfuel(SMARTFUEL_REPLY)

check("a complete payload is accepted", smartfuel ~= nil, smartfuelReason)

if smartfuel then
  check("mode", smartfuel.mode == 2, smartfuel.mode)
  check("voltageFallPerSecond", math.abs(smartfuel.voltageFallPerSecond - 0.010) < 1e-9,
    smartfuel.voltageFallPerSecond)
  check("chargeDropPerSecond", math.abs(smartfuel.chargeDropPerSecond - 0.005) < 1e-9,
    smartfuel.chargeDropPerSecond)
end

-- ---------------------------------------------------------------------------
-- Case 4: a short BATTERY_CONFIG payload is refused, not half-filled
-- ---------------------------------------------------------------------------

print("case 4: a truncated BATTERY_CONFIG payload is reported instead of decoded")

-- One byte short of every field boundary, so each case truncates in the middle
-- of a different field. 3 truncates straight after cellCount, which is the one
-- that put a nil into a typed numeric field before this change; 15 is exactly
-- the pre-profile part, which the old code accepted with profiles[5] == 0.
for _, len in ipairs({ 0, 1, 2, 3, 14, 15, 20, 21, 26 }) do
  local got, reason = decodeBattery(firstN(BATTERY_REPLY, len))
  check(string.format("a %d-byte payload is refused with short_payload", len),
    got == nil and reason == "short_payload",
    string.format("decoded=%s reason=%s", tostring(got), tostring(reason)))
end

-- The refusal has to reach the caller, not just stop the decode. session.lua's
-- handshake leaves batteryConfig unset on error, so the read is retried -- and
-- a config published as valid would satisfy the `if not session.batteryConfig`
-- guard on the table alone, whatever its fields hold.
local seenReason
mspBattery.buildBatteryConfigReadMessage(
  function() check("onData is not called for a short payload", false, "it was called") end,
  function(r) seenReason = r end
).processReply(nil, firstN(BATTERY_REPLY, 20))
check("the refusal reaches errorHandler", seenReason == "short_payload", tostring(seenReason))

-- ---------------------------------------------------------------------------
-- Case 5: a short SMARTFUEL_CONFIG payload is refused, not raised
-- ---------------------------------------------------------------------------

print("case 5: a truncated SMARTFUEL_CONFIG payload is reported instead of raising")

-- This is the case that goes red on the pre-fix sources by raising rather than
-- by returning a wrong value: the decoder divided a readU8 result by 1000, and
-- readU8 returned nil past the end of the buffer. tasks/msp/queue.lua calls
-- processReply with no pcall and there is none in the task path either, so the
-- error left the background task rather than being reported.
for _, len in ipairs({ 0, 1, 2, 3 }) do
  local raised, got, reason = pcall(decodeSmartfuel, firstN(SMARTFUEL_REPLY, len))
  check(string.format("a %d-byte payload is refused, not raised", len),
    raised and got == nil and reason == "short_payload",
    string.format("raised=%s decoded=%s reason=%s", tostring(not raised), tostring(got),
      tostring(reason)))
end

-- ---------------------------------------------------------------------------
-- Case 6: readU8 is bounds-safe, and the encoders cannot emit a fraction
-- ---------------------------------------------------------------------------

print("case 6: the codec defaults a short read and floors a write")

-- The primitive every other decoder funnels through. Its siblings have always
-- substituted 0 for a byte past the end; this one returned nil, and a nil in
-- the middle of a numeric field is what reached the caller's arithmetic.
check("readU8 of an empty buffer is 0", mspcodec.readU8({}) == 0)
check("readU8 past the end of a buffer is 0", (function()
  local buf = { 7 }
  mspcodec.readU8(buf)   -- consumes the one byte there is
  return mspcodec.readU8(buf) == 0
end)())
check("readU8 still reads a real byte", mspcodec.readU8({ 42 }) == 42)
check("readU8 of an empty buffer is 0, not nil", (function()
  local v = mspcodec.readU8({})
  return v ~= nil and v == 0
end)())
check("readS8 of an empty buffer is 0", mspcodec.readS8({}) == 0)
check("readU16 past the end is 0", (function()
  local buf = { 1 }       -- the second byte is missing
  return mspcodec.readU16(buf) == 1
end)())
check("readU16 of an empty buffer is 0", mspcodec.readU16({}) == 0)
check("readU32 of an empty buffer is 0", mspcodec.readU32({}) == 0)

-- The encode side. A float used to be written as-is -- 3.7 % 256 is 3.7 -- and
-- only failed later at the transport's bitwise or, with "number has no integer
-- representation". Not reachable from a current caller, but the guard belongs
-- next to the arithmetic that assumes it, and it is checkable.
local function encodedBytes(fn, value)
  local buf = {}
  mspcodec[fn](buf, value)
  return buf
end

check("writeU8 floors its argument", encodedBytes("writeU8", 3.7)[1] == 3)
check("writeU16 floors both bytes", (function()
  local b = encodedBytes("writeU16", 300.9)
  return b[1] == 44 and b[2] == 1
end)())
check("writeU32 floors all four bytes", (function()
  local b = encodedBytes("writeU32", 0x01020304.5)
  return b[1] == 4 and b[2] == 3 and b[3] == 2 and b[4] == 1
end)())
check("writeS8 of a negative value still wraps", encodedBytes("writeS8", -1)[1] == 255)
check("writeS16 of a negative value still wraps", (function()
  local b = encodedBytes("writeS16", -2)
  return b[1] == 254 and b[2] == 255
end)())

-- Every emitted byte has to survive the transport's `|`, which is what the
-- flooring above exists for. A fractional byte is the thing that must not
-- reach the wire.
check("no encoder emits a fraction outside 0..255", (function()
  local emitted = {}
  local function collect(fn, value)
    for _, b in ipairs(encodedBytes(fn, value)) do emitted[#emitted + 1] = b end
  end
  collect("writeU8", 1.5)
  collect("writeU16", 2.5)
  collect("writeU32", 3.5)
  for _, b in ipairs(emitted) do
    if b % 1 ~= 0 or b < 0 or b > 255 then return false, b end
  end
  return true
end)())

check("writeU16 round-trips through readU16", (function()
  local b = encodedBytes("writeU16", 0xBEEF)
  return mspcodec.readU16(b) == 0xBEEF
end)())
check("writeU32 round-trips through readU32", (function()
  local b = encodedBytes("writeU32", 0xDEADBEEF)
  return mspcodec.readU32(b) == 0xDEADBEEF
end)())

-- ---------------------------------------------------------------------------
-- Case 7: a caller that supplied no errorHandler must not be made to crash
-- ---------------------------------------------------------------------------

print("case 7: a refused payload with no errorHandler is still not a crash")

-- onBatteryConfigSaved() in session.lua passes no onError. A refusal that
-- raised there would turn "we could not confirm your save" into a dead task.
check("BATTERY_CONFIG survives a nil onError", pcall(function()
  mspBattery.buildBatteryConfigReadMessage(function() end).processReply(nil, {})
end) == true)
check("SMARTFUEL_CONFIG survives a nil onError", pcall(function()
  mspBattery.buildSmartfuelConfigReadMessage(function() end).processReply(nil, {})
end) == true)

-- ---------------------------------------------------------------------------
-- Case 8: stream and variable-length decoders (msp_modes) terminate safely
-- ---------------------------------------------------------------------------

print("case 8: stream and variable-length decoders terminate safely with readU8 bounds")

local function testModesDecoders()
  local mspModes = requireModule("lib/msp_modes.lua")

  -- Box names
  local namesSim = { 65, 82, 77, 59, 65, 78, 71, 76, 69, 59, 72, 79, 82, 73, 90, 79, 78, 59 }
  local names
  mspModes.buildBoxNamesReadMessage(function(d) names = d end).processReply(nil, namesSim)
  check("BOXNAMES decodes real names", names and #names == 3 and names[1] == "ARM" and names[2] == "ANGLE" and names[3] == "HORIZON")

  local emptyNames
  mspModes.buildBoxNamesReadMessage(function(d) emptyNames = d end).processReply(nil, {})
  check("BOXNAMES terminates on empty buffer", emptyNames and #emptyNames == 0)

  -- Box IDs
  local idsSim = { 0, 1, 2, 53, 27, 36, 45, 13, 52, 19, 20, 26, 31, 51, 55, 56, 57 }
  local ids
  mspModes.buildBoxIdsReadMessage(function(d) ids = d end).processReply(nil, idsSim)
  check("BOXIDS decodes all simulated ids", ids and #ids == #idsSim and ids[4] == 53)

  local emptyIds
  mspModes.buildBoxIdsReadMessage(function(d) emptyIds = d end).processReply(nil, {})
  check("BOXIDS terminates on empty buffer", emptyIds and #emptyIds == 0)

  -- Mode ranges
  local ranges
  local rangesSim = { 1, 0, 216, 40 }
  mspModes.buildModeRangesReadMessage(function(d) ranges = d end).processReply(nil, rangesSim)
  check("MODE_RANGES decodes valid 4-byte range", ranges and #ranges == 1 and ranges[1].id == 1 and ranges[1].auxChannelIndex == 0)

  local emptyRanges
  mspModes.buildModeRangesReadMessage(function(d) emptyRanges = d end).processReply(nil, {})
  check("MODE_RANGES terminates on empty buffer", emptyRanges and #emptyRanges == 0)

  local truncRanges
  mspModes.buildModeRangesReadMessage(function(d) truncRanges = d end).processReply(nil, { 1, 0, 216 })
  check("MODE_RANGES rejects truncated entry without loop", truncRanges and #truncRanges == 0)

  -- Mode ranges extra
  local extras
  local extrasSim = { 1, 5, 0, 2 }
  mspModes.buildModeRangesExtraReadMessage(function(d) extras = d end).processReply(nil, extrasSim)
  check("MODE_RANGES_EXTRA decodes valid entry", extras and #extras == 1 and extras[1].id == 5)

  local truncExtras
  mspModes.buildModeRangesExtraReadMessage(function(d) truncExtras = d end).processReply(nil, { 5, 1 })
  check("MODE_RANGES_EXTRA handles count exceeding buffer", truncExtras and #truncExtras == 0)
end

testModesDecoders()

-- ---------------------------------------------------------------------------
-- Case 9: the extended BATTERY_CONFIG payload carries per-profile cells
-- ---------------------------------------------------------------------------

print("case 9: an 81-byte BATTERY_CONFIG reply decodes its per-profile cells")

-- The 27-byte BATTERY_REPLY above stops at the capacities, so nothing in this
-- harness reached the per-profile block. The simulator fixture is the one
-- payload of that length in the tree, so it is decoded here: a 27-byte reply
-- must report no profileCells at all rather than six empty ones, and the
-- 81-byte one must report six profiles whose cell counts and cell voltages
-- are the ones the bytes carry.
local legacy = decodeBattery(BATTERY_REPLY)
check("a 27-byte reply reports no profileCells",
  legacy ~= nil and legacy.profileCells == nil,
  legacy and type(legacy.profileCells))

local extended = decodeBattery(simBattery)
check("the 81-byte fixture is accepted", extended ~= nil)

if extended then
  check("profileCells is present", extended.profileCells ~= nil)
  if extended.profileCells then
    -- Every fixture profile writes cellCount 6, and the four cell voltages as
    -- 330 / 420 / 410 / 350 -- index 5 included, which is the one a six-pack
    -- pilot actually picks.
    for i = 0, 5 do
      local p = extended.profileCells[i]
      check(string.format("profileCells[%d].cellCount", i),
        p ~= nil and p.cellCount == 6, p and p.cellCount)
      check(string.format("profileCells[%d].vbatMinCell", i),
        p ~= nil and math.abs(p.vbatMinCell - 3.30) < 1e-9, p and p.vbatMinCell)
      check(string.format("profileCells[%d].vbatMaxCell", i),
        p ~= nil and math.abs(p.vbatMaxCell - 4.20) < 1e-9, p and p.vbatMaxCell)
      check(string.format("profileCells[%d].vbatFullCell", i),
        p ~= nil and math.abs(p.vbatFullCell - 4.10) < 1e-9, p and p.vbatFullCell)
      check(string.format("profileCells[%d].vbatWarningCell", i),
        p ~= nil and math.abs(p.vbatWarningCell - 3.50) < 1e-9, p and p.vbatWarningCell)
    end
  end
end

-- ---------------------------------------------------------------------------

print("")
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
else
  print(string.format("%d of %d checks FAILED", failures, checks))
  os.exit(1)
end

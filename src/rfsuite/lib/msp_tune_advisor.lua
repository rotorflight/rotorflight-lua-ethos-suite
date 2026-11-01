-- Schema + message-builders for rotorflight-firmware's tune advisor
-- statistics: MSP2_GET_TUNE_ADVISOR (cmd 0x5F10, read) and
-- MSP2_CLEAR_TUNE_ADVISOR (cmd 0x5F11, write, empty payload). Both are new
-- commands with no MSP API version change: an FC without them answers with
-- an error, which the page reports as "needs newer firmware".
--
-- One axis per request: the request payload is U8 axis (0 roll, 1 pitch,
-- 2 yaw). The reply is 51 bytes, the most one CRSF frame carries (the
-- firmware sends a reply that exactly fills a frame as two), and 12
-- S.Port/FBUS frames.
--
-- Wire layout verified against rotorflight-firmware's own serializer
-- (src/main/msp/msp.c, MSP2_GET_TUNE_ADVISOR case), payload version 3:
--   U8 version, U8 flags (bits 0-1 axis, bit 2 collecting, bits 3-5
--   rates_type), U16 seconds of usable flight, then:
--     U32 P | F << 10 | B << 20, U8 iterm_relax_cutoff, U8 rc_rate,
--     U8 s_rate                                            (the tune measured)
--     U16 ffCount, U8 ffGain x64, S8 ffCorr x100, U8 ffLagMs
--     3 x {U8 gain x64, U16 count}  by request 40-100, 100-200, 200+ deg/s
--     3 x {U8 gain x64, U16 count}  by |collective| <25%, 25-50%, 50%+
--     U16 fullCount, U16 fullSatCount, U8 fullRatio x100,
--     U8 fullMaxRate in 10 deg/s
--     U16 releases, U8 bigRebounds, U8 meanRebound x100,
--     U8 meanOvershoot x64, U8 meanCounter x100, S16 meanIterm x1000
--     U16 shakeCount, U8 shakeRms x4 (deg/s)
-- Scaled values are decoded to plain numbers here; the firmware saturates
-- each, and bigRebounds, at its byte's range. Counts saturate at 65535. Versions 1 and 2 (67
-- and 71 bytes, every ratio 16-bit) were never in a firmware release and are
-- refused like any other. See src/main/flight/tune_advisor.c for what each
-- value measures.
--
-- Self-caches via package.loaded (same mechanism lib/bus.lua uses).
if package.loaded["rfsuite.lib.msp_tune_advisor"] then
  return package.loaded["rfsuite.lib.msp_tune_advisor"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 0x5F10
local CLEAR_COMMAND = 0x5F11
local AXIS_COUNT = 3
local BAND_COUNT = 3

local msp_tune_advisor = {
  READ_COMMAND = READ_COMMAND,
  CLEAR_COMMAND = CLEAR_COMMAND,
  AXIS_COUNT = AXIS_COUNT,
}

-- Simulator fixture, one reply per axis (Actual rates, center 180, max 240):
-- cyclic turning faster than asked with the usual stop bounce, pitch too
-- irregular to judge, tail with little data. The tune (P, F, B, cutoff,
-- rates) is the other fixtures' (lib/msp_pid_tuning.lua, msp_pid_profile.lua,
-- msp_rc_tuning.lua), so the Tune Advisor's Apply finds the FC still on the
-- tune that was flown.
local SIM_AXES = {
  {p = 70, f = 120, b = 0, cutoff = 10, rcRate = 18, sRate = 24, ffCount = 1491, ff = 1.53, corr = 0.97, lag = 90,
   sp = {{1.52, 1341}, {1.54, 163}, {1.03, 50}}, coll = {{1.24, 385}, {1.54, 763}, {1.73, 356}},
   full = {87, 25, 0.38, 395}, rel = {35, 18, 0.15, 1.47, 0.020, 0.003}, shake = {2410, 3.1}},
  {p = 100, f = 120, b = 0, cutoff = 10, rcRate = 18, sRate = 24, ffCount = 1172, ff = 0.79, corr = 0.78, lag = 70,
   sp = {{1.06, 999}, {0.45, 194}, {0, 54}}, coll = {{0.28, 446}, {1.27, 629}, {1.59, 118}},
   full = {105, 72, 0, 23}, rel = {10, 2, 0.09, 1.33, 0.019, 0.011}, shake = {1980, 2.4}},
  {p = 100, f = 0, b = 0, cutoff = 10, rcRate = 18, sRate = 40, ffCount = 404, ff = 0.27, corr = 0.84, lag = 250,
   sp = {{0.26, 300}, {0.30, 109}, {0, 0}}, coll = {{0.29, 409}, {0, 0}, {0, 0}},
   full = {29, 29, 0.09, 42}, rel = {0, 0, 0, 0, 0, 0}, shake = {3120, 1.2}},
}
local RATES_TYPE_ACTUAL = 4

-- Payload version 3 (firmware msp.c, MSP2_GET_TUNE_ADVISOR): its length,
-- and its one-byte values as value x scale
local PAYLOAD_VERSION = 3
local REPLY_LENGTH = 51
local GAIN_SCALE = 64        -- ffGain, band gains, meanOvershoot: U8, 0..3.98
local CORR_SCALE = 100       -- ffCorr: S8, -1.27..1.27
local FRACTION_SCALE = 100   -- fullRatio, meanRebound, meanCounter: U8, 0..2.55
local RATE_STEP = 10         -- fullMaxRate: U8 in steps of 10 deg/s
local SHAKE_SCALE = 4        -- shakeRms: U8, 0..63.75 deg/s
local ITERM_SCALE = 1000     -- meanIterm: S16
local GAIN_BITS = 1024       -- P, F and B: 10 bits each of one U32

local function scaled(v, scale, lo, hi)
  local n = math.floor(v * scale + 0.5)
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function buildSimulatorResponse(axis)
  local buf = {}
  local a = SIM_AXES[axis]
  local function u8(v, scale) mspcodec.writeU8(buf, scaled(v, scale, 0, 255)) end
  mspcodec.writeU8(buf, PAYLOAD_VERSION)
  mspcodec.writeU8(buf, (axis - 1) + RATES_TYPE_ACTUAL * 8)    -- not collecting
  mspcodec.writeU16(buf, 147)
  mspcodec.writeU32(buf, a.p + a.f * GAIN_BITS + a.b * GAIN_BITS * GAIN_BITS)
  mspcodec.writeU8(buf, a.cutoff)
  mspcodec.writeU8(buf, a.rcRate)
  mspcodec.writeU8(buf, a.sRate)
  mspcodec.writeU16(buf, a.ffCount)
  u8(a.ff, GAIN_SCALE)
  mspcodec.writeS8(buf, scaled(a.corr, CORR_SCALE, -128, 127))
  mspcodec.writeU8(buf, a.lag)
  for i = 1, BAND_COUNT do u8(a.sp[i][1], GAIN_SCALE); mspcodec.writeU16(buf, a.sp[i][2]) end
  for i = 1, BAND_COUNT do u8(a.coll[i][1], GAIN_SCALE); mspcodec.writeU16(buf, a.coll[i][2]) end
  mspcodec.writeU16(buf, a.full[1])
  mspcodec.writeU16(buf, a.full[2])
  u8(a.full[3], FRACTION_SCALE)
  u8(a.full[4], 1 / RATE_STEP)
  mspcodec.writeU16(buf, a.rel[1])
  mspcodec.writeU8(buf, math.min(a.rel[2], 255))
  u8(a.rel[3], FRACTION_SCALE)
  u8(a.rel[4], GAIN_SCALE)
  u8(a.rel[5], FRACTION_SCALE)
  mspcodec.writeS16(buf, scaled(a.rel[6], ITERM_SCALE, -32768, 32767))
  mspcodec.writeU16(buf, a.shake[1])
  u8(a.shake[2], SHAKE_SCALE)
  return buf
end

local function readScaled(buf, scale)
  return (mspcodec.readU8(buf) or 0) / scale
end

local function readBands(buf)
  local bands = {}
  for i = 1, BAND_COUNT do
    bands[i] = {gain = readScaled(buf, GAIN_SCALE), count = mspcodec.readU16(buf) or 0}
  end
  return bands
end

-- Returns {version, collecting, seconds, axis (1-3), a = {per-axis fields}},
-- or nil, a reason, and true when the reply was REFUSED rather than lost.
-- A reply of another version or length is refused, not decoded: a reworded
-- record would otherwise come out as plausible numbers, and tune_history
-- saves them.
--
-- The third value is what separates the two reasons a caller can do nothing about differently.
-- `true` from the transport means the firmware has no tune advisor at all; a refusal means it has
-- one and answered, in a layout this suite does not know. Both are deterministic -- asking again
-- cannot change either -- so a caller retries neither. The reason text stays a string, so a log
-- line and a pilot-facing message can name what came back.
function msp_tune_advisor.decode(buf)
  local length = #buf
  if buf[1] ~= PAYLOAD_VERSION then
    return nil, "tune advisor payload version " .. tostring(buf[1]) .. ", expected " .. PAYLOAD_VERSION, true
  end
  if length ~= REPLY_LENGTH then
    return nil, "tune advisor reply is " .. length .. " bytes, expected " .. REPLY_LENGTH, true
  end

  buf.offset = 1
  local version = mspcodec.readU8(buf)
  local flags = mspcodec.readU8(buf) or 0
  local data = {
    version = version,
    collecting = (flags // 4) % 2 == 1,
    seconds = mspcodec.readU16(buf) or 0,
    axis = flags % 4 + 1,
  }

  local gains = mspcodec.readU32(buf) or 0
  local a = {
    P = gains % GAIN_BITS,
    F = (gains // GAIN_BITS) % GAIN_BITS,
    B = (gains // (GAIN_BITS * GAIN_BITS)) % GAIN_BITS,
    ratesType = (flags // 8) % 8,
  }
  a.relaxCutoff = mspcodec.readU8(buf) or 0
  a.rcRate = mspcodec.readU8(buf) or 0
  a.sRate = mspcodec.readU8(buf) or 0
  a.ffCount = mspcodec.readU16(buf) or 0
  a.ffGain = readScaled(buf, GAIN_SCALE)
  a.ffCorr = (mspcodec.readS8(buf) or 0) / CORR_SCALE
  a.ffLagMs = mspcodec.readU8(buf) or 0
  a.spBands = readBands(buf)
  a.collBands = readBands(buf)
  a.fullCount = mspcodec.readU16(buf) or 0
  a.fullSatCount = mspcodec.readU16(buf) or 0
  a.fullRatio = readScaled(buf, FRACTION_SCALE)
  a.fullMaxRate = (mspcodec.readU8(buf) or 0) * RATE_STEP
  a.releases = mspcodec.readU16(buf) or 0
  a.bigRebounds = mspcodec.readU8(buf) or 0
  a.meanRebound = readScaled(buf, FRACTION_SCALE)
  a.meanOvershoot = readScaled(buf, GAIN_SCALE)
  a.meanCounter = readScaled(buf, FRACTION_SCALE)
  a.meanIterm = (mspcodec.readS16(buf) or 0) / ITERM_SCALE
  a.shakeCount = mspcodec.readU16(buf) or 0
  a.shakeRms = readScaled(buf, SHAKE_SCALE)
  data.a = a

  return data
end

local simulatorResponses = {}

-- axis: 1 roll, 2 pitch, 3 yaw
function msp_tune_advisor.buildReadMessage(axis, onData, onError)
  simulatorResponses[axis] = simulatorResponses[axis] or buildSimulatorResponse(axis)
  return {
    command = READ_COMMAND,
    payload = {axis - 1},
    processReply = function(_, buf)
      local data, reason, refused = msp_tune_advisor.decode(buf)
      if not data then
        -- `errorHandler` below answers an MSP error reply with `reason` alone, so a caller
        -- that tests the third value sees nil there and can still tell the two apart.
        if onError then onError(reason, refused) end
        return
      end
      onData(data)
    end,
    errorHandler = onError,
    -- Three sends, not the queue's six: the queue holds every other request
    -- while this one is out, and a 12-frame reply over S.Port or FBUS is the
    -- one most often lost. tasks/tune_history.lua asks again later anyway.
    maxRetries = 2,
    simulatorResponse = simulatorResponses[axis],
  }
end

function msp_tune_advisor.buildClearMessage(onDone, onError)
  return {
    command = CLEAR_COMMAND,
    payload = {},
    isWrite = true,
    processReply = function()
      if onDone then onDone() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

-- First firmware release that carries the commands above. 4.6.0 has none. That
-- release is not out yet, so 4.7.0 is the planned minimum (issue #2579); adjust it
-- once the release that ships the commands is known.
local FIRST_FIRMWARE = {4, 7, 0}

-- The Ethos simulator answers every command from the simulatorResponse
-- fixtures, these included, while its FC_VERSION fixture (lib/msp_handshake.lua)
-- reports an older firmware: there the version says nothing.
local IS_SIM = system ~= nil and system.getVersion ~= nil and system.getVersion().simulation == true

-- true when the FC firmware version (session.fcVersion, "M.m.p") is at least
-- FIRST_FIRMWARE, false when it is older, nil while the version is not known.
-- Always true in the simulator.
function msp_tune_advisor.supportFor(fcVersion)
  if IS_SIM then return true end
  if type(fcVersion) ~= "string" then return nil end
  local major, minor, patch = fcVersion:match("^(%d+)%.(%d+)%.(%d+)")
  if not major then return nil end
  local parts = {tonumber(major), tonumber(minor), tonumber(patch)}
  for i = 1, 3 do
    if parts[i] ~= FIRST_FIRMWARE[i] then return parts[i] > FIRST_FIRMWARE[i] end
  end
  return true
end

package.loaded["rfsuite.lib.msp_tune_advisor"] = msp_tune_advisor
return msp_tune_advisor

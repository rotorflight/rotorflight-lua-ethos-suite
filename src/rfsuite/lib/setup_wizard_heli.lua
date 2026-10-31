-- Setup Wizard: the helicopter rules every step shares. A copy of
-- rotorflight-configurator's src/tabs/setup_wizard/heli.js (and the EdgeTX
-- suite's helicopter_setup/math.lua, which ports the same file): which
-- servos a swashplate uses, the override units, pitch calibration and the
-- receiver channel detection. No form or MSP code: bin/setup_wizard_heli
-- runs it under plain Lua.

if package.loaded["rfsuite.lib.setup_wizard_heli"] then
  return package.loaded["rfsuite.lib.setup_wizard_heli"]
end

local floor = math.floor

local M = {}

local function round(v) return floor(v + 0.5) end
M.round = round

function M.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- A U16 read back as signed (the mixer inputs are int16 on the wire, but
-- lib/msp_mixer_input.lua reads them unsigned).
function M.signed16(v)
  v = tonumber(v) or 0
  if v >= 32768 then return v - 65536 end
  return v
end

-- Mixer inputs (MSP_MIXER_OVERRIDE index, lib/msp_mixer_input.lua index).
M.INPUT = {roll = 1, pitch = 2, yaw = 3, collective = 4}

-- Override values (rotorflight-firmware flight/mixer.h, flight/servos.h).
M.MIXER_OFF = 2501
M.MIXER_PASSTHROUGH = 2502
M.SERVO_OFF = 2001

-- Tail modes (mixer_config.tail_rotor_mode).
M.TAIL_VARIABLE = 0
M.TAIL_MOTORIZED = 1
M.TAIL_BIDIRECTIONAL = 2

-- A variable-pitch tail is always servo 4 (index 3).
M.TAIL_SERVO = 3

-- Swash types (mixer_config.swash_type) and the servos each one drives, in
-- servo order. `angle` is where the servo sits around the swash, degrees
-- clockwise from the front, seen from above (src/js/swash.js).
M.SWASH_NONE = 0
M.SWASH = {
  [1] = {name = "THRU", servos = {
    {role = "pitch", angle = 0}, {role = "roll", angle = -90}, {role = "collective", angle = 90}}},
  [2] = {name = "120", servos = {
    {role = "centre", angle = 0}, {role = "left", angle = -120}, {role = "right", angle = 120}}},
  [3] = {name = "135", servos = {
    {role = "centre", angle = 0}, {role = "left", angle = -135}, {role = "right", angle = 135}}},
  [4] = {name = "140", servos = {
    {role = "centre", angle = 0}, {role = "left", angle = -140}, {role = "right", angle = 140}}},
  [5] = {name = "90L", servos = {
    {role = "front", angle = 0}, {role = "left", angle = -90}}},
  [6] = {name = "90V", servos = {
    {role = "front_left", angle = -45}, {role = "front_right", angle = 45}}},
}
-- Offered by the Swashplate step, in this order; NONE stays in the Mixer pages.
M.SWASH_CHOICES = {2, 3, 4, 5, 6, 1}

function M.motorised(tailMode)
  return tailMode ~= nil and tailMode ~= M.TAIL_VARIABLE
end

-- The servos the wizard works on: {{servo = 0-based index, role =, tail =,
-- angle =, missing =}}. `missing` marks a servo past servoCount.
function M.wizardServos(swashType, tailMode, servoCount)
  local out = {}
  local swash = M.SWASH[swashType]
  if swash then
    for i, s in ipairs(swash.servos) do
      out[#out + 1] = {servo = i - 1, role = s.role, angle = s.angle, tail = false, missing = (i - 1) >= servoCount}
    end
  end
  if not M.motorised(tailMode) then
    out[#out + 1] = {servo = M.TAIL_SERVO, role = "tail", tail = true, missing = M.TAIL_SERVO >= servoCount}
  end
  return out
end

-- PWM servo count from MSP_STATUS: with bus servos it reports the PWM count
-- plus 18 (see lib/msp_servo_config.lua). The wizard drives at most 8.
function M.pwmServoCount(statusCount)
  local n = tonumber(statusCount) or 0
  if n > 8 then n = math.max(0, n - 18) end
  if n > 8 then n = 8 end
  return n
end

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------

-- Mixer override, main rotor: 1000 = 12 degrees of blade pitch.
function M.swashRaw(deg) return round(deg * 1000 / 12) end
-- Mixer override, variable-pitch tail: 1000 = 24 degrees.
function M.tailRaw(deg) return round(deg * 1000 / 24) end
-- Servo override: 1000 = 50 degrees of servo arm.
function M.servoRaw(deg) return round(deg * 1000 / 50) end

-- Mixer input min/max (and blade_pitch_limit) <-> degrees.
function M.limitDegrees(raw, tail)
  return round(math.abs(raw) * (tail and 24 or 12)) / 1000
end
function M.limitRaw(deg, tail)
  return round(deg * 1000 / (tail and 24 or 12))
end

-- tail_center_trim (0.1 % of the tail range) <-> degrees, one decimal.
function M.tailTrimDegrees(trim) return round(trim * 24 / 100) / 10 end
function M.tailTrimRaw(deg) return round(deg * 1000 / 24) end

-- The mixer rate that makes `commanded` degrees come out as `commanded`
-- degrees, when it measured `measured` at the current rate. Keeps the sign
-- (the direction), and the firmware's 200..2000 range.
function M.calibratedRate(rate, commanded, measured)
  if not (measured and measured > 0) or not (commanded and commanded > 0) then return rate end
  local sign = rate < 0 and -1 or 1
  return sign * round(M.clamp(math.abs(rate) * commanded / measured, 200, 2000))
end

---------------------------------------------------------------------------
-- Servo types (StepServoType.svelte)
---------------------------------------------------------------------------

M.BANDS = {
  wide = {mid = 1520, travel = 700, scale = 500},
  narrow = {mid = 760, travel = 250, scale = 250},
}
M.SERVO_TYPES = {
  {key = "analog", rate = 50, band = "wide"},
  {key = "digital", rate = 333, band = "wide"},
  {key = "narrow", rate = 560, band = "narrow"},
}

function M.bandOf(config)
  return (config and config.mid or 1520) > 860 and "wide" or "narrow"
end

function M.bandCentre(config)
  return M.BANDS[M.bandOf(config)].mid
end

-- The type a servo config matches, or nil (custom).
function M.servoTypeOf(config)
  if not config then return nil end
  local band = M.bandOf(config)
  for _, t in ipairs(M.SERVO_TYPES) do
    if t.rate == config.rate and t.band == band then return t.key end
  end
  return nil
end

-- Applies a type to a servo config in place. Returns true when the update
-- rate changed (which only applies after a restart).
function M.applyServoType(config, key)
  local t
  for _, v in ipairs(M.SERVO_TYPES) do
    if v.key == key then t = v end
  end
  if not t then return false end
  local rateChanged = config.rate ~= t.rate
  config.rate = t.rate
  if M.bandOf(config) ~= t.band then
    local b = M.BANDS[t.band]
    config.mid = b.mid
    config.min = -b.travel
    config.max = b.travel
    config.rneg = b.scale
    config.rpos = b.scale
  end
  return rateChanged
end

M.SERVO_FLAG_REVERSE = 1

---------------------------------------------------------------------------
-- Receiver (StepReceiver.svelte)
---------------------------------------------------------------------------

-- RX map presets, by function: roll, pitch, yaw, collective, throttle,
-- AUX1..3 -> receiver channel (0-based).
M.CHANNEL_PRESETS = {
  {key = "elrs", map = {0, 1, 3, 2, 5, 4, 6, 7}},
  {key = "frsky", map = {0, 1, 3, 4, 2, 5, 6, 7}},
  {key = "futaba", map = {0, 1, 3, 5, 2, 4, 6, 7}},
  {key = "spektrum", map = {1, 2, 3, 5, 0, 4, 6, 7}},
}

-- Function order the sticks are detected in (RX map slot, 1-based):
-- collective, roll, pitch, yaw, throttle.
M.DETECT_ORDER = {4, 1, 2, 3, 5}

-- The channel that moved: its peak deviation is at least `minimum` us and
-- at least twice any other channel's. peaks[i] for channel i (1-based);
-- excluded[i] true skips a channel already taken. Returns i or nil.
function M.moved(peaks, excluded, minimum)
  local best, high, second = nil, 0, 0
  for i = 1, #peaks do
    if not (excluded and excluded[i]) then
      local v = peaks[i] or 0
      if v > high then
        second, high, best = high, v, i
      elseif v > second then
        second = v
      end
    end
  end
  if high < (minimum or 300) or high < second * 2 then return nil end
  return best
end

-- An RX map from detected channels: detected[slot] = channel (0-based) for
-- the slots found; every other slot gets the channels left over, in order.
function M.mapFromDetected(detected, slots)
  slots = slots or 8
  local map, used = {}, {}
  for slot = 1, slots do
    local ch = detected[slot]
    if ch ~= nil then
      map[slot] = ch
      used[ch] = true
    end
  end
  local nextCh = 0
  for slot = 1, slots do
    if map[slot] == nil then
      while used[nextCh] do nextCh = nextCh + 1 end
      map[slot] = nextCh
      used[nextCh] = true
    end
  end
  return map
end

-- The preset key a map matches, or nil.
function M.presetOf(map)
  for _, p in ipairs(M.CHANNEL_PRESETS) do
    local same = true
    for i = 1, #p.map do
      if map[i] ~= p.map[i] then same = false; break end
    end
    if same then return p.key end
  end
  return nil
end

-- Throttle range: the FC's own end points when rc_min/max_throttle are 0.
function M.throttleEnds(rc)
  local zero = (rc.rc_min_throttle or 0) ~= 0 and rc.rc_min_throttle
    or round(rc.rc_center - rc.rc_deflection * 0.9)
  local full = (rc.rc_max_throttle or 0) ~= 0 and rc.rc_max_throttle
    or round(rc.rc_center + rc.rc_deflection * 0.9)
  return zero, full
end

-- Measured low/high (us) -> rc_min_throttle, rc_max_throttle, or nil when
-- the travel is under 300 us.
function M.throttleFromMeasured(low, high)
  if not low or not high or high - low < 300 then return nil end
  return low + 20, high - 20
end

package.loaded["rfsuite.lib.setup_wizard_heli"] = M
return M

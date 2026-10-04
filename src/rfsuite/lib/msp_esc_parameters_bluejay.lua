-- Bluejay forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_bluejay"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_bluejay"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 217
local WRITE_COMMAND = 218

local ON_OFF = {{"Off", 0}, {"On", 1}}
local MOTOR_DIRECTION = {{"Normal", 1}, {"Reversed", 2}, {"Bidirectional", 3}, {"Bidirectional Rev", 4}}
local MOTOR_TIMING = {{"Low", 1}, {"Medium Low", 2}, {"Medium", 3}, {"Medium High", 4}, {"High", 5}}
local DEMAG = {{"Off", 1}, {"Low", 2}, {"High", 3}}
local BEACON_DELAY = {
  {"1 minute", 1}, {"2 minutes", 2}, {"5 minutes", 3}, {"10 minutes", 4}, {"Infinite", 5},
}
local TEMP_PROTECTION = {
  {"Disabled", 0}, {"80C", 1}, {"90C", 2}, {"100C", 3}, {"110C", 4},
  {"120C", 5}, {"130C", 6}, {"140C", 7},
}
local RAMPUP_POWER = {
  {"1x (More protection)", 1}, {"2x", 2}, {"3x", 3}, {"4x", 4},
  {"5x", 5}, {"6x", 6}, {"7x", 7}, {"8x", 8}, {"9x", 9},
  {"10x", 10}, {"11x", 11}, {"12x", 12}, {"13x (Less protection)", 13},
  {"Off", 0},
}
local RAMPUP_START_POWER = {
  {"0.5% (0.031)", 1}, {"5% (0.25)", 7}, {"7% (0.38)", 8},
  {"10% (0.50)", 9}, {"15% (0.75)", 10}, {"20% (1.00)", 11},
  {"24% (1.25)", 12}, {"29% (1.50)", 13},
}
local PWM_OLD = {{"24kHz", 24}, {"48kHz", 48}, {"96kHz", 96}}
local PWM_DYNAMIC = {{"24kHz", 24}, {"48kHz", 48}, {"96kHz", 96}, {"Dynamic", 0}}
local STARTUP_BEEP_OLD = ON_OFF
local STARTUP_BEEP_205 = {{"Off", 0}, {"Normal", 1}, {"Custom", 2}}
local BRAKING_MODE = {{"Off", 0}, {"Not during startup", 1}, {"On", 2}}
local LED_CONTROL = {
  {"Off", 0x00}, {"Blue", 0x03}, {"Green", 0x0c}, {"Red", 0x30},
  {"Cyan", 0x0f}, {"Magenta", 0x33}, {"Yellow", 0x3c}, {"White", 0x3f},
}
local POWER_RATING = {{"1S", 1}, {"2S+", 2}}

local FIELD_META = {
  motor_direction = {choices = MOTOR_DIRECTION},
  rpm_power_slope = {choices = RAMPUP_POWER},
  startup_power_min = {min = 1000, max = 1125},
  startup_power_max = {min = 1004, max = 1300},
  pwm_frequency = {choices = PWM_OLD},
  commutation_timing = {choices = MOTOR_TIMING},
  demag_compensation = {choices = DEMAG},
  brake_on_stop = {choices = ON_OFF},
  braking_strength = {min = 0, max = 255},
  led_control = {choices = LED_CONTROL},
  beep_strength = {min = 0, max = 255},
  beacon_strength = {min = 0, max = 255},
  beacon_delay = {choices = BEACON_DELAY},
  startup_beep = {choices = STARTUP_BEEP_OLD},
  temperature_protection = {choices = TEMP_PROTECTION},
  low_rpm_power_protection = {choices = ON_OFF},
  power_rating = {choices = POWER_RATING},
  force_edt_arm = {choices = ON_OFF},
  dithering = {choices = ON_OFF},
  threshold_48to24 = {min = 0, max = 100, suffix = "%"},
  threshold_96to48 = {min = 0, max = 100, suffix = "%"},
}

local WIRE_FIELDS = {
  {"esc_signature", "u8"},
  {"esc_command", "u8"},
  {"main_revision", "u8"},
  {"sub_revision", "u8"},
  {"layout_revision", "u8"},
  {"reserved_03", "u8"},
  {"startup_power_min", "startup_power_min"},
  {"startup_beep", "u8"},
  {"dithering", "u8"},
  {"startup_power_max", "startup_power_max"},
  {"reserved_08", "u8"},
  {"rpm_power_slope", "u8"},
  {"pwm_frequency", "pwm_frequency"},
  {"motor_direction", "u8"},
  {"reserved_0c", "u8"},
  {"mode_raw", "u16"},
  {"reserved_0f", "u8"},
  {"braking_strength", "u8"},
  {"reserved_11", "u8"},
  {"reserved_12", "u8"},
  {"reserved_13", "u8"},
  {"reserved_14", "u8"},
  {"commutation_timing", "u8"},
  {"reserved_16", "u8"},
  {"reserved_17", "u8"},
  {"reserved_18", "u8"},
  {"reserved_19", "u8"},
  {"reserved_1a", "u8"},
  {"beep_strength", "u8"},
  {"beacon_strength", "u8"},
  {"beacon_delay", "u8"},
  {"reserved_1e", "u8"},
  {"demag_compensation", "u8"},
  {"reserved_20", "u8"},
  {"reserved_21", "u8"},
  {"reserved_22", "u8"},
  {"temperature_protection", "u8"},
  {"low_rpm_power_protection", "u8"},
  {"reserved_25", "u8"},
  {"reserved_26", "u8"},
  {"brake_on_stop", "u8"},
  {"led_control", "u8"},
  {"power_rating", "u8"},
  {"force_edt_arm", "u8"},
  {"threshold_48to24", "threshold"},
  {"threshold_96to48", "threshold"},
}

for i = 0x2d, 0x3f do
  WIRE_FIELDS[#WIRE_FIELDS + 1] = {string.format("reserved_%02x", i), "u8"}
end

local SIMULATOR_RESPONSE = {
  193, 0, 0, 22, 209, 255, 51, 0, 0, 5, 255, 9, 24, 1, 255, 85,
  170, 255, 255, 255, 255, 255, 255, 4, 255, 255, 255, 255, 255, 40, 80, 4,
  255, 2, 255, 255, 255, 0, 1, 255, 255, 0, 0, 2, 0, 170, 85, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
}

local function clamp(value, min, max)
  value = math.floor((value or 0) + 0.5)
  if value < min then return min end
  if value > max then return max end
  return value
end

-- For four of these wire types the byte the ESC stores is not the number the
-- page shows: the range is coarser than the 256 bytes behind it, so several
-- bytes share one displayed value. NORMALIZE is stored byte -> shown value and
-- ENCODED is the other direction; a wire type in neither is the identity, which
-- is every u8 and the one u16.
--
-- That is also why none of these can be inverted from the value alone.
-- startup_power_min folds 256 bytes onto 126 shown values, so a shown value does
-- not say which byte it came from; pwm_frequency spells one position two ways,
-- with 192 and 0 both meaning "Dynamic". encode() therefore compares against the
-- stored byte rather than against a re-derived one, which is what lets it write
-- a byte it did not have to change back untouched.
local NORMALIZE = {
  startup_power_min = function(raw) return clamp(raw * 1000 / 2047 + 1000, 1000, 1125) end,
  startup_power_max = function(raw) return clamp(raw * 1000 / 250 + 1000, 1004, 1300) end,
  pwm_frequency = function(raw) if raw == 192 then return 0 end return raw end,
  threshold = function(raw) return clamp(raw * 100 / 255, 0, 100) end,
}

local ENCODED = {
  startup_power_min = function(value) return clamp((value - 1000) * 2047 / 1000, 0, 255) end,
  startup_power_max = function(value) return clamp((value - 1000) * 250 / 1000, 0, 255) end,
  pwm_frequency = function(value) if value == 0 then return 192 end return value end,
  threshold = function(value) return clamp(value * 255 / 100, 0, 255) end,
}

-- The two PWM-frequency thresholds are one decision wearing two rows: the 96->48
-- threshold must not sit above the 48->24 one. Kept as names because the pair
-- has to be recognised field by field while the block is laid out, and
-- THRESHOLD_CEILING is declared first in WIRE_FIELDS on purpose -- it is the
-- value the other one is held under, so it has to be known before the second
-- of the pair is written.
local THRESHOLD_CEILING = "threshold_48to24"
local THRESHOLD_CAPPED = "threshold_96to48"

-- The next field out of `source`, as the number the ESC stores, advancing
-- source.offset. u16 is little-endian, which is the order mspcodec.writeU16
-- lays it down in.
local function takeRaw(source, wireType)
  if wireType == "u16" then
    local lo = mspcodec.readU8(source)
    local hi = mspcodec.readU8(source)
    return lo + hi * 256
  end
  return mspcodec.readU8(source)
end

local function putRaw(payload, wireType, value)
  if wireType == "u16" then
    mspcodec.writeU16(payload, value)
    return
  end
  mspcodec.writeU8(payload, value)
end

local function shownValue(wireType, stored)
  local normalize = NORMALIZE[wireType]
  if not normalize then return stored end
  return normalize(stored)
end

local function storedValue(wireType, value)
  local encode = ENCODED[wireType]
  if not encode then return value end
  return encode(value)
end

local function decode(buf)
  buf.offset = 1
  -- Every byte the ESC sent, kept verbatim. The page declares 21 rows for this
  -- block and fewer are shown on any one ESC, since several depend on the layout
  -- revision; the rest of the 66 are vendor bytes, reserved flags and legacy
  -- encodings that a configurator app wrote and this suite never had to
  -- understand. encode() is why they are worth keeping.
  local raw = {}
  for i = 1, #buf do raw[i] = buf[i] or 0 end
  local data = {_raw = raw}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = shownValue(field[2], takeRaw(buf, field[2]))
  end
  return data
end

-- The block the flight controller hands the ESC is the 66 bytes this suite
-- sends and nothing else: msp.c's MSP_SET_ESC_PARAMETERS copies exactly
-- escGetParamBufferLength() bytes over the update buffer and commits that
-- (msp.c:3399-3408, esc_sensor.c:4553-4570 -- a 2-byte header plus the ESC's
-- first 0x40 parameter bytes). The firmware keeps the rest of the ESC's
-- parameter block itself, from its own cache; these 64 are the Lua suite's.
--
-- So every byte this function does not reproduce is a byte the ESC is told
-- changed. Laying the block out from the parsed fields rewrites all of it, and
-- it rewrites the rows that DO exist too whenever the number a row shows is not
-- the byte behind it -- measured on the pre-fix codec, a save that touched only
-- the beacon volume moved the minimum startup power on 130 of its 256 byte
-- values, the maximum startup power on 181, and a PWM threshold on 155 and 188.
--
-- So the payload starts as a copy of what the ESC sent, and one field is
-- written only when the pilot moved it off the byte that value came from.
-- Everything else is the ESC's own byte back, verbatim. This is the rule the
-- EdgeTX suite applies to its five transformed fields
-- (esc_parameters_bluejay.lua's TRANSFORMS and buildWritePayload), extended
-- from those five to the whole block -- and, unlike that one, a byte this
-- layout does not name at all survives too, because the payload is the ESC's
-- rather than a fresh one.
local function encode(data)
  if type(data) ~= "table" or type(data._raw) ~= "table" then
    return nil, "_raw"
  end

  local payload = {}
  local ceiling, ceilingMoved = nil, false

  data._raw.offset = 1
  for i = 1, #WIRE_FIELDS do
    local name, wireType = WIRE_FIELDS[i][1], WIRE_FIELDS[i][2]
    local stored = takeRaw(data._raw, wireType)
    local shown = shownValue(wireType, stored)
    local value = data[name]
    local moved = value ~= nil and value ~= shown
    if not moved then value = shown end

    if name == THRESHOLD_CEILING then
      ceiling, ceilingMoved = value, moved
    elseif name == THRESHOLD_CAPPED then
      -- One decision wearing two rows, so moving either half moves the pair --
      -- but only then. An ESC that reports the two the other way round keeps
      -- them on a save that changed something else, which is the whole point of
      -- starting from the ESC's own bytes.
      if (ceilingMoved or moved) and ceiling ~= nil and value > ceiling then
        value = ceiling
        moved = true
      end
    end

    if moved then
      putRaw(payload, wireType, storedValue(wireType, value))
    else
      putRaw(payload, wireType, stored)
    end
  end

  return payload
end

local function layout(data)
  return tonumber(data and data.layout_revision) or 0
end

local function supportsLedControl(data)
  local raw = data and data._raw
  local prefix = raw and raw[67]
  return prefix == string.byte("E") or prefix == string.byte("J") or prefix == string.byte("M")
    or prefix == string.byte("Q") or prefix == string.byte("U")
end

local function choicesFor(data, key)
  local rev = layout(data)
  if key == "rpm_power_slope" then
    if rev == 200 then return RAMPUP_START_POWER end
    return RAMPUP_POWER
  end
  if key == "startup_beep" then
    if rev == 205 then return STARTUP_BEEP_205 end
    return STARTUP_BEEP_OLD
  end
  if key == "braking_strength" and rev == 202 then return BRAKING_MODE end
  if key == "pwm_frequency" then
    if rev >= 209 then return PWM_DYNAMIC end
    return PWM_OLD
  end
  return nil
end

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 193,
  FIELD_META = FIELD_META,
  TITLE = "Bluejay",
}

function msp.isCompatible(data)
  return tonumber(data and data.esc_signature) == msp.EXPECTED_SIGNATURE
    and tonumber(data and data.main_revision) == 0
end

function msp.supportsLedControl(data)
  return supportsLedControl(data)
end

function msp.choicesFor(data, key)
  return choicesFor(data, key)
end

function msp.summaryFor(data)
  return string.format("Bluejay / Rev %d / FW%d.%d",
    tonumber(data and data.layout_revision) or 0,
    tonumber(data and data.main_revision) or 0,
    tonumber(data and data.sub_revision) or 0)
end

function msp.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf) onData(decode(buf)) end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- Builds a ready-to-publish write message. `data` is the table buildReadMessage()
-- handed onData() -- the whole thing, not only the rows this page shows, since
-- the block is written at once and encode() starts from the bytes it carries.
--
-- Returns `nil, reason` when there is no such table, and no message at all in
-- that case: a payload laid out without the ESC's own bytes would put zeroes
-- where the ESC had vendor flags and legacy timing tables, which is the defect
-- this encoding exists to prevent, so there is nothing to publish. Returning a
-- message with no payload is not an option -- app/page_runtime.lua treats a nil
-- message as a refused write and reports it (see its writeSource()), the same
-- as lib/msp_governor_profile.lua's refusal.
function msp.buildWriteMessage(data, onWritten, onError)
  local payload, reason = encode(data)
  if not payload then
    return nil, reason
  end
  return {
    command = WRITE_COMMAND,
    payload = payload,
    isWrite = true,
    processReply = function() if onWritten then onWritten() end end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

msp._decode = decode
msp._encode = encode
msp._simulatorResponse = SIMULATOR_RESPONSE

package.loaded["rfsuite.lib.msp_esc_parameters_bluejay"] = msp
return msp

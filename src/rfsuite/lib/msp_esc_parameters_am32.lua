-- AM32 forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_am32"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_am32"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 217
local WRITE_COMMAND = 218

local MOTOR_DIRECTION = {{"Normal", 0}, {"Reversed", 1}}
local ON_OFF = {{"Off", 0}, {"On", 1}}
local TIMING_ADVANCE = {{"0 deg", 0}, {"7.5 deg", 1}, {"15 deg", 2}, {"22.5 deg", 3}}
local PROTOCOL = {{"Auto", 0}, {"Dshot 300-600", 1}, {"Servo 1-2ms", 2}, {"Serial", 3}, {"BF Safe Arming", 4}}
local BRAKE_ON_STOP = {
  {"@i18n(app.modules.esc_tools.mfg.am32.tbl_brake_off)@", 0},
  {"@i18n(app.modules.esc_tools.mfg.am32.tbl_brake_brake)@", 1},
  {"@i18n(app.modules.esc_tools.mfg.am32.tbl_brake_active)@", 2},
}
local VARIABLE_PWM = {
  {"@i18n(app.modules.esc_tools.mfg.am32.tbl_pwm_fixed)@", 0},
  {"@i18n(app.modules.esc_tools.mfg.am32.tbl_pwm_variable)@", 1},
  {"@i18n(app.modules.esc_tools.mfg.am32.tbl_pwm_rpm)@", 2},
}
local LOW_VOLTAGE_CUTOFF = {
  {"@i18n(app.modules.esc_tools.mfg.am32.tbl_lvc_off)@", 0},
  {"@i18n(app.modules.esc_tools.mfg.am32.tbl_lvc_cell)@", 1},
  {"@i18n(app.modules.esc_tools.mfg.am32.tbl_lvc_abs)@", 2},
}

local FIELD_META = {
  motor_direction = {choices = MOTOR_DIRECTION},
  bidirectional_mode = {choices = ON_OFF},
  sinusoidal_startup = {choices = ON_OFF},
  complementary_pwm = {choices = ON_OFF},
  variable_pwm_frequency = {choices = VARIABLE_PWM},
  stuck_rotor_protection = {choices = ON_OFF},
  timing_advance = {choices = TIMING_ADVANCE},
  pwm_frequency = {min = 8, max = 144, suffix = "kHz"},
  startup_power = {min = 50, max = 150, default = 100, suffix = "%"},
  motor_kv = {min = 20, max = 10220, suffix = "KV"},
  motor_poles = {min = 2, max = 36, default = 14},
  brake_on_stop = {choices = BRAKE_ON_STOP},
  stall_protection = {choices = ON_OFF},
  beep_volume = {min = 0, max = 11, default = 10},
  interval_telemetry = {choices = ON_OFF},
  servo_low_threshold = {min = 750, max = 1250, suffix = "us"},
  servo_high_threshold = {min = 1750, max = 2250, suffix = "us"},
  servo_neutral = {min = 1374, max = 1630, suffix = "us"},
  servo_dead_band = {min = 0, max = 100},
  low_voltage_cutoff = {choices = LOW_VOLTAGE_CUTOFF},
  low_voltage_threshold = {min = 250, max = 350, suffix = "cV"},
  rc_car_reversing = {choices = ON_OFF},
  use_hall_sensors = {choices = ON_OFF},
  sine_mode_range = {min = 5, max = 25},
  brake_strength = {min = 0, max = 10, default = 0},
  running_brake_level = {min = 0, max = 10, default = 0},
  temperature_limit = {min = 70, max = 145, suffix = "C"},
  current_limit = {min = 0, max = 510},
  sine_mode_power = {min = 1, max = 10},
  esc_protocol = {choices = PROTOCOL},
  auto_advance = {choices = ON_OFF},
}

local WIRE_FIELDS = {
  {"esc_signature", "u8"},
  {"esc_command", "u8"},
  {"reserved_0", "u8"},
  {"eeprom_version", "u8"},
  {"reserved_1", "u8"},
  {"version_major", "u8"},
  {"version_minor", "u8"},
  {"max_ramp", "u8"},
  {"minimum_duty_cycle", "u8"},
  {"disable_stick_calibration", "u8"},
  {"absolute_voltage_cutoff", "u8"},
  {"current_p", "u8"},
  {"current_i", "u8"},
  {"current_d", "u8"},
  {"active_brake_power", "u8"},
  {"reserved_eeprom_3_0", "u8"},
  {"reserved_eeprom_3_1", "u8"},
  {"reserved_eeprom_3_2", "u8"},
  {"reserved_eeprom_3_3", "u8"},
  {"motor_direction", "u8"},
  {"bidirectional_mode", "u8"},
  {"sinusoidal_startup", "u8"},
  {"complementary_pwm", "u8"},
  {"variable_pwm_frequency", "u8"},
  {"stuck_rotor_protection", "u8"},
  {"timing_advance", "timing"},
  {"pwm_frequency", "u8"},
  {"startup_power", "u8"},
  {"motor_kv", "motor_kv"},
  {"motor_poles", "u8"},
  {"brake_on_stop", "u8"},
  {"stall_protection", "u8"},
  {"beep_volume", "u8"},
  {"interval_telemetry", "u8"},
  {"servo_low_threshold", "servo_low"},
  {"servo_high_threshold", "servo_high"},
  {"servo_neutral", "servo_neutral"},
  {"servo_dead_band", "u8"},
  {"low_voltage_cutoff", "u8"},
  {"low_voltage_threshold", "low_voltage"},
  {"rc_car_reversing", "u8"},
  {"use_hall_sensors", "u8"},
  {"sine_mode_range", "u8"},
  {"brake_strength", "u8"},
  {"running_brake_level", "u8"},
  {"temperature_limit", "u8"},
  {"current_limit", "current_limit"},
  {"sine_mode_power", "u8"},
  {"esc_protocol", "u8"},
  {"auto_advance", "u8"},
}

local SIMULATOR_RESPONSE = {
  194, 64, 1, 3, 1, 2, 19, 50, 1, 0, 10, 100, 0, 100, 0,
  255, 255, 255, 255, 0, 0, 0, 0, 0, 1, 26, 16, 50, 12, 24,
  0, 1, 5, 0, 128, 128, 128, 50, 0, 50, 0, 0, 10, 10, 5, 145,
  102, 7, 1, 0
}

local function clamp(value, min, max)
  value = math.floor((value or 0) + 0.5)
  if value < min then return min end
  if value > max then return max end
  return value
end

-- For seven of these wire types the byte the ESC stores is not the number the
-- page shows. NORMALIZE is stored byte -> shown value and ENCODED is the other
-- direction; a wire type in neither is the identity, which is every plain byte.
--
-- timing is the one that costs the ESC something. Two firmware generations
-- number the four timing-advance positions differently -- 0..3 and 10..42 in
-- steps of 8 -- and both spellings are in the field, so the byte a position
-- came from decides what has to go back. That is why ENCODED.timing takes the
-- stored byte as its second argument: it is not derivable from the position.
local NORMALIZE = {
  timing = function(raw)
    if raw >= 10 and raw <= 42 then return clamp((raw - 10) / 8, 0, 3) end
    return clamp(raw, 0, 3)
  end,
  motor_kv = function(raw) return raw * 40 + 20 end,
  servo_low = function(raw) return raw * 2 + 750 end,
  servo_high = function(raw) return raw * 2 + 1750 end,
  servo_neutral = function(raw) return raw + 1374 end,
  low_voltage = function(raw) return raw + 250 end,
  current_limit = function(raw) return raw * 2 end,
}

local ENCODED = {
  timing = function(value, stored)
    if stored >= 10 and stored <= 42 then return 10 + value * 8 end
    return value
  end,
  motor_kv = function(value) return clamp((value - 20) / 40, 0, 255) end,
  servo_low = function(value) return clamp((value - 750) / 2, 0, 255) end,
  servo_high = function(value) return clamp((value - 1750) / 2, 0, 255) end,
  servo_neutral = function(value) return clamp(value - 1374, 0, 255) end,
  low_voltage = function(value) return clamp(value - 250, 0, 255) end,
  current_limit = function(value) return clamp(value / 2, 0, 255) end,
}

local function shownValue(wireType, stored)
  local normalize = NORMALIZE[wireType]
  if not normalize then return stored end
  return normalize(stored)
end

local function storedValue(wireType, value, stored)
  local encode = ENCODED[wireType]
  if not encode then return value end
  return encode(value, stored)
end

local function decode(buf)
  buf.offset = 1
  -- Every byte the ESC sent, kept verbatim. The page declares 31 rows for these
  -- 50; the rest are the governor's PID terms, the EEPROM bookkeeping and the
  -- reserved bytes a vendor tool wrote. encode() is why they are worth keeping.
  local raw = {}
  for i = 1, #buf do raw[i] = buf[i] or 0 end
  local data = {_raw = raw}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = shownValue(field[2], mspcodec.readU8(buf))
  end
  return data
end

-- The 50 bytes this suite sends are the whole of what the flight controller
-- hands the ESC for an AM32: msp.c's MSP_SET_ESC_PARAMETERS copies exactly
-- escGetParamBufferLength() bytes over the update buffer and commits that
-- (msp.c:3399-3408, esc_sensor.c:4608-4611 -- AM32_NUM_EEPROM_BYTES plus the
-- two-byte header). Whatever encode() does not reproduce is a byte the ESC is
-- told changed.
--
-- Laying the block out from the parsed fields rewrites all of it, and it
-- rewrites the rows that DO exist too wherever the number a row shows is not
-- the byte behind it. The timing-advance byte is the worst case by a wide
-- margin: two firmware generations number the same four positions differently,
-- so 248 of its 256 values came back as something else -- measured on the
-- pre-fix codec, an ESC reporting 11 (a timing position the older numbering
-- does not have) was saved as 10, and one reporting 42 as 34. That is motor
-- timing rewritten by a save that changed the beep volume.
--
-- So the payload starts as a copy of what the ESC sent, and one field is
-- written only when the pilot moved it off the byte that value came from.
-- Everything else is the ESC's own byte back, verbatim. This is the rule the
-- EdgeTX suite already applies to the timing byte
-- (esc_parameters_am32.lua's encodeTimingAdvance), and starting from the ESC's
-- own block rather than from the layout is what extends it to the other 49.
local function encode(data)
  if type(data) ~= "table" or type(data._raw) ~= "table" then
    return nil, "_raw"
  end

  local payload = {}
  data._raw.offset = 1
  for i = 1, #WIRE_FIELDS do
    local name, wireType = WIRE_FIELDS[i][1], WIRE_FIELDS[i][2]
    local stored = mspcodec.readU8(data._raw)
    local shown = shownValue(wireType, stored)
    local value = data[name]
    if value == nil or value == shown then
      mspcodec.writeU8(payload, stored)
    else
      mspcodec.writeU8(payload, storedValue(wireType, value, stored))
    end
  end
  return payload
end

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 194,
  FIELD_META = FIELD_META,
  TITLE = "AM32",
}

function msp.summaryFor(data)
  return string.format("AM32 / EEPROM %d / v%d.%d",
    tonumber(data and data.eeprom_version) or 0,
    tonumber(data and data.version_major) or 0,
    tonumber(data and data.version_minor) or 0)
end

function msp.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf) onData(decode(buf)) end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- Builds a ready-to-publish write message. `data` is the table
-- buildReadMessage() handed onData() -- the whole thing, not only the rows this
-- page shows, since the block is written at once and encode() starts from the
-- bytes it carries.
--
-- Returns `nil, reason` when there is no such table, and no message at all in
-- that case: a payload laid out without the ESC's own bytes would put zeroes
-- where the ESC had its timing advance and its governor terms. Returning a
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

package.loaded["rfsuite.lib.msp_esc_parameters_am32"] = msp
return msp

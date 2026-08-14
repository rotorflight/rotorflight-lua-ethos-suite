-- AM32 forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_am32"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_am32"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
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

local function decodeTiming(raw, data)
  data._timing_advance_encoding = "legacy"
  if raw >= 10 and raw <= 42 then
    data._timing_advance_encoding = "new"
    return clamp((raw - 10) / 8, 0, 3)
  end
  return clamp(raw, 0, 3)
end

local function encodeTiming(value, data)
  local normalized = clamp(value, 0, 3)
  if data and data._timing_advance_encoding == "new" then
    return 10 + normalized * 8
  end
  return normalized
end

local function readValue(buf, wireType, data)
  local raw = mspcodec.readU8(buf) or 0
  if wireType == "timing" then return decodeTiming(raw, data) end
  if wireType == "motor_kv" then return raw * 40 + 20 end
  if wireType == "servo_low" then return raw * 2 + 750 end
  if wireType == "servo_high" then return raw * 2 + 1750 end
  if wireType == "servo_neutral" then return raw + 1374 end
  if wireType == "low_voltage" then return raw + 250 end
  if wireType == "current_limit" then return raw * 2 end
  return raw
end

local function writeValue(payload, wireType, value, data)
  local raw = value
  if wireType == "timing" then raw = encodeTiming(value, data) end
  if wireType == "motor_kv" then raw = clamp(((value or 20) - 20) / 40, 0, 255) end
  if wireType == "servo_low" then raw = clamp(((value or 750) - 750) / 2, 0, 255) end
  if wireType == "servo_high" then raw = clamp(((value or 1750) - 1750) / 2, 0, 255) end
  if wireType == "servo_neutral" then raw = clamp((value or 1374) - 1374, 0, 255) end
  if wireType == "low_voltage" then raw = clamp((value or 250) - 250, 0, 255) end
  if wireType == "current_limit" then raw = clamp((value or 0) / 2, 0, 255) end
  mspcodec.writeU8(payload, raw or 0)
end

local function decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = readValue(buf, field[2], data)
  end
  return data
end

local function encode(data)
  local payload = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    writeValue(payload, field[2], data and data[field[1]], data)
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

function msp.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = encode(data),
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

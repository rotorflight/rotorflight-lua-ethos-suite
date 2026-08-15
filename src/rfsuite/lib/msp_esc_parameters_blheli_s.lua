-- BLHeli_S forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_blheli_s"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_blheli_s"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 217
local WRITE_COMMAND = 218

local ON_OFF = {{"Off", 0}, {"On", 1}}
local MOTOR_DIRECTION = {{"Normal", 1}, {"Reversed", 2}, {"Bidirectional", 3}, {"Bidirectional Rev", 4}}
local STARTUP_POWER = {
  {"0.031", 1}, {"0.047", 2}, {"0.063", 3}, {"0.094", 4}, {"0.125", 5},
  {"0.188", 6}, {"0.25", 7}, {"0.38", 8}, {"0.50", 9}, {"0.75", 10},
  {"1.00", 11}, {"1.25", 12}, {"1.50", 13},
}
local MOTOR_TIMING = {{"Low", 1}, {"Medium Low", 2}, {"Medium", 3}, {"Medium High", 4}, {"High", 5}}
local DEMAG = {{"Off", 1}, {"Low", 2}, {"High", 3}}
local BEACON_DELAY = {
  {"1 minute", 1}, {"2 minutes", 2}, {"5 minutes", 3}, {"10 minutes", 4}, {"Infinite", 5},
}
local TEMP_PROTECTION = {
  {"Disabled", 0}, {"80C", 1}, {"90C", 2}, {"100C", 3}, {"110C", 4},
  {"120C", 5}, {"130C", 6}, {"140C", 7},
}

local FIELD_META = {
  motor_direction = {choices = MOTOR_DIRECTION},
  startup_power = {choices = STARTUP_POWER},
  commutation_timing = {choices = MOTOR_TIMING},
  demag_compensation = {choices = DEMAG},
  brake_on_stop = {choices = ON_OFF},
  temperature_protection = {choices = TEMP_PROTECTION},
  beep_strength = {min = 1, max = 255},
  beacon_strength = {min = 1, max = 255},
  beacon_delay = {choices = BEACON_DELAY},
  ppm_min_throttle = {min = 1000, max = 1500, suffix = "us"},
  ppm_max_throttle = {min = 1504, max = 2020, suffix = "us"},
  ppm_center_throttle = {min = 1000, max = 2020, suffix = "us"},
}

local WIRE_FIELDS = {
  {"esc_signature", "u8"},
  {"esc_command", "u8"},
  {"main_revision", "u8"},
  {"sub_revision", "u8"},
  {"layout_revision", "u8"},
  {"p_gain", "u8"},
  {"i_gain", "u8"},
  {"governor_mode", "u8"},
  {"low_voltage_limit", "u8"},
  {"motor_gain", "u8"},
  {"motor_idle", "u8"},
  {"startup_power", "u8"},
  {"pwm_frequency", "u8"},
  {"motor_direction", "u8"},
  {"input_pwm_polarity", "u8"},
  {"mode_raw", "u16"},
  {"programming_by_tx", "u8"},
  {"rearm_at_start", "u8"},
  {"governor_setup_target", "u8"},
  {"startup_rpm", "u8"},
  {"startup_acceleration", "u8"},
  {"volt_comp", "u8"},
  {"commutation_timing", "u8"},
  {"damping_force", "u8"},
  {"governor_range", "u8"},
  {"startup_method", "u8"},
  {"ppm_min_throttle", "throttle"},
  {"ppm_max_throttle", "throttle"},
  {"beep_strength", "u8"},
  {"beacon_strength", "u8"},
  {"beacon_delay", "u8"},
  {"throttle_rate", "u8"},
  {"demag_compensation", "u8"},
  {"bec_voltage", "u8"},
  {"ppm_center_throttle", "throttle"},
  {"spoolup_time", "u8"},
  {"temperature_protection", "u8"},
  {"low_rpm_power_protection", "u8"},
  {"pwm_input", "u8"},
  {"pwm_dither", "u8"},
  {"brake_on_stop", "u8"},
  {"led_control", "u8"},
}

for i = 0x29, 0x3f do
  WIRE_FIELDS[#WIRE_FIELDS + 1] = {string.format("reserved_%02x", i), "u8"}
end

local SIMULATOR_RESPONSE = {
  193, 0, 16, 7, 33, 255, 255, 255, 255, 255, 255, 9, 255, 1, 255, 85,
  170, 1, 255, 255, 255, 255, 255, 3, 255, 255, 255, 37, 208, 40, 80, 4,
  255, 2, 255, 122, 255, 7, 1, 255, 255, 0, 0, 255, 255, 255, 255, 255,
  255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
  255, 255, 255, 255
}

local function clamp(value, min, max)
  value = math.floor((value or 0) + 0.5)
  if value < min then return min end
  if value > max then return max end
  return value
end

local function readValue(buf, wireType)
  if wireType == "u16" then return mspcodec.readU16(buf) or 0 end
  local raw = mspcodec.readU8(buf) or 0
  if wireType == "throttle" then return raw * 4 + 1000 end
  return raw
end

local function writeValue(payload, wireType, value)
  if wireType == "u16" then
    mspcodec.writeU16(payload, value or 0)
    return
  end
  local raw = value or 0
  if wireType == "throttle" then raw = clamp(((value or 1000) - 1000) / 4, 0, 255) end
  mspcodec.writeU8(payload, raw)
end

local function decode(buf)
  buf.offset = 1
  local data = {_raw = {}}
  for i = 1, #buf do data._raw[i] = buf[i] end
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = readValue(buf, field[2])
  end
  return data
end

local function encode(data)
  local payload = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    writeValue(payload, field[2], data and data[field[1]])
  end
  return payload
end

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 193,
  FIELD_META = FIELD_META,
  TITLE = "BLHeli_S",
}

function msp.isCompatible(data)
  return tonumber(data and data.esc_signature) == msp.EXPECTED_SIGNATURE
    and tonumber(data and data.main_revision) == 16
end

function msp.summaryFor(data)
  return string.format("BLHeli_S / Revision %d / FW%d.%d",
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

package.loaded["rfsuite.lib.msp_esc_parameters_blheli_s"] = msp
return msp

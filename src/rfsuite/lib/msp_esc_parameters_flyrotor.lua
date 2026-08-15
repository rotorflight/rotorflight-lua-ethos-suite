-- FlyRotor forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_flyrotor"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_flyrotor"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 217
local WRITE_COMMAND = 218

local ESC_MODE = {{"ESC Gov", 0}, {"Linear Thr", 1}, {"RF Gov", 2}}
local BEC_VOLTAGE = {{"Disabled", 0}, {"7.5V", 1}, {"8.0V", 2}, {"8.5V", 3}, {"12.0V", 4}}
local ELECTRICAL_ANGLE = {{"Auto", 0}, {"1 deg", 1}, {"2 deg", 2}, {"3 deg", 3}, {"4 deg", 4}, {"5 deg", 5}, {"6 deg", 6}, {"7 deg", 7}, {"8 deg", 8}, {"9 deg", 9}, {"10 deg", 10}}
local DIRECTION = {{"CW", 0}, {"CCW", 1}}
local FAN_CONTROL = {{"Automatic", 0}, {"Always On", 1}, {"Always Off", 2}}
local DISABLED_ENABLED = {{"Disabled", 0}, {"Enabled", 1}}
local THROTTLE_PROTOCOL = {{"PWM", 0}, {"DShot", 1}, {"Serial", 2}}
local TELEMETRY_PROTOCOL = {{"FLYROTOR", 0}}
local LED_COLOR = {
  {"CUSTOM", 0}, {"OFF", 1}, {"RED", 2}, {"GREEN", 3}, {"BLUE", 4},
  {"YELLOW", 5}, {"MAGENTA", 6}, {"CYAN", 7}, {"WHITE", 8}, {"ORANGE", 9},
  {"GRAY", 10}, {"MAROON", 11}, {"DARK_GREEN", 12}, {"NAVY", 13},
  {"PURPLE", 14}, {"TEAL", 15}, {"SILVER", 16}, {"PINK", 17}, {"GOLD", 18},
  {"BROWN", 19}, {"LIGHT_BLUE", 20}, {"FL_PINK", 21}, {"FL_ORANGE", 22},
  {"FL_LIME", 23}, {"FL_MINT", 24}, {"FL_CYAN", 25}, {"FL_PURPLE", 26},
  {"FL_HOT_PINK", 27}, {"FL_LIGHT_YELLOW", 28}, {"FL_AQUAMARINE", 29},
  {"FL_GOLD", 30}, {"FL_DEEP_PINK", 31}, {"FL_NEON_GREEN", 32},
  {"FL_ORANGE_RED", 33},
}

local FIELD_META = {
  esc_mode = {choices = ESC_MODE},
  cell_count = {min = 4, max = 14, default = 6},
  low_voltage_protection = {min = 28, max = 38, default = 30, decimals = 1, suffix = "V"},
  temperature_protection = {min = 50, max = 135, default = 125, suffix = "deg"},
  bec_voltage = {choices = BEC_VOLTAGE},
  electrical_angle = {choices = ELECTRICAL_ANGLE},
  motor_direction = {choices = DIRECTION},
  starting_torque = {min = 1, max = 15, default = 3},
  response_speed = {min = 1, max = 15, default = 5},
  buzzer_volume = {min = 1, max = 5, default = 2},
  current_gain = {min = -20, max = 20, default = 0},
  fan_control = {choices = FAN_CONTROL},
  soft_start = {min = 5, max = 55, default = 15, suffix = "s"},
  auto_restart_time = {min = 0, max = 100, default = 30, suffix = "s"},
  restart_acc = {min = 1, max = 10, default = 5},
  gov_p = {min = 0, max = 100, default = 45},
  gov_i = {min = 0, max = 100, default = 35},
  active_freewheel = {choices = DISABLED_ENABLED},
  drive_freq = {min = 10, max = 24, default = 16, suffix = "KHz"},
  motor_erpm_max = {min = 0, max = 1000000, step = 100},
  throttle_protocol = {choices = THROTTLE_PROTOCOL},
  telemetry_protocol = {choices = TELEMETRY_PROTOCOL},
  led_color_index = {choices = LED_COLOR},
  motor_temp_sensor = {choices = DISABLED_ENABLED},
  motor_temp = {min = 50, max = 150, default = 100, suffix = "deg"},
  battery_capacity = {min = 0, max = 50000, default = 0, suffix = "mAh"},
}

local WIRE_FIELDS = {
  {"esc_signature", "u8"},
  {"esc_command", "u8"},
  {"esc_type", "u8"},
  {"esc_model", "u16be"},
  {"esc_sn", "bytes8"},
  {"esc_iap", "bytes3"},
  {"esc_fw", "bytes3"},
  {"esc_hardware", "u8"},
  {"throttle_min", "u16be"},
  {"throttle_max", "u16be"},
  {"esc_mode", "u8"},
  {"cell_count", "u8"},
  {"low_voltage_protection", "u8"},
  {"temperature_protection", "u8"},
  {"bec_voltage", "u8"},
  {"electrical_angle", "u8"},
  {"motor_direction", "u8"},
  {"starting_torque", "u8"},
  {"response_speed", "u8"},
  {"buzzer_volume", "u8"},
  {"current_gain", "current_gain"},
  {"fan_control", "u8"},
  {"soft_start", "u8"},
  {"auto_restart_time", "u8"},
  {"restart_acc", "u8"},
  {"gov_p", "u8"},
  {"gov_i", "u8"},
  {"active_freewheel", "u8"},
  {"drive_freq", "u8"},
  {"motor_erpm_max", "u24be"},
  {"throttle_protocol", "u8"},
  {"telemetry_protocol", "u8"},
  {"led_color_index", "u8"},
  {"led_color_rgb", "bytes3"},
  {"motor_temp_sensor", "u8"},
  {"motor_temp", "u8"},
  {"battery_capacity", "u16be"},
}

local SIMULATOR_RESPONSE = {
  115, 0, 0,
  1, 24, -- esc_model
  231, 79, 190, 216, 78, 29, 169, 244, -- esc_sn
  1, 0, 0, -- esc_iap
  1, 0, 1, -- esc_fw
  0, -- esc_hardware
  4, 76, -- throttle_min
  7, 148, -- throttle_max
  0, -- esc_mode
  6, -- cell_count
  30, -- low_voltage_protection
  125, -- temperature_protection
  1, -- bec_voltage
  0, -- electrical_angle
  0, -- motor_direction
  3, -- starting_torque
  5, -- response_speed
  1, -- buzzer_volume
  20, -- current_gain
  0, -- fan_control
  15, -- soft_start
  15, -- auto_restart_time
  15, -- restart_acc
  45, -- gov_p
  35, -- gov_i
  0, -- active_freewheel
  16, -- drive_freq
  1, 255, 184, -- motor_erpm_max
  0, -- throttle_protocol
  0, -- telemetry_protocol
  3, -- led_color_index
  0, 0, 0, -- led_color_rgb
  0, -- motor_temp_sensor
  100, -- motor_temp
  0, 0 -- battery_capacity
}

local function readBytes(buf, count)
  local bytes = {}
  for i = 1, count do
    bytes[i] = mspcodec.readU8(buf) or 0
  end
  return bytes
end

local function writeBytes(payload, bytes, count)
  bytes = bytes or {}
  for i = 1, count do
    mspcodec.writeU8(payload, bytes[i] or 0)
  end
end

local function readValue(buf, wireType)
  if wireType == "u8" then return mspcodec.readU8(buf) end
  if wireType == "u16be" then
    local high = mspcodec.readU8(buf) or 0
    local low = mspcodec.readU8(buf) or 0
    return high * 256 + low
  end
  if wireType == "u24be" then
    local high = mspcodec.readU8(buf) or 0
    local mid = mspcodec.readU8(buf) or 0
    local low = mspcodec.readU8(buf) or 0
    return high * 65536 + mid * 256 + low
  end
  if wireType == "current_gain" then return (mspcodec.readS8(buf) or 0) - 20 end
  if wireType == "bytes3" then return readBytes(buf, 3) end
  return readBytes(buf, 8)
end

local function writeValue(payload, wireType, value)
  value = value or 0
  if wireType == "u8" then
    mspcodec.writeU8(payload, value)
  elseif wireType == "u16be" then
    mspcodec.writeU8(payload, math.floor(value / 256) % 256)
    mspcodec.writeU8(payload, value % 256)
  elseif wireType == "u24be" then
    mspcodec.writeU8(payload, math.floor(value / 65536) % 256)
    mspcodec.writeU8(payload, math.floor(value / 256) % 256)
    mspcodec.writeU8(payload, value % 256)
  elseif wireType == "current_gain" then
    mspcodec.writeS8(payload, value + 20)
  elseif wireType == "bytes3" then
    writeBytes(payload, value, 3)
  else
    writeBytes(payload, value, 8)
  end
end

local function decode(buf)
  buf.offset = 1
  local data = {}
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
    writeValue(payload, field[2], data and data[field[1]] or nil)
  end
  return payload
end

local function version(bytes)
  bytes = bytes or {}
  return tostring(bytes[1] or 0) .. "." .. tostring(bytes[2] or 0) .. "." .. tostring(bytes[3] or 0)
end

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 115,
  FIELD_META = FIELD_META,
  TITLE = "FLYROTOR",
}

function msp.isModel150A(data)
  return tonumber(data and data.esc_model) == 150
end

function msp.summaryFor(data)
  return string.format("FLYROTOR %dA / %s",
    tonumber(data and data.esc_model) or 0,
    version(data and data.esc_fw))
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

package.loaded["rfsuite.lib.msp_esc_parameters_flyrotor"] = msp
return msp

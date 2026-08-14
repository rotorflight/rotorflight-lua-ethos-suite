-- MSP_MOTOR_CONFIG helper (cmd 131 read / 222 write).

if package.loaded["rfsuite.lib.msp_motor_config"] then
  return package.loaded["rfsuite.lib.msp_motor_config"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 131
local WRITE_COMMAND = 222

local PROTOCOL_CHOICES = {
  {"PWM", 0},
  {"ONESHOT125", 1},
  {"ONESHOT42", 2},
  {"MULTISHOT", 3},
  {"BRUSHED", 4},
  {"DSHOT150", 5},
  {"DSHOT300", 6},
  {"DSHOT600", 7},
  {"PROSHOT", 8},
  {"CASTLE", 9},
  {"DISABLED", 10},
}

local ON_OFF_CHOICES = {
  {"@i18n(api.MOTOR_CONFIG.tbl_off)@", 0},
  {"@i18n(api.MOTOR_CONFIG.tbl_on)@", 1},
}

local READ_FIELDS = {
  {"minthrottle", "U16"},
  {"maxthrottle", "U16"},
  {"mincommand", "U16"},
  {"motor_count_blheli", "U8"},
  {"motor_pole_count_blheli", "U8"},
  {"use_dshot_telemetry", "U8"},
  {"motor_pwm_protocol", "U8"},
  {"motor_pwm_rate", "U16"},
  {"use_unsynced_pwm", "U8"},
  {"motor_pole_count_0", "U8"},
  {"motor_pole_count_1", "U8"},
  {"motor_pole_count_2", "U8"},
  {"motor_pole_count_3", "U8"},
  {"motor_rpm_lpf_0", "U8"},
  {"motor_rpm_lpf_1", "U8"},
  {"motor_rpm_lpf_2", "U8"},
  {"motor_rpm_lpf_3", "U8"},
  {"main_rotor_gear_ratio_0", "U16"},
  {"main_rotor_gear_ratio_1", "U16"},
  {"tail_rotor_gear_ratio_0", "U16"},
  {"tail_rotor_gear_ratio_1", "U16"},
}

local WRITE_FIELDS = {
  {"minthrottle", "U16"},
  {"maxthrottle", "U16"},
  {"mincommand", "U16"},
  {"motor_pole_count_blheli", "U8"},
  {"use_dshot_telemetry", "U8"},
  {"motor_pwm_protocol", "U8"},
  {"motor_pwm_rate", "U16"},
  {"use_unsynced_pwm", "U8"},
  {"motor_pole_count_0", "U8"},
  {"motor_pole_count_1", "U8"},
  {"motor_pole_count_2", "U8"},
  {"motor_pole_count_3", "U8"},
  {"motor_rpm_lpf_0", "U8"},
  {"motor_rpm_lpf_1", "U8"},
  {"motor_rpm_lpf_2", "U8"},
  {"motor_rpm_lpf_3", "U8"},
  {"main_rotor_gear_ratio_0", "U16"},
  {"main_rotor_gear_ratio_1", "U16"},
  {"tail_rotor_gear_ratio_0", "U16"},
  {"tail_rotor_gear_ratio_1", "U16"},
}

local FIELD_META = {
  minthrottle = {min = 50, max = 2250, default = 1070, suffix = "us"},
  maxthrottle = {min = 50, max = 2250, default = 2000, suffix = "us"},
  mincommand = {min = 50, max = 2250, default = 1000, suffix = "us"},
  use_dshot_telemetry = {choices = ON_OFF_CHOICES},
  motor_pwm_protocol = {choices = PROTOCOL_CHOICES},
  motor_pwm_rate = {min = 50, max = 8000, default = 250, suffix = "Hz"},
  use_unsynced_pwm = {choices = ON_OFF_CHOICES},
  motor_pole_count_0 = {min = 2, max = 256, default = 10},
  main_rotor_gear_ratio_0 = {min = 1, max = 50000, default = 1},
  main_rotor_gear_ratio_1 = {min = 1, max = 50000, default = 1},
  tail_rotor_gear_ratio_0 = {min = 1, max = 50000, default = 1},
  tail_rotor_gear_ratio_1 = {min = 1, max = 50000, default = 1},
}

local SIMULATOR_RESPONSE = {
  45, 4,
  208, 7,
  232, 3,
  1,
  6,
  0,
  0,
  250, 0,
  1,
  6,
  4,
  2,
  1,
  8,
  7,
  7,
  8,
  20, 0,
  50, 0,
  9, 0,
  30, 0,
}

local msp_motor_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELD_META = FIELD_META,
  PROTOCOL_CHOICES = PROTOCOL_CHOICES,
  ON_OFF_CHOICES = ON_OFF_CHOICES,
}

local function readByType(buf, wireType)
  if wireType == "U16" then return mspcodec.readU16(buf) end
  return mspcodec.readU8(buf)
end

local function writeByType(buf, wireType, value)
  if wireType == "U16" then
    mspcodec.writeU16(buf, value or 0)
  else
    mspcodec.writeU8(buf, value or 0)
  end
end

function msp_motor_config.decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #READ_FIELDS do
    local name, wireType = READ_FIELDS[i][1], READ_FIELDS[i][2]
    data[name] = readByType(buf, wireType)
  end
  return data
end

function msp_motor_config.encode(data)
  local payload = {}
  data = data or {}
  for i = 1, #WRITE_FIELDS do
    local name, wireType = WRITE_FIELDS[i][1], WRITE_FIELDS[i][2]
    writeByType(payload, wireType, data[name])
  end
  return payload
end

function msp_motor_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_motor_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_motor_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_motor_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_motor_config"] = msp_motor_config
return msp_motor_config

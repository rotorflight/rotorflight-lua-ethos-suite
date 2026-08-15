-- MSP_ESC_SENSOR_CONFIG helper (cmd 123 read / 216 write).

if package.loaded["rfsuite.lib.msp_esc_sensor_config"] then
  return package.loaded["rfsuite.lib.msp_esc_sensor_config"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 123
local WRITE_COMMAND = 216

local PROTOCOL_CHOICES = {
  {"NONE", 0},
  {"BLHELI32", 1},
  {"HOBBYWING V4", 2},
  {"HOBBYWING V5", 3},
  {"SCORPION", 4},
  {"KONTRONIK", 5},
  {"OMP", 6},
  {"ZTW", 7},
  {"APD", 8},
  {"OPENYGE", 9},
  {"FLYROTOR", 10},
  {"GRAUPNER", 11},
  {"XDFLY", 12},
  {"FrSky F.BUS", 13},
  {"RECORD", 14},
}

local ON_OFF_CHOICES = {
  {"@i18n(api.ESC_SENSOR_CONFIG.tbl_off)@", 0},
  {"@i18n(api.ESC_SENSOR_CONFIG.tbl_on)@", 1},
}

local FIELDS = {
  {"protocol", "U8"},
  {"half_duplex", "U8"},
  {"update_hz", "U16"},
  {"current_offset", "U16"},
  {"hw4_current_offset", "U16"},
  {"hw4_current_gain", "U8"},
  {"hw4_voltage_gain", "U8"},
  {"pin_swap", "U8"},
  {"voltage_correction", "S8"},
  {"current_correction", "S8"},
  {"consumption_correction", "S8"},
}

local FIELD_META = {
  protocol = {choices = PROTOCOL_CHOICES},
  half_duplex = {choices = ON_OFF_CHOICES},
  update_hz = {min = 10, max = 500, default = 200, suffix = "Hz"},
  current_offset = {min = 0, max = 1000, default = 0},
  hw4_current_offset = {min = 0, max = 1000, default = 0},
  hw4_current_gain = {min = 0, max = 250, default = 0},
  hw4_voltage_gain = {min = 0, max = 250, default = 30},
  pin_swap = {choices = ON_OFF_CHOICES},
  voltage_correction = {min = -99, max = 125, default = 1, suffix = "%"},
  current_correction = {min = -99, max = 125, default = 1, suffix = "%"},
  consumption_correction = {min = -99, max = 125, default = 1, suffix = "%"},
}

local SIMULATOR_RESPONSE = {
  0,
  0,
  200, 0,
  0, 15,
  0, 0,
  0,
  30,
  0,
  0,
  0,
  0,
}

local msp_esc_sensor_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELD_META = FIELD_META,
  PROTOCOL_CHOICES = PROTOCOL_CHOICES,
  ON_OFF_CHOICES = ON_OFF_CHOICES,
}

local function readByType(buf, wireType)
  if wireType == "U16" then return mspcodec.readU16(buf) end
  if wireType == "S8" then return mspcodec.readS8(buf) end
  return mspcodec.readU8(buf)
end

local function writeByType(buf, wireType, value)
  if wireType == "U16" then
    mspcodec.writeU16(buf, value or 0)
  elseif wireType == "S8" then
    mspcodec.writeS8(buf, value or 0)
  else
    mspcodec.writeU8(buf, value or 0)
  end
end

function msp_esc_sensor_config.decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    data[name] = readByType(buf, wireType)
  end
  return data
end

function msp_esc_sensor_config.encode(data)
  local payload = {}
  data = data or {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    writeByType(payload, wireType, data[name])
  end
  return payload
end

function msp_esc_sensor_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_esc_sensor_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_esc_sensor_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_esc_sensor_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_esc_sensor_config"] = msp_esc_sensor_config
return msp_esc_sensor_config

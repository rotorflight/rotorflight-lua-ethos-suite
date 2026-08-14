-- Scorpion forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_scorpion"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_scorpion"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 217
local WRITE_COMMAND = 218

local ESC_MODE = {{"Heli Gov", 0}, {"Heli Store", 1}, {"VBar Gov", 2}, {"Ext Gov", 3}, {"Airplane", 4}, {"Boat", 5}, {"Quad", 6}}
local ROTATION = {{"CCW", 0}, {"CW", 1}}
local BEC_VOLTAGE = {{"5.1 V", 0}, {"6.1 V", 1}, {"7.3 V", 2}, {"8.3 V", 3}, {"Disabled", 4}}
local TELEMETRY_PROTOCOL = {{"Standard", 0}, {"VBar", 1}, {"EX Bus", 2}, {"Unsolicited", 3}, {"Futaba SBUS", 4}}
local ON_OFF = {{"On", 0}, {"Off", 1}}

local FIELD_META = {
  esc_mode = {choices = ESC_MODE},
  bec_voltage = {choices = BEC_VOLTAGE},
  rotation = {choices = ROTATION},
  telemetry_protocol = {choices = TELEMETRY_PROTOCOL},
  protection_delay = {min = 0, max = 5000, scale = 1000, suffix = "s"},
  min_voltage = {min = 0, max = 7000, scale = 100, decimals = 1, suffix = "v"},
  max_temperature = {min = 0, max = 40000, scale = 100, suffix = "deg"},
  max_current = {min = 0, max = 30000, scale = 100, suffix = "A"},
  cutoff_handling = {min = 0, max = 10000, scale = 100, suffix = "%"},
  max_used = {min = 0, max = 6000, scale = 100, suffix = "Ah"},
  motor_startup_sound = {choices = ON_OFF},
  soft_start_time = {min = 0, max = 60000, scale = 1000, suffix = "s"},
  runup_time = {min = 0, max = 60000, scale = 1000, suffix = "s"},
  bailout = {min = 0, max = 100000, scale = 1000, suffix = "s"},
  gov_proportional = {min = 30, max = 180, scale = 100, decimals = 2},
  gov_integral = {min = 150, max = 250, scale = 100, decimals = 2},
}

local WIRE_FIELDS = {
  {"esc_signature", "u8"},
  {"esc_command", "u8"},
}
for i = 1, 32 do
  WIRE_FIELDS[#WIRE_FIELDS + 1] = {"escinfo_" .. i, "u8"}
end
local REST_FIELDS = {
  {"esc_mode", "u16"},
  {"bec_voltage", "u16"},
  {"rotation", "u16"},
  {"telemetry_protocol", "u16"},
  {"protection_delay", "u16"},
  {"min_voltage", "u16"},
  {"max_temperature", "u16"},
  {"max_current", "u16"},
  {"cutoff_handling", "u16"},
  {"max_used", "u16"},
  {"motor_startup_sound", "u16"},
  {"padding_1", "u16"},
  {"padding_2", "u16"},
  {"padding_3", "u16"},
  {"soft_start_time", "u16"},
  {"runup_time", "u16"},
  {"bailout", "u16"},
  {"gov_proportional", "u32"},
  {"gov_integral", "u32"},
}
for i = 1, #REST_FIELDS do WIRE_FIELDS[#WIRE_FIELDS + 1] = REST_FIELDS[i] end

local SIMULATOR_RESPONSE = {
  83, 128,
  84, 114, 105, 98, 117, 110, 117, 115,
  32, 69, 83, 67, 45, 54, 83, 45,
  56, 48, 65, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 4, 0,
  3, 0, -- esc_mode
  3, 0, -- bec_voltage
  1, 0, -- rotation
  3, 0, -- telemetry_protocol
  136, 19, -- protection_delay
  22, 3, -- min_voltage
  16, 39, -- max_temperature
  64, 31, -- max_current
  136, 19, -- cutoff_handling
  0, 0, -- max_used
  1, 0, -- motor_startup_sound
  7, 2, -- padding_1
  0, 6, -- padding_2
  63, 0, -- padding_3
  160, 15, -- soft_start_time
  64, 31, -- runup_time
  208, 7, -- bailout
  100, 0, 0, 0, -- gov_proportional
  200, 0, 0, 0 -- gov_integral
}

local function readValue(buf, wireType)
  if wireType == "u8" then return mspcodec.readU8(buf) end
  if wireType == "u16" then return mspcodec.readU16(buf) end
  return mspcodec.readU32(buf)
end

local function writeValue(payload, wireType, value)
  value = value or 0
  if wireType == "u8" then
    mspcodec.writeU8(payload, value)
  elseif wireType == "u16" then
    mspcodec.writeU16(payload, value)
  else
    mspcodec.writeU32(payload, value)
  end
end

local function decode(buf)
  buf.offset = 1
  local data = {_raw = {}}
  for i = 1, #buf do data._raw[i] = buf[i] or 0 end
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
    writeValue(payload, field[2], data and data[field[1]] or 0)
  end
  return payload
end

local function textFromInfo(data)
  local out = {}
  for i = 1, 32 do
    local value = data and data["escinfo_" .. i]
    if value == 0 or value == nil then break end
    out[#out + 1] = string.char(value)
  end
  return table.concat(out)
end

local function uintFromRaw(data, positions)
  local raw = data and data._raw or {}
  local value = 0
  for i = 1, #positions do
    value = value + (raw[positions[i]] or 0) * (256 ^ (i - 1))
  end
  return value
end

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 83,
  FIELD_META = FIELD_META,
  TITLE = "Scorpion",
}

function msp.summaryFor(data)
  local model = textFromInfo(data)
  if model == "" then model = msp.TITLE end
  return string.format("%s / FW %08X / v%d",
    model,
    uintFromRaw(data, {55, 56, 57, 58}),
    uintFromRaw(data, {61, 62}))
end

function msp.beforeSave(runtime)
  if runtime and runtime.data then
    runtime.data.esc_command = 0
  end
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

package.loaded["rfsuite.lib.msp_esc_parameters_scorpion"] = msp
return msp

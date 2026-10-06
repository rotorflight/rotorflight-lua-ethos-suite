-- Scorpion forward-programming payload (MSP 217 read / 218 write).
--
-- The block is 84 bytes, and the length is not cosmetic (#2457). The flight
-- controller treats MSP_SET_ESC_PARAMETERS as an opaque move of
-- escGetParamBufferLength() bytes: for a Scorpion (ESC_SIG_TRIB, 0x53) that is
-- PARAM_HEADER_SIZE + tribCalcParamBufferLength(), and tribParamAddrLen sums to
-- 82, so 2 + 82 = 84 (rotorflight-firmware src/main/sensors/esc_sensor.c:
-- tribParamAddrLen, tribCalcParamBufferLength(), escGetParamBufferLength()).
-- sbufReadData copies that many bytes out of the received frame with no bounds
-- check and no comparison against what actually arrived, and the destination is
-- a persistent static buffer, so a payload shorter than 84 leaves the tail to be
-- filled from past the end of the frame. This codec used to send 76.

if package.loaded["rfsuite.lib.msp_esc_parameters_scorpion"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_scorpion"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
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
  -- Bytes 57..62, and they are not padding. The sibling suite's field list for
  -- this block names them, and the widths add up exactly: 4 + 2 = the 6 bytes
  -- these three U16s used to occupy, and soft_start_time lands on byte 63 either
  -- way -- so this renames, it does not move anything.
  --   rotorflight-lua-edgetx-suite src/rfsuite/tasks/msp/api/esc_parameters_scorpion.lua
  --   ... {"serial_number","U32"}, {"firmware_version","U16"}, {"soft_start_time","U16"},
  -- The page reads those two out of the block with no header compensation
  -- (.../escmfg/scorp/init.lua getEscVersion/getEscFirmware), so its byte numbers
  -- and these are the same numbers.
  {"serial_number", "u32"},
  {"firmware_version", "u16"},
  {"soft_start_time", "u16"},
  {"runup_time", "u16"},
  {"bailout", "u16"},
  {"gov_proportional", "u32"},
  {"gov_integral", "u32"},
  -- The block does not end at gov_integral. Bytes 77..84 are two U32s the sibling
  -- suite names stick_max and stick_zero; its field list carries both after
  -- gov_integral (rotorflight-lua-edgetx-suite src/rfsuite/tasks/msp/api/
  -- esc_parameters_scorpion.lua), and the width that closes the gap is the 84 the
  -- flight controller asks for. The page builds no row for either, so they are
  -- never edited -- they are decoded and written back verbatim, because the
  -- firmware commits all 84 bytes whether or not the tool sent them (#2457).
  {"stick_max", "u32"},
  {"stick_zero", "u32"},
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
  200, 0, 0, 0, -- gov_integral
  -- The last eight bytes, taken verbatim from the sibling suite's SIM_RESPONSE
  -- (rotorflight-lua-edgetx-suite .../msp/api/esc_parameters_scorpion.lua), which
  -- carries the same 84 bytes and describes the same ESC. Without them this fixture
  -- -- and so every save -- is 76 bytes where the ESC's block is 84 (#2457).
  1, 0, 0, 0, -- stick_max
  200, 250, 0, 0 -- stick_zero
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

-- uintFromRaw() used to live here and had no caller left after summaryFor stopped
-- reading the block by byte offset. Removed rather than left defined: an unused
-- helper in a codec is an invitation to the next reader to reach for byte offsets
-- again, which is how the FW word below came to be labelled wrong in the first
-- place.

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 83,
  FIELD_META = FIELD_META,
  TITLE = "Scorpion",
}

-- The line the pilot reads. The version comes from firmware_version, which used to
-- be read as raw bytes 61-62 and is a named field now.
--
-- What used to sit in the middle is gone, and it should be: "FW %08X" was assembled
-- from bytes 55-58, which the field list above calls motor_startup_sound (55-56) and
-- the low half of serial_number (57-58). It was a number with no name behind it.
-- The version was already on the line as "v%d" from bytes 61-62, so nothing that
-- meant anything disappeared with it.
--
-- The serial is placed after the version because that is the order the sibling suite
-- builds its subheader in (firmware, then S/N), and it is decimal because
-- .../escmfg/scorp/init.lua prints it with tostring():
--
--   local sn = getUInt(buffer, {57, 58, 59, 60})
--   return sn ~= 0 and tostring(sn) or ""
--
-- A serial of 0 is left out, which is the same rule and for the same reason.
function msp.summaryFor(data)
  local model = textFromInfo(data)
  if model == "" then model = msp.TITLE end
  local parts = {
    model,
    string.format("v%d", tonumber(data and data.firmware_version) or 0),
  }
  local serial = tonumber(data and data.serial_number)
  if serial and serial > 0 then
    parts[#parts + 1] = string.format("S/N %d", serial)
  end
  return table.concat(parts, " / ")
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

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

-- The block this codec reads and writes is 56 bytes, and where that number comes
-- from is the firmware's own page table rather than anybody's transcription of
-- it:
--
--   rotorflight-firmware src/main/sensors/esc_sensor.c:1931-1932
--     static uint16_t flyParamPages[] = { 0x0016, 0x160C, 0x220A, 0x2C0A };
--     // hi-byte = offset, low-byte = length
--     //   INFO  payload  0..21   22 bytes
--     //   BASIC payload 22..33   12 bytes
--     //   ADV   payload 34..43   10 bytes
--     //   OTHER payload 44..53   10 bytes
--
--   flyCalcParamBufferLength() (:2130-2136) sums the low bytes -- 22 + 12 + 10 +
--   10 = 54 -- and escGetParamFullBufferLength() (:4540-4551) adds
--   PARAM_HEADER_SIZE (2, :107), so an MSP_ESC_PARAMETERS block is 56 bytes.
--
-- Two things follow from that table being a COMPILE-TIME CONSTANT in the flight
-- controller, and both are worth stating because they are the opposite of what a
-- reader assumes:
--
--   * 56 is not a floor that a newer ESC firmware raises. The FC never asks the
--     ESC how long its parameter block is; flyParamPages is compiled in. There is
--     no revision of the ESC behind which the block grows.
--   * the four pages are filled in one at a time (flyDecodeReadResp, :2138-2157)
--     and the payload only becomes available -- paramPayloadLength, and with it
--     any MSP answer at all -- once every page is cached (:2150-2151). So a
--     partial block is not a state the FC offers; msp.c returns false for a zero
--     length. A short buffer on the wire is a TRUNCATED read, not a smaller
--     layout, and decode() below refuses it rather than filling the tail with
--     zeros.
--
-- WIRE_FIELDS below is laid out on exactly those four boundaries, and the two
-- bytes in front of them are PARAM_HEADER_SIG and PARAM_HEADER_VER -- which is
-- why esc_signature and esc_command are the first two entries and esc_type, the
-- first INFO byte, is the third.
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
  -- A non-table here used to raise ("attempt to index a number value"), because
  -- writeValue() turns a missing field into 0 first and 0 is truthy in Lua, so
  -- `bytes or {}` kept the number. encode() refuses a table that is missing a
  -- field, which is where a 0 comes from at all; this is the second half of the
  -- same answer, for a field that is present with the wrong type.
  if type(bytes) ~= "table" then bytes = {} end
  for i = 1, count do
    mspcodec.writeU8(payload, bytes[i] or 0)
  end
end

-- Big-endian, which four of these fields are: esc_model, throttle_min,
-- throttle_max and battery_capacity as U16, motor_erpm_max as U24. The ESC's
-- pages are big-endian throughout, so this is a read and a write of the same
-- byte order rather than two conventions.
local function readBigEndian(buf, count)
  local value = 0
  for _ = 1, count do
    value = value * 256 + (mspcodec.readU8(buf) or 0)
  end
  return value
end

local function writeBigEndian(payload, value, count)
  for i = count - 1, 0, -1 do
    mspcodec.writeU8(payload, math.floor((value or 0) / (256 ^ i)) % 256)
  end
end

-- One table, and it is the only place in the file that knows how wide a wire
-- type is. readValue()/writeValue() used to be a pair of if-chains over the same
-- six types, and a third copy here would have been a third thing to update when
-- a field is added -- which is how a length and a layout end up disagreeing.
-- BLOCK_BYTES below is summed from these widths, so the guard in decode() and the
-- layout above cannot drift apart.
local WIRE = {
  u8 = {
    width = 1,
    read = function(buf) return mspcodec.readU8(buf) end,
    write = function(payload, value) mspcodec.writeU8(payload, value) end,
  },
  u16be = {
    width = 2,
    read = function(buf) return readBigEndian(buf, 2) end,
    write = function(payload, value) writeBigEndian(payload, value, 2) end,
  },
  u24be = {
    width = 3,
    read = function(buf) return readBigEndian(buf, 3) end,
    write = function(payload, value) writeBigEndian(payload, value, 3) end,
  },
  -- The one field here that is not the identity. The page offers -20..+20 and
  -- the ESC has one byte, so the stored byte is the value shifted by 20: byte 0
  -- is -20 and byte 40 (0x28) is +20. Reading it as signed costs nothing over the
  -- declared range, because both ends land below 0x80 -- it only differs on a byte
  -- the ESC should never send, and there the codec carries it unchanged rather
  -- than clamping it, because a clamp would write back a byte the pilot never set.
  current_gain = {
    width = 1,
    read = function(buf) return (mspcodec.readS8(buf) or 0) - 20 end,
    write = function(payload, value) mspcodec.writeS8(payload, (value or 0) + 20) end,
  },
  bytes3 = {
    width = 3,
    read = function(buf) return readBytes(buf, 3) end,
    write = function(payload, value) writeBytes(payload, value, 3) end,
  },
  bytes8 = {
    width = 8,
    read = function(buf) return readBytes(buf, 8) end,
    write = function(payload, value) writeBytes(payload, value, 8) end,
  },
}

-- The block length, from the widths above: 2 header + 54 payload = 56. Exported
-- because it is the number the whole codec is judged by, and a harness that has
-- to count the bytes itself is a harness with a second opinion.
local BLOCK_BYTES = 0
for i = 1, #WIRE_FIELDS do
  BLOCK_BYTES = BLOCK_BYTES + WIRE[WIRE_FIELDS[i][2]].width
end

local function decode(buf)
  -- lib/mspcodec.lua is deliberately bounds-safe -- a byte past the end of the
  -- buffer reads as 0 rather than nil -- and its own header says a decoder that
  -- cannot tolerate a missing field must check the length itself. This one could
  -- not: without the check a truncated reply decoded into a table whose tail was
  -- zeros, the editor opened on it, and a save wrote those zeros to the ESC.
  -- flyParamCommit() (:1964-1987) writes every page whose bytes DIFFER from the
  -- cached block, so the ADV and OTHER pages would have gone out as zeros --
  -- soft_start, auto_restart_time, restart_acc, gov_p, gov_i, active_freewheel,
  -- drive_freq and motor_erpm_max among them. The EdgeTX codec refuses the same
  -- case outright (`if #buf < PAYLOAD_LEN then return nil end`,
  -- esc_parameters_flyrotor.lua:166).
  if type(buf) ~= "table" then
    return nil, "no parameter block"
  end
  if #buf < BLOCK_BYTES then
    return nil, string.format("parameter block is %d of %d bytes", #buf, BLOCK_BYTES)
  end

  buf.offset = 1
  local data = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = WIRE[field[2]].read(buf)
  end
  return data
end

-- A write is refused rather than invented. A table missing a field would encode
-- that field as zero, and for this block a zero is a value the firmware accepts
-- and commits -- gov_p 0, soft_start 0, motor_temp 0 -- so the pilot would be
-- told the save succeeded and the ESC would be holding a different governor.
-- Same contract as lib/msp_governor_profile.lua's encode(), which app/page_runtime.lua
-- already turns into a refused write it reports (see its writeSource()).
local function encode(data)
  if type(data) ~= "table" then
    return nil, "<not a table>"
  end
  for i = 1, #WIRE_FIELDS do
    local name = WIRE_FIELDS[i][1]
    if data[name] == nil then
      return nil, name
    end
  end

  local payload = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    WIRE[field[2]].write(payload, data[field[1]])
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

-- `onData(data)` carries the decoded field table once the reply arrives;
-- `onError(reason)` on failure -- and on a block too short to decode, because a
-- block that cannot be decoded must not reach the editor at all. Same shape as
-- lib/msp_battery.lua's read path, which is the in-tree precedent for refusing a
-- short payload.
function msp.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      local data, reason = decode(buf)
      if not data then
        if onError then onError(reason) end
        return
      end
      onData(data)
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- `data` is the table buildReadMessage() handed onData() -- the whole thing, not
-- only the rows this page shows, since the block is written at once.
--
-- Returns `nil, reason` and no message at all when there is no such table or it
-- is missing a field, so a write is refused rather than sent with that field
-- zeroed. app/page_runtime.lua treats a nil message as a refused write and
-- reports it (see its writeSource()), the same as lib/msp_governor_profile.lua.
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

msp.BLOCK_BYTES = BLOCK_BYTES
msp._decode = decode
msp._encode = encode
msp._simulatorResponse = SIMULATOR_RESPONSE

package.loaded["rfsuite.lib.msp_esc_parameters_flyrotor"] = msp
return msp

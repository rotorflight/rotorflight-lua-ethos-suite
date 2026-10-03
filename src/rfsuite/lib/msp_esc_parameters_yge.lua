-- YGE forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_yge"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_yge"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 217
local WRITE_COMMAND = 218

local ESC_MODE = {{"Freew.", 0}, {"Ext Gov", 1}, {"Heli Gov", 2}, {"Heli Store", 3}, {"Glider", 4}, {"Airplane", 5}, {"F3A", 6}}
local ROTATION = {{"Normal", 0}, {"Reverse", 1}}
local CUTOFF = {{"Off", 0}, {"Slowdown", 1}, {"Cutoff", 2}}
local CUTOFF_VOLTAGE = {{"2.9 V", 0}, {"3.0 V", 1}, {"3.1 V", 2}, {"3.2 V", 3}, {"3.3 V", 4}, {"3.4 V", 5}}
local OFF_ON = {{"Off", 0}, {"On", 1}}
local THROTTLE_RESPONSE = {{"Slow", 0}, {"Medium", 1}, {"Fast", 2}, {"Custom", 3}}
-- The Motor Timing row is drawn from list positions, because that is what the
-- choice widget takes. Those positions are NOT the ESC's words: the ESC spells
-- the four automatic modes 16..19 and the six fixed advance angles 1..6, with 0
-- a second spelling of the first automatic mode, and 7..15 and everything above
-- 19 are values it does not define. The word is therefore decoded on the way in
-- and encoded again on the way out.
local TIMING = {{"Auto Norm", 0}, {"Auto Eff", 1}, {"Auto Power", 2}, {"Auto Extr", 3}, {"0 deg", 4}, {"6 deg", 5}, {"12 deg", 6}, {"18 deg", 7}, {"24 deg", 8}, {"30 deg", 9}}
local MOTOR_TIMING_TO_UI = {
  [0] = 0, [1] = 4, [2] = 5, [3] = 6, [4] = 7, [5] = 8, [6] = 9,
  [16] = 0, [17] = 1, [18] = 2, [19] = 3
}
local MOTOR_TIMING_FROM_UI = {
  [0] = 0, [1] = 17, [2] = 18, [3] = 19, [4] = 1,
  [5] = 2, [6] = 3, [7] = 4, [8] = 5, [9] = 6
}
local FREEWHEEL = {{"Off", 0}, {"Auto", 1}, {"Unused", 2}, {"Always On", 3}}

-- Both halves of the same mapping, and both needed: decode() has to turn the
-- ESC's word into a row the widget can show, and encode() has to turn the row
-- back into a word the ESC understands. Without them a pilot picking "Auto
-- Efficient" commands wire 1, which the ESC reads as a fixed 0-degree advance.
local function motorTimingToUi(raw)
  return MOTOR_TIMING_TO_UI[raw] or 0
end

-- `raw` is the word the ESC itself sent, kept in `data.timing_raw` by decode().
-- A row still standing on the entry that word decoded to writes that word back
-- rather than the canonical spelling of the same entry, so a save that changed
-- nothing changes nothing in the ESC. The table is indexed rather than decoded
-- here on purpose: an undefined word decodes to the first automatic mode like
-- everything else the ESC does not define, and keeping it would mean a pilot who
-- deliberately picks that mode leaves the undefined word in place on a page that
-- says he changed it.
local function motorTimingFromUi(value, raw)
  if raw ~= nil and MOTOR_TIMING_TO_UI[raw] == value then return raw end
  return MOTOR_TIMING_FROM_UI[value] or 0
end

local ESC_TYPE = {
  [848] = "YGE 35 LVT BEC",
  [1616] = "YGE 65 LVT BEC",
  [2128] = "YGE 85 LVT BEC",
  [2384] = "YGE 95 LVT BEC",
  [4944] = "YGE 135 LVT BEC",
  [2304] = "YGE 90 HVT Opto",
  [4608] = "YGE 120 HVT Opto",
  [5712] = "YGE 165 HVT",
  [8272] = "YGE 205 HVT",
  [8273] = "YGE 205 HVT BEC",
  [4177] = "YGE Aureus 105",
  [4179] = "YGE Aureus 105v2",
  [5025] = "YGE Aureus 135",
  [5027] = "YGE Aureus 135v2",
  [5457] = "YGE Saphir 155",
  [5459] = "YGE Saphir 155v2",
  [4689] = "YGE Saphir 125",
  [4928] = "YGE Opto 135",
  [9552] = "YGE Opto 255",
  [16464] = "YGE Opto 405",
}

local FIELD_META = {
  governor = {choices = ESC_MODE},
  lv_bec_voltage = {min = 55, max = 84, decimals = 1, suffix = "v"},
  timing = {choices = TIMING},
  acceleration = {min = 0, max = 65535, default = 0},
  gov_p = {min = 1, max = 10, default = 5},
  gov_i = {min = 1, max = 10, default = 5},
  throttle_response = {choices = THROTTLE_RESPONSE},
  auto_restart_time = {choices = CUTOFF},
  cell_cutoff = {choices = CUTOFF_VOLTAGE},
  active_freewheel = {choices = FREEWHEEL},
  stick_zero_us = {min = 900, max = 1900, suffix = "us"},
  stick_range_us = {min = 600, max = 1500, suffix = "us"},
  motor_pole_pairs = {min = 1, max = 100},
  pinion_teeth = {min = 1, max = 255},
  main_teeth = {min = 1, max = 1800},
  min_start_power = {min = 0, max = 26, suffix = "%"},
  max_start_power = {min = 0, max = 31, suffix = "%"},
  current_limit = {min = 1, max = 65500, decimals = 2, suffix = "A"},
}

local WIRE_FIELDS = {
  {"esc_signature", "u8"},
  {"esc_command", "u8"},
  {"esc_model", "u8"},
  {"esc_version", "u8"},
  {"governor", "u16"},
  {"lv_bec_voltage", "u16"},
  {"timing", "u16"},
  {"acceleration", "u16"},
  {"gov_p", "u16"},
  {"gov_i", "u16"},
  {"throttle_response", "u16"},
  {"auto_restart_time", "u16"},
  {"cell_cutoff", "u16"},
  {"active_freewheel", "u16"},
  {"esc_type", "u16"},
  {"firmware_version", "u32"},
  {"serial_number", "u32"},
  {"unknown_1", "u16"},
  {"stick_zero_us", "u16"},
  {"stick_range_us", "u16"},
  {"unknown_2", "u16"},
  {"motor_pole_pairs", "u16"},
  {"pinion_teeth", "u16"},
  {"main_teeth", "u16"},
  {"min_start_power", "u16"},
  {"max_start_power", "u16"},
  {"unknown_3", "u16"},
  {"flags", "u8"},
  {"unknown_4", "u8"},
  {"current_limit", "u16"},
}

local EDIT_FIELDS = {
  "governor",
  "lv_bec_voltage",
  "timing",
  "gov_p",
  "gov_i",
  "throttle_response",
  "auto_restart_time",
  "cell_cutoff",
  "active_freewheel",
  "stick_zero_us",
  "stick_range_us",
  "motor_pole_pairs",
  "pinion_teeth",
  "main_teeth",
  "min_start_power",
  "max_start_power",
  "current_limit",
}

local SIMULATOR_RESPONSE = {
  165, 0, 32, 0,
  3, 0, -- governor
  55, 0, -- lv_bec_voltage
  0, 0, -- timing
  0, 0, -- acceleration
  4, 0, -- gov_p
  3, 0, -- gov_i
  1, 0, -- throttle_response
  1, 0, -- auto_restart_time
  2, 0, -- cell_cutoff
  3, 0, -- active_freewheel
  80, 3, -- esc_type
  131, 148, 1, 0, -- firmware_version
  30, 170, 0, 0, -- serial_number
  3, 0, -- unknown_1
  86, 4, -- stick_zero_us
  22, 3, -- stick_range_us
  163, 15, -- unknown_2
  1, 0, -- motor_pole_pairs
  2, 0, -- pinion_teeth
  2, 0, -- main_teeth
  20, 0, -- min_start_power
  20, 0, -- max_start_power
  0, 0, -- unknown_3
  0, -- flags
  0, -- unknown_4
  2, 19 -- current_limit
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
  local data = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    data[field[1]] = readValue(buf, field[2])
  end
  -- The word the ESC sent, kept beside the row it decoded to so encode() can
  -- write it back unchanged. See motorTimingFromUi().
  data.timing_raw = data.timing
  data.timing = motorTimingToUi(data.timing)
  return data
end

local function encode(data)
  local payload = {}
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    local value = data and data[field[1]] or 0
    if field[1] == "timing" then
      value = motorTimingFromUi(value, data and data.timing_raw)
    end
    writeValue(payload, field[2], value)
  end
  return payload
end

local function typeLabel(value)
  return ESC_TYPE[value or 0] or ("YGE ESC (" .. tostring(value or 0) .. ")")
end

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 165,
  FIELD_META = FIELD_META,
  EDIT_FIELDS = EDIT_FIELDS,
  TITLE = "YGE",
}

function msp.summaryFor(data)
  return string.format("%s / %.5f",
    typeLabel(data and data.esc_type),
    (tonumber(data and data.firmware_version) or 0) / 100000)
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

package.loaded["rfsuite.lib.msp_esc_parameters_yge"] = msp
return msp

-- Bluejay forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_bluejay"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_bluejay"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 217
local WRITE_COMMAND = 218

local ON_OFF = {{"Off", 0}, {"On", 1}}
local MOTOR_DIRECTION = {{"Normal", 1}, {"Reversed", 2}, {"Bidirectional", 3}, {"Bidirectional Rev", 4}}
local MOTOR_TIMING = {{"Low", 1}, {"Medium Low", 2}, {"Medium", 3}, {"Medium High", 4}, {"High", 5}}
local DEMAG = {{"Off", 1}, {"Low", 2}, {"High", 3}}
local BEACON_DELAY = {
  {"1 minute", 1}, {"2 minutes", 2}, {"5 minutes", 3}, {"10 minutes", 4}, {"Infinite", 5},
}
local TEMP_PROTECTION = {
  {"Disabled", 0}, {"80C", 1}, {"90C", 2}, {"100C", 3}, {"110C", 4},
  {"120C", 5}, {"130C", 6}, {"140C", 7},
}
local RAMPUP_POWER = {
  {"1x (More protection)", 1}, {"2x", 2}, {"3x", 3}, {"4x", 4},
  {"5x", 5}, {"6x", 6}, {"7x", 7}, {"8x", 8}, {"9x", 9},
  {"10x", 10}, {"11x", 11}, {"12x", 12}, {"13x (Less protection)", 13},
  {"Off", 0},
}
local RAMPUP_START_POWER = {
  {"0.5% (0.031)", 1}, {"5% (0.25)", 7}, {"7% (0.38)", 8},
  {"10% (0.50)", 9}, {"15% (0.75)", 10}, {"20% (1.00)", 11},
  {"24% (1.25)", 12}, {"29% (1.50)", 13},
}
local PWM_OLD = {{"24kHz", 24}, {"48kHz", 48}, {"96kHz", 96}}
local PWM_DYNAMIC = {{"24kHz", 24}, {"48kHz", 48}, {"96kHz", 96}, {"Dynamic", 0}}
local STARTUP_BEEP_OLD = ON_OFF
local STARTUP_BEEP_205 = {{"Off", 0}, {"Normal", 1}, {"Custom", 2}}
local BRAKING_MODE = {{"Off", 0}, {"Not during startup", 1}, {"On", 2}}
local LED_CONTROL = {
  {"Off", 0x00}, {"Blue", 0x03}, {"Green", 0x0c}, {"Red", 0x30},
  {"Cyan", 0x0f}, {"Magenta", 0x33}, {"Yellow", 0x3c}, {"White", 0x3f},
}
local POWER_RATING = {{"1S", 1}, {"2S+", 2}}

local FIELD_META = {
  motor_direction = {choices = MOTOR_DIRECTION},
  rpm_power_slope = {choices = RAMPUP_POWER},
  startup_power_min = {min = 1000, max = 1125},
  startup_power_max = {min = 1004, max = 1300},
  pwm_frequency = {choices = PWM_OLD},
  commutation_timing = {choices = MOTOR_TIMING},
  demag_compensation = {choices = DEMAG},
  brake_on_stop = {choices = ON_OFF},
  braking_strength = {min = 0, max = 255},
  led_control = {choices = LED_CONTROL},
  beep_strength = {min = 0, max = 255},
  beacon_strength = {min = 0, max = 255},
  beacon_delay = {choices = BEACON_DELAY},
  startup_beep = {choices = STARTUP_BEEP_OLD},
  temperature_protection = {choices = TEMP_PROTECTION},
  low_rpm_power_protection = {choices = ON_OFF},
  power_rating = {choices = POWER_RATING},
  force_edt_arm = {choices = ON_OFF},
  dithering = {choices = ON_OFF},
  threshold_48to24 = {min = 0, max = 100, suffix = "%"},
  threshold_96to48 = {min = 0, max = 100, suffix = "%"},
}

local WIRE_FIELDS = {
  {"esc_signature", "u8"},
  {"esc_command", "u8"},
  {"main_revision", "u8"},
  {"sub_revision", "u8"},
  {"layout_revision", "u8"},
  {"reserved_03", "u8"},
  {"startup_power_min", "startup_power_min"},
  {"startup_beep", "u8"},
  {"dithering", "u8"},
  {"startup_power_max", "startup_power_max"},
  {"reserved_08", "u8"},
  {"rpm_power_slope", "u8"},
  {"pwm_frequency", "pwm_frequency"},
  {"motor_direction", "u8"},
  {"reserved_0c", "u8"},
  {"mode_raw", "u16"},
  {"reserved_0f", "u8"},
  {"braking_strength", "u8"},
  {"reserved_11", "u8"},
  {"reserved_12", "u8"},
  {"reserved_13", "u8"},
  {"reserved_14", "u8"},
  {"commutation_timing", "u8"},
  {"reserved_16", "u8"},
  {"reserved_17", "u8"},
  {"reserved_18", "u8"},
  {"reserved_19", "u8"},
  {"reserved_1a", "u8"},
  {"beep_strength", "u8"},
  {"beacon_strength", "u8"},
  {"beacon_delay", "u8"},
  {"reserved_1e", "u8"},
  {"demag_compensation", "u8"},
  {"reserved_20", "u8"},
  {"reserved_21", "u8"},
  {"reserved_22", "u8"},
  {"temperature_protection", "u8"},
  {"low_rpm_power_protection", "u8"},
  {"reserved_25", "u8"},
  {"reserved_26", "u8"},
  {"brake_on_stop", "u8"},
  {"led_control", "u8"},
  {"power_rating", "u8"},
  {"force_edt_arm", "u8"},
  {"threshold_48to24", "threshold"},
  {"threshold_96to48", "threshold"},
}

for i = 0x2d, 0x3f do
  WIRE_FIELDS[#WIRE_FIELDS + 1] = {string.format("reserved_%02x", i), "u8"}
end

local SIMULATOR_RESPONSE = {
  193, 0, 0, 22, 209, 255, 51, 0, 0, 5, 255, 9, 24, 1, 255, 85,
  170, 255, 255, 255, 255, 255, 255, 4, 255, 255, 255, 255, 255, 40, 80, 4,
  255, 2, 255, 255, 255, 0, 1, 255, 255, 0, 0, 2, 0, 170, 85, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
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
  if wireType == "startup_power_min" then return clamp(raw * 1000 / 2047 + 1000, 1000, 1125) end
  if wireType == "startup_power_max" then return clamp(raw * 1000 / 250 + 1000, 1004, 1300) end
  if wireType == "pwm_frequency" and raw == 192 then return 0 end
  if wireType == "threshold" then return clamp(raw * 100 / 255, 0, 100) end
  return raw
end

local function writeValue(payload, wireType, value)
  if wireType == "u16" then
    mspcodec.writeU16(payload, value or 0)
    return
  end
  local raw = value or 0
  if wireType == "startup_power_min" then raw = clamp(((value or 1000) - 1000) * 2047 / 1000, 0, 255) end
  if wireType == "startup_power_max" then raw = clamp(((value or 1004) - 1000) * 250 / 1000, 0, 255) end
  if wireType == "pwm_frequency" and tonumber(value) == 0 then raw = 192 end
  if wireType == "threshold" then raw = clamp((value or 0) * 255 / 100, 0, 255) end
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
  local original96 = data and data.threshold_96to48
  if data and data.threshold_48to24 and data.threshold_96to48 and data.threshold_96to48 > data.threshold_48to24 then
    data.threshold_96to48 = data.threshold_48to24
  end
  for i = 1, #WIRE_FIELDS do
    local field = WIRE_FIELDS[i]
    writeValue(payload, field[2], data and data[field[1]])
  end
  if data then data.threshold_96to48 = original96 end
  return payload
end

local function layout(data)
  return tonumber(data and data.layout_revision) or 0
end

local function supportsLedControl(data)
  local raw = data and data._raw
  local prefix = raw and raw[67]
  return prefix == string.byte("E") or prefix == string.byte("J") or prefix == string.byte("M")
    or prefix == string.byte("Q") or prefix == string.byte("U")
end

local function choicesFor(data, key)
  local rev = layout(data)
  if key == "rpm_power_slope" then
    if rev == 200 then return RAMPUP_START_POWER end
    return RAMPUP_POWER
  end
  if key == "startup_beep" then
    if rev == 205 then return STARTUP_BEEP_205 end
    return STARTUP_BEEP_OLD
  end
  if key == "braking_strength" and rev == 202 then return BRAKING_MODE end
  if key == "pwm_frequency" then
    if rev >= 209 then return PWM_DYNAMIC end
    return PWM_OLD
  end
  return nil
end

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 193,
  FIELD_META = FIELD_META,
  TITLE = "Bluejay",
}

function msp.isCompatible(data)
  return tonumber(data and data.esc_signature) == msp.EXPECTED_SIGNATURE
    and tonumber(data and data.main_revision) == 0
end

function msp.supportsLedControl(data)
  return supportsLedControl(data)
end

function msp.choicesFor(data, key)
  return choicesFor(data, key)
end

function msp.summaryFor(data)
  return string.format("Bluejay / Rev %d / FW%d.%d",
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

package.loaded["rfsuite.lib.msp_esc_parameters_bluejay"] = msp
return msp

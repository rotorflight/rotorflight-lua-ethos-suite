-- XDFLY forward-programming payload (MSP 217 read / 218 write).

if package.loaded["rfsuite.lib.msp_esc_parameters_xdfly"] then
  return package.loaded["rfsuite.lib.msp_esc_parameters_xdfly"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 217
local WRITE_COMMAND = 218

local GOV_MODE = {{"ESC Gov", 0}, {"Ext Gov", 1}, {"FW Gov", 2}}
local LOW_VOLTAGE = {{"Off", 0}, {"2.7V", 1}, {"3.0V", 2}, {"3.2V", 3}, {"3.4V", 4}, {"3.6V", 5}, {"3.8V", 6}}
local TIMING = {{"Auto", 0}, {"Low", 1}, {"Medium", 2}, {"High", 3}}
local BEC_LV = {{"6.0V", 0}, {"7.4V", 1}, {"8.4V", 2}}
local DIRECTION = {{"CW", 0}, {"CCW", 1}}
local ACCEL = {{"Fast", 0}, {"Normal", 1}, {"Slow", 2}, {"Very Slow", 3}}
local AUTO_RESTART = {{"Off", 0}, {"90s", 1}}
local BEC_HV = {{"6.0V", 0}, {"6.2V", 1}, {"6.4V", 2}, {"6.6V", 3}, {"6.8V", 4}, {"7.0V", 5}, {"7.2V", 6}, {"7.4V", 7}, {"7.6V", 8}, {"7.8V", 9}, {"8.0V", 10}, {"8.2V", 11}, {"8.4V", 12}, {"8.6V", 13}, {"8.8V", 14}, {"9.0V", 15}, {"9.2V", 16}, {"9.4V", 17}, {"9.6V", 18}, {"9.8V", 19}, {"10.0V", 20}, {"10.2V", 21}, {"10.4V", 22}, {"10.6V", 23}, {"10.8V", 24}, {"11.0V", 25}, {"11.2V", 26}, {"11.4V", 27}, {"11.6V", 28}, {"11.8V", 29}, {"12.0V", 30}}
local STARTUP_POWER = {{"Low", 0}, {"Medium", 1}, {"High", 2}}
local BRAKE_TYPE = {{"Normal", 0}, {"Reverse", 1}}
local ON_OFF = {{"On", 0}, {"Off", 1}}
local LED_COLOR = {{"Red", 0}, {"Yellow", 1}, {"Orange", 2}, {"Green", 3}, {"Jade Green", 4}, {"Blue", 5}, {"Cyan", 6}, {"Purple", 7}, {"Pink", 8}, {"White", 9}}
local ESC_MODELS = {"RESERVED", "35A", "65A", "85A", "125A", "155A", "130A", "195A", "300A"}

local FIELD_META = {
  governor = {choices = GOV_MODE},
  cell_cutoff = {choices = LOW_VOLTAGE},
  timing = {choices = TIMING},
  lv_bec_voltage = {choices = BEC_LV},
  motor_direction = {choices = DIRECTION},
  gov_p = {min = 1, max = 10, default = 5},
  gov_i = {min = 1, max = 10, default = 5},
  acceleration = {choices = ACCEL},
  auto_restart_time = {choices = AUTO_RESTART},
  hv_bec_voltage = {choices = BEC_HV},
  startup_power = {choices = STARTUP_POWER},
  brake_type = {choices = BRAKE_TYPE},
  brake_force = {min = 0, max = 100, default = 0, suffix = "%"},
  sr_function = {choices = ON_OFF},
  capacity_correction = {min = -10, max = 10, default = 0, suffix = "%"},
  motor_poles = {min = 1, max = 55, default = 10},
  led_color = {choices = LED_COLOR},
  smart_fan = {choices = ON_OFF},
}

local EDIT_FIELDS = {
  "governor",
  "cell_cutoff",
  "timing",
  "lv_bec_voltage",
  "motor_direction",
  "gov_p",
  "gov_i",
  "acceleration",
  "auto_restart_time",
  "hv_bec_voltage",
  "startup_power",
  "brake_type",
  "brake_force",
  "sr_function",
  "capacity_correction",
  "motor_poles",
  "led_color",
  "smart_fan",
}

local FIELD_OFFSETS = {
  gov_p = 1,
  gov_i = 1,
  capacity_correction = -10,
  motor_poles = 1,
}

local ACTIVE_FIELD_POS = {
  governor = 2,
  timing = 4,
  lv_bec_voltage = 5,
  motor_direction = 6,
  gov_p = 6,
  gov_i = 7,
  acceleration = 9,
  auto_restart_time = 10,
  hv_bec_voltage = 11,
  cell_cutoff = 11,
  startup_power = 12,
  brake_force = 14,
  sr_function = 15,
  capacity_correction = 16,
  motor_poles = 17,
  led_color = 18,
  smart_fan = 19,
}

local SIMULATOR_RESPONSE = {
  166, 0, 23, 3,
  0, 0, -- governor
  0, 0, -- cell_cutoff
  0, 0, -- timing
  0, 0, -- lv_bec_voltage
  0, 0, -- motor_direction
  4, 0, -- gov_p
  3, 0, -- gov_i
  0, 0, -- acceleration
  0, 0, -- auto_restart_time
  0, 0, -- hv_bec_voltage
  0, 0, -- startup_power
  0, 0, -- brake_type
  0, 0, -- brake_force
  0, 0, -- sr_function
  0, 0, -- capacity_correction
  9, 0, -- motor_poles
  0, 0, -- led_color
  0, 0, -- smart_fan
  238, 255, 1, 0 -- activefields
}

local function decode(buf)
  buf.offset = 1
  local data = {
    esc_signature = mspcodec.readU8(buf),
    esc_command = mspcodec.readU8(buf),
    esc_model = mspcodec.readU8(buf),
    esc_version = mspcodec.readU8(buf),
  }
  for i = 1, #EDIT_FIELDS do
    local key = EDIT_FIELDS[i]
    data[key] = (mspcodec.readU16(buf) or 0) + (FIELD_OFFSETS[key] or 0)
  end
  data.activefields = mspcodec.readU32(buf) or 0
  return data
end

local function encode(data)
  local payload = {}
  mspcodec.writeU8(payload, data and data.esc_signature or 166)
  mspcodec.writeU8(payload, data and data.esc_command or 0)
  mspcodec.writeU8(payload, data and data.esc_model or 0)
  mspcodec.writeU8(payload, data and data.esc_version or 0)
  for i = 1, #EDIT_FIELDS do
    local key = EDIT_FIELDS[i]
    local value = data and data[key] or 0
    mspcodec.writeU16(payload, value - (FIELD_OFFSETS[key] or 0))
  end
  mspcodec.writeU32(payload, data and data.activefields or 0)
  return payload
end

local msp = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  EXPECTED_SIGNATURE = 166,
  FIELD_META = FIELD_META,
  EDIT_FIELDS = EDIT_FIELDS,
  TITLE = "XDFLY",
}

function msp.isFieldAvailable(data, key)
  local index = ACTIVE_FIELD_POS[key]
  if not index then return true end
  local flags = tonumber(data and data.activefields)
  if flags == nil or flags == 0 then return true end
  return math.floor(flags / (2 ^ (index - 1))) % 2 == 1
end

function msp.summaryFor(data, title)
  local name = title or msp.TITLE
  local firmware = tonumber(data and data.esc_model) or 0
  local modelIndex = tonumber(data and data.esc_version) or 0
  local model = ESC_MODELS[modelIndex] or "UNKNOWN"
  return string.format("%s %s / SW%d.%d",
    name,
    model,
    math.floor(firmware / 16),
    firmware % 16)
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

package.loaded["rfsuite.lib.msp_esc_parameters_xdfly"] = msp
return msp

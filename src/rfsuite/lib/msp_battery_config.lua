-- MSP_BATTERY_CONFIG helper (cmd 32 read / 33 write).

if package.loaded["rfsuite.lib.msp_battery_config"] then
  return package.loaded["rfsuite.lib.msp_battery_config"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 32
local WRITE_COMMAND = 33

local SOURCE_CHOICES = {
  {"@i18n(api.BATTERY_CONFIG.source_none)@", 0},
  {"@i18n(api.BATTERY_CONFIG.source_adc)@", 1},
  {"@i18n(api.BATTERY_CONFIG.source_esc)@", 2},
  {"@i18n(api.BATTERY_CONFIG.source_fbus)@", 3},
}

local FIELDS = {
  {"batteryCapacity", "U16"},
  {"batteryCellCount", "U8"},
  {"voltageMeterSource", "U8"},
  {"currentMeterSource", "U8"},
  {"vbatmincellvoltage", "U16"},
  {"vbatmaxcellvoltage", "U16"},
  {"vbatfullcellvoltage", "U16"},
  {"vbatwarningcellvoltage", "U16"},
  {"lvcPercentage", "U8"},
  {"consumptionWarningPercentage", "U8"},
  {"batteryCapacity_0", "U16"},
  {"batteryCapacity_1", "U16"},
  {"batteryCapacity_2", "U16"},
  {"batteryCapacity_3", "U16"},
  {"batteryCapacity_4", "U16"},
  {"batteryCapacity_5", "U16"},
}

local FIELD_META = {
  batteryCapacity = {min = 0, max = 20000, default = 0, suffix = "mAh"},
  batteryCellCount = {min = 0, max = 24, default = 6},
  voltageMeterSource = {choices = SOURCE_CHOICES},
  currentMeterSource = {choices = SOURCE_CHOICES},
  vbatmincellvoltage = {min = 0, max = 500, default = 330, decimals = 2, suffix = "V"},
  vbatmaxcellvoltage = {min = 0, max = 500, default = 420, decimals = 2, suffix = "V"},
  vbatfullcellvoltage = {min = 0, max = 500, default = 410, decimals = 2, suffix = "V"},
  vbatwarningcellvoltage = {min = 0, max = 500, default = 350, decimals = 2, suffix = "V"},
  lvcPercentage = {min = 0, max = 100, default = 100, suffix = "%"},
  consumptionWarningPercentage = {min = 0, max = 60, default = 35, suffix = "%"},
  batteryCapacity_0 = {min = 0, max = 40000, default = 0, suffix = "mAh"},
  batteryCapacity_1 = {min = 0, max = 40000, default = 0, suffix = "mAh"},
  batteryCapacity_2 = {min = 0, max = 40000, default = 0, suffix = "mAh"},
  batteryCapacity_3 = {min = 0, max = 40000, default = 0, suffix = "mAh"},
  batteryCapacity_4 = {min = 0, max = 40000, default = 0, suffix = "mAh"},
  batteryCapacity_5 = {min = 0, max = 40000, default = 0, suffix = "mAh"},
}

local SIMULATOR_RESPONSE = {
  136, 19,
  6,
  1,
  1,
  74, 1,
  164, 1,
  154, 1,
  94, 1,
  100,
  30,
  232, 3,
  20, 5,
  64, 6,
  108, 7,
  152, 8,
  196, 9,
}

local msp_battery_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
  SOURCE_CHOICES = SOURCE_CHOICES,
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

function msp_battery_config.decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    data[name] = readByType(buf, wireType)
  end
  return data
end

function msp_battery_config.encode(data)
  local payload = {}
  data = data or {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    writeByType(payload, wireType, data[name])
  end
  return payload
end

function msp_battery_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_battery_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_battery_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_battery_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_battery_config"] = msp_battery_config
return msp_battery_config

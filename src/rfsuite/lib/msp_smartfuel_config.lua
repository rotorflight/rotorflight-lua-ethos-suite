-- MSP_SF_CONFIG helper (cmd 0x4000 read / 0x4001 write).

if package.loaded["rfsuite.lib.msp_smartfuel_config"] then
  return package.loaded["rfsuite.lib.msp_smartfuel_config"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 0x4000
local WRITE_COMMAND = 0x4001

local MODE_CHOICES = {
  {"OFF (LOCAL)", 0},
  {"VOLTAGE", 1},
  {"CURRENT", 2},
  {"COMBINED", 3},
}

local FIELDS = {
  {"smartfuel_mode", "U8"},
  {"voltage_drop_rate", "U8"},
  {"charge_drop_rate", "U8"},
  {"sag_gain", "U8"},
}

local FIELD_META = {
  smartfuel_mode = {choices = MODE_CHOICES},
  voltage_drop_rate = {min = 0, max = 250, default = 10, suffix = "mV/s"},
  charge_drop_rate = {min = 0, max = 250, default = 50, decimals = 2, suffix = "%/s"},
  sag_gain = {min = 0, max = 100, default = 40, suffix = "%"},
}

local SIMULATOR_RESPONSE = {
  0,
  10,
  50,
  40,
}

local msp_smartfuel_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
  MODE_CHOICES = MODE_CHOICES,
}

function msp_smartfuel_config.decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #FIELDS do
    data[FIELDS[i][1]] = mspcodec.readU8(buf)
  end
  return data
end

function msp_smartfuel_config.encode(data)
  local payload = {}
  data = data or {}
  for i = 1, #FIELDS do
    mspcodec.writeU8(payload, data[FIELDS[i][1]] or 0)
  end
  return payload
end

function msp_smartfuel_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_smartfuel_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_smartfuel_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_smartfuel_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_smartfuel_config"] = msp_smartfuel_config
return msp_smartfuel_config

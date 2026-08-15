-- Schema + message-builders for MSP_SENSOR_ALIGNMENT /
-- MSP_SET_SENSOR_ALIGNMENT (cmd 126 read / 220 write).

if package.loaded["rfsuite.lib.msp_sensor_alignment"] then
  return package.loaded["rfsuite.lib.msp_sensor_alignment"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 126
local WRITE_COMMAND = 220

local SIMULATOR_RESPONSE = {
  0, -- gyro_1_alignment
  0, -- gyro_2_alignment
  0, -- mag_alignment
}

local FIELD_META = {
  gyro_1_alignment = {min = 0, max = 255, default = 0},
  gyro_2_alignment = {min = 0, max = 255, default = 0},
  mag_alignment = {min = 0, max = 9, default = 0},
}

local msp_sensor_alignment = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELD_META = FIELD_META,
}

function msp_sensor_alignment.decode(buf)
  buf.offset = 1
  return {
    gyro_1_alignment = mspcodec.readU8(buf),
    gyro_2_alignment = mspcodec.readU8(buf),
    mag_alignment = mspcodec.readU8(buf),
  }
end

function msp_sensor_alignment.encode(data)
  local payload = {}
  data = data or {}
  mspcodec.writeU8(payload, data.gyro_1_alignment or 0)
  mspcodec.writeU8(payload, data.gyro_2_alignment or 0)
  mspcodec.writeU8(payload, data.mag_alignment or 0)
  return payload
end

function msp_sensor_alignment.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_sensor_alignment.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_sensor_alignment.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_sensor_alignment.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_sensor_alignment"] = msp_sensor_alignment
return msp_sensor_alignment

-- Schema + message-builders for MSP_BOARD_ALIGNMENT_CONFIG /
-- MSP_SET_BOARD_ALIGNMENT_CONFIG (cmd 38 read / 39 write).
--
-- Firmware declares these fields as U16 on the wire, but the original
-- Alignment page interprets them as signed 16-bit mounting offsets. This
-- codec does that directly so the page can edit plain signed degrees.

if package.loaded["rfsuite.lib.msp_board_alignment_config"] then
  return package.loaded["rfsuite.lib.msp_board_alignment_config"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 38
local WRITE_COMMAND = 39

local SIMULATOR_RESPONSE = {
  0, 0, -- roll_degrees
  0, 0, -- pitch_degrees
  0, 0, -- yaw_degrees
}

local FIELD_META = {
  roll_degrees = {min = -180, max = 360, default = 0, suffix = "°"},
  pitch_degrees = {min = -180, max = 360, default = 0, suffix = "°"},
  yaw_degrees = {min = -180, max = 360, default = 0, suffix = "°"},
}

local msp_board_alignment_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELD_META = FIELD_META,
}

function msp_board_alignment_config.decode(buf)
  buf.offset = 1
  return {
    roll_degrees = mspcodec.readS16(buf),
    pitch_degrees = mspcodec.readS16(buf),
    yaw_degrees = mspcodec.readS16(buf),
  }
end

function msp_board_alignment_config.encode(data)
  local payload = {}
  mspcodec.writeS16(payload, (data and data.roll_degrees) or 0)
  mspcodec.writeS16(payload, (data and data.pitch_degrees) or 0)
  mspcodec.writeS16(payload, (data and data.yaw_degrees) or 0)
  return payload
end

function msp_board_alignment_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_board_alignment_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_board_alignment_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_board_alignment_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_board_alignment_config"] = msp_board_alignment_config
return msp_board_alignment_config

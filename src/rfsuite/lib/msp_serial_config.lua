-- Schema + message-builders for MSP_SERIAL_CONFIG /
-- MSP_SET_SERIAL_CONFIG (cmd 54 read / 55 write).
--
-- The read reply is a packed list of up to 12 serial-port records:
-- identifier(U8), function_mask(U32), msp/gps/telem/blackbox baud indices
-- (U8 each). The write command writes exactly one such record at a time,
-- matching rotorflight-lua-ethos-suite's SERIAL_CONFIG API.

if package.loaded["rfsuite.lib.msp_serial_config"] then
  return package.loaded["rfsuite.lib.msp_serial_config"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 54
local WRITE_COMMAND = 55
local MAX_SERIAL_PORTS = 12
local RECORD_BYTES = 9

local SIMULATOR_RESPONSE = {}
for i = 1, MAX_SERIAL_PORTS do
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = i - 1
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 0
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 0
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 0
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 0
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 0
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 0
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 0
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 0
end

local msp_serial_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  MAX_SERIAL_PORTS = MAX_SERIAL_PORTS,
}

function msp_serial_config.decode(buf)
  buf.offset = 1
  local ports = {}
  local limit = math.floor(#buf / RECORD_BYTES)
  if limit > MAX_SERIAL_PORTS then limit = MAX_SERIAL_PORTS end

  for _ = 1, limit do
    ports[#ports + 1] = {
      identifier = mspcodec.readU8(buf),
      function_mask = mspcodec.readU32(buf),
      msp_baud_index = mspcodec.readU8(buf),
      gps_baud_index = mspcodec.readU8(buf),
      telem_baud_index = mspcodec.readU8(buf),
      blackbox_baud_index = mspcodec.readU8(buf),
    }
  end

  return {ports = ports}
end

function msp_serial_config.encode(port)
  local payload = {}
  port = port or {}
  mspcodec.writeU8(payload, port.identifier or 0)
  mspcodec.writeU32(payload, port.function_mask or 0)
  mspcodec.writeU8(payload, port.msp_baud_index or 0)
  mspcodec.writeU8(payload, port.gps_baud_index or 0)
  mspcodec.writeU8(payload, port.telem_baud_index or 0)
  mspcodec.writeU8(payload, port.blackbox_baud_index or 0)
  return payload
end

function msp_serial_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_serial_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_serial_config.buildWriteMessage(port, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_serial_config.encode(port),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_serial_config"] = msp_serial_config
return msp_serial_config

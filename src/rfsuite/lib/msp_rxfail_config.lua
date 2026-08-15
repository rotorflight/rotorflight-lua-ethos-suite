-- MSP_RXFAIL_CONFIG helper (cmd 77 read / 78 write).
--
-- Read returns up to 18 RC-channel failsafe records: mode(U8), value(U16).
-- Write updates one channel at a time, matching the firmware/API shape.

if package.loaded["rfsuite.lib.msp_rxfail_config"] then
  return package.loaded["rfsuite.lib.msp_rxfail_config"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 77
local WRITE_COMMAND = 78
local CHANNEL_COUNT = 18
local RECORD_BYTES = 3

local SIMULATOR_RESPONSE = {}
for _ = 1, CHANNEL_COUNT do
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 0
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 220
  SIMULATOR_RESPONSE[#SIMULATOR_RESPONSE + 1] = 5
end

local msp_rxfail_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  CHANNEL_COUNT = CHANNEL_COUNT,
}

function msp_rxfail_config.decode(buf)
  buf.offset = 1
  local channels = {}
  local count = math.floor(#buf / RECORD_BYTES)
  if count > CHANNEL_COUNT then count = CHANNEL_COUNT end
  for i = 1, count do
    channels[i] = {
      mode = mspcodec.readU8(buf),
      value = mspcodec.readU16(buf),
    }
  end
  return {channels = channels}
end

function msp_rxfail_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_rxfail_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_rxfail_config.buildWriteMessage(index, channel, onWritten, onError)
  channel = channel or {}
  local payload = {index - 1}
  mspcodec.writeU8(payload, channel.mode or 0)
  mspcodec.writeU16(payload, channel.value or 1500)
  return {
    command = WRITE_COMMAND,
    payload = payload,
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_rxfail_config"] = msp_rxfail_config
return msp_rxfail_config

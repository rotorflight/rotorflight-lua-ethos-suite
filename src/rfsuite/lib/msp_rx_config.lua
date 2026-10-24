-- Schema + message-builder for MSP_RX_CONFIG (cmd 44).
--
-- Ports only needs serialrx_provider today, but decodes the full wire
-- layout from rotorflight-lua-ethos-suite's RX_CONFIG API so the payload
-- is consumed in the same order and can grow without revisiting the
-- command shape.

if package.loaded["rfsuite.lib.msp_rx_config"] then
  return package.loaded["rfsuite.lib.msp_rx_config"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 44
local WRITE_COMMAND = 45

-- The wire layout, in order: the same for the read and the write (the
-- Configurator's MSP_SET_RX_CONFIG). pinSwap is only in newer firmware, so
-- it is written only when the read gave it.
local FIELDS = {
  {"serialrx_provider", "U8"}, {"serialrx_inverted", "U8"}, {"halfDuplex", "U8"},
  {"rx_pulse_min", "U16"}, {"rx_pulse_max", "U16"}, {"rx_spi_protocol", "U8"},
  {"rx_spi_id", "U32"}, {"rx_spi_rf_channel_count", "U8"}, {"pinSwap", "U8"},
}

local SIMULATOR_RESPONSE = {
  0,       -- serialrx_provider
  0,       -- serialrx_inverted
  0,       -- halfDuplex
  107, 3,  -- rx_pulse_min
  77, 8,   -- rx_pulse_max
  0,       -- rx_spi_protocol
  0, 0, 0, 0,
  0,       -- rx_spi_rf_channel_count
  0,       -- pinSwap
}

local msp_rx_config = {
  READ_COMMAND = READ_COMMAND,
}

function msp_rx_config.decode(buf)
  buf.offset = 1
  return {
    serialrx_provider = mspcodec.readU8(buf),
    serialrx_inverted = mspcodec.readU8(buf),
    halfDuplex = mspcodec.readU8(buf),
    rx_pulse_min = mspcodec.readU16(buf),
    rx_pulse_max = mspcodec.readU16(buf),
    rx_spi_protocol = mspcodec.readU8(buf),
    rx_spi_id = mspcodec.readU32(buf),
    rx_spi_rf_channel_count = mspcodec.readU8(buf),
    pinSwap = mspcodec.readU8(buf),
  }
end

function msp_rx_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_rx_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_rx_config.encode(data)
  local payload = {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    local value = data[name]
    if value ~= nil or name ~= "pinSwap" then
      if wireType == "U16" then
        mspcodec.writeU16(payload, value or 0)
      elseif wireType == "U32" then
        mspcodec.writeU32(payload, value or 0)
      else
        mspcodec.writeU8(payload, value or 0)
      end
    end
  end
  return payload
end

function msp_rx_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_rx_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_rx_config"] = msp_rx_config
return msp_rx_config

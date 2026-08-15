-- Factory for MSP mixer-input records (cmd 174 read / 171 write).
--
-- The command payload selects a fixed input index:
--   roll=1, pitch=2, yaw=3, collective=4.
-- Replies contain only rate/min/max for that selected input; writes send
-- the index followed by the same three U16 values.

if package.loaded["rfsuite.lib.msp_mixer_input"] then
  return package.loaded["rfsuite.lib.msp_mixer_input"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 174
local WRITE_COMMAND = 171

local SIMULATOR_RESPONSE = {
  250, 0,  -- rate = 250
  30, 251, -- min = -1250
  226, 4,  -- max = 1250
}

local function new(index, rateKey, minKey, maxKey)
  local module = {
    READ_COMMAND = READ_COMMAND,
    WRITE_COMMAND = WRITE_COMMAND,
    INDEX = index,
  }

  function module.decode(buf)
    buf.offset = 1
    return {
      [rateKey] = mspcodec.readU16(buf),
      [minKey] = mspcodec.readU16(buf),
      [maxKey] = mspcodec.readU16(buf),
    }
  end

  function module.encode(data)
    data = data or {}
    local payload = {}
    mspcodec.writeU8(payload, index)
    mspcodec.writeU16(payload, data[rateKey] or 0)
    mspcodec.writeU16(payload, data[minKey] or 0)
    mspcodec.writeU16(payload, data[maxKey] or 0)
    return payload
  end

  function module.buildReadMessage(onData, onError)
    return {
      command = READ_COMMAND,
      payload = {index},
      processReply = function(_, buf)
        onData(module.decode(buf))
      end,
      errorHandler = onError,
      simulatorResponse = SIMULATOR_RESPONSE,
    }
  end

  function module.buildWriteMessage(data, onWritten, onError)
    return {
      command = WRITE_COMMAND,
      payload = module.encode(data),
      isWrite = true,
      processReply = function()
        if onWritten then onWritten() end
      end,
      errorHandler = onError,
      simulatorResponse = {},
    }
  end

  return module
end

local msp_mixer_input = {
  new = new,
  roll = function() return new(1, "rate_stabilized_roll", "min_stabilized_roll", "max_stabilized_roll") end,
  pitch = function() return new(2, "rate_stabilized_pitch", "min_stabilized_pitch", "max_stabilized_pitch") end,
  yaw = function() return new(3, "rate_stabilized_yaw", "min_stabilized_yaw", "max_stabilized_yaw") end,
  collective = function() return new(4, "rate_stabilized_collective", "min_stabilized_collective", "max_stabilized_collective") end,
}

package.loaded["rfsuite.lib.msp_mixer_input"] = msp_mixer_input
return msp_mixer_input

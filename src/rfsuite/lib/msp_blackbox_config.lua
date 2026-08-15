-- MSP_BLACKBOX_CONFIG helper (cmd 80 read / 81 write).

if package.loaded["rfsuite.lib.msp_blackbox_config"] then
  return package.loaded["rfsuite.lib.msp_blackbox_config"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 80
local WRITE_COMMAND = 81

local SIMULATOR_RESPONSE = {
  1, -- blackbox_supported
  1, -- device
  1, -- mode
  8, 0, -- denom
  127, 238, 7, 0, -- fields
  0, 0, -- initialEraseFreeSpaceKiB
  0, -- rollingErase
  5, -- gracePeriod
}

local msp_blackbox_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
}

function msp_blackbox_config.defaultConfig()
  return {
    blackbox_supported = 0,
    device = 0,
    mode = 0,
    denom = 8,
    fields = 0,
    initialEraseFreeSpaceKiB = 0,
    rollingErase = 0,
    gracePeriod = 5,
  }
end

function msp_blackbox_config.clone(config)
  config = config or {}
  return {
    blackbox_supported = tonumber(config.blackbox_supported or 0) or 0,
    device = tonumber(config.device or 0) or 0,
    mode = tonumber(config.mode or 0) or 0,
    denom = tonumber(config.denom or 8) or 8,
    fields = tonumber(config.fields or 0) or 0,
    initialEraseFreeSpaceKiB = tonumber(config.initialEraseFreeSpaceKiB or 0) or 0,
    rollingErase = tonumber(config.rollingErase or 0) or 0,
    gracePeriod = tonumber(config.gracePeriod or 5) or 5,
  }
end

function msp_blackbox_config.decode(buf)
  buf.offset = 1
  local config = msp_blackbox_config.defaultConfig()
  config.blackbox_supported = mspcodec.readU8(buf)
  config.device = mspcodec.readU8(buf)
  config.mode = mspcodec.readU8(buf)
  config.denom = mspcodec.readU16(buf)
  config.fields = mspcodec.readU32(buf)
  if #buf >= 11 then config.initialEraseFreeSpaceKiB = mspcodec.readU16(buf) end
  if #buf >= 12 then config.rollingErase = mspcodec.readU8(buf) end
  if #buf >= 13 then config.gracePeriod = mspcodec.readU8(buf) end
  return config
end

function msp_blackbox_config.same(a, b)
  a = a or {}
  b = b or {}
  return (a.device or 0) == (b.device or 0)
    and (a.mode or 0) == (b.mode or 0)
    and (a.denom or 0) == (b.denom or 0)
    and (a.fields or 0) == (b.fields or 0)
    and (a.initialEraseFreeSpaceKiB or 0) == (b.initialEraseFreeSpaceKiB or 0)
    and (a.rollingErase or 0) == (b.rollingErase or 0)
    and (a.gracePeriod or 0) == (b.gracePeriod or 0)
end

function msp_blackbox_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_blackbox_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_blackbox_config.buildWriteMessage(config, onWritten, onError)
  config = msp_blackbox_config.clone(config)
  local payload = {}
  mspcodec.writeU8(payload, config.device)
  mspcodec.writeU8(payload, config.mode)
  mspcodec.writeU16(payload, config.denom)
  mspcodec.writeU32(payload, config.fields)
  mspcodec.writeU16(payload, config.initialEraseFreeSpaceKiB)
  mspcodec.writeU8(payload, config.rollingErase)
  mspcodec.writeU8(payload, config.gracePeriod)
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

package.loaded["rfsuite.lib.msp_blackbox_config"] = msp_blackbox_config
return msp_blackbox_config
